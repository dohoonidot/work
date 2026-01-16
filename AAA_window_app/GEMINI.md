# Gemini Project Context

This file helps Gemini understand the ASPN_AI_AGENT project.

## Project Overview

ASPN_AI_AGENT is a desktop application built with Flutter. It appears to be an AI-powered agent or assistant, likely with chat functionalities, given the file names and dependencies. The application is for Windows, with placeholders for iOS, Android, Linux, and macOS.

## Architecture

The application follows a standard Flutter project structure.

*   **State Management:** `flutter_riverpod` is used for state management.
*   **Services:** A `services` directory contains logic for handling API calls (`api_service.dart`), AMQP (`amqp_service.dart`), local database (`database_helper.dart`), and more.
*   **UI:** The UI is split into `screens`, `widgets`, and `theme`.
*   **Configuration:** Configuration files for the app, gifts, and message queues are in the `config` directory.
*   **Local Storage:** `sqflite` and `shared_preferences` are used for local data storage.

## Coding Conventions

*   The project follows standard Dart and Flutter coding conventions.
*   Lints are defined in `analysis_options.yaml`.

## Important Files

*   `pubspec.yaml`: Defines project dependencies, assets, and fonts.
*   `lib/main.dart`: The main entry point of the application.
*   `lib/provider/providers.dart`: Centralized provider definitions for Riverpod.
*   `lib/services/api_service.dart`: Handles communication with backend APIs.
*   `lib/screens/chat_home_page_v5.dart`: Likely the main chat interface.
*   `lib/config/app_config.dart`: Contains application-level configuration.

## Dependencies

The project uses several key dependencies:

*   `flutter`: The core framework.
*   `flutter_riverpod`: For state management.
*   `http`: For making HTTP requests.
*   `sqflite`, `drift`, `sqlite3`: For local database storage.
*   `dart_amqp`: For AMQP messaging.
*   `gpt_markdown`: For rendering markdown from AI models.
*   `window_manager`, `system_tray`: For desktop-specific features.