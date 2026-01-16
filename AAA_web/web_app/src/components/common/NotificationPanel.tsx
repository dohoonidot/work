/**
 * SSE 알림 패널 컴포넌트
 * 우측 상단에 배지 아이콘으로 표시되며, 클릭 시 알림 목록 표시
 */

import React, { useEffect } from 'react';
import {
  Badge,
  IconButton,
  Drawer,
  Box,
  Typography,
  List,
  ListItem,
  ListItemText,
  ListItemButton,
  Divider,
  Button,
  Chip,
  Stack,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Paper,
  useTheme,
} from '@mui/material';
import NotificationsIcon from '@mui/icons-material/Notifications';
import CloseIcon from '@mui/icons-material/Close';
import DeleteIcon from '@mui/icons-material/Delete';
import DoneAllIcon from '@mui/icons-material/DoneAll';
import FiberManualRecordIcon from '@mui/icons-material/FiberManualRecord';
import RefreshIcon from '@mui/icons-material/Refresh';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import { useNotificationStore, extractNotificationDetails } from '../../store/notificationStore';
import { useNavigate } from 'react-router-dom';
import { ackSseNotifications } from '../../services/sseService';
import type { NotificationDisplay } from '../../types/notification';
import LeaveAnalyzeNotificationContent from '../leave/LeaveAnalyzeNotificationContent';
import { sanitizeNotificationPreview } from '../../utils/notificationHelpers';

/**
 * 알림 패널 아이콘 버튼
 * 헤더나 네비게이션 바에 배치
 */
export function NotificationButton() {
  const { unreadCount, toggleNotificationPanel } = useNotificationStore();
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';

  return (
    <IconButton
      onClick={toggleNotificationPanel}
      aria-label="알림"
      sx={{ 
        mr: 1,
        bgcolor: isDark ? 'rgba(37, 99, 235, 0.35)' : 'rgba(29, 68, 135, 0.9)',
        color: 'white',
        '&:hover': {
          bgcolor: isDark ? 'rgba(37, 99, 235, 0.55)' : 'rgba(29, 68, 135, 1)',
        },
        boxShadow: 2,
      }}
    >
      <Badge badgeContent={unreadCount} color="error">
        <NotificationsIcon />
      </Badge>
    </IconButton>
  );
}

/**
 * 알림 패널 Drawer
 * App 컴포넌트에 배치
 */
export function NotificationPanel() {
  const navigate = useNavigate();
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  const panelBg = isDark ? '#0F172A' : '#F8F9FA';
  const panelSurface = isDark ? '#111827' : 'white';
  const panelBorder = isDark ? 'rgba(255,255,255,0.08)' : 'divider';
  const headerBg = isDark ? '#1E3A8A' : '#1D4487';
  const {
    isNotificationPanelOpen,
    setNotificationPanelOpen,
    notifications,
    unreadCount,
    markAsRead,
    markAllAsRead,
    removeNotification,
    clearAllNotifications,
    refreshNotificationMessages,
  } = useNotificationStore();

  // 컴포넌트 마운트 시 기존 알림 메시지 재생성 (JSON → 사용자 친화적)
  useEffect(() => {
    refreshNotificationMessages();
  }, [refreshNotificationMessages]);

  // 알림 상세 모달 상태
  const [selectedNotification, setSelectedNotification] = React.useState<NotificationDisplay | null>(null);
  const [notificationModalOpen, setNotificationModalOpen] = React.useState(false);

  // 모든 알림 삭제 및 ACK
  const handleClearAll = async () => {
    // 모든 알림 ID 수집
    const eventIds = notifications.map((n) => n.id);

    if (eventIds.length === 0) return;

    // ACK 전송 (배치)
    try {
      await ackSseNotifications(eventIds);
      console.log('[NotificationPanel] 모든 알림 ACK 완료:', eventIds.length);
    } catch (error) {
      console.error('[NotificationPanel] 모든 알림 ACK 실패:', error);
    }

    // UI에서 모든 알림 제거
    clearAllNotifications();
  };

  const handleClose = () => {
    setNotificationPanelOpen(false);
  };

  const handleNotificationClick = async (notificationId: string, _link?: string) => {
    // 읽음 처리만 수행 (페이지 이동 없이 패널에서 내용 확인)
    markAsRead(notificationId);

    // ACK 전송 (서버에서 알림 삭제)
    try {
      await ackSseNotifications(notificationId);
      console.log('[NotificationPanel] 알림 ACK 완료:', notificationId);
    } catch (error) {
      console.error('[NotificationPanel] 알림 ACK 실패:', error);
    }

    // 클릭한 알림 찾기
    const clickedNotification = notifications.find(n => n.id === notificationId);
    if (clickedNotification) {
      setSelectedNotification(clickedNotification);
      setNotificationModalOpen(true);
    }
  };

  const handleDelete = async (notificationId: string, event: React.MouseEvent) => {
    event.stopPropagation();

    // ACK 전송 (서버에서 알림 삭제)
    try {
      await ackSseNotifications(notificationId);
      console.log('[NotificationPanel] 알림 삭제 및 ACK 완료:', notificationId);
    } catch (error) {
      console.error('[NotificationPanel] 알림 ACK 실패:', error);
    }

    // UI에서 알림 제거
    removeNotification(notificationId);
  };

  const formatTime = (date: Date) => {
    try {
      const now = new Date();
      const diff = now.getTime() - date.getTime();
      const minutes = Math.floor(diff / 60000);
      const hours = Math.floor(diff / 3600000);
      const days = Math.floor(diff / 86400000);

      if (minutes < 1) return '방금 전';
      if (minutes < 60) return `${minutes}분 전`;
      if (hours < 24) return `${hours}시간 전`;
      if (days < 7) return `${days}일 전`;

      // 날짜 포맷 (M월 d일)
      const month = date.getMonth() + 1;
      const day = date.getDate();
      return `${month}월 ${day}일`;
    } catch (error) {
      return '';
    }
  };

  return (
    <Drawer
      anchor="right"
      open={isNotificationPanelOpen}
      onClose={handleClose}
      disableEnforceFocus={true}
      disableRestoreFocus={true}
      sx={{
        zIndex: (theme) => theme.zIndex.appBar + 2,
        '& .MuiDrawer-paper': {
          zIndex: (theme) => theme.zIndex.appBar + 3,
        },
      }}
      ModalProps={{
        sx: { zIndex: (theme) => theme.zIndex.appBar + 2 },
        disableAutoFocus: true,
        disableEnforceFocus: true,
        disableRestoreFocus: true,
        keepMounted: false,
        hideBackdrop: false,
      }}
      PaperProps={{
        sx: {
          width: { xs: '100%', sm: 400 },
          maxWidth: '100%',
          bgcolor: panelBg,
        },
      }}
    >
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        {/* 헤더 */}
        <Box
          sx={{
            p: 2,
            bgcolor: headerBg,
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <NotificationsIcon />
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              알림함
            </Typography>
            <Chip
              label={`${notifications.length}개`}
              size="small"
              sx={{
                bgcolor: isDark ? 'rgba(255,255,255,0.12)' : 'white',
                color: isDark ? 'white' : '#1D4487',
                fontWeight: 600,
              }}
            />
          </Box>
        </Box>

        {/* 액션 버튼 영역 */}
        <Box sx={{ p: 1, borderBottom: 1, borderColor: panelBorder, bgcolor: panelSurface }}>
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            {/* 왼쪽: 뒤로가기 버튼 */}
            <IconButton
              size="small"
              onClick={handleClose}
              sx={{ color: isDark ? 'grey.400' : 'text.secondary' }}
            >
              <ArrowBackIcon />
            </IconButton>

            {/* 오른쪽: 새로고침 버튼 */}
            <Button
              size="small"
              onClick={refreshNotificationMessages}
              variant="outlined"
            >
              새로고침
            </Button>
          </Box>
        </Box>

        {/* 추가 액션 버튼 (모두 읽음, 모두 삭제) */}
        {notifications.length > 0 && (
          <Box sx={{ p: 1, borderBottom: 1, borderColor: panelBorder, bgcolor: panelSurface }}>
            <Stack direction="row" spacing={1} justifyContent="flex-end">
              {unreadCount > 0 && (
                <Button
                  size="small"
                  startIcon={<DoneAllIcon />}
                  onClick={markAllAsRead}
                >
                  모두 읽음
                </Button>
              )}
              <Button
                size="small"
                color="error"
                startIcon={<DeleteIcon />}
                onClick={handleClearAll}
              >
                모두 삭제
              </Button>
            </Stack>
          </Box>
        )}

        {/* 알림 목록 */}
        <Box
          sx={{
            flex: 1,
            overflowY: 'scroll', // 항상 스크롤바 표시
            p: 2,
            maxHeight: 'calc(100vh - 200px)', // 명시적 높이 제한
            // 스크롤바 스타일링
            '&::-webkit-scrollbar': {
              width: '10px',
            },
            '&::-webkit-scrollbar-track': {
              backgroundColor: isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)',
              borderRadius: '5px',
            },
            '&::-webkit-scrollbar-thumb': {
              backgroundColor: isDark ? 'rgba(255,255,255,0.25)' : 'rgba(0,0,0,0.3)',
              borderRadius: '5px',
              border: isDark ? '2px solid rgba(255,255,255,0.08)' : '2px solid rgba(0,0,0,0.05)',
              '&:hover': {
                backgroundColor: isDark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.5)',
              },
              '&:active': {
                backgroundColor: isDark ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.6)',
              },
            },
          }}
        >
          {notifications.length === 0 ? (
            <Box
              sx={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                height: '100%',
                color: isDark ? 'grey.400' : 'text.secondary',
              }}
            >
              <NotificationsIcon sx={{ fontSize: 64, mb: 2, opacity: 0.3 }} />
              <Typography variant="h6" gutterBottom>
                알림이 없습니다
              </Typography>
              <Typography variant="body2">
                새로운 알림이 도착하면 여기에 표시됩니다
              </Typography>
            </Box>
          ) : (
            <List sx={{ p: 0 }}>
              {notifications.map((notification, index) => (
                <React.Fragment key={notification.id}>
                  <ListItemButton
                    onClick={() =>
                      handleNotificationClick(notification.id, notification.link)
                    }
                    sx={{
                      bgcolor: notification.read ? 'transparent' : 'action.hover',
                      '&:hover': {
                        bgcolor: notification.read
                          ? 'action.hover'
                          : 'action.selected',
                      },
                    }}
                  >
                    <ListItemText
                      primary={
                        <Box
                          sx={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 1,
                            mb: 0.5,
                          }}
                        >
                          {!notification.read && (
                            <FiberManualRecordIcon
                              sx={{ fontSize: 8, color: 'primary.main' }}
                            />
                          )}
                          <Typography variant="subtitle2" fontWeight="bold" component="span">
                            {notification.title}
                          </Typography>
                        </Box>
                      }
                      secondary={
                        <>
                          <Typography
                            variant="body2"
                            color={isDark ? 'grey.200' : 'text.primary'}
                            component="span"
                            sx={{ mb: 0.5, display: 'block' }}
                          >
                            {sanitizeNotificationPreview(notification.message, 120)}
                          </Typography>
                          <Typography variant="caption" color="text.secondary" component="span">
                            {formatTime(notification.receivedAt)}
                          </Typography>
                        </>
                      }
                    />
                    <IconButton
                      size="small"
                      onClick={(e) => handleDelete(notification.id, e)}
                      sx={{ ml: 1 }}
                    >
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </ListItemButton>
                  {index < notifications.length - 1 && <Divider />}
                </React.Fragment>
              ))}
            </List>
          )}
        </Box>

      </Box>

      {/* 알림 상세 모달 */}
      <Dialog
        open={notificationModalOpen}
        onClose={() => {
          setNotificationModalOpen(false);
          setSelectedNotification(null);
        }}
        maxWidth="sm"
        fullWidth
        PaperProps={{
          sx: { minHeight: '400px', bgcolor: panelSurface }
        }}
      >
        <DialogTitle>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <Typography variant="h6" component="span">
              {selectedNotification?.title}
            </Typography>
            <Chip
              label={selectedNotification?.type}
              size="small"
              color="primary"
              variant="outlined"
            />
          </Box>
        </DialogTitle>

        <DialogContent>
          <Stack spacing={2}>
            {/* 메시지 내용 */}
            {selectedNotification?.queue_name === 'leave.analyze' ? (
              // AI 휴가 추천 분석 결과 표시
              <LeaveAnalyzeNotificationContent
                message={selectedNotification?.message || ''}
                isDark={isDark}
              />
            ) : (
              // 일반 알림 메시지 표시
              <Box>
                <Typography variant="body1" sx={{ mb: 2 }}>
                  {selectedNotification?.message}
                </Typography>
              </Box>
            )}

            {/* 상세 정보 (사용자 친화적 표시) */}
            {selectedNotification?.payload && (() => {
              const details = extractNotificationDetails(
                selectedNotification.payload,
                selectedNotification.type
              );

              if (!details || Object.keys(details).length === 0) {
                return null;
              }

              return (
                <Box>
                  <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1.5, fontWeight: 600 }}>
                    상세 정보:
                  </Typography>
                  <Paper
                    sx={{
                      p: 2.5,
                      bgcolor: isDark ? 'rgba(255,255,255,0.04)' : 'grey.50',
                      borderRadius: 2,
                      border: '1px solid',
                      borderColor: panelBorder
                    }}
                  >
                    <Box
                      sx={{
                        display: 'grid',
                        gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)' },
                        gap: 2,
                      }}
                    >
                      {Object.entries(details).map(([label, value]) => {
                        // 상태 필드는 Chip으로 표시
                        if (label.includes('상태') || label.includes('결재 상태') || label.includes('처리 상태')) {
                          return (
                            <Box key={label}>
                              <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 0.5, fontSize: '0.75rem' }}>
                                {label}
                              </Typography>
                              <Chip
                                label={value}
                                size="small"
                                color={
                                  String(value).includes('승인') && !String(value).includes('대기') ? 'success' :
                                  String(value).includes('거부') || String(value).includes('반려') ? 'error' :
                                  String(value).includes('취소') ? 'warning' :
                                  String(value).includes('대기') ? 'default' :
                                  'info'
                                }
                                sx={{ fontWeight: 500 }}
                              />
                            </Box>
                          );
                        }

                        // 반려 사유나 거부 사유는 빨간색으로 강조 (전체 너비)
                        if (label.includes('반려') || label.includes('거부')) {
                          return (
                            <Box key={label} sx={{ gridColumn: { xs: '1', sm: '1 / -1' } }}>
                              <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 0.5, fontSize: '0.75rem' }}>
                                {label}
                              </Typography>
                              <Typography variant="body2" color="error.main" sx={{ fontWeight: 500 }}>
                                {value}
                              </Typography>
                            </Box>
                          );
                        }

                        // 일반 정보
                        return (
                          <Box key={label}>
                            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 0.5, fontSize: '0.75rem' }}>
                              {label}
                            </Typography>
                            <Typography variant="body2" sx={{ wordBreak: 'break-word', fontWeight: 500 }}>
                              {value}
                            </Typography>
                          </Box>
                        );
                      })}
                    </Box>
                  </Paper>
                </Box>
              );
            })()}

            {/* 메타 정보 */}
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
              <Typography variant="caption" color="text.secondary">
                수신 시간: {selectedNotification?.receivedAt.toLocaleString('ko-KR')}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                알림 ID: {selectedNotification?.id}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                이벤트 타입: {selectedNotification?.type}
              </Typography>
            </Box>
          </Stack>
        </DialogContent>

        <DialogActions>
          <Button
            onClick={() => {
              setNotificationModalOpen(false);
              setSelectedNotification(null);
            }}
            variant="outlined"
          >
            닫기
          </Button>
          {selectedNotification?.link && (
            <Button
              onClick={() => {
                navigate(selectedNotification.link!);
                setNotificationModalOpen(false);
                setSelectedNotification(null);
                setNotificationPanelOpen(false);
              }}
              variant="contained"
            >
              해당 페이지로 이동
            </Button>
          )}
        </DialogActions>
      </Dialog>
    </Drawer>
  );
}
