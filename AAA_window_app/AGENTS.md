# Repository Guidelines

## Project Structure & Module Organization
This is a Flutter desktop app with standard multi-platform layout. Core Dart code lives in `lib/`, with feature modules under `lib/features/` and shared UI/services in `lib/shared/`. Platform shells are in `android/`, `ios/`, `macos/`, `windows/`, and `linux/`. Static assets live in `assets/` (see `pubspec.yaml` for asset declarations). Tests live in `test/`.

## Build, Test, and Development Commands
- `flutter pub get` fetches Dart/Flutter dependencies listed in `pubspec.yaml`.
- `flutter run -d windows` runs the desktop app on Windows (use another device id for macOS/Linux).
- `flutter build windows` builds a Windows desktop release binary.
- `flutter analyze` runs static analysis and lints.
- `dart format .` formats all Dart sources.
- `flutter test` runs the test suite in `test/`.

## Coding Style & Naming Conventions
Use standard Dart style: 2-space indentation, trailing commas where useful for formatting, and idiomatic `UpperCamelCase` for types/classes, `lowerCamelCase` for variables/functions, and `lower_snake_case` for file names. Keep widget build methods small; extract reusable widgets into `lib/shared/` or a relevant `lib/features/<feature>/` folder. Update `pubspec.yaml` when adding assets or dependencies.

## Testing Guidelines
Tests use Flutter's default `flutter_test` framework. Name tests descriptively and keep them under `test/`, mirroring the structure of `lib/` when possible. Run `flutter test` before submitting changes. If you add new logic in services or adapters, add unit tests for the public API.

## Commit & Pull Request Guidelines
This repo does not include git history, so no commit convention is enforced. Prefer short, imperative commit subjects (e.g., "Fix approval line save") and include a scope when helpful. PRs should include a concise description, testing notes (commands run), and screenshots when UI changes are visible.

## Configuration Notes
Feature flags and app configuration live under `lib/core/config/` (for example `lib/core/config/feature_config.dart`). Keep environment-specific values out of source control unless explicitly required.
