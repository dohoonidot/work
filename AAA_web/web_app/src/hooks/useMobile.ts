import { useState, useEffect, useCallback } from 'react';
import { useMediaQuery, useTheme } from '@mui/material';

/**
 * 모바일 디바이스 감지 훅
 */
export const useIsMobile = () => {
  const theme = useTheme();
  return useMediaQuery(theme.breakpoints.down('md'));
};

/**
 * 터치 디바이스 감지 훅
 */
export const useIsTouchDevice = () => {
  const [isTouch, setIsTouch] = useState(false);

  useEffect(() => {
    setIsTouch('ontouchstart' in window || navigator.maxTouchPoints > 0);
  }, []);

  return isTouch;
};

/**
 * 뷰포트 크기 감지 훅
 */
export const useViewportSize = () => {
  const [viewportSize, setViewportSize] = useState({
    width: window.innerWidth,
    height: window.innerHeight,
  });

  useEffect(() => {
    const handleResize = () => {
      setViewportSize({
        width: window.innerWidth,
        height: window.innerHeight,
      });
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  return viewportSize;
};

/**
 * 네트워크 상태 감지 훅
 */
export const useNetworkStatus = () => {
  const [isOnline, setIsOnline] = useState(navigator.onLine);

  useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  return isOnline;
};

/**
 * 키보드 높이 감지 훅 (모바일용)
 */
export const useKeyboardHeight = () => {
  const [keyboardHeight, setKeyboardHeight] = useState(0);

  useEffect(() => {
    if (!('ontouchstart' in window)) return;

    const initialHeight = window.innerHeight;

    const handleResize = () => {
      const currentHeight = window.innerHeight;
      const height = initialHeight - currentHeight;
      setKeyboardHeight(Math.max(0, height));
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  return keyboardHeight;
};

/**
 * 스와이프 제스처 감지 훅
 */
export const useSwipeGesture = (
  onSwipeLeft?: () => void,
  onSwipeRight?: () => void,
  onSwipeUp?: () => void,
  onSwipeDown?: () => void
) => {
  const [startPos, setStartPos] = useState({ x: 0, y: 0 });
  const [endPos, setEndPos] = useState({ x: 0, y: 0 });

  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    setStartPos({
      x: e.touches[0].clientX,
      y: e.touches[0].clientY,
    });
  }, []);

  const handleTouchEnd = useCallback((e: React.TouchEvent) => {
    setEndPos({
      x: e.changedTouches[0].clientX,
      y: e.changedTouches[0].clientY,
    });

    const deltaX = endPos.x - startPos.x;
    const deltaY = endPos.y - startPos.y;
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
  }, [startPos, endPos, onSwipeLeft, onSwipeRight, onSwipeUp, onSwipeDown]);

  return {
    onTouchStart: handleTouchStart,
    onTouchEnd: handleTouchEnd,
  };
};

/**
 * 모바일 최적화된 스크롤 훅
 */
export const useMobileScroll = (elementRef: React.RefObject<HTMLElement>) => {
  useEffect(() => {
    if (!elementRef.current) return;

    const element = elementRef.current;
    element.style.webkitOverflowScrolling = 'touch';
    element.style.overflowScrolling = 'touch';

    return () => {
      element.style.webkitOverflowScrolling = 'auto';
      element.style.overflowScrolling = 'auto';
    };
  }, [elementRef]);
};

/**
 * 모바일에서 햅틱 피드백 훅
 */
export const useHapticFeedback = () => {
  const vibrate = useCallback((pattern: number | number[]) => {
    if ('vibrate' in navigator) {
      navigator.vibrate(pattern);
    }
  }, []);

  const lightFeedback = useCallback(() => vibrate(10), [vibrate]);
  const mediumFeedback = useCallback(() => vibrate(20), [vibrate]);
  const heavyFeedback = useCallback(() => vibrate(30), [vibrate]);

  return {
    vibrate,
    lightFeedback,
    mediumFeedback,
    heavyFeedback,
  };
};

/**
 * 모바일에서 포커스 관리 훅
 */
export const useMobileFocus = () => {
  const [focusedElement, setFocusedElement] = useState<HTMLElement | null>(null);

  const focusElement = useCallback((element: HTMLElement) => {
    setFocusedElement(element);
    element.focus();
  }, []);

  const blurElement = useCallback(() => {
    if (focusedElement) {
      focusedElement.blur();
      setFocusedElement(null);
    }
  }, [focusedElement]);

  const focusNext = useCallback(() => {
    if (!focusedElement) return;

    const focusableElements = document.querySelectorAll(
      'input, textarea, select, button, [tabindex]:not([tabindex="-1"])'
    );
    const currentIndex = Array.from(focusableElements).indexOf(focusedElement);
    
    if (currentIndex < focusableElements.length - 1) {
      const nextElement = focusableElements[currentIndex + 1] as HTMLElement;
      focusElement(nextElement);
    }
  }, [focusedElement, focusElement]);

  const focusPrevious = useCallback(() => {
    if (!focusedElement) return;

    const focusableElements = document.querySelectorAll(
      'input, textarea, select, button, [tabindex]:not([tabindex="-1"])'
    );
    const currentIndex = Array.from(focusableElements).indexOf(focusedElement);
    
    if (currentIndex > 0) {
      const previousElement = focusableElements[currentIndex - 1] as HTMLElement;
      focusElement(previousElement);
    }
  }, [focusedElement, focusElement]);

  return {
    focusedElement,
    focusElement,
    blurElement,
    focusNext,
    focusPrevious,
  };
};

/**
 * 모바일에서 성능 최적화 훅
 */
export const useMobilePerformance = () => {
  const [isLowEndDevice, setIsLowEndDevice] = useState(false);

  useEffect(() => {
    // 저사양 디바이스 감지
    const checkDevicePerformance = () => {
      const memory = (navigator as any).deviceMemory || 4;
      const cores = navigator.hardwareConcurrency || 4;
      const connection = (navigator as any).connection;
      
      const isLowEnd = 
        memory < 4 || 
        cores < 4 || 
        (connection && connection.effectiveType === 'slow-2g');
      
      setIsLowEndDevice(isLowEnd);
    };

    checkDevicePerformance();
  }, []);

  const optimizeForLowEnd = useCallback((callback: () => void) => {
    if (isLowEndDevice) {
      // 저사양 디바이스에서는 requestIdleCallback 사용
      if ('requestIdleCallback' in window) {
        requestIdleCallback(callback);
      } else {
        setTimeout(callback, 0);
      }
    } else {
      callback();
    }
  }, [isLowEndDevice]);

  return {
    isLowEndDevice,
    optimizeForLowEnd,
  };
};

/**
 * 모바일에서 PWA 설치 상태 훅
 */
export const usePWAInstall = () => {
  const [isInstallable, setIsInstallable] = useState(false);
  const [deferredPrompt, setDeferredPrompt] = useState<any>(null);

  useEffect(() => {
    const handleBeforeInstallPrompt = (e: Event) => {
      e.preventDefault();
      setDeferredPrompt(e);
      setIsInstallable(true);
    };

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt);

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
    };
  }, []);

  const installPWA = useCallback(async () => {
    if (!deferredPrompt) return false;

    deferredPrompt.prompt();
    const { outcome } = await deferredPrompt.userChoice;
    
    if (outcome === 'accepted') {
      setIsInstallable(false);
      setDeferredPrompt(null);
      return true;
    }
    
    return false;
  }, [deferredPrompt]);

  return {
    isInstallable,
    installPWA,
  };
};
