<div align="center">

# Accurova Ingest

**A Windows PowerShell GUI tool that ingests SD card photos and video into a dated vault — sorted by EXIF date, deduped, verified, then ready to format.**

![Version](https://img.shields.io/badge/version-1.1.0-00D4C8)
![PowerShell](https://img.shields.io/badge/-PowerShell-5391FE?logo=powershell&logoColor=white)
![License](https://img.shields.io/badge/license-AGPLv3%20%2F%20Commercial-00D4C8.svg)

</div>

---

## What it does

Accurova Ingest is a Windows PowerShell GUI utility for photographers and videographers. It auto-detects the SD card, reads EXIF capture dates via ExifTool, and sorts your RAW, video, and auxiliary/proxy footage into a structured vault (`Dest\YYYY_MM\YYYY_MM_DD [Event] [Location]\`) — skipping duplicates, flagging orphan JPGs, and verifying the copy before you format the card. It's camera-agnostic: tell it your RAW/video/aux file extensions once (Canon CR2/CR3, Sony ARW, Fujifilm RAF, GoPro/Insta360 LRV/INSV, etc.) and it works the same as it does for a Nikon NEF shooter. Config is persisted to a local JSON file so your vault path, log folder, ExifTool location, and file types are remembered between runs.

## Features

- Auto-detects SD card by looking for a `DCIM` folder on removable drives
- Camera-agnostic file typing — configure your own RAW / video / auxiliary (proxy, 360 footage, etc.) extensions instead of a hardcoded list
- Sorts matched files into dated vault folders using EXIF capture date
- Duplicate detection against the existing vault before copying, confirmed by checksum (not just filename/size) so recycled camera file-counters don't produce false positives
- Orphan JPG detection (JPGs with no matching RAW file)
- Dry run mode — full simulation with no files copied
- Live progress: percentage, speed, ETA, and current file
- Pre-flight storage space check with continue/cancel dialog
- Post-ingest verification (source vs. destination file and byte counts)
- Optional SD card eject on completion
- Optional auto-launch on SD card insertion (Task Scheduler event trigger — see `accurova_register_autolaunch.ps1`)
- Persisted config (`accurova_config.json`) for vault path, log folder, ExifTool path, and file extensions

## Tech Stack

| Layer | Choice |
|---|---|
| Script | PowerShell (WinForms GUI) |
| EXIF parsing | ExifTool |

## Quick Start

1. Copy `accurova_config.example.json` to `accurova_config.json` in the same folder as the script and adjust the paths, or set them from the UI after launching.
2. Run `accurova_ingest.ps1`.
3. Set your **Vault Destination**, **Log Folder**, and **ExifTool Path** under Paths (e.g. `D:\Photos\Vault`, `D:\Photos\Vault\_logs`, `C:\exiftool\exiftool.exe`), then click **Save Paths**.
4. Under **File Types**, set your camera's extensions — e.g. **RAW**: `nef` (Nikon), `cr2, cr3` (Canon), `arw` (Sony), `raf` (Fujifilm); **Video**: `mp4, mov`; **Aux** (optional): `lrv, insv` for GoPro/Insta360 proxy or 360 footage.
5. Optionally enter an **Event Name** / **Location** — appended to each day's folder name.
6. Confirm the detected **SD Card Drive** (or pick manually).
7. Toggle **Dry run** to preview without copying, and/or **Eject SD card after ingest**.
8. Click **START INGEST**.

### Optional: auto-launch on SD card insert

Run `accurova_register_autolaunch.ps1` once from an elevated (Administrator) PowerShell. It registers a Scheduled Task that fires `accurova_autolaunch.ps1` whenever Windows detects a new device; that script checks for a DCIM-bearing removable drive and pops the GUI up automatically if one is found (no-ops otherwise, and no-ops if the app is already running).

## Requirements

- Windows with PowerShell
- [ExifTool](https://exiftool.org/) installed and its path set in config or the UI

## Configuration

| Field | Required | Description |
|---|---|---|
| `Dest` | Yes | Root path of your photo vault, e.g. `D:\Photos\Vault` |
| `LogDir` | Yes | Where ingest logs are written, e.g. `D:\Photos\Vault\_logs` |
| `Exiftool` | Yes | Full path to the ExifTool executable, e.g. `C:\exiftool\exiftool.exe` |
| `RawExt` | Yes | Comma-separated RAW extensions, no dots, e.g. `nef, cr2, cr3, arw, raf, orf, rw2, dng` |
| `VideoExt` | Yes | Comma-separated video extensions, e.g. `mp4, mov` |
| `AuxExt` | No | Comma-separated proxy/360 extensions, e.g. `lrv, insv` — leave blank to skip this category |

Config is stored in `accurova_config.json` next to the script. Copy `accurova_config.example.json` to get started.

## Project Structure

```
accurova-ingest/
|-- accurova_ingest.ps1
|-- accurova_autolaunch.ps1
|-- accurova_register_autolaunch.ps1
|-- accurova_config.example.json
|-- LICENSE
|-- COMMERCIAL-LICENSE.md
`-- README.md
```

## Versioning

This project follows [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`):

- **MAJOR** — breaking changes to config format, folder structure, or workflow that require user action
- **MINOR** — new features that are backward compatible (new toggles, new file types, new UI sections)
- **PATCH** — bug fixes and small tweaks with no behavior change for existing users

## Status / Roadmap

**Done**

- [x] EXIF-based date sorting for configurable RAW, video, and auxiliary (proxy/360) file types
- [x] Camera-agnostic file typing — no longer hardcoded to a single body's extensions
- [x] Duplicate detection (name + size + checksum) and orphan JPG flagging
- [x] Dry run mode and live progress reporting
- [x] Post-ingest verification and optional SD card eject
- [x] Persisted JSON config with in-UI editing
- [x] Two-column WinForms layout with live output log
- [x] Optional auto-launch on SD card insertion via Task Scheduler

**Planned / Suggestions**

- **Config profiles** — support multiple named destination/camera profiles (e.g. different bodies, different vault drives) instead of a single global config
- **Resume/retry on interruption** — recover cleanly from a killed process or dropped SD card mid-ingest instead of requiring a full re-run
- **Structured logging** — write machine-readable (JSON/CSV) ingest logs alongside the human-readable log for easier auditing over time
- **Packaging** — distribute as a signed `.exe` (e.g. via ps2exe) so it can run without an explicit PowerShell execution policy change
- **Cross-platform ingest core** — split the ingest/verify logic from the WinForms UI so a CLI-only mode is possible on non-Windows setups running PowerShell Core
- **CI parse-check** — a lightweight GitHub Actions workflow that runs PowerShell's AST parser against `accurova_ingest.ps1` on every push/PR, catching syntax errors before they reach a user's machine
- **Mirrored/dual-destination ingest** — copy to a second vault path (e.g. a backup drive) in the same pass, for photographers who want on-site redundancy before formatting the card
- **Toast notification on completion** — a Windows notification when ingest finishes, most useful once auto-launch is running unattended in the background and nobody's watching the log
- **Config schema versioning** — an internal `ConfigVersion` field so future config-shape changes (like this release's new `RawExt`/`VideoExt`/`AuxExt` fields) can auto-migrate old files instead of silently falling back to defaults
- **Adjustable duplicate-check strictness** — an option to skip the MD5 checksum pass and trust name+size alone, for users ingesting very large cards where per-file hashing adds noticeable time
- **Customizable vault folder pattern** — the `YYYY_MM\YYYY_MM_DD [Event] [Location]` structure is currently fixed; a configurable date/folder template would suit different organizational preferences
- No `.env.example` equivalent is provided for the PowerShell config path defaults — a setup script or first-run wizard could reduce manual config steps
- No automated tests for ingest logic (duplicate detection, path construction, verification counts)

Suggestions and feedback welcome — open an issue or reach out directly.

## Changelog

All notable changes to this project are documented here, newest first. Versions prior to 1.0.0 predate this repository's git history (the tool evolved as a single script across iterations); dates below are only as precise as the available evidence — 0.5.0–0.8.0 are anchored to file timestamps, 0.1.0–0.4.0 predate those and are undated.

### [1.1.0] - 2026-08-04
- Camera-agnostic file typing — replaced the hardcoded NEF/MP4/LRV/INSV extension list with a **FILE TYPES** UI section (RAW / Video / Aux, comma-separated, persisted to config); works for any camera, not just the D850
- Note: the auxiliary-file subfolder is now named `aux` instead of `360`, since aux files aren't always 360 footage — existing vault folders are unaffected, new ingests will create `aux` going forward
- Duplicate detection now confirms name+size matches with an MD5 checksum before treating a file as a true duplicate, so a camera's recycled file counter (e.g. wrapping back to `0001` after ~9999 shots) can't cause a false-positive skip
- Live (non-dry-run) ingest now actually skips confirmed duplicates before invoking ExifTool, instead of copying/overwriting them anyway while only mislabeling the log
- Optional auto-launch on SD card insertion — `accurova_register_autolaunch.ps1` registers a Task Scheduler event trigger that runs `accurova_autolaunch.ps1`, which pops the GUI up automatically when a DCIM-bearing drive appears
- Fixed a crash ("cannot call a method on a null-valued expression") that could occur ~2 seconds after clicking **Save Paths**, caused by a WinForms Timer closure referencing an out-of-scope variable
- Removed the verbose "Output folders" listing from the end-of-run log
- Rebranded away from Nikon D850-specific naming for public release

### [1.0.0] - 2026-07-25
- First tracked release of the public repo (git-backed versioning starts here); code already includes everything through 0.8.0 below

### [0.8.0] - 2026-03-14
- 360 camera file support — `.lrv`/`.insv` ingested as a third file type, nested into a `360` subfolder within the date folder; skipped silently if none found; included in progress tracking, verification, and summary

### [0.7.0] - 2026-03-14
- Two-column layout — form widened to 1140×760px; output log moved to a full-height right panel with a vertical divider

### [0.6.0] - 2026-03-14
- Fixed toggle controls and Browse buttons — WinForms closure scoping bugs caused the eject/dry run toggles and Browse buttons to crash at runtime; toggles inlined with explicit `$script:` scoped state, Browse buttons fixed by storing the textbox reference in `$this.Tag`

### [0.5.0] - 2026-03-10
- In-UI config with JSON persistence — vault destination, log folder, and ExifTool path moved into editable fields with Browse buttons; config saved to `accurova_config.json` next to the script and reloaded on next launch; log folder auto-updates when vault path changes

### [0.4.0] - date unknown
- Progress bar, per-file transfer speed, and ETA calculated from bytes transferred vs. total
- Pre-flight storage check with continue/cancel dialog
- Vault indexed on startup; duplicate files skipped and logged
- SD card auto-detected by scanning for removable drives with a `DCIM` folder
- Dry run toggle to simulate the full pipeline without touching any files
- Post-ingest verification comparing source vs. destination file counts, flagging missing files, confirming safe-to-format

### [0.3.0] - date unknown
- GUI wrapper — replaced terminal interaction with a WinForms dark-themed UI: event name and location fields, SD card drive dropdown, eject checkbox, live output log panel, Stop button, status label

### [0.2.0] - date unknown
- Ported to PowerShell (Windows) — rebuilt entirely for Windows, same logic as the original shell script, PowerShell-native syntax, `.ps1` file

### [0.1.0] - date unknown (predecessor, not in this repo)
- Initial concept as a bash shell script on Mac using ExifTool: sorted NEFs and MP4s by EXIF date, rescued orphan JPGs, logged output, optionally ejected the SD card

## License

This project is dual licensed.

- Community Edition — [GNU Affero General Public License v3 (AGPLv3)](LICENSE). Free to use, modify, and self-host. If you distribute a modified version or run it as a network service, you must make the corresponding source available.
- Commercial License — for organisations that want to embed, modify, or distribute this software without AGPLv3's obligations. See [COMMERCIAL-LICENSE.md](COMMERCIAL-LICENSE.md).

---

<div align="center">
<sub>Built by <a href="https://github.com/TheBooleanJulian">@TheBooleanJulian</a></sub>
</div>
