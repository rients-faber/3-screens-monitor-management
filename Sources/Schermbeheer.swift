import AppKit
import ServiceManagement

// MARK: - Model

enum Side: String, CaseIterable {
    case left, right

    var title: String { self == .left ? "Linker scherm" : "Rechter scherm" }
}

/// How a screen is drawn in the menu bar icon.
enum IconState {
    case on        // outlined rectangle
    case off       // filled rectangle (black screen)
    case missing   // thin dashed rectangle (not connected)
}

// MARK: - Black overlay window

/// A borderless, pure-black window that covers an entire screen
/// (including the menu bar and Dock on that screen). The display keeps
/// its power and signal; it simply shows black.
final class BlackoutWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class BlackoutView: NSView {
    var onDoubleClick: (() -> Void)?

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Double-click on a black screen turns it back on.
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onDoubleClick?() }
    }
}

// MARK: - App controller

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var windows: [Side: BlackoutWindow] = [:]
    private var offSides: Set<Side> = []
    private let defaultsKey = "offSides"

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        offSides = Set((UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
            .compactMap(Side.init(rawValue:)))

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Klik links/rechts op het icoon om dat scherm aan of uit te zetten.\nKlik in het midden of rechtsklik voor het menu."
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        refresh()
    }

    @objc private func screensChanged() {
        refresh()
    }

    // MARK: Screen layout

    private func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }

    /// Determines which physical screen is left, middle (the iMac) and right.
    private func layout() -> (left: NSScreen?, middle: NSScreen?, right: NSScreen?) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return (nil, nil, nil) }

        // The iMac's own display is the built-in one; fall back to the primary screen.
        let middle = screens.first { CGDisplayIsBuiltin(displayID(of: $0)) != 0 } ?? screens[0]
        let others = screens
            .filter { $0 !== middle }
            .sorted { $0.frame.midX < $1.frame.midX }

        var left: NSScreen?
        var right: NSScreen?
        if others.count >= 2 {
            left = others.first
            right = others.last
        } else if let only = others.first {
            if only.frame.midX < middle.frame.midX { left = only } else { right = only }
        }
        return (left, middle, right)
    }

    private func screen(for side: Side) -> NSScreen? {
        let l = layout()
        return side == .left ? l.left : l.right
    }

    // MARK: Actions

    private func toggle(_ side: Side) {
        guard screen(for: side) != nil else { NSSound.beep(); return }
        if offSides.contains(side) { offSides.remove(side) } else { offSides.insert(side) }
        save()
        refresh()
    }

    private func setOn(_ side: Side) {
        offSides.remove(side)
        save()
        refresh()
    }

    private func save() {
        UserDefaults.standard.set(offSides.map(\.rawValue), forKey: defaultsKey)
    }

    /// Brings windows and the menu bar icon in line with the current state.
    private func refresh() {
        for side in Side.allCases {
            if offSides.contains(side), let screen = screen(for: side) {
                showBlackout(side, on: screen)
            } else {
                windows[side]?.orderOut(nil)
                windows[side] = nil
            }
        }
        updateIcon()
    }

    private func showBlackout(_ side: Side, on screen: NSScreen) {
        let window: BlackoutWindow
        if let existing = windows[side] {
            window = existing
        } else {
            window = BlackoutWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.animationBehavior = .none

            let view = BlackoutView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.autoresizingMask = [.width, .height]
            view.onDoubleClick = { [weak self] in self?.setOn(side) }
            window.contentView = view
            windows[side] = window
        }
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
    }

    // MARK: Status item

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
            return
        }

        let point = sender.convert(event.locationInWindow, from: nil)
        let fraction = sender.bounds.width > 0 ? point.x / sender.bounds.width : 0.5
        if fraction < 1.0 / 3.0 {
            toggle(.left)
        } else if fraction > 2.0 / 3.0 {
            toggle(.right)
        } else {
            showMenu()
        }
    }

    private func updateIcon() {
        let l = layout()
        func state(_ side: Side, _ screen: NSScreen?) -> IconState {
            guard screen != nil else { return .missing }
            return offSides.contains(side) ? .off : .on
        }
        statusItem.button?.image = makeIcon(
            left: state(.left, l.left),
            middle: .on,
            right: state(.right, l.right)
        )
    }

    private func makeIcon(left: IconState, middle: IconState, right: IconState) -> NSImage {
        let rectW: CGFloat = 18
        let rectH: CGFloat = 13
        let gap: CGFloat = 6
        let size = NSSize(width: rectW * 3 + gap * 2 + 2, height: 20)

        let image = NSImage(size: size, flipped: false) { bounds in
            NSColor.black.set()
            let y = ((bounds.height - rectH) / 2).rounded()
            for (index, state) in [left, middle, right].enumerated() {
                let rect = NSRect(x: 1 + CGFloat(index) * (rectW + gap), y: y, width: rectW, height: rectH)
                switch state {
                case .on:
                    let path = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
                    path.lineWidth = 2
                    path.stroke()
                case .off:
                    NSBezierPath(rect: rect).fill()
                case .missing:
                    let path = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
                    path.lineWidth = 1
                    path.setLineDash([1.5, 1.5], count: 2, phase: 0)
                    path.stroke()
                }
            }
            return true
        }
        image.isTemplate = true // adapts to light/dark menu bar
        return image
    }

    // MARK: Menu

    private func showMenu() {
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let l = layout()

        for side in Side.allCases {
            let connected = (side == .left ? l.left : l.right) != nil
            let title = connected ? side.title : "\(side.title) (niet aangesloten)"
            let item = NSMenuItem(title: title, action: #selector(menuToggle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = side.rawValue
            item.state = connected && !offSides.contains(side) ? .on : .off
            item.isEnabled = connected
            menu.addItem(item)

            if side == .left {
                let mid = NSMenuItem(title: "Middelste scherm (iMac) – altijd aan", action: nil, keyEquivalent: "")
                mid.state = .on
                mid.isEnabled = false
                menu.addItem(mid)
            }
        }

        menu.addItem(.separator())
        let allOn = NSMenuItem(title: "Alle schermen aan", action: #selector(allScreensOn), keyEquivalent: "")
        allOn.target = self
        allOn.isEnabled = !offSides.isEmpty
        menu.addItem(allOn)

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Start bij inloggen", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Stop Schermbeheer", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func menuToggle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let side = Side(rawValue: raw) else { return }
        toggle(side)
    }

    @objc private func allScreensOn() {
        offSides.removeAll()
        save()
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Kon 'Start bij inloggen' niet aanpassen"
            alert.informativeText = "\(error.localizedDescription)\n\nZorg dat Schermbeheer in de map Programma's (Applications) staat."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func quit() {
        // Turn every screen back on before quitting.
        for window in windows.values { window.orderOut(nil) }
        NSApp.terminate(nil)
    }
}

// MARK: - Entry point

@main
struct SchermbeheerMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let controller = AppController()
        app.delegate = controller
        app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        withExtendedLifetime(controller) {
            app.run()
        }
    }
}
