# Schermbeheer

Menubalk-app voor een iMac met drie schermen. Boven in de menubalk staat een icoon met drie
rechthoekjes (links – iMac – rechts):

| Icoon | Betekenis |
|-------|-----------|
| ▭ open rechthoek | scherm staat aan |
| ▬ gevulde rechthoek | scherm is zwart (sluimer) |
| ┄ stippellijn | scherm niet aangesloten |

## Gebruik

- **Klik op het linker rechthoekje** → linker scherm zwart / weer aan.
- **Klik op het rechter rechthoekje** → rechter scherm zwart / weer aan.
- **Klik in het midden of rechtsklik** → menu met:
  - Linker / Rechter scherm aan/uit
  - Alle schermen aan
  - **Start bij inloggen** (vinkje aan/uit)
  - Stop Schermbeheer
- **Dubbelklik op een zwart scherm** zet het ook weer aan.

Het middelste scherm (de iMac zelf) blijft altijd aan. Een "uit"-scherm krijgt een volledig zwart
venster eroverheen; het scherm blijft aangesloten en houdt stroom. De app onthoudt welke schermen
uit stonden. Bij "Stop" gaan alle schermen weer aan.

## Installeren

1. Download `Schermbeheer-x.y.z.dmg` (zie *Releases*, of het artefact van de laatste
   *Build DMG*-run onder *Actions*).
2. Open de DMG en sleep **Schermbeheer** naar **Programma's (Applications)**.
3. De app is niet door Apple genotariseerd. Eerste keer openen:
   - Open de app; macOS weigert hem.
   - Ga naar **Systeeminstellingen → Privacy en beveiliging** en klik onderaan op
     **Open toch**.
   - Of in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/Schermbeheer.app
     ```

Vereist macOS 13 (Ventura) of nieuwer. Werkt op Apple Silicon en Intel.

## Zelf bouwen (op een Mac)

```bash
./build.sh
```

De DMG komt in `build/`. Elke push naar GitHub bouwt de DMG ook automatisch via GitHub Actions;
een tag `v1.2.3` maakt er een release van.
