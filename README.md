<div align="center">

# Accurova Ingest

**A Windows PowerShell GUI tool that ingests SD card photos and video into a dated vault — sorted by EXIF date, deduped, verified, then ready to format.**

![Version](https://img.shields.io/badge/version-1.0.0-00D4C8)
![PowerShell](https://img.shields.io/badge/-PowerShell-5391FE?logo=powershell&logoColor=white)
![License](https://img.shields.io/badge/license-AGPLv3%20%2F%20Commercial-00D4C8.svg)

</div>

---

## What it does

Accurova Ingest is a Windows PowerShell GUI utility for photographers shooting with a Nikon D850 (and 360 cameras). It auto-detects the SD card, reads EXIF capture dates via ExifTool, and sorts NEFs, MP4s, and 360 footage into a structured vault (`Dest\YYYY_MM\YYYY_MM_DD [Event] [Location]\`) — skipping duplicates, flagging orphan JPGs, and verifying the copy before you format the card. Config is persisted to a local JSON file so your vault path, log folder, and ExifTool location are remembered between runs.

## Features

- Auto-detects SD card by looking for a `DCIM` folder on removable drives
- Sorts NEFs, MP4s, and 360 footage (`.lrv` / `.insv`) into dated vault folders using EXIF capture date
- Duplicate detection against the existing vault before copying
- Orphan JPG detection (JPGs with no matching NEF)
- Dry run mode — full simulation with no files copied
- Live progress: percentage, speed, ETA, and current file
- Pre-flight storage space check with continue/cancel dialog
- Post-ingest verification (source vs. destination file and byte counts)
- Optional SD card eject on completion
- Persisted config (`accurova_config.json`) for vault path, log folder, and ExifTool path

## Tech Stack

| Layer | Choice |
|---|---|
| Script | PowerShell (WinForms GUI) |
| EXIF parsing | ExifTool |

## Quick Start

1. Copy `accurova_config.example.json` to `accurova_config.json` in the same folder as the script and adjust the paths, or set them from the UI after launching.
2. Run `accurova_ingest.ps1`.
3. Set your **Vault Destination**, **Log Folder**, and **ExifTool Path** under Paths, then click **Save Paths**.
4. Optionally enter an **Event Name** / **Location** — appended to each day's folder name.
5. Confirm the detected **SD Card Drive** (or pick manually).
6. Toggle **Dry run** to preview without copying, and/or **Eject SD card after ingest**.
7. Click **START INGEST**.

## Requirements

- Windows with PowerShell
- [ExifTool](https://exiftool.org/) installed and its path set in config or the UI

## Configuration

| Field | Required | Description |
|---|---|---|
| `Dest` | Yes | Root path of your photo vault |
| `LogDir` | Yes | Where ingest logs are written |
| `Exiftool` | Yes | Full path to the ExifTool executable |

Config is stored in `accurova_config.json` next to the script. Copy `accurova_config.example.json` to get started.

## Project Structure

```
accurova-ingest/
|-- accurova_ingest.ps1
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

- [x] EXIF-based date sorting for NEF, MP4, LRV, and INSV files
- [x] Duplicate detection and orphan JPG flagging
- [x] Dry run mode and live progress reporting
- [x] Post-ingest verification and optional SD card eject
- [x] Persisted JSON config with in-UI editing
- [x] Two-column WinForms layout with live output log
- [x] 360 footage ingested into a `360` subfolder per day

**Planned / Suggestions**

- **Config profiles** — support multiple named destination/camera profiles (e.g. different bodies, different vault drives) instead of a single global config
- **Additional camera support** — generalize the file-type/extension list beyond D850 (NEF/MP4/LRV/INSV) so other bodies can be ingested without editing the script
- **Checksum verification** — optional hash-based verification pass instead of (or in addition to) filename/size matching, for stronger integrity guarantees before formatting the card
- **Resume/retry on interruption** — recover cleanly from a killed process or dropped SD card mid-ingest instead of requiring a full re-run
- **Structured logging** — write machine-readable (JSON/CSV) ingest logs alongside the human-readable log for easier auditing over time
- **Packaging** — distribute as a signed `.exe` (e.g. via ps2exe) so it can run without an explicit PowerShell execution policy change
- **Cross-platform ingest core** — split the ingest/verify logic from the WinForms UI so a CLI-only mode is possible on non-Windows setups running PowerShell Core
- No `.env.example` equivalent is provided for the PowerShell config path defaults — a setup script or first-run wizard could reduce manual config steps
- No automated tests for ingest logic (duplicate detection, path construction, verification counts)

Suggestions and feedback welcome — open an issue or reach out directly.

## Changelog

All notable changes to this project are documented here, newest first. Versions prior to 1.0.0 predate this repository's git history (the tool evolved as a single script across iterations); dates below are only as precise as the available evidence — 0.5.0–0.8.0 are anchored to file timestamps, 0.1.0–0.4.0 predate those and are undated.

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
