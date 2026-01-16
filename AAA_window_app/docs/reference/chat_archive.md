# App Reference - Chat and Archive

## UI Components
- `ChatArea` (main chat body): `lib/features/chat/chat_area_v3.dart`
  - switches to `CodingAssistantPage` or `SapMainPage` by `ChatState.archiveType`
  - handles paste/drag via `FileAttachmentUtils`
- `FileAttachmentModal`: `lib/features/chat/file_attachment_modal.dart`
  - allowedExtensions: `jpg`, `jpeg`, `png`, `pdf`
- `AttachmentPreview`: `lib/features/chat/attachment_preview.dart`
  - shows selected attachments from `attachmentProvider`
- `AiModelSelector`: `lib/features/chat/ai_model_selector.dart`

## Providers and State
- `chatProvider` -> `ChatNotifier`, `ChatState`
  - `ChatState` fields: `arvChatHistory`, `selectedTopic`, `currentArchiveId`,
    `arvChatDetail`, `isSidebarVisible`, `isDashboardVisible`, `archiveType`,
    `isNewArchive`, `isStreaming`, `isFirstTimeCodeAssistant`,
    `isProcessingAutoTitle`, `selectedModule`, `searchKeyword`,
    `highlightedChatId`
  - `lib/shared/providers/chat_state.dart`
- `attachmentProvider` -> list of `CustomPlatformFile`
  - `CustomPlatformFile`: `name`, `path`, `size`, `bytes`, `mimeType`
  - `lib/shared/providers/attachment_provider.dart`
- `clipboardProvider` for image paste support
- `selectedWebSearchProvider` (bool) for search toggle

## Attachment Rules
- Allowed types: `jpg`, `jpeg`, `png`, `pdf`
- Size validation: 20MB per file in drag/drop/attachment flow
- Storage: `attachmentProvider` uses `CustomPlatformFile`

## Stream Payloads (quick)
- `POST /streamChat/timeout` fields: `category`, `module`, `archive_id`,
  `user_id`, `message` + `files[]`
- `POST /streamChat/withModel` fields: `archive_id`, `user_id`, `message`,
  optional `category`, `module`, `model`, `search_yn` + `files[]`

## Module Checklist (what to change)
- Archive list/rename/delete logic: `lib/shared/services/api_service.dart`
- Message send/stream flow: `lib/shared/providers/chat_notifier.dart`
- Stream endpoint payloads: `lib/shared/services/stream_service.dart`
- UI composition: `lib/features/chat/chat_area_v3.dart`
- File pick/drag rules: `lib/features/chat/file_attachment_modal.dart`,
  `lib/shared/utils/file_attachment_utils.dart`
