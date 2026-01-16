// 모바일 최적화 유틸리티 함수들

/**
 * 모바일 디바이스 감지
 */
export const isMobile = (): boolean => {
  return window.innerWidth <= 768;
};

/**
 * 터치 디바이스 감지
 */
export const isTouchDevice = (): boolean => {
  return 'ontouchstart' in window || navigator.maxTouchPoints > 0;
};

/**
 * 모바일에서 입력 필드 줌 방지를 위한 폰트 크기 조정
 */
export const getMobileFontSize = (baseSize: number = 14): number => {
  return isMobile() ? Math.max(baseSize, 16) : baseSize;
};

/**
 * 모바일에서 터치 영역 최소 크기 보장
 */
export const getMinTouchSize = (): number => {
  return 44; // iOS HIG 권장사항
};

/**
 * 모바일에서 스크롤 최적화
 */
export const enableMobileScroll = (element: HTMLElement): void => {
  element.style.webkitOverflowScrolling = 'touch';
  element.style.overflowScrolling = 'touch';
};

/**
 * 모바일에서 뷰포트 높이 계산 (주소창 고려)
 */
export const getViewportHeight = (): number => {
  return window.innerHeight;
};

/**
 * 모바일에서 안전한 영역 계산
 */
export const getSafeAreaInsets = () => {
  const style = getComputedStyle(document.documentElement);
  return {
    top: parseInt(style.getPropertyValue('--safe-area-inset-top') || '0'),
    right: parseInt(style.getPropertyValue('--safe-area-inset-right') || '0'),
    bottom: parseInt(style.getPropertyValue('--safe-area-inset-bottom') || '0'),
    left: parseInt(style.getPropertyValue('--safe-area-inset-left') || '0'),
  };
};

/**
 * 모바일에서 햅틱 피드백 (지원하는 경우)
 */
export const hapticFeedback = (type: 'light' | 'medium' | 'heavy' = 'light'): void => {
  if ('vibrate' in navigator) {
    const patterns = {
      light: [10],
      medium: [20],
      heavy: [30],
    };
    navigator.vibrate(patterns[type]);
  }
};

/**
 * 모바일에서 키보드 높이 감지
 */
export const getKeyboardHeight = (): Promise<number> => {
  return new Promise((resolve) => {
    const initialHeight = window.innerHeight;
    
    const handleResize = () => {
      const currentHeight = window.innerHeight;
      const keyboardHeight = initialHeight - currentHeight;
      resolve(Math.max(0, keyboardHeight));
    };

    window.addEventListener('resize', handleResize);
    
    // 5초 후 자동으로 정리
    setTimeout(() => {
      window.removeEventListener('resize', handleResize);
    }, 5000);
  });
};

/**
 * 모바일에서 스와이프 제스처 감지
 */
export const detectSwipe = (
  element: HTMLElement,
  onSwipeLeft?: () => void,
  onSwipeRight?: () => void,
  onSwipeUp?: () => void,
  onSwipeDown?: () => void
): (() => void) => {
  let startX = 0;
  let startY = 0;
  let endX = 0;
  let endY = 0;

  const handleTouchStart = (e: TouchEvent) => {
    startX = e.touches[0].clientX;
    startY = e.touches[0].clientY;
  };

  const handleTouchEnd = (e: TouchEvent) => {
    endX = e.changedTouches[0].clientX;
    endY = e.changedTouches[0].clientY;
    
    const deltaX = endX - startX;
    const deltaY = endY - startY;
    const minSwipeDistance = 50;

    if (Math.abs(deltaX) > Math.abs(deltaY)) {
      // 수평 스와이프
      if (deltaX > minSwipeDistance && onSwipeRight) {
        onSwipeRight();
      } else if (deltaX < -minSwipeDistance && onSwipeLeft) {
        onSwipeLeft();
      }
    } else {
      // 수직 스와이프
      if (deltaY > minSwipeDistance && onSwipeDown) {
        onSwipeDown();
      } else if (deltaY < -minSwipeDistance && onSwipeUp) {
        onSwipeUp();
      }
    }
  };

  element.addEventListener('touchstart', handleTouchStart);
  element.addEventListener('touchend', handleTouchEnd);

  // 정리 함수 반환
  return () => {
    element.removeEventListener('touchstart', handleTouchStart);
    element.removeEventListener('touchend', handleTouchEnd);
  };
};

/**
 * 모바일에서 풀스크린 모드 토글
 */
export const toggleFullscreen = (): void => {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen().catch(console.error);
  } else {
    document.exitFullscreen().catch(console.error);
  }
};

/**
 * 모바일에서 PWA 설치 프롬프트
 */
export const installPWA = (): Promise<boolean> => {
  return new Promise((resolve) => {
    if ('serviceWorker' in navigator && 'PushManager' in window) {
      // PWA 설치 가능
      resolve(true);
    } else {
      resolve(false);
    }
  });
};

/**
 * 모바일에서 오프라인 상태 감지
 */
export const isOnline = (): boolean => {
  return navigator.onLine;
};

/**
 * 모바일에서 네트워크 상태 변경 감지
 */
export const onNetworkChange = (callback: (isOnline: boolean) => void): (() => void) => {
  const handleOnline = () => callback(true);
  const handleOffline = () => callback(false);

  window.addEventListener('online', handleOnline);
  window.addEventListener('offline', handleOffline);

  return () => {
    window.removeEventListener('online', handleOnline);
    window.removeEventListener('offline', handleOffline);
  };
};

/**
 * 모바일에서 이미지 최적화
 */
export const optimizeImageForMobile = (imageUrl: string, width: number = 400): string => {
  // 이미지 최적화 서비스 사용 (예: Cloudinary, ImageKit 등)
  return `${imageUrl}?w=${width}&q=80&f=auto`;
};

/**
 * 모바일에서 로딩 상태 표시
 */
export const showMobileLoading = (message: string = '로딩 중...'): void => {
  // 모바일 최적화된 로딩 인디케이터 표시
  const loadingElement = document.createElement('div');
  loadingElement.id = 'mobile-loading';
  loadingElement.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    z-index: 9999;
    color: white;
    font-size: 16px;
  `;
  loadingElement.innerHTML = `
    <div style="
      width: 40px;
      height: 40px;
      border: 4px solid #f3f3f3;
      border-top: 4px solid #1D4487;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin-bottom: 16px;
    "></div>
    <div>${message}</div>
    <style>
      @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }
    </style>
  `;
  document.body.appendChild(loadingElement);
};

/**
 * 모바일 로딩 상태 숨기기
 */
export const hideMobileLoading = (): void => {
  const loadingElement = document.getElementById('mobile-loading');
  if (loadingElement) {
    loadingElement.remove();
  }
};

/**
 * 모바일에서 토스트 메시지 표시
 */
export const showMobileToast = (message: string, type: 'success' | 'error' | 'info' = 'info'): void => {
  const toast = document.createElement('div');
  const colors = {
    success: '#4caf50',
    error: '#f44336',
    info: '#2196f3',
  };
  
  toast.style.cssText = `
    position: fixed;
    bottom: 20px;
    left: 50%;
    transform: translateX(-50%);
    background: ${colors[type]};
    color: white;
    padding: 12px 24px;
    border-radius: 8px;
    font-size: 14px;
    z-index: 10000;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    max-width: 90%;
    text-align: center;
  `;
  
  toast.textContent = message;
  document.body.appendChild(toast);
  
  // 3초 후 자동 제거
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transition = 'opacity 0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, 3000);
};
