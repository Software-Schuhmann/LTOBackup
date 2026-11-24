[README.md](https://github.com/user-attachments/files/35278569/README.md)
# LTO Band Backup 

LTO Backup ist ein Windows-Programm zum Sichern und Wiederherstellen von Dateien und Ordnern auf Bandlaufwerken. Es bietet eine grafische Oberfläche, einen lokalen Katalog und speicherbare Sicherungsaufträge.

## Funktionen

- Einzelne Dateien und ganze Ordner als Sicherungsquellen auswählen
- Sicherungen auf ein Band schreiben oder an vorhandene Sicherungsdaten anhängen
- Beim Anhängen die Band-ID prüfen, damit nicht versehentlich an ein anderes Band angehängt wird
- Bandkatalog einlesen und Ordner sowie Dateien durchsuchen
- Lokalen Katalog verwenden oder mit „Inh. verz. aktualisieren“ vollständig neu vom Band einlesen
- Ausgewählte Dateien und Ordner an einen frei wählbaren Zielort zurücksichern
- Katalogdaten lokal in einer SQLite-Datenbank verwalten
- Sicherungsaufträge speichern, laden, umbenennen und löschen
- Gespeicherte Aufträge im Hintergrund prüfen und automatisch auf geänderte Quellen aktualisieren
- Fortschritt, aktuelle Datei und geschätzte Restzeit anzeigen
- Fehlerhafte oder nicht lesbare Quelldateien protokollieren und überspringen
- Hardware-Kompression und byteweise Abschlussprüfung optional aktivieren
- Optional das Band nach erfolgreichem Backup auswerfen und den PC herunterfahren
- Sicherungsaufträge per Startparameter für die Windows-Aufgabenplanung ausführen

## Automatischer Start

Ein gespeicherter Sicherungsauftrag kann über seinen Namen als Programmargument gestartet werden:

```text
LTOBackup.exe "Name des Sicherungsauftrags"
```

Der Auftrag wird aus der lokalen SQLite-Auftragsdatenbank geladen. Der eingestellte Sicherungsmodus (Band neu beschreiben oder an vorhandenes Backup anhängen) gilt auch beim automatischen Start.

## Optionen

Über `Datei -> Optionen ...` können folgende Einstellungen gespeichert werden:

- Hardware-Kompression verwenden
- An vorhandenes Backup anhängen
- Dateiinhalte nach dem Schreiben byteweise prüfen
- Nach erfolgreichem Backup den PC herunterfahren

Beim Anhängen wird die Band-ID geprüft. Ein älteres Backup-Format ohne Band-ID kann nicht sicher erweitert werden.

## Erzeugen

Der Release-Build wird im Projektverzeichnis mit Lazarus erzeugt:

```text
C:\fpcupdeluxe\5\lazarus\lazbuild.exe --build-mode=Release LTO.lpi
```

Die ausführbare Datei liegt anschließend unter:

```text
Release\win64\LTOBackup.exe
```

## Voraussetzungen

- Windows
- Unterstütztes und korrekt eingerichtetes Bandlaufwerk mit passendem Treiber (SCSI)
- Schreib- und Leserechte für die ausgewählten Quelldateien und Zielordner
- `sqlite3.dll` neben der ausführbaren Datei
- Für automatisierte Sicherungen: gespeicherter Sicherungsauftrag und entsprechend eingerichtete Windows-Aufgabe

## Daten und Kataloge

Die Katalog- und Auftragsdatenbanken werden in folgenden Unterordnern neben der Programmdatei angelegt:

- `Catalogs\catalog.sqlite3` - lokaler Bandkatalog
- `BackupJobs\backup_jobs.sqlite3` - gespeicherte Sicherungsaufträge

Sie enthalten Verwaltungsinformationen und ersetzen nicht die eigentliche Sicherung auf Band.

## Hinweis

Das Programm verwendet derzeit Windows-spezifische Tape- und Gerätefunktionen. Eine Linux-Kompilierung ist mit dem aktuellen Quellstand nicht ohne Portierung der Hardware-Schicht möglich.

Eine ausführliche Schritt-für-Schritt-Anleitung befindet sich in [`Bedienungsanleitung_LTO.pdf`](Bedienungsanleitung_LTO.pdf).
