# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Running the Application
```bash
# Development mode
flutter run

# Platform-specific runs
flutter run -d windows    # Primary target platform
flutter run -d macos      # macOS desktop
flutter run -d linux      # Linux desktop
flutter run -d chrome     # Web browser
```

### Building
```bash
# Windows build (primary platform)
flutter build windows --release

# Other platforms
flutter build macos --release
flutter build linux --release
flutter build web --release
```

### Dependencies and Maintenance
```bash
flutter pub get           # Install dependencies
flutter clean             # Clean build cache
flutter analyze           # Static code analysis
flutter test              # Run tests
flutter format .          # Format code
```

### Icon Generation
```bash
flutter pub run flutter_launcher_icons:main
```

## Architecture Overview

### Core Structure
This is a **Flutter desktop application** (ASPN AI Agent) that serves as a multi-AI chat client with the following key architectural components:

**State Management**: Uses **Riverpod** for all state management
- `ChatNotifier` and `ChatState` manage chat functionality
- `ThemeProvider` handles UI theming
- `NotificationNotifier` manages system notifications and alerts

**Main Application Flow**:
1. **LoginPage** → **ChatHomePageV5** (main chat interface)
2. Window management with different sizes for login vs main app
3. Auto-startup capability on Windows

### Key Directories

**`lib/provider/`** - Riverpod state management
- `providers.dart` - Main provider declarations
- `chat_notifier.dart` & `chat_state.dart` - Chat state management
- `notification_notifier.dart` - Notification system
- `theme_provider.dart` - Theme switching

**`lib/screens/`** - Main application screens
- `login_page.dart` - Authentication interface
- `chat_home_page_v5.dart` - Primary chat interface
- `settings_page.dart` - App configuration

**`lib/services/`** - External service integrations
- `api_service.dart` - AI model API communications
- `amqp_service.dart` - Message queue for real-time notifications
- `system_tray_service.dart` - System tray integration

**`lib/utils/message_renderer/`** - Chat message rendering system
- `gpt_markdown_renderer.dart` - AI response formatting
- `code_block_renderer.dart` - Syntax highlighting for code
- Specialized renderers for different AI model outputs

**`lib/widgets/`** - Reusable UI components
- `ai_model_selector.dart` - AI model switching interface
- `chat_area_v3.dart` - Main chat display area
- `attachment_preview.dart` - File attachment handling

### Database
- **SQLite** with sqflite for local data persistence
- **DatabaseHelper** (`lib/local/database_helper.dart`) manages DB operations
- Stores chat history, user preferences, and session data

### AI Model Integration
The app supports multiple AI models:
- **ChatGPT** (gpt-o3 as default)
- **Claude**
- **Gemini**

AI model selection is managed through `selectedAiModelProvider` and handled by `api_service.dart`.

### Message Queue System
**AMQP integration** for real-time notifications:
- Configuration in `lib/config/messageq_config.dart`
- Server: `211.43.205.49:5672`
- Handles birthday messages and system notifications
- See `messageQ.md` for detailed implementation guide

### Theming
- **AppTheme** (`lib/theme/app_theme.dart`) with **ColorSchemes** 
- Supports light/dark mode switching
- Custom color schemes for different UI states

### File Attachments
- **Desktop file dropping** support via `desktop_drop`
- **File picker** integration
- **Image handling** with preview capabilities
- Attachment state managed through `attachment_provider.dart`

## Important Notes

### Local Packages
The project includes local packages for syntax highlighting:
- `highlighting` - Core highlighting engine
- `flutter_highlighting` - Flutter-specific highlighting widgets
Located in `packages/dart-highlighting-main/`

### Platform Support
Primary target is **Windows desktop**, with secondary support for macOS, Linux, and web.

### Window Management
- Login window: 400x600 (portrait orientation)
- Main app window: 1280x720 (landscape orientation) 
- Automatic window resizing and centering

### Auto-startup
Windows auto-startup is configured and enabled by default through `launch_at_startup` package.

### Version Management
Current version tracked in `version.txt` (1.0.0)