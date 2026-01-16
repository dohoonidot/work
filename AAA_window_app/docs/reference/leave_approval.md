# App Reference - Leave and Approval

## Primary Screens and Modals
- User leave management: `lib/ui/screens/leave_management_screen.dart`
- Admin approval: `lib/ui/screens/admin_leave_approval_screen.dart`
- Leave request modal: `lib/features/leave/leave_request_manual_modal.dart`
- Leave draft modal (AI-triggered): `lib/features/leave/leave_draft_modal.dart`
- Leave sidebar: `lib/features/leave/leave_request_sidebar.dart`
- Full calendar modal: `lib/features/leave/full_calendar_modal.dart`
- Annual leave notice: `lib/features/leave/annual_leave_notice_screen.dart`
- Grant history: `lib/features/leave/leave_grant_history_screen.dart`
- Vacation recommendation UI: `lib/features/leave/widgets/vacation_recommendation_popup.dart`

## Providers
- `leaveManagementProvider`: `lib/provider/leave_management_provider.dart`
- `leaveModalProvider`: `lib/features/leave/leave_modal_provider.dart`
- `vacationDataProvider`: `lib/features/leave/vacation_data_provider.dart`
- `leaveNotificationProvider`: `lib/features/leave/providers/leave_notification_provider.dart`
- `leaveRequestHistoryProvider`, `leaveBalanceProvider`,
  `departmentMembersProvider`, `departmentLeaveHistoryProvider`,
  `leaveManagementTableProvider`, `pendingApprovalsProvider`,
  `selectedYearProvider`, `currentUserIdProvider`
  - `lib/features/leave/leave_providers.dart`

## Key Models (fields)
`lib/models/leave_management_models.dart`
- `LeaveStatus`: `leave_type`, `total_days`, `remain_days`
- `ApprovalStatus`: `REQUESTED`, `APPROVED`, `REJECTED`
- `YearlyDetail`: `id`, `status`, `leave_type`, `start_date`, `end_date`,
  `workdays_count`, `requested_date`, `reason`, `reject_message`, `is_cancel`
- `YearlyWholeStatus`: `leave_type`, `total_days`, `m01..m12`, `remain_days`
- `MonthlyLeave`: `status`, `leave_type`, `start_date`, `end_date`,
  `half_day_slot`, `reason`, `reject_message`
- Admin models: `AdminWaitingLeave`, `AdminMonthlyLeave`,
  `AdminApprovalStatus`, `AdminManagementRequest/Response`,
  `AdminApprovalRequest/Response`, `AdminDeptCalendarRequest/Response`

`lib/features/leave/leave_models.dart`
- `LeaveRequestHistory` (user request list)
- `LeaveGrantRequest` / `LeaveGrantResponse`
- `LeaveGrantRequestItem` / `LeaveGrantRequestListResponse`
- `NextYearLeaveStatus` / `NextYearLeaveStatusResponse`

Draft/AI data mapping
`lib/features/leave/vacation_data_provider.dart`
- `VacationRequestData`: `user_id`, `leave_type`, `start_date`, `end_date`,
  `half_day_slot`, `reason`, `approval_line`, `cc_list`, `leave_status`
- `ApprovalLineData`, `CcPersonData`, `LeaveStatusData`

## Module Checklist (what to change)
- User leave UI: `lib/ui/screens/leave_management_screen.dart`
- Admin approval UI: `lib/ui/screens/admin_leave_approval_screen.dart`
- Leave API params/endpoints: `lib/shared/services/leave_api_service.dart`
- Leave data models: `lib/models/leave_management_models.dart`
- Draft/AI mapping: `lib/features/leave/vacation_data_provider.dart`

## Realtime / AMQP
- AMQP integration: `lib/shared/services/amqp_service.dart`
- Leave realtime stream: `lib/features/leave/services/leave_realtime_service.dart`
- UI badges / counts: `lib/shared/providers/notification_notifier.dart`,
  `lib/features/leave/providers/leave_notification_provider.dart`
