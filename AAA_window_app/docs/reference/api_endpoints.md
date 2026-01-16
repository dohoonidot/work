# App Reference - API Endpoints

Base URL: `AppConfig.baseUrl` in `lib/core/config/app_config.dart`

## Core APIs (archives, notifications, org data)
`lib/shared/services/api_service.dart`

Archive APIs
- `POST /getArchiveList` -> `{ user_id }`
- `POST /getSingleArchive` -> `{ archive_id, max_chat_id }`
- `POST /createArchive` -> `{ user_id, archive_type }`
- `POST /updateArchive` -> `{ user_id, archive_id, archive_name }`
- `POST /deleteArchive` -> `{ archive_id }`

Notifications / queue
- `POST /getNotifications` -> `{ user_id }`
- `POST /getMaxSerial`
- `POST /getlastChatId`
- `POST /checkPrivacy` -> `{ user_id }`
- `POST /updatePrivacy` -> `{ user_id, consent }`
- `POST /queue/checkGifts` -> `{ user_id }`
- `POST /queue/checkAlerts` -> `{ user_id }`
- `POST /queue/updateAlerts` -> `{ user_id, alert_id }`
- `POST /queue/deleteAlerts` -> `{ user_id, alert_id }`

Org data
- `POST /api/getDepartmentList`
- `POST /api/getCompanyMembers`
- `GET /api/holidays?year=YYYY&month=MM`

## Chat Stream APIs
`lib/shared/services/stream_service.dart`
- `POST /streamChat/timeout` (multipart)
  - fields: `category`, `module`, `archive_id`, `user_id`, `message`
  - files: `files[]` (bytes + `mimeType`)
- `POST /streamChat/withModel` (multipart)
  - fields: `archive_id`, `user_id`, `message`, optional `category`, `module`,
    `model`, `search_yn`
  - files: `files[]`
- `POST /streamChat/attachment` (deprecated)

## Leave / Approval APIs
`lib/shared/services/leave_api_service.dart`

User management
- `POST /leave/user/management` -> `{ user_id }`
- `POST /leave/user/management/myCalendar` -> `MonthlyCalendarRequest`
- `POST /leave/user/management/yearly` -> `YearlyLeaveRequest`
- `POST /leave/user/management/totalCalendar` -> `TotalCalendarRequest`
- `POST /leave/user/management/nextYear` -> `{ user_id }`

User requests
- `POST /leave/user/request` -> `LeaveRequestRequest`
- `POST /leave/user/cancel` -> `LeaveCancelRequest`
- `POST /leave/user/cancel/request` -> `{ id, user_id, reason }`

Admin / approver
- `POST /leave/admin/management` -> `AdminManagementRequest`
- `POST /leave/admin/management/yearly` -> `AdminManagementRequest`
- `POST /leave/admin/management/deptCalendar` -> `AdminDeptCalendarRequest`
- `POST /leave/admin/management/waitingLeaves` -> `{ approver_id }`
- `POST /leave/admin/approval` -> `AdminApprovalRequest`
- `POST /leave/admin/approval/cancel` -> `AdminApprovalRequest`
- `POST /leave/admin/status` -> `{ approver_id }`

Grant/attachments
- `POST /leave/grant/request` (multipart)
  - text fields: `user_id`, `department`, `approval_date`, `approval_type`,
    `title`, `leave_type`, `grant_days`, `reason`, optional `start_date`,
    `end_date`, `half_day_slot`, JSON fields `approval_line`,
    `attachments_list`, optional `cc_list`
  - files: `files[]` + `fileNames[]` (when provided)
- `POST /leave/user/getGrantRequestList` -> `{ user_id }`
- `POST /api/getFileUrl` -> `{ file_id }`

Approval line
- `POST /leave/user/getApprover`
- `POST /leave/user/setApprovalLine` -> `ApprovalLineSaveRequest`
- `POST /leave/user/getApprovalLine`
- `POST /eapproval/setApprovalLine` -> `ApprovalLineSaveRequest`
- `POST /eapproval/getApprovalLine`

## API Sample Shapes
Archive list
```json
// POST /getArchiveList
{ "user_id": "user@company.com" }
```

Stream chat (no files)
```json
// POST /streamChat/timeout (multipart fields only)
{
  "category": "",
  "module": "",
  "archive_id": "uuid",
  "user_id": "user@company.com",
  "message": "질문"
}
```

Leave management
```json
// POST /leave/user/management
{ "user_id": "user@company.com" }
```

Leave request
```json
// POST /leave/user/request
{
  "user_id": "user@company.com",
  "leave_type": "연차",
  "start_date": "2025-01-20",
  "end_date": "2025-01-20",
  "half_day_slot": "AM",
  "reason": "사유"
}
```

Approval line save
```json
// POST /leave/user/setApprovalLine
{
  "user_id": "user@company.com",
  "approval_line": [
    { "approver_id": "A001", "approver_name": "김과장", "approval_seq": 1 }
  ],
  "cc_list": [
    { "user_id": "B002", "name": "이차장" }
  ]
}
```
