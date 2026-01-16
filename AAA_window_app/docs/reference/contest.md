# App Reference - Contest

## Primary Screens
- Contest main screen: `lib/ui/screens/contest_screen.dart`
- Contest guide: `lib/ui/screens/contest_guide_screen.dart`
- Voting: `lib/ui/screens/voting_screen.dart`

## Contest API Service
`lib/shared/services/contest_api_service.dart`
- `POST /contest/chat` (multipart) -> contest chat
- `POST /contest/request` (multipart) -> submit application
- `POST /contest/management` -> list
- `POST /contest/management/detail` -> detail
- `POST /contest/user/remainVotes` -> remaining votes
- `POST /contest/user/management` -> user submissions
- `POST /contest/user/check` -> submitted or not
- `POST /contest/userInfo` -> user info
- `POST /contest/vote` -> vote
- `POST /contest/comment/management` -> list comments
- `POST /contest/comment/request` (multipart) -> add comment
- `POST /contest/comment/delete` -> delete comment
- `POST /contest/like` -> like
- `POST /contest/update` (multipart) -> update submission

## AMQP / Notifications
- Contest detail alerts: `lib/shared/services/amqp_service.dart`
  - `renderType: contest_detail`
  - fields: `contest_id`, `contest_type`

## Module Checklist (what to change)
- Form fields and chat UX: `lib/ui/screens/contest_screen.dart`
- API payloads and file uploads: `lib/shared/services/contest_api_service.dart`
- Voting UX: `lib/ui/screens/voting_screen.dart`
