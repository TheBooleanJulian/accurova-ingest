# Accurova Ingest

A Windows PowerShell GUI utility for ingesting photos and video from Nikon D850 SD cards (plus 360-camera footage) into a dated vault folder structure, using ExifTool to sort files by capture date, skip duplicates, and verify the copy before you format the card.

## Features

- Auto-detects the SD card (looks for a `DCIM` folder on removable drives)
- Sorts NEFs, MP4s, and 360 footage (`.lrv` / `.insv`) into `Dest\YYYY_MM\YYYY_MM_DD [Event] [Location]\` using EXIF capture date
- Duplicate detection against the existing vault before copying
- Orphan JPG detection (JPGs with no matching NEF)
- Dry run mode — simulate a full ingest with no files copied
- Live progress: percentage, speed, ETA, current file
- Storage space check before starting a live ingest
- Post-ingest verification (source vs. destination file/byte counts)
- Optional SD card eject when the ingest completes
- Persisted config (`accurova_config.json`) for vault destination, log folder, and ExifTool path

## Requirements

- Windows with PowerShell
- [ExifTool](https://exiftool.org/) installed somewhere accessible (path is configurable in the app)

## Usage

1. Copy [`accurova_config.example.json`](accurova_config.example.json) to `accurova_config.json` (in the same folder as the script) and adjust the paths, or just launch the app and set them from the UI.
2. Run `accurova_ingest.ps1`.
3. Set your **Vault Destination**, **Log Folder**, and **ExifTool Path** under Paths, and click **Save Paths**.
3. Optionally enter an **Event Name** / **Location** — these are appended to each day's destination folder name.
4. Confirm the detected **SD Card Drive** (or pick manually).
5. Toggle **Dry run** to preview the ingest without copying anything, and/or **Eject SD card after ingest**.
6. Click **START INGEST**.

Config is stored in `accurova_config.json` next to the script.

## Versioning

This project follows [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`):

- **MAJOR** — breaking changes to config format, folder structure, or workflow that require user action
- **MINOR** — new features that are backward compatible (new toggles, new file types, new UI sections)
- **PATCH** — bug fixes and small tweaks with no behavior change for existing users

## Changelog

All notable changes to this project are documented here, newest first.

### [1.0.0] - 2026-07-25
- First tracked release of the public repo (git-backed versioning starts here)

### [0.6.0] - 2026-03-14
- Fixed toggle controls (Eject / Dry run) that were not updating state correctly

### [0.1.0] - 2026-03-10
- Initial version of the ingest script and config

## Future Roadmap

Ideas under consideration for future releases — not commitments, just a running list:

- **Config profiles** — support multiple named destination/camera profiles (e.g. different bodies, different vault drives) instead of a single global config
- **Additional camera support** — generalize the file-type/extension list beyond D850 (NEF/MP4/LRV/INSV) so other bodies can be ingested without editing the script
- **Checksum verification** — optional hash-based verification pass instead of (or in addition to) filename/size matching, for stronger integrity guarantees before formatting the card
- **Resume/retry on interruption** — recover cleanly from a killed process or dropped SD card mid-ingest instead of requiring a full re-run
- **Structured logging** — write machine-readable (JSON/CSV) ingest logs alongside the human-readable log for easier auditing over time
- **Packaging** — distribute as a signed `.exe` (e.g. via ps2exe) so it can run without an explicit PowerShell execution policy change
- **Cross-platform ingest core** — split the ingest/verify logic from the WinForms UI so a CLI-only mode is possible on non-Windows setups running PowerShell Core

Suggestions and feedback welcome — open an issue or reach out directly.

## License

This project is dual licensed.

- Community Edition — [GNU Affero General Public License v3 (AGPLv3)](LICENSE). Free to use, modify, and self-host. If you distribute a modified version or run it as a network service, you must make the corresponding source available.
- Commercial License — for organisations that want to embed, modify, or distribute this software without AGPLv3's obligations. See [COMMERCIAL-LICENSE.md](COMMERCIAL-LICENSE.md).

---

<div align="center">
<sub>Built by <a href="https://github.com/TheBooleanJulian">@TheBooleanJulian</a></sub>
</div>
