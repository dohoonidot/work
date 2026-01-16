import React from 'react';
import { useIsMobile } from '../../hooks/useMobile';

interface ResponsiveProps {
  children: React.ReactNode;
}

/**
 * 렌더링 시점에 모바일일 경우에만 children을 렌더링합니다.
 * CSS hidden과 달리 DOM에서 아예 제외됩니다.
 */
export const MobileOnly: React.FC<ResponsiveProps> = ({ children }) => {
  const isMobile = useIsMobile();
  return isMobile ? <>{children}</> : null;
};

/**
 * 렌더링 시점에 데스크톱(태블릿 포함)일 경우에만 children을 렌더링합니다.
 * CSS hidden과 달리 DOM에서 아예 제외됩니다.
 */
export const DesktopOnly: React.FC<ResponsiveProps> = ({ children }) => {
  const isMobile = useIsMobile();
  return !isMobile ? <>{children}</> : null;
};
