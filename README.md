# LTOBackup – Windows-Software für Backups auf LTO-Bandlaufwerke

LTOBackup ist ein Windows-Programm zum Sichern und Wiederherstellen von Dateien und Ordnern auf LTO-Bandlaufwerken. Die Anwendung bietet eine grafische Oberfläche, einen lokalen Bandkatalog und speicherbare Sicherungsaufträge.

**Aktuelle Version:** [LTOBackup-Portable-v1.0.0-win64](https://github.com/Software-Schuhmann/LTOBackup/releases/latest)

## Kompatibilität

- Entwickelt und getestet mit LTO-2-Bandlaufwerken
- Andere LTO-Generationen und Windows-kompatible Bandlaufwerke können möglicherweise verwendet werden, sind aber derzeit nicht vollständig verifiziert
- Voraussetzung ist ein Windows-Tape-Treiber, über den das Laufwerk als Tape-Gerät erreichbar ist
- Das Programm verwendet feste 64-KiB-Blöcke. Das Laufwerk und der Treiber müssen diese Blockgröße unterstützen
- Die Anwendung verwendet ein eigenes Backup-Format und kann keine fremden Formate wie LTFS, TAR oder Backup-Sätze anderer Programme lesen
- Die Kompatibilität hängt vom Laufwerk, dem Band, dem Treiber, der Schnittstelle und der Windows-Konfiguration ab

Für produktive Daten sollte die Kombination aus Laufwerk und Band zunächst mit einem Test-Backup, einer Rücksicherung und der optionalen byteweisen Abschlussprüfung überprüft werden.

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

Beim Anhängen wird die Band-ID geprüft. 

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
- Getestetes oder kompatibles Bandlaufwerk mit passendem Windows-Tape-Treiber
- Schreib- und Leserechte für die ausgewählten Quelldateien und Zielordner
- `sqlite3.dll` neben der ausführbaren Datei
- Für automatisierte Sicherungen: gespeicherter Sicherungsauftrag und entsprechend eingerichtete Windows-Aufgabe

## Installation und Verwendung

1. Die aktuelle portable Version aus den [Releases](https://github.com/Software-Schuhmann/LTOBackup/releases/latest) herunterladen.
2. Das Archiv in einen eigenen Programmordner entpacken.
3. Prüfen, dass `LTOBackup.exe` und `sqlite3.dll` im selben Ordner liegen.
4. Das Bandlaufwerk unter Windows installieren und das Band vollständig laden.
5. LTOBackup starten, Quelldateien auswählen und einen Sicherungsauftrag erstellen.

Vor dem ersten produktiven Einsatz sollte eine Datei testweise gesichert und wiederhergestellt werden. Die Anwendung ersetzt keine zusätzliche Sicherung auf einem zweiten Medium.

## Daten und Kataloge

Die Katalog- und Auftragsdatenbanken werden in folgenden Unterordnern neben der Programmdatei angelegt:

- `Catalogs\catalog.sqlite3` - lokaler Bandkatalog
- `BackupJobs\backup_jobs.sqlite3` - gespeicherte Sicherungsaufträge

Sie enthalten Verwaltungsinformationen und ersetzen nicht die eigentliche Sicherung auf Band.

## Technische Hinweise

Das Programm verwendet derzeit Windows-spezifische Tape- und Gerätefunktionen. Eine Linux-Kompilierung ist mit dem aktuellen Quellstand nicht ohne Portierung der Hardware-Schicht möglich.

Die Banddaten werden nicht als allgemeines Austauschformat geschrieben. LTOBackup kann daher nur Sicherungen lesen, die mit dem eigenen Backup-Format von LTOBackup erstellt wurden.

Eine ausführliche Schritt-für-Schritt-Anleitung befindet sich in [`Bedienungsanleitung_LTO.pdf`](Bedienungsanleitung_LTO.pdf).

# Lizenzbedingungen (Source-Available)

Diese Software wird unter einer dualen, quelloffenen, aber proprietären Lizenz bereitgestellt. Durch die Nutzung, das Kopieren oder Modifizieren dieser Software erklären Sie sich mit den folgenden Bedingungen einverstanden.

## 1. Private und nicht-kommerzielle Nutzung
* Die Nutzung, Modifikation und Vervielfältigung dieser Software für rein private, schulische, akademische oder sonstige nicht-kommerzielle Zwecke ist **vollständig kostenlos**.
* Der Quellcode darf für diese Zwecke frei eingesehen und angepasst werden.

## 2. Kommerzielle Nutzung
* Jede Nutzung dieser Software (oder von Teilen davon) innerhalb eines kommerziellen Umfelds, für geschäftliche Zwecke, durch Unternehmen, Freiberufler oder zur Erzielung von Einnahmen ist **kostenpflichtig**.
* Für die kommerzielle Nutzung muss vorab eine kommerzielle Lizenz zum Preis von **39,00 EUR (einmalig)** erworben werden.
* Eine kommerzielle Lizenz kann unter folgendem Link erworben werden: info@softwareschuhmann.de

## 3. Weiterverbreitung
* Es ist nicht gestattet, diesen Quellcode als eigenen Dienst oder als eigenes Produkt (weder kostenlos noch kostenpflichtig) weiterzuverkaufen oder zu vertreiben, ohne dass die Endnutzer an diese Lizenz gebunden sind.

## 4. Haftungsausschluss
Diese Software wird "wie besehen" (as is) und ohne jegliche ausdrückliche oder stillschweigende Gewährleistung bereitgestellt. Der Urheber haftet nicht für Schäden, die durch die Nutzung dieser Software entstehen.



# License Terms (Source-Available)

This software is provided under a dual, source-available, proprietary license. By using, copying, or modifying this software, you agree to the following terms and conditions.

## 1. Private and Non-Commercial Use
* Using, modifying, and copying this software for purely private, educational, academic, or other non-commercial purposes is **completely free of charge**.
* The source code may be freely viewed and customized for these purposes.

## 2. Commercial Use
* Any use of this software (or parts of it) within a commercial environment, for business purposes, by companies, freelancers, or to generate revenue **requires a paid license**.
* For commercial use, a commercial license must be purchased in advance for a one-time fee of **39.00 EUR**.
* A commercial license can be purchased at the following link: info@softwareschuhmann.de

## 3. Redistribution
* You are not allowed to resell or redistribute this source code as your own standalone service or product (neither free nor paid) unless the end-users are bound by this exact license.

## 4. Disclaimer of Warranty
This software is provided "as is" without warranty of any kind, either express or implied. In no event shall the author be liable for any claim, damages, or other liability arising from the use of this software.

