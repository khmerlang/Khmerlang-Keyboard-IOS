# Khmerlang Keyboard iOS

Khmerlang is an iOS app plus custom keyboard extension for Khmer + English typing.

## Production Defaults

- Cloud spell check is opt-in by default.
- Users must grant explicit consent before cloud spell check is enabled.
- Keyboard still requires Full Access for cloud spell-check requests.

## Build

```bash
xcodebuild -scheme Khmerlang-Keyboard-IOS -configuration Release -sdk iphonesimulator build
```

## Test

```bash
xcodebuild -scheme Khmerlang-Keyboard-IOS -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Privacy Policy Page

- In-app policy screen: Khmerlang-Keyboard-IOS/PrivacyPolicyView.swift
- Hostable web page source: docs/privacy-policy.html
- Markdown source: PRIVACY_POLICY.md

To publish at your production URL:

1. Upload docs/privacy-policy.html to your website as /ios-privacy.
2. Verify https://www.khmerlang.com/ios-privacy is publicly accessible without login.
3. Keep web content aligned with PRIVACY_POLICY.md and the in-app policy text.

## Release Checklist

- Verify App Store privacy answers match actual keyboard data handling.
- Verify cloud spell-check consent and disable paths in app and keyboard.
- Verify Full Access messaging and fallback behavior.
- Run release build and unit tests in CI.
- Bump MARKETING_VERSION and CURRENT_PROJECT_VERSION.
- Validate app + keyboard behavior on at least one older iOS version and one latest iOS version.
