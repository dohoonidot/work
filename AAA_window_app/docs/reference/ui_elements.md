# App Reference - UI Elements

## Chat UI
`lib/features/chat/chat_area_v3.dart`
- Send button: 메시지 전송 + 스트리밍 시작
- Attachment button: `FileAttachmentModal` 열기
- Web search toggle: `selectedWebSearchProvider` 반영
- Model selector: `AiModelSelector` (코드/SAP/AI Chatbot)

## Attachment Modal
`lib/features/chat/file_attachment_modal.dart`
- Title: "파일 첨부"
- Drop zone: 클릭/드래그로 파일 추가
- Allowed types: `jpg, jpeg, png, pdf`

## Leave Management
`lib/ui/screens/leave_management_screen.dart`
- Title: "휴가관리"
- Buttons: "휴가 작성", "관리자용 결재"(approver만)
- Sections: 내 휴가 현황, 결재 진행 현황, 개인별 휴가 내역,
  달력, 휴가 관리 대장

## Admin Leave Approval
`lib/ui/screens/admin_leave_approval_screen.dart`
- Title: "관리자 - 휴가 결재 관리"
- Tabs: "대기 중", "전체"
- Filters: "휴가관리" (user 화면 전환), "취소건 숨기기"
