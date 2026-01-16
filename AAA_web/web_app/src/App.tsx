import React, { useEffect, useCallback, useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom';
import { ThemeProvider, CssBaseline, Snackbar, Alert, Box, CircularProgress } from '@mui/material';
import LoginPage from './pages/LoginPage';
import ChatPage from './pages/ChatPage';
import CodingAssistantPage from './pages/CodingAssistantPage';
import AiAssistantPage from './pages/AiAssistantPage';
import LeaveManagementPage from './pages/LeaveManagementPage';
import AdminLeaveApprovalPage from './pages/AdminLeaveApprovalPage';
import ApprovalPage from './pages/ApprovalPage';
import GiftPage from './pages/GiftPage';
import SapPage from './pages/SapPage';
import SettingsPage from './pages/SettingsPage';
import ContestPage from './pages/ContestPage';
import LeaveGrantHistoryPage from './pages/LeaveGrantHistoryPage';
import PrivateRoute from './components/auth/PrivateRoute';
import authService from './services/authService';
import { useThemeStore } from './store/themeStore';
import { useNotificationStore } from './store/notificationStore';
import { useSseNotifications } from './hooks/useSseNotifications';
import type { NotificationEnvelope } from './types/notification';
import { NotificationPanel } from './components/common/NotificationPanel';
import GiftArrivalPopup from './components/common/GiftArrivalPopup';

function AppContent() {
  const navigate = useNavigate();
  const location = useLocation();
  const [notification, setNotification] = React.useState<{ message: string; severity: 'success' | 'error' | 'warning' | 'info' } | null>(null);
  const [isLoggedIn, setIsLoggedIn] = useState<boolean>(false);
  const [isCheckingAuth, setIsCheckingAuth] = useState<boolean>(true);

  // 알림 스토어
  const { setConnectionState, setSseEnabled } = useNotificationStore();

  // 선물 도착 팝업 상태 관리
  const [giftArrivalPopup, setGiftArrivalPopup] = useState<{
    open: boolean;
    data: {
      gift_name?: string;
      message?: string;
      couponImgUrl?: string;
      coupon_end_date?: string;
      queue_name?: string;
      sender_name?: string;
    } | null;
  }>({ open: false, data: null });

  // 앱 시작 시 refresh API 호출하여 로그인 상태 확인 (로그인 페이지가 아닐 때만)
  useEffect(() => {
    // 로그인 페이지에서는 refresh 호출하지 않음
    if (location.pathname === '/login' || location.pathname === '/') {
      setIsCheckingAuth(false);
      setIsLoggedIn(false);
      return;
    }

    const checkAuthStatus = async () => {
      setIsCheckingAuth(true);
      try {
        const refreshResult = await authService.refresh();
        if (refreshResult && refreshResult.status_code === 200) {
          setIsLoggedIn(true);
          console.log('[App] 리프레시 성공 - 로그인 상태 유지');
        } else {
          setIsLoggedIn(false);
          console.log('[App] 리프레시 실패 - 로그인 필요');
        }
      } catch (error) {
        console.error('[App] 리프레시 에러:', error);
        setIsLoggedIn(false);
      } finally {
        setIsCheckingAuth(false);
      }
    };

    checkAuthStatus();
  }, [location.pathname]);

  // SSE 알림 수신 핸들러
  const handleNotification = useCallback((envelope: NotificationEnvelope) => {
    console.log('🔔 [App] SSE 알림 수신 → NotificationStore로 전달:', {
      event: envelope.event,
      event_id: envelope.event_id,
      user_id: envelope.user_id,
      queue_name: envelope.queue_name,
      sent_at: envelope.sent_at,
      payload: envelope.payload,
    });

    // 2. 특정 이벤트는 스낵바로도 표시 (선택적)
    if (envelope.event === 'birthday') {
      const payload = envelope.payload as any;
      setNotification({
        message: payload?.name ? `${payload.name}님의 생일을 축하합니다! 🎉` : '생일 축하합니다! 🎂',
        severity: 'info',
      });
    } else if (envelope.event === 'leave_approval') {
      setNotification({
        message: '새로운 휴가 승인 요청이 있습니다',
        severity: 'info',
      });
    } else if (envelope.event === 'eapproval_approval') {
      setNotification({
        message: '새로운 결재 문서가 도착했습니다',
        severity: 'info',
      });
    }

    const isGiftEvent =
      envelope.event === 'gift' ||
      envelope.event === 'gift_arrival' ||
      envelope.queue_name?.startsWith('gift.') ||
      (envelope.event === 'notification' && envelope.queue_name?.startsWith('gift.')) ||
      (envelope.payload as any)?.queue_name === 'gift' ||
      (envelope.payload as any)?.queue_name?.startsWith('gift.');

    if (isGiftEvent) {
      setTimeout(() => {
        const payload = envelope.payload as any;
        setGiftArrivalPopup({
          open: true,
          data: {
            gift_name: payload?.gift_name || payload?.title,
            message: payload?.message || payload?.description,
            couponImgUrl: payload?.couponImgUrl || payload?.coupon_img_url,
            coupon_end_date: payload?.coupon_end_date || payload?.couponEndDate,
            queue_name: payload?.queue_name || envelope.queue_name,
            sender_name: payload?.sender_name || payload?.senderName || 'ASPN AI',
          },
        });
      }, 2000);
    }
  }, []);

  // SSE 연결 관리
  useSseNotifications({
    enabled: isLoggedIn,
    onNotification: handleNotification,
    withCredentials: true,
    onConnectionStateChange: (state) => {
      setConnectionState(state);
      console.log('[App] SSE 연결 상태:', state);
    },
  });

  useEffect(() => {
    setSseEnabled(isLoggedIn);
  }, [isLoggedIn, setSseEnabled]);

  const handleGiftArrivalConfirm = () => {
    setGiftArrivalPopup({ open: false, data: null });
    navigate('/gift');
  };

  const handleGiftArrivalClose = () => {
    setGiftArrivalPopup({ open: false, data: null });
  };

  if (isCheckingAuth) {
    return (
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <>
      <NotificationPanel />
      <GiftArrivalPopup
        open={giftArrivalPopup.open}
        giftData={giftArrivalPopup.data}
        onConfirm={handleGiftArrivalConfirm}
        onClose={handleGiftArrivalClose}
      />

      <Routes>
        <Route
          path="/"
          element={
            isLoggedIn ? (
              <Navigate to="/chat" replace />
            ) : (
              <LoginPage />
            )
          }
        />
        <Route path="/login" element={<LoginPage />} />
        <Route
          path="/chat"
          element={
            <PrivateRoute>
              <ChatPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/coding"
          element={
            <PrivateRoute>
              <CodingAssistantPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/ai"
          element={
            <PrivateRoute>
              <AiAssistantPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/sap"
          element={
            <PrivateRoute>
              <SapPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/leave"
          element={
            <PrivateRoute>
              <LeaveManagementPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/leave-grant-history"
          element={
            <PrivateRoute>
              <LeaveGrantHistoryPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/admin-leave"
          element={
            <PrivateRoute>
              <AdminLeaveApprovalPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/approval"
          element={
            <PrivateRoute>
              <ApprovalPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/gift"
          element={
            <PrivateRoute>
              <GiftPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/settings"
          element={
            <PrivateRoute>
              <SettingsPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/contest"
          element={
            <PrivateRoute>
              <ContestPage />
            </PrivateRoute>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>

      <Snackbar
        open={!!notification}
        autoHideDuration={6000}
        onClose={() => setNotification(null)}
        anchorOrigin={{ vertical: 'top', horizontal: 'center' }}
      >
        <Alert
          onClose={() => setNotification(null)}
          severity={notification?.severity || 'info'}
          sx={{ width: '100%' }}
        >
          {notification?.message}
        </Alert>
      </Snackbar>
    </>
  );
}

function App() {
  const { muiTheme } = useThemeStore();

  return (
    <ThemeProvider theme={muiTheme}>
      <CssBaseline />
      <BrowserRouter>
        <AppContent />
      </BrowserRouter>
    </ThemeProvider>
  );
}

export default App;
