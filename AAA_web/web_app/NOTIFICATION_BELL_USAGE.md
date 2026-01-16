# 알림함 API 연동 가이드

알림함 API를 사용하여 React 웹에서 알림 기능을 구현한 가이드입니다.

## 📁 생성된 파일

### 1. 타입 정의
**파일**: `src/types/notification.ts`

알림함 관련 타입 정의가 추가되었습니다:
- `AlertItem`: 알림 아이템
- `CheckAlertsRequest/Response`: 알림 목록 조회
- `UpdateAlertRequest/Response`: 알림 읽음 처리
- `DeleteAlertRequest/Response`: 알림 삭제

### 2. API 서비스
**파일**: `src/services/notificationApi.ts`

다음 3개의 API 함수를 제공합니다:
- `getAlerts(userId)`: 알림 목록 조회
- `markAsRead(userId, alertId)`: 알림 읽음 처리
- `deleteAlert(userId, alertId)`: 알림 삭제

### 3. 헬퍼 함수
**파일**: `src/utils/notificationHelpers.ts`

UI 표시를 위한 유틸리티 함수:
- `getIconByQueueName()`: 큐 이름별 아이콘
- `getTitleByQueueName()`: 큐 이름별 제목
- `formatDateTime()`: 상대 시간 포맷팅
- `formatAbsoluteDateTime()`: 절대 시간 포맷팅
- `truncateMessage()`: 메시지 축약

### 4. NotificationBell 컴포넌트
**파일**: `src/components/common/NotificationBell.tsx`

알림함 기능을 제공하는 React 컴포넌트입니다.

## 🚀 사용 방법

### 기본 사용법

```tsx
import { NotificationBell } from './components/common/NotificationBell';

function App() {
  const userId = 'admin@aspnc.com'; // 로그인한 사용자 ID

  return (
    <div>
      <header>
        <h1>My App</h1>
        {/* 알림 벨 컴포넌트 추가 */}
        <NotificationBell userId={userId} />
      </header>
      {/* ... 나머지 앱 내용 */}
    </div>
  );
}
```

### Props

| Prop | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `userId` | `string` | ✅ | - | 사용자 ID (이메일) |
| `refreshInterval` | `number` | ❌ | `30000` | 알림 자동 새로고침 간격 (ms) |

### 예제: 헤더에 통합

```tsx
import React from 'react';
import { AppBar, Toolbar, Typography, Box } from '@mui/material';
import { NotificationBell } from './components/common/NotificationBell';

interface HeaderProps {
  userId: string;
}

export function Header({ userId }: HeaderProps) {
  return (
    <AppBar position="static">
      <Toolbar>
        <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
          ASPN AI Agent
        </Typography>

        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          {/* 알림 벨 */}
          <NotificationBell
            userId={userId}
            refreshInterval={60000} // 1분마다 새로고침
          />

          {/* 다른 헤더 버튼들 */}
          {/* ... */}
        </Box>
      </Toolbar>
    </AppBar>
  );
}
```

### 예제: 사용자 정보와 함께 사용

```tsx
import React from 'react';
import { NotificationBell } from './components/common/NotificationBell';
import { useAuth } from './hooks/useAuth'; // 인증 훅

export function MainLayout() {
  const { user } = useAuth(); // 로그인한 사용자 정보

  if (!user) {
    return <div>로그인이 필요합니다.</div>;
  }

  return (
    <div>
      <header>
        <h1>Welcome, {user.name}</h1>
        <NotificationBell userId={user.email} />
      </header>
      {/* ... */}
    </div>
  );
}
```

## 🔧 API 직접 사용하기

컴포넌트 없이 API만 사용하는 방법:

```tsx
import { notificationApi } from './services/notificationApi';

// 알림 목록 조회
async function loadNotifications() {
  try {
    const alerts = await notificationApi.getAlerts('admin@aspnc.com');
    console.log('알림 목록:', alerts);

    // 읽지 않은 알림 개수
    const unreadCount = alerts.filter(a => !a.is_read).length;
    console.log('읽지 않은 알림:', unreadCount);
  } catch (error) {
    console.error('알림 로드 실패:', error);
  }
}

// 알림 읽음 처리
async function markNotificationAsRead(alertId: number) {
  try {
    const updatedAlerts = await notificationApi.markAsRead(
      'admin@aspnc.com',
      alertId
    );
    console.log('읽음 처리 완료:', updatedAlerts);
  } catch (error) {
    console.error('읽음 처리 실패:', error);
  }
}

// 알림 삭제
async function deleteNotification(alertId: number) {
  try {
    const updatedAlerts = await notificationApi.deleteAlert(
      'admin@aspnc.com',
      alertId
    );
    console.log('삭제 완료:', updatedAlerts);
  } catch (error) {
    console.error('삭제 실패:', error);
  }
}
```

## 🎨 커스터마이징

### 큐 이름별 아이콘/제목 추가

`src/utils/notificationHelpers.ts` 파일을 수정하여 새로운 큐 타입을 추가할 수 있습니다:

```typescript
export const getIconByQueueName = (queueName: string): string => {
  switch (queueName) {
    case 'birthday':
      return '🎂';
    case 'gift':
      return '🎁';
    // 새로운 큐 타입 추가
    case 'my_custom_queue':
      return '🌟';
    default:
      return '🔔';
  }
};

export const getTitleByQueueName = (queueName: string): string => {
  switch (queueName) {
    case 'birthday':
      return '생일 알림';
    case 'gift':
      return '선물 도착';
    // 새로운 큐 타입 추가
    case 'my_custom_queue':
      return '커스텀 알림';
    default:
      return '알림';
  }
};
```

### 스타일 커스터마이징

NotificationBell 컴포넌트의 스타일을 수정하려면 `sx` prop을 수정하거나, Material-UI 테마를 사용하세요:

```tsx
// 아이콘 버튼 색상 변경 예시
<IconButton
  onClick={() => setIsOpen(true)}
  aria-label="알림함"
  sx={{
    mr: 1,
    bgcolor: 'primary.main', // 테마의 primary 색상 사용
    color: 'white',
    '&:hover': {
      bgcolor: 'primary.dark',
    },
    boxShadow: 2,
  }}
>
  {/* ... */}
</IconButton>
```

## 📊 API 응답 형식

### 알림 목록 조회 응답
```json
{
  "alerts": [
    {
      "id": 123,
      "queue_name": "birthday",
      "message": "🎉 김철수님의 생일입니다! 선물을 준비해보세요.",
      "send_time": "2024-01-15 09:00:00",
      "is_read": false,
      "is_deleted": false
    }
  ]
}
```

### 에러 응답
```json
{
  "error": "알림 목록 조회에 실패했습니다.",
  "alerts": []
}
```

## 🔍 디버깅

API 호출 로그를 확인하려면 브라우저 개발자 도구의 콘솔을 확인하세요:

```
[NotificationBell] 알림 로드 실패: Error: ...
[NotificationBell] 읽음 처리 실패: Error: ...
[NotificationBell] 삭제 실패: Error: ...
```

## ⚠️ 주의사항

1. **사용자 ID**: `userId` prop은 반드시 로그인한 사용자의 이메일이어야 합니다.
2. **API 엔드포인트**: API 서버는 `https://ai2great.com:8060`을 사용합니다 (개발 환경).
3. **새로고침 간격**: `refreshInterval`을 너무 짧게 설정하면 서버 부하가 증가할 수 있습니다.
4. **쿠키 인증**: API는 쿠키 기반 인증을 사용하므로 `withCredentials: true` 설정이 필요합니다.

## 🧪 테스트

### 수동 테스트

1. 앱 실행:
```bash
cd /mnt/c/AI_Agent/AI_Agent/Agent_APP/AAA_web/web_app
npm run dev
```

2. 브라우저에서 알림 벨 아이콘 클릭

3. 알림 목록 확인

4. 알림 클릭하여 읽음 처리 테스트

5. 삭제 버튼으로 알림 삭제 테스트

### API 테스트 (curl)

```bash
# 알림 목록 조회
curl -X POST https://ai2great.com:8060/queue/checkAlerts \
  -H "Content-Type: application/json" \
  -d '{"user_id":"admin@aspnc.com"}'

# 알림 읽음 처리
curl -X POST https://ai2great.com:8060/queue/updateAlerts \
  -H "Content-Type: application/json" \
  -d '{"id":123,"user_id":"admin@aspnc.com"}'

# 알림 삭제
curl -X POST https://ai2great.com:8060/queue/deleteAlerts \
  -H "Content-Type: application/json" \
  -d '{"id":123,"user_id":"admin@aspnc.com"}'
```

## 📝 관련 파일

- `src/types/notification.ts` - 타입 정의
- `src/services/notificationApi.ts` - API 서비스
- `src/utils/notificationHelpers.ts` - 헬퍼 함수
- `src/components/common/NotificationBell.tsx` - 메인 컴포넌트

## 🎯 다음 단계

1. **실시간 알림**: SSE (Server-Sent Events)와 통합하여 실시간 알림 수신
2. **알림 필터링**: 큐 타입별로 알림 필터링 기능 추가
3. **알림 검색**: 알림 메시지 검색 기능 추가
4. **알림 설정**: 사용자별 알림 설정 (알림 끄기/켜기 등)

---

구현 완료! 🎉
