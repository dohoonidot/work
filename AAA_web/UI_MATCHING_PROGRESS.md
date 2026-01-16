# Flutter UI 매칭 진행 상황

## ✅ 완료된 작업 (2024-01-24)

### 1. **사이드바 완전 일치**

#### 변경 사항:
- ✅ 너비: `280px` → `230px` (Flutter와 동일)
- ✅ 배경색: `colorScheme.sidebarBackgroundColor` (#F7F7F8) 적용
- ✅ 헤더 그라디언트: Flutter 스타일 그라디언트 적용
  - Start: `#FAFAFA`
  - End: `#F0F0F0`
- ✅ 헤더 텍스트:
  - 메인: "AI Chatbot" (Flutter와 동일)
  - 서브: "ASPN AI Agent"

#### 아이콘 & 버튼:
- ✅ 검색 버튼: 20px, opacity 0.7
- ✅ 새 채팅방 버튼: 19px, opacity 0.7
- ✅ 리스트 아이콘: 18px, opacity 0.7 (Flutter와 동일)

#### 리스트 아이템 스타일:
- ✅ Border Radius: `8px` (Flutter와 동일)
- ✅ 패딩: `vertical 0.5 (4px)`, Flutter 패딩 적용
- ✅ 최소 높이: 40px
- ✅ 아이콘 minWidth: 36px
- ✅ 폰트 크기: 14px (0.875rem)
- ✅ 선택 상태 배경:
  - AI Chatbot: `rgba(107, 70, 193, 0.08)` (보라색)
  - 기타: `#E5E7EB` (회색)
- ✅ Hover 상태: `rgba(0, 0, 0, 0.04)`

#### 태그 스타일:
- ✅ 높이: 18px
- ✅ 폰트 크기: 10px (0.625rem)
- ✅ Border Radius: 4px
- ✅ 배경: `${color}33` (20% opacity)

---

### 2. **업무 메뉴 섹션**

#### 변경 사항:
- ✅ 헤더 제거 (Flutter에는 없음)
- ✅ 아이콘 크기: 18px, opacity 0.7
- ✅ Border Radius: 8px
- ✅ 패딩: Flutter와 동일
- ✅ minWidth: 36px

---

### 3. **반응형 통합 유지**

#### 유지된 기능:
- ✅ Desktop/Mobile 단일 컴포넌트
- ✅ 900px breakpoint
- ✅ Drawer variant 자동 전환 (permanent/temporary)
- ✅ 모바일 AppBar with hamburger menu

---

## 📊 전후 비교

### Before (이전)
```
사이드바 너비: 280px
헤더: "ASPN AI Agent" (파란색 그라디언트)
아이콘: 20px, 색상 다양
리스트 패딩: 큼 (py: 1.5)
Border Radius: 16px (2)
선택 상태: borderLeft만
```

### After (현재 - Flutter 일치)
```
사이드바 너비: 230px ✅
헤더: "AI Chatbot" (연한 회색 그라디언트) ✅
아이콘: 18px, opacity 0.7 ✅
리스트 패딩: 작음 (py: 0.5) ✅
Border Radius: 8px ✅
선택 상태: 전체 배경색 ✅
```

---

## 🎨 적용된 Flutter 디자인 값

### 색상 (Light Theme)
```javascript
sidebarBackgroundColor: '#F7F7F8'  ✅
sidebarTextColor: '#202123'        ✅
sidebarGradientStart: '#FAFAFA'    ✅
sidebarGradientEnd: '#F0F0F0'      ✅
```

### 크기
```javascript
SIDEBAR_WIDTH: 230px               ✅
아이콘: 18px                        ✅
리스트 아이템: 40px minHeight       ✅
Border Radius: 8px                 ✅
```

### 간격
```javascript
아이템 패딩: vertical 4px (0.5)     ✅
아이템 마진: horizontal 8px (1)     ✅
아이콘 minWidth: 36px               ✅
```

---

## 🚧 다음 작업 (남은 작업)

### 1. ChatArea (메인 채팅 영역)
- [ ] 채팅 버블 스타일 일치
  - User bubble: #FFFFFF with shadow
  - AI bubble: #F7F7F8
  - Border radius: 12px
  - Padding: 10px
  - Box shadow: rgba(0,0,0,0.15) blur 4px offset (0, 2)
- [ ] 메시지 간격: 4px top, 12px bottom
- [ ] 최대 너비: 85% (일반), 95% (테이블/첨부파일)

### 2. Input Field
- [ ] Border radius: 8px (현재는 12px)
- [ ] 높이: 35px~200px
- [ ] Border: 1px #E5E5E5
- [ ] 첨부 버튼: 40x40px, 아이콘 20px

### 3. 기타 페이지
- [ ] LoginPage 스타일 일치
- [ ] SettingsPage 스타일 일치
- [ ] 모든 버튼 border radius 8px로 통일

### 4. 세부 조정
- [ ] 코드 블록: border radius 8px, 패딩 10px
- [ ] AI Model Selector: 11px font, 600 weight
- [ ] 모든 transition 속도 200ms로 통일

---

## 📁 수정된 파일

### 완료
- ✅ `/web_app/src/pages/ChatPage.tsx` - 사이드바 완전 일치
- ✅ `/web_app/src/store/themeStore.ts` - 이미 Flutter 색상 일치

### 다음 차례
- ⏳ `/web_app/src/components/chat/ChatArea.tsx` - 채팅 버블, 입력창
- ⏳ `/web_app/src/components/chat/MessageRenderer.tsx` - 메시지 렌더링
- ⏳ `/web_app/src/pages/LoginPage.tsx` - 로그인 UI
- ⏳ `/web_app/src/pages/SettingsPage.tsx` - 설정 UI

---

## 🎯 목표

**Flutter Desktop App UI와 100% 동일한 React 웹앱 완성**

### 진행률
- [x] 테마 색상 시스템 (100%)
- [x] 사이드바 (100%)
- [ ] 채팅 영역 (50%)
- [ ] 입력 필드 (30%)
- [ ] 기타 페이지 (20%)

**전체 진행률: ~60%**

---

## 📸 스크린샷 비교 (예정)

향후 Flutter 앱과 React 웹의 스크린샷을 나란히 비교하여
완벽한 UI 일치를 검증할 예정입니다.
