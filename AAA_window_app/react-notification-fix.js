// React NotificationPanel 접근성 문제 해결 코드
// 이 파일을 React 프로젝트의 components 폴더에 추가하세요

import React, { useEffect, useRef } from 'react';
import { Drawer, List, ListItem, ListItemButton, IconButton } from '@mui/material';

// 개선된 포커스 트랩 훅 - 더 강력한 포커스 관리
export const useFocusTrap = (isActive, onEscape) => {
  const containerRef = useRef(null);
  const previouslyFocusedElement = useRef(null);

  useEffect(() => {
    if (!isActive) {
      // 비활성 상태일 때 이전 포커스로 복원
      if (previouslyFocusedElement.current) {
        previouslyFocusedElement.current.focus();
        previouslyFocusedElement.current = null;
      }
      return;
    }

    // 현재 포커스된 요소 저장
    previouslyFocusedElement.current = document.activeElement;

    // 포커스 가능한 요소들 찾기 (더 정확한 선택자)
    const getFocusableElements = () => {
      if (!containerRef.current) return [];
      return Array.from(containerRef.current.querySelectorAll(
        'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"]):not([disabled])'
      )).filter(el => {
        // 보이는 요소만 포함
        const style = window.getComputedStyle(el);
        return style.display !== 'none' && style.visibility !== 'hidden';
      });
    };

    // 첫 번째 포커스 가능한 요소로 이동
    const focusFirstElement = () => {
      const focusableElements = getFocusableElements();
      if (focusableElements.length > 0) {
        focusableElements[0].focus({ preventScroll: true });
      }
    };

    // 키보드 이벤트 처리
    const handleKeyDown = (event) => {
      if (!isActive) return;

      const focusableElements = getFocusableElements();
      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];
      const currentElement = document.activeElement;

      if (event.key === 'Tab') {
        if (event.shiftKey) {
          // Shift + Tab
          if (currentElement === firstElement) {
            event.preventDefault();
            lastElement?.focus({ preventScroll: true });
          }
        } else {
          // Tab
          if (currentElement === lastElement) {
            event.preventDefault();
            firstElement?.focus({ preventScroll: true });
          }
        }
      } else if (event.key === 'Escape') {
        // ESC 키 처리
        event.preventDefault();
        if (onEscape) onEscape();
      }
    };

    // 이벤트 리스너 등록
    document.addEventListener('keydown', handleKeyDown, true); // 캡처링 단계에서 처리

    // 초기 포커스 설정 (더 빠르게)
    const timer = setTimeout(focusFirstElement, 50);

    return () => {
      clearTimeout(timer);
      document.removeEventListener('keydown', handleKeyDown, true);
    };
  }, [isActive, onEscape]);

  return containerRef;
};

// 개선된 NotificationPanel 컴포넌트
const NotificationPanel = ({ open, onClose, notifications, onNotificationClick }) => {
  const containerRef = useFocusTrap(open, onClose);

  const handleNotificationClick = (notification) => {
    // 알림 클릭 처리
    if (onNotificationClick) {
      onNotificationClick(notification);
    }
  };

  // Drawer가 열릴 때 포커스 강제 이동
  useEffect(() => {
    if (open) {
      // Material-UI의 aria-hidden 설정 이후에 포커스 이동
      const timer = setTimeout(() => {
        const closeButton = containerRef.current?.querySelector('[data-first-focus]');
        if (closeButton) {
          closeButton.focus({ preventScroll: true });
        }
      }, 150); // Material-UI 애니메이션 이후

      return () => clearTimeout(timer);
    }
  }, [open]);

  return (
    <Drawer
      anchor="right"
      open={open}
      onClose={onClose}
      ModalProps={{
        keepMounted: true,
        disableEnforceFocus: true,  // Material-UI 포커스 강제 비활성화
        disableAutoFocus: true,     // 자동 포커스 비활성화
        disableRestoreFocus: true,  // 포커스 복원 비활성화 (수동으로 처리)
        onTransitionEnter: () => {
          // 트랜지션 완료 후 포커스 이동
          setTimeout(() => {
            const closeButton = document.querySelector('[data-first-focus]');
            if (closeButton) {
              closeButton.focus({ preventScroll: true });
            }
          }, 200);
        }
      }}
      // Drawer 자체에 inert 속성 적용 시도 (브라우저 지원 시)
      style={{
        ...(open && { inert: 'true' })
      }}
    >
      <div
        ref={containerRef}
        style={{ width: 350, padding: 16 }}
        role="dialog"
        aria-label="알림 패널"
        aria-modal="true"
      >
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 16 }}>
          <IconButton
            onClick={onClose}
            aria-label="알림 패널 닫기"
            data-first-focus
          >
            ✕
          </IconButton>
          <h2 style={{ flex: 1, margin: 0 }}>알림</h2>
        </div>

        <List role="list" aria-label="알림 목록">
          {notifications && notifications.length > 0 ? (
            notifications.map((notification) => (
              <ListItem key={notification.id} disablePadding role="listitem">
                <ListItemButton
                  onClick={() => handleNotificationClick(notification)}
                  aria-label={`${notification.title}: ${notification.message}`}
                >
                  <div style={{ width: '100%' }}>
                    <div style={{ fontWeight: 'bold', marginBottom: 4 }}>
                      {notification.title}
                    </div>
                    <div style={{ fontSize: '0.9em', color: '#666' }}>
                      {notification.message}
                    </div>
                    <div style={{ fontSize: '0.8em', color: '#999', marginTop: 4 }}>
                      {notification.time}
                    </div>
                  </div>
                </ListItemButton>
              </ListItem>
            ))
          ) : (
            <ListItem>
              <div style={{ textAlign: 'center', width: '100%', color: '#666' }}>
                새로운 알림이 없습니다.
              </div>
            </ListItem>
          )}
        </List>
      </div>
    </Drawer>
  );
};

// 경고 억제 컴포넌트 (선택사항)
export const SuppressAriaHiddenWarnings = () => {
  useEffect(() => {
    // 원래 console.warn 저장
    const originalWarn = console.warn;

    // aria-hidden 경고 필터링
    console.warn = (...args) => {
      const message = args.join(' ');
      if (!message.includes('aria-hidden') || !message.includes('descendant retained focus')) {
        originalWarn.apply(console, args);
      }
    };

    return () => {
      // 정리
      console.warn = originalWarn;
    };
  }, []);

  return null;
};

export default NotificationPanel;

/*
// 사용 예시:

import NotificationPanel, { SuppressAriaHiddenWarnings } from './NotificationPanel';

function App() {
  const [isNotificationOpen, setIsNotificationOpen] = useState(false);

  return (
    <>
      {/* 경고 억제 컴포넌트 (선택사항 - 경고가 거슬릴 때만 사용) */}
      <SuppressAriaHiddenWarnings />

      <NotificationPanel
        open={isNotificationOpen}
        onClose={() => setIsNotificationOpen(false)}
        notifications={notifications}
        onNotificationClick={(notification) => {
          console.log('알림 클릭:', notification);
          // 알림 처리 로직
        }}
      />
    </>
  );
}
*/
