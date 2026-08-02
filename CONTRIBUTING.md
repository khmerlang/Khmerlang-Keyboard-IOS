# Contributing to Khmerlang Keyboard

Thanks for your interest in improving Khmer typing on iOS.

## Getting started

1. Fork the repo and clone your fork.
2. Open `Khmerlang-Keyboard-IOS.xcodeproj` in Xcode.
3. Build and run the `Khmerlang-Keyboard-IOS` scheme on a simulator or device.
4. Add the Khmerlang keyboard via Settings › General › Keyboard › Keyboards
   to test the keyboard extension itself.

See [README.md](README.md) for build/test commands.

## Making changes

- Keep pull requests focused on a single change.
- Match the existing code style (see nearby files for conventions).
- Add or update tests in `KhmerlangTests/` for behavior changes.
- Run the test suite before opening a PR:

  ```bash
  xcodebuild -scheme Khmerlang-Keyboard-IOS -destination 'platform=iOS Simulator,name=iPhone 17' test
  ```

- If you touch the roman-to-Khmer ML model, see `ml/roman2khmer/README.md`
  for the training/export pipeline. Model bundles committed to
  `Khmerlang/` and `ml/roman2khmer/dist/` should be regenerated with the
  documented scripts, not hand-edited.

## Reporting bugs

Open a GitHub issue with:
- Steps to reproduce
- Expected vs. actual behavior
- iOS version and device/simulator

## Reporting security issues

Do not open a public issue for security vulnerabilities — see
[SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions will be licensed under
the project's [GPLv3 license](LICENSE).
