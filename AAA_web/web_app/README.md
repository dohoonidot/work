# ASPN AI Agent - 모바일 웹 버전

Flutter Windows 데스크톱 앱을 웹으로 전환한 프로젝트입니다.
`lib` 폴더의 Flutter 코드를 참조하여 React + TypeScript로 구현했습니다.

## 📂 위치

```
C:\AI_Agent\AI_Agent\Agent_APP\AAA_mobile_web\web_app\
```

## 🎯 구현 완료 기능

### ✅ Phase 1 (완료)
- [x] React + TypeScript 프로젝트 생성 (Vite)
- [x] Material-UI 통합
- [x] API 서비스 (lib/core/config/app_config.dart 참조)
- [x] 로그인 기능 (lib/features/auth 참조)
- [x] 채팅 기능 (lib/features/chat 참조)
- [x] 아카이브 관리
- [x] AI 응답 스트리밍
- [x] 마크다운 렌더링

## 🚀 실행 방법

### 1. 개발 서버 실행
```bash
cd C:\AI_Agent\AI_Agent\Agent_APP\AAA_mobile_web\web_app
npm run dev
```

브라우저에서 http://localhost:5173 열기

### 2. 프로덕션 빌드
```bash
npm run build
```

빌드된 파일은 `dist/` 폴더에 생성됩니다.

## 📁 프로젝트 구조

```
web_app/
├── src/
│   ├── components/
│   │   ├── auth/
│   │   │   ├── LoginForm.tsx          ✅ 로그인 폼
│   │   │   └── PrivateRoute.tsx       ✅ 인증 보호
│   │   └── chat/
│   │       └── ChatArea.tsx            ✅ 채팅 UI
│   ├── pages/
│   │   ├── LoginPage.tsx               ✅ 로그인 페이지
│   │   └── ChatPage.tsx                ✅ 채팅 페이지
│   ├── services/
│   │   ├── api.ts                      ✅ Axios 설정
│   │   ├── authService.ts              ✅ 인증 API
│   │   └── chatService.ts              ✅ 채팅 API
│   └── App.tsx                         ✅ 메인 앱
├── .env                                ✅ 환경 변수
└── package.json
```

## 🛠 기술 스택

- **React 19** + **TypeScript**
- **Vite** (빌드 도구)
- **Material-UI** (UI 프레임워크)
- **React Router v6** (라우팅)
- **Axios** (HTTP 클라이언트)
- **react-markdown** (마크다운 렌더링)
- **Zustand** (상태 관리 - 준비됨)

## 🔗 Flutter 코드 참조

이 웹 앱은 다음 Flutter 코드를 참조하여 구현되었습니다:

| 웹 파일 | 참조한 Flutter 파일 |
|---------|---------------------|
| `services/api.ts` | `lib/core/config/app_config.dart` |
| `services/authService.ts` | `lib/shared/services/api_service.dart` (로그인 부분) |
| `services/chatService.ts` | `lib/shared/services/api_service.dart` (채팅 부분) |
| `components/auth/LoginForm.tsx` | `lib/ui/screens/login_page.dart` |
| `components/chat/ChatArea.tsx` | `lib/ui/screens/chat_home_page_v5.dart` |

## 📱 API 엔드포인트

### 인증
- `POST /api/login` - 로그인
- `POST /checkPrivacy` - 개인정보 동의 상태 조회
- `POST /updatePrivacy` - 개인정보 동의 상태 업데이트

### 채팅
- `POST /getArchiveList` - 아카이브 목록 조회
- `POST /getSingleArchive` - 아카이브 상세 조회
- `POST /createArchive` - 새 아카이브 생성
- `POST /updateArchive` - 아카이브 이름 수정
- `POST /deleteArchive` - 아카이브 삭제
- `POST /chat` - AI에게 메시지 전송 (스트리밍)

## 🔐 환경 변수

`.env` 파일:
```env
VITE_API_URL=https://ai2great.com:8060  # 개발 환경
# VITE_API_URL=https://ai2great.com:8080  # 프로덕션 환경
VITE_APP_NAME=ASPN AI Agent
VITE_APP_VERSION=1.3.0
```

## 📝 다음 단계

### Phase 2: 추가 기능 구현
- [ ] 전자결재 관리 (lib/features/approval 참조)
- [ ] 휴가 관리 (lib/features/leave 참조)
- [ ] 파일 첨부 기능
- [ ] 실시간 알림 (AMQP)

### Phase 3: Flutter 모바일 WebView 통합
- [ ] Flutter 모바일 앱 생성
- [ ] WebView 설정
- [ ] JavaScript 브릿지

## 🐛 트러블슈팅

### CORS 이슈
개발 환경에서 CORS 에러 발생 시:
```typescript
// vite.config.ts
server: {
  proxy: {
    '/api': {
      target: 'https://ai2great.com:8060',
      changeOrigin: true,
    },
  },
}
```

### 빌드 에러
타입 에러 발생 시:
```bash
npm run build -- --mode development
```

## 📄 라이선스

Private - ASPN AI Agent Team
