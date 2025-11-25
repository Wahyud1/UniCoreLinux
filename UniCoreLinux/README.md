# UniCoreLinux

UniCoreLinux is an Arch-based skeleton distribution inspired by macOS Sequoia.
This repository contains scaffolding to build an ISO, an interactive installer,
and supporting subsystems such as a `.kext`-style wrapper, a plist config daemon,
and detection scripts.

## What's included (scaffold)
- `installer/` — interactive ncurses/dialog installer (bash)
- `build/` — iso build helpers
- `configs/kexts/` — .kext examples and packaging notes
- `configs/plists/` — example plist files
- `system/services/` — systemd unit files for included daemons
- `system/modules/` — placeholder modules or symlink targets
- `docs/` — design notes and next steps

## How to use
1. Unzip the archive: `unzip UniCoreLinux.zip`
2. Enter the directory: `cd UniCoreLinux`
3. Initialize git (if not already): `git init && git add . && git commit -m "Initial commit"`
4. Push to your GitHub remote.
5. To build a test ISO, see `build/build.sh` (requires `mkarchiso`).

## Important notes
These scripts are **scaffolding** and intended for development/testing. Do not run them on production machines without reading and adapting to your environment.
