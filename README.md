# Selettore Colore (ColorPointer)

App per macOS che, premendo una scorciatoia, mostra accanto al puntatore il **nome del colore in italiano** (es. "Rosso scuro", "Azzurro chiaro"). Non ritaglia né salva nulla: muovi il mouse e il nome cambia in tempo reale. Pensata per chi ha difficoltà a distinguere i colori.

- Scorciatoia predefinita: **⌘⌥4** (personalizzabile dalle Preferenze)
- Per uscire: premi di nuovo la scorciatoia oppure **Esc**
- Icona nella barra dei menu, nessuna icona nel Dock
- Opzioni: codice esadecimale (#RRGGBB) e dimensione del testo (Normale / Grande / Molto grande)

## Download

Non vuoi compilarla? Scarica `ColorPointer.zip` dalla pagina [Releases](../../releases), decomprimi e segui il file `LEGGIMI.txt` incluso (l'app non è firmata da Apple, quindi al primo avvio serve un passaggio manuale).

## Requisiti

- macOS 13 o successivo
- Xcode o Command Line Tools (per compilare)

## Compilazione

```bash
cd ColorPointer
./build.sh
```

Il risultato è `build/ColorPointer.app`. Trascinala in Applicazioni se vuoi tenerla.

## Primo avvio: permesso di registrazione dello schermo

Per leggere il colore sotto il puntatore, macOS richiede il permesso **Registrazione dello schermo**:

1. Apri **Impostazioni di Sistema › Privacy e sicurezza › Registrazione dello schermo**.
2. Attiva **ColorPointer**.
3. Riavvia l'app.

L'app non registra né invia nulla: legge solo il pixel sotto il cursore.

## Personalizzare la scorciatoia

Icona nella barra dei menu › **Preferenze…** › pulsante della scorciatoia → premi la nuova combinazione (deve includere ⌘, ⌥ o ⌃). **Esc** annulla. "Ripristina predefinita" torna a ⌘⌥4.

Se una combinazione è già usata dal sistema o da un'altra app, l'app te lo segnala e puoi sceglierne un'altra.

## Struttura del progetto

| File | Contenuto |
|---|---|
| `Sources/ColorPointer/main.swift` | App delegate, barra dei menu, attivazione |
| `Sources/ColorPointer/HotkeyManager.swift` | Scorciatoie globali (Carbon, nessun permesso di Accessibilità) |
| `Sources/ColorPointer/Shortcut.swift` | Salvataggio e visualizzazione della scorciatoia |
| `Sources/ColorPointer/PointerOverlay.swift` | Campionamento del colore e etichetta che segue il cursore |
| `Sources/ColorPointer/ColorNamer.swift` | Conversione RGB → nome italiano |
| `Sources/ColorPointer/Preferences.swift` | Finestra Preferenze e impostazioni |
| `Resources/Info.plist` | Configurazione del bundle (`LSUIElement`, niente Dock) |

## Come vengono scelti i nomi

Il colore viene convertito in HSV: la tonalità decide il nome base (rosso, arancione, giallo, verde, ciano, azzurro, blu, viola, fucsia, marrone), la luminosità aggiunge "chiaro" o "scuro". I colori poco saturi diventano bianco, nero o grigio. Puoi modificare le soglie in `ColorNamer.swift`.

## Contribuire

Idee, segnalazioni di bug e pull request sono benvenute, soprattutto per nuove lingue, nomi di colori più precisi e miglioramenti per l'accessibilità. Apri una [issue](../../issues) per discutere prima di modifiche grandi.

## Licenza

Rilasciato con licenza MIT: vedi il file [LICENSE](LICENSE).
