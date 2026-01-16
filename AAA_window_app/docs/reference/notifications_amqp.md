# App Reference - Notifications and AMQP

## AMQP Core
- Service: `lib/shared/services/amqp_service.dart`
  - Queues created: `alert`, `event`, `eapproval.alert`, `leave.draft`
  - Handles: alert ticker, eapproval alerts, leave draft trigger, contest alerts

## Notification Providers
- `notificationProvider`: `lib/shared/providers/notification_notifier.dart`
  - unread count: `unreadCountProvider`
- Leave notifications: `lib/features/leave/providers/leave_notification_provider.dart`

## UI Surfaces
- Scrolling ticker: `lib/shared/widgets/scrolling_ticker.dart`
- Alert popup: `lib/features/approval/approval_alert_popup.dart`
- Leave notification overlay: `lib/features/leave/widgets/leave_notification_overlay.dart`

## Module Checklist (what to change)
- AMQP message routing: `lib/shared/services/amqp_service.dart`
- Notification state: `lib/shared/providers/notification_notifier.dart`
- Leave alerts: `lib/features/leave/providers/leave_notification_provider.dart`
