# KhmerEnglishKeyboard (iOS)

Starter scaffold for a custom iOS keyboard extension that supports:
- English (QWERTY)
- Khmer (basic keys)
- A language toggle key
- Delete / Space / Return

This repo is intentionally lightweight: since the actual Xcode project can only be generated/built on macOS, we use **XcodeGen** to produce the `.xcodeproj` from config.

## Prerequisites (macOS)
- Xcode
- `xcodegen` (`brew install xcodegen`)

## Generate the Xcode project
From this folder:

```bash
cd ios
xcodegen generate -s project.yml
```

## Quick customization
Edit `ios/project.yml` and set:
- `bundleIdPrefix`
- `DEVELOPMENT_TEAM` (if you want to auto-select signing)

