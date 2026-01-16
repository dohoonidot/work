# App Reference - Overview

Quick reference for global config, core screens, and shared state.

## Global Config
- Base URL switch: `lib/core/config/app_config.dart`
  - `AppConfig.isOfficialRelease` (bool)
  - `AppConfig.baseUrl` -> `https://ai2great.com:8080` (release) / `:8060` (dev)

## Screens and Navigation (UI names)
Main screens (key entry points)
- `ChatHomePage` (main hub): `lib/ui/screens/chat_home_page_v5.dart`
- `LoginPage`: `lib/ui/screens/login_page.dart`
- `LeaveManagementScreen` (user): `lib/ui/screens/leave_management_screen.dart`
- `AdminLeaveApprovalScreen` (approver): `lib/ui/screens/admin_leave_approval_screen.dart`
- `ElectronicApprovalManagementScreen`: `lib/ui/screens/electronic_approval_management_screen.dart`
- `SignFlowScreen` (approval flow): `lib/ui/screens/signflow_screen.dart`
- `SapMainPage` (SAP chat UI): `lib/ui/screens/sap_main_page.dart`
- `CodingAssistantPage` (code chat UI): `lib/ui/screens/coding_assistant_page.dart`
- `ContestScreen` / `ContestGuideScreen`: `lib/ui/screens/contest_screen.dart`,
  `lib/ui/screens/contest_guide_screen.dart`
- `VotingScreen`: `lib/ui/screens/voting_screen.dart`
- `SettingsPage`: `lib/ui/screens/settings_page.dart`
- `VacationManagementWebViewScreen`: `lib/ui/screens/vacation_management_webview_screen.dart`

Sidebar navigation
- Sidebar widget: `lib/shared/widgets/sidebar.dart`
  - For approver users (`approverProvider`): routes to `AdminLeaveApprovalScreen`
  - Otherwise: routes to `LeaveManagementScreen`

Back behavior (leave/admin screens)
- `WillPopScope` -> `ChatHomePage` and clears stack
  - `lib/ui/screens/leave_management_screen.dart`
  - `lib/ui/screens/admin_leave_approval_screen.dart`

## Shared Providers (state names)
Shared app state
- `userIdProvider` (String?) `lib/shared/providers/providers.dart`
- `usernameProvider`, `passwordProvider`
- `rememberMeProvider` (bool)
- `approverProvider` (bool, from login `is_approver`)
- `permissionProvider` (int?)
- `themeProvider` (ThemeState) `lib/shared/providers/theme_provider.dart`
- `notificationProvider` / `unreadCountProvider` `lib/shared/providers/notification_notifier.dart`
- `alertTickerProvider` `lib/shared/providers/alert_ticker_provider.dart`

Chat state
- `chatProvider` -> `ChatNotifier`, `ChatState`
  - `ChatState` fields: `arvChatHistory`, `selectedTopic`, `currentArchiveId`,
    `arvChatDetail`, `isSidebarVisible`, `isDashboardVisible`, `archiveType`,
    `isNewArchive`, `isStreaming`, `isFirstTimeCodeAssistant`,
    `isProcessingAutoTitle`, `selectedModule`, `searchKeyword`,
    `highlightedChatId`
  - `lib/shared/providers/chat_state.dart`

Attachment state
- `attachmentProvider` -> list of `CustomPlatformFile`
  - `CustomPlatformFile`: `name`, `path`, `size`, `bytes`, `mimeType`
  - `lib/shared/providers/attachment_provider.dart`
- `clipboardProvider` for image paste support

## Fast Pointers
- Chat routing + main UI: `lib/ui/screens/chat_home_page_v5.dart`
- Chat state + sending: `lib/shared/providers/chat_notifier.dart`
- Stream payloads: `lib/shared/services/stream_service.dart`
- Leave UI: `lib/ui/screens/leave_management_screen.dart`,
  `lib/ui/screens/admin_leave_approval_screen.dart`
- Leave API + models: `lib/shared/services/leave_api_service.dart`,
  `lib/models/leave_management_models.dart`
