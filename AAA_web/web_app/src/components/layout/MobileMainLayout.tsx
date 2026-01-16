import React, { useState, useEffect, useRef } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import {
  Box,
  AppBar,
  Toolbar,
  IconButton,
  Typography,
  Drawer,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Divider,
  Avatar,
  Chip,
  SwipeableDrawer,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  Menu as MenuIcon,
  Chat as ChatIcon,
  Event as EventIcon,
  Assignment as AssignmentIcon,
  CardGiftcard as GiftIcon,
  Settings as SettingsIcon,
  Help as HelpIcon,
  Logout as LogoutIcon,
  ArrowBack as ArrowBackIcon,
} from '@mui/icons-material';
import authService from '../../services/authService';
import ChatSidebar from '../chat/ChatSidebar';
import { GiftButton } from '../common/GiftBox';
import HelpDialog from '../common/HelpDialog';

const DRAWER_WIDTH = 280;

interface MobileMainLayoutProps {
  children: React.ReactNode;
  hideAppBar?: boolean; // 모바일 뷰에서 AppBar 숨김 여부
  hideSidebarOnDesktop?: boolean; // 데스크톱 뷰에서 사이드바 숨김 여부
  title?: string; // 앱바 타이틀
  showBackButton?: boolean; // 뒤로가기 버튼 표시 여부
  onBackClick?: () => void; // 뒤로가기 버튼 클릭 핸들러
}

export default function MobileMainLayout({
  children,
  hideAppBar = false,
  hideSidebarOnDesktop = false,
  title,
  showBackButton = false,
  onBackClick
}: MobileMainLayoutProps) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [helpDialogOpen, setHelpDialogOpen] = useState(false);
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const isDark = theme.palette.mode === 'dark';
  const navigate = useNavigate();
  const location = useLocation();
  const user = authService.getCurrentUser();
  const drawerRef = useRef<HTMLDivElement>(null);


  // is_approver에 따라 휴가관리 경로 분기
  const isApprover = user?.isApprover || false;

  // 디버깅: isApprover 값 확인
  console.log('📍 [MobileMainLayout] user:', user);
  console.log('📍 [MobileMainLayout] isApprover:', isApprover);

  const workMenuItems = [
    {
      text: '전자결재',
      icon: <AssignmentIcon />,
      path: '/approval',
    },
    {
      text: '휴가 관리',
      icon: <EventIcon />,
      // 승인자인 경우 관리자 휴가관리로 바로 이동
      path: isApprover ? '/admin-leave' : '/leave',
    },
    {
      text: '받은선물함',
      icon: <GiftIcon />,
      path: '/gift',
    },
  ];

  const handleDrawerToggle = () => {
    setMobileOpen(!mobileOpen);
  };

  const handleDrawerClose = () => {
    setMobileOpen(false);
  };

  // 사이드바가 열릴 때 포커스 관리 및 aria-hidden 제거
  useEffect(() => {
    if (mobileOpen && isMobile) {
      // MutationObserver로 aria-hidden 속성 실시간 제거
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (mutation.type === 'attributes' && mutation.attributeName === 'aria-hidden') {
            const target = mutation.target as HTMLElement;
            // root 요소나 그 자식 요소에서 aria-hidden 제거
            if (target.id === 'root' || target.closest('#root')) {
              const rootElement = document.getElementById('root');
              if (rootElement && rootElement.getAttribute('aria-hidden') === 'true') {
                rootElement.removeAttribute('aria-hidden');
              }
            }
          }
        });
      });

      // root 요소 관찰 시작
      const rootElement = document.getElementById('root');
      if (rootElement) {
        observer.observe(rootElement, {
          attributes: true,
          attributeFilter: ['aria-hidden'],
          subtree: true, // 자식 요소도 관찰
        });

        // 즉시 aria-hidden 제거
        if (rootElement.getAttribute('aria-hidden') === 'true') {
          rootElement.removeAttribute('aria-hidden');
        }
      }

      // 전체 문서에서 포커스된 요소 찾기 및 제거
      const activeElement = document.activeElement as HTMLElement;
      if (activeElement && activeElement !== document.body) {
        // AppBar의 버튼은 포커스 유지 (접근성)
        if (!activeElement.closest('header') && !activeElement.closest('[role="banner"]')) {
          activeElement.blur();
        }
      }

      // 메인 콘텐츠의 모든 포커스 가능한 요소에서 포커스 제거
      const mainContent = document.querySelector('main');
      if (mainContent) {
        const focusableElements = mainContent.querySelectorAll(
          'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
        );
        focusableElements.forEach(element => {
          (element as HTMLElement).blur();
        });
      }

      // 주기적으로 aria-hidden 제거 (추가 보장)
      const intervalId = setInterval(() => {
        const rootElement = document.getElementById('root');
        if (rootElement && rootElement.getAttribute('aria-hidden') === 'true') {
          rootElement.removeAttribute('aria-hidden');
        }
      }, 50); // 더 빠른 간격으로 체크

      // 사이드바가 열릴 때 첫 번째 포커스 가능한 요소에 포커스
      if (drawerRef.current) {
        const firstFocusableElement = drawerRef.current.querySelector(
          'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
        ) as HTMLElement;

        if (firstFocusableElement) {
          setTimeout(() => {
            firstFocusableElement.focus();
          }, 200);
        }
      }

      // 정리 함수
      return () => {
        observer.disconnect();
        clearInterval(intervalId);
      };
    } else {
      // 사이드바가 닫힐 때 aria-hidden 제거
      const rootElement = document.getElementById('root');
      if (rootElement && rootElement.getAttribute('aria-hidden') === 'true') {
        rootElement.removeAttribute('aria-hidden');
      }
    }
  }, [mobileOpen, isMobile]);

  const handleMenuClick = (path: string) => {
    navigate(path);
    if (isMobile) {
      setMobileOpen(false);
    }
  };

  const handleLogout = () => {
    authService.logout();
  };

  const drawer = (
    <Box ref={drawerRef} sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* 사용자 정보 헤더 */}
      <Box
        sx={{
          p: 2,
          backgroundColor: '#f8f9fa',
          color: '#333333',
          borderBottom: '1px solid #e0e0e0',
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1.5 }}>
          <Avatar sx={{ bgcolor: '#e3f2fd', color: '#1976d2', width: 40, height: 40 }}>
            <ChatIcon sx={{ fontSize: 20 }} />
          </Avatar>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography
              variant="subtitle1"
              sx={{
                fontWeight: 'bold',
                fontSize: '1rem',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                maxWidth: '100%'
              }}
            >
              {user?.userId || '사용자'}
            </Typography>
            <Typography variant="body2" sx={{ opacity: 0.9, fontSize: '0.8rem' }}>
              ASPN AI Agent
            </Typography>
          </Box>
        </Box>
        <Chip
          label="모바일 웹 버전"
          size="small"
          sx={{
            bgcolor: '#e3f2fd',
            color: '#1976d2',
            fontSize: '0.75rem',
            height: 22
          }}
        />
      </Box>

      {/* ChatSidebar 컴포넌트 사용 */}
      <ChatSidebar
        isMobile={isMobile}
        onMobileMenuClose={() => handleDrawerClose()}
      />

      <Divider sx={{ mx: 2 }} />

      {/* 업무 메뉴 섹션 */}
      <Box sx={{ px: 2, py: 1 }}>
        <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>
          업무
        </Typography>
      </Box>
      <List sx={{ px: 1 }}>
        {workMenuItems.map((item) => (
          <ListItem key={item.text} disablePadding>
            <ListItemButton
              onClick={() => handleMenuClick(item.path)}
              selected={location.pathname === item.path}
              component="div"
              sx={{
                borderRadius: 2,
                mb: 0.5,
                '&.Mui-selected': {
                  backgroundColor: '#e3f2fd',
                  color: '#1976d2',
                  '&:hover': {
                    backgroundColor: '#bbdefb',
                  },
                  '& .MuiListItemIcon-root': {
                    color: '#1976d2',
                  },
                },
                '&:hover': {
                  backgroundColor: '#f5f5f5',
                },
              }}
            >
              <ListItemIcon
                sx={{
                  color: location.pathname === item.path ? '#1976d2' : 'text.secondary',
                }}
              >
                {
                  item.icon
                }
              </ListItemIcon>
              <ListItemText
                primary={item.text}
                primaryTypographyProps={{
                  fontSize: '0.9rem',
                  fontWeight: location.pathname === item.path ? 600 : 400,
                }}
              />
            </ListItemButton>
          </ListItem>
        ))}
      </List>

      <Divider sx={{ mx: 2 }} />

      {/* 하단 메뉴 */}
      <Box sx={{ flex: 1 }} />
      <List sx={{ px: 1 }}>
        <ListItem disablePadding>
          <ListItemButton
            onClick={() => handleMenuClick('/settings')}
            selected={location.pathname === '/settings'}
            sx={{
              borderRadius: 2,
              mb: 0.5,
              '&.Mui-selected': {
                backgroundColor: '#e3f2fd',
                color: '#1976d2',
                '&:hover': {
                  backgroundColor: '#bbdefb',
                },
                '& .MuiListItemIcon-root': {
                  color: '#1976d2',
                },
              },
              '&:hover': {
                backgroundColor: '#f5f5f5',
              },
            }}
          >
            <ListItemIcon
              sx={{
                color: location.pathname === '/settings' ? '#1976d2' : 'text.secondary',
              }}
            >
              <SettingsIcon />
            </ListItemIcon>
            <ListItemText
              primary="설정"
              primaryTypographyProps={{
                fontSize: '0.9rem',
                fontWeight: location.pathname === '/settings' ? 600 : 400,
              }}
            />
          </ListItemButton>
        </ListItem>

        <ListItem disablePadding>
          <ListItemButton
            onClick={() => {
              setHelpDialogOpen(true);
              setMobileOpen(false);
            }}
            selected={helpDialogOpen}
            sx={{
              borderRadius: 2,
              mb: 0.5,
              '&.Mui-selected': {
                backgroundColor: '#e3f2fd',
                color: '#1976d2',
                '&:hover': {
                  backgroundColor: '#bbdefb',
                },
                '& .MuiListItemIcon-root': {
                  color: '#1976d2',
                },
              },
              '&:hover': {
                backgroundColor: '#f5f5f5',
              },
            }}
          >
            <ListItemIcon
              sx={{
                color: helpDialogOpen ? '#1976d2' : 'text.secondary',
              }}
            >
              <HelpIcon />
            </ListItemIcon>
            <ListItemText
              primary="도움말"
              primaryTypographyProps={{
                fontSize: '0.9rem',
                fontWeight: helpDialogOpen ? 600 : 400,
              }}
            />
          </ListItemButton>
        </ListItem>

        <ListItem disablePadding>
          <ListItemButton
            onClick={handleLogout}
            component="div"
            sx={{
              borderRadius: 2,
              color: '#d32f2f',
              '&:hover': {
                backgroundColor: '#ffebee',
                color: '#b71c1c',
              },
            }}
          >
            <ListItemIcon sx={{ color: 'inherit' }}>
              <LogoutIcon />
            </ListItemIcon>
            <ListItemText
              primary="로그아웃"
              primaryTypographyProps={{ fontSize: '0.9rem' }}
            />
          </ListItemButton>
        </ListItem>
      </List>
    </Box>
  );

  return (
    <Box sx={{ display: 'flex', height: '100vh' }}>
      {/* 앱바 - 모바일에서 hideAppBar가 true이면 숨김 */}
      {!(isMobile && hideAppBar) && (
        <AppBar
          position="fixed"
          sx={{
            width: { md: hideSidebarOnDesktop ? '100%' : `calc(100% - ${DRAWER_WIDTH}px)` },
            ml: { md: hideSidebarOnDesktop ? 0 : `${DRAWER_WIDTH}px` },
            backgroundColor: isDark ? '#0F172A' : 'white',
            color: isDark ? '#E5E7EB' : '#333333',
            boxShadow: isDark ? '0 2px 8px rgba(0,0,0,0.4)' : '0 2px 8px rgba(0,0,0,0.1)',
            zIndex: 1301, // 모바일 사이드바 z-index(1300)보다 높게 설정
          }}
        >
          <Toolbar>
            {showBackButton ? (
              <IconButton
                color="inherit"
                edge="start"
                onClick={onBackClick}
                sx={{ mr: 2 }}
              >
                <ArrowBackIcon />
              </IconButton>
            ) : (
              <IconButton
                color="inherit"
                aria-label="open drawer"
                edge="start"
                onClick={handleDrawerToggle}
                sx={{ mr: 2, display: { md: 'none' } }}
              >
                <MenuIcon />
              </IconButton>
            )}
            <Typography variant="h6" noWrap component="div" sx={{ flexGrow: 1 }}>
              {title || 'ASPN AI Agent'}
            </Typography>
            <GiftButton />
          </Toolbar>
        </AppBar>
      )}

      {/* 사이드바 */}
      <Box
        component="nav"
        sx={{
          width: { md: hideSidebarOnDesktop ? 0 : DRAWER_WIDTH },
          flexShrink: { md: 0 },
          display: { md: hideSidebarOnDesktop ? 'none' : 'block' }
        }}
      >
        {/* 모바일 드로어 */}
        <SwipeableDrawer
          variant="temporary"
          open={mobileOpen}
          onClose={handleDrawerClose}
          onOpen={handleDrawerToggle}
          ModalProps={{
            keepMounted: true,
            disableAutoFocus: true,
            disableEnforceFocus: true,
            disableRestoreFocus: true,
            disablePortal: true,
            disableScrollLock: true,
            hideBackdrop: false,
            style: {
              zIndex: 1300,
              top: hideAppBar ? 0 : '64px',
            },
            // aria-hidden을 설정하지 않도록 함 (inert 속성 사용)
          }}
          BackdropProps={{
            invisible: false,
            sx: {
              backgroundColor: 'rgba(0, 0, 0, 0.5)',
              top: hideAppBar ? 0 : '64px', // hideAppBar에 따라 Backdrop도 위치 조정
            },
          }}
          sx={{
            display: { xs: 'block', md: 'none' },
            '& .MuiDrawer-paper': {
              boxSizing: 'border-box',
              width: DRAWER_WIDTH,
              top: hideAppBar ? 0 : '64px', // hideAppBar가 true면 top 0, false면 앱바 아래
              height: hideAppBar ? '100vh' : 'calc(100vh - 64px)', // hideAppBar에 따라 높이 조정
            },
            '& .MuiBackdrop-root': {
              backgroundColor: 'rgba(0, 0, 0, 0.5)',
              top: hideAppBar ? 0 : '64px',
            },
          }}
        >
          {drawer}
        </SwipeableDrawer>

        {/* 데스크톱 드로어 */}
        {!hideSidebarOnDesktop && (
          <Drawer
            variant="permanent"
            sx={{
              display: { xs: 'none', md: 'block' },
              '& .MuiDrawer-paper': {
                boxSizing: 'border-box',
                width: DRAWER_WIDTH,
              },
            }}
            open
          >
            {drawer}
          </Drawer>
        )}
      </Box>

      {/* 메인 콘텐츠 */}
      <Box
        component="main"
        inert={isMobile && mobileOpen ? true : undefined}
        sx={{
          flexGrow: 1,
          width: { md: hideSidebarOnDesktop ? '100%' : `calc(100% - ${DRAWER_WIDTH}px)` },
          // Mobile Optimization: Use dvh and handle safe areas
          height: {
            xs: '100dvh', // Mobile: dynamic viewport height
            md: '100vh',  // Desktop: standard viewport height
          },
          overflow: 'hidden',
          // 사이드바가 열릴 때 포커스 방지
          ...(isMobile && mobileOpen && {
            pointerEvents: 'none',
            userSelect: 'none',
            '& *': {
              pointerEvents: 'none !important',
            },
          }),
        }}
      >
        {/* 모바일에서 hideAppBar가 true이면 Toolbar 스페이서를 렌더링하지 않음 */}
        {!(isMobile && hideAppBar) && <Toolbar />}
        {/*
          Content box height calculation:
          - Mobile (hideAppBar): 100dvh - safe area top - safe area bottom
          - Mobile (showAppBar): 100dvh - 56px(toolbar) - safe area top - safe area bottom
          - Desktop: 100vh - 64px(toolbar)
        */}
        <Box
          sx={{
            height: isMobile
              ? hideAppBar
                ? 'calc(100dvh - var(--sat) - var(--sab))'
                : 'calc(100dvh - 56px - var(--sat) - var(--sab))'
              : 'calc(100vh - 64px)',
            overflow: 'auto', // Enable scrolling for content
            // Add padding for safe areas to prevent content from being hidden behind notches/home bars
            pt: isMobile && hideAppBar ? 'var(--sat)' : 0,
            pb: isMobile ? 'var(--sab)' : 0,
            pl: isMobile ? 'var(--sal)' : 0,
            pr: isMobile ? 'var(--sar)' : 0,
          }}
        >
          {children}
        </Box>
      </Box>

      {/* 도움말 다이얼로그 */}
      <HelpDialog
        open={helpDialogOpen}
        onClose={() => setHelpDialogOpen(false)}
      />
    </Box>
  );
}
