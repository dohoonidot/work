# App Reference - Electronic Approval

## Primary Screens and Modals
- Management screen: `lib/ui/screens/electronic_approval_management_screen.dart`
- Common approval form: `lib/features/approval/common_electronic_approval_modal.dart`
- Draft modal (chat-triggered): `lib/features/approval/electronic_approval_draft_modal.dart`
- AI approval modal: `lib/features/approval/ai_electronic_approval_modal.dart`
- Approval alert popup: `lib/features/approval/approval_alert_popup.dart`
- Contract approval form: `lib/features/approval/contract_approval_modal.dart`
  - Usage doc: `lib/features/approval/USAGE_EXAMPLE.md`

## Key UI Elements
- ElectronicApprovalManagementScreen
  - New document button -> opens `CommonElectronicApprovalModal`
  - Approval line management entry
  - Table row -> `ApprovalDetailModal` (`lib/ui/screens/approval_detail_modal.dart`)

## AMQP / Notifications
- AMQP queue routing: `lib/shared/services/amqp_service.dart`
  - `eapproval.alert` queue
  - `approval_type`: `eapproval`, `hr_leave`, `hr_leave_grant`
  - Alerts rendered by `ApprovalAlertPopup`

## Approval Line (shared with Leave)
- Save/Load endpoints
  - `POST /eapproval/setApprovalLine`
  - `POST /eapproval/getApprovalLine`
- Save/Load service: `lib/shared/services/leave_api_service.dart`

## Module Checklist (what to change)
- Approval form layout/fields: `lib/features/approval/common_electronic_approval_modal.dart`
- Draft modal defaults: `lib/features/approval/electronic_approval_draft_modal.dart`
- Alert routing/UI: `lib/shared/services/amqp_service.dart`,
  `lib/features/approval/approval_alert_popup.dart`
