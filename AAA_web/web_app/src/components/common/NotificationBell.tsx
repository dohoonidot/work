/**
 * 알림함 벨 컴포넌트
 *
 * /queue/checkAlerts, /queue/updateAlerts, /queue/deleteAlerts API 사용
 * Flutter 앱과 동일한 알림함 기능 제공
 */

import React, { useState, useEffect, useCallback } from 'react';
import {
  Badge,
  IconButton,
  Drawer,
  Box,
  Typography,
  List,
  ListItemButton,
  ListItemText,
  Divider,
  Button,
  Chip,
  Stack,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Paper,
} from '@mui/material';
import NotificationsIcon from '@mui/icons-material/Notifications';
import CloseIcon from '@mui/icons-material/Close';
import DeleteIcon from '@mui/icons-material/Delete';
import DoneAllIcon from '@mui/icons-material/DoneAll';
import FiberManualRecordIcon from '@mui/icons-material/FiberManualRecord';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import AutoAwesomeIcon from '@mui/icons-material/AutoAwesome';
import { notificationApi } from '../../services/notificationApi';
import {
  getIconByQueueName,
  getTitleByQueueName,
  formatDateTime,
  formatAbsoluteDateTime,
} from '../../utils/notificationHelpers';
import type { AlertItem } from '../../types/notification';

interface NotificationBellProps {
  /** 사용자 ID (이메일) */
  userId: string;
  /** 자동 새로고침 간격 (ms, 기본값: 30초) */
  refreshInterval?: number;
  /** 외부에서 Drawer 열림/닫힘 제어 (선택사항) */
  open?: boolean;
  /** 외부에서 Drawer 닫기 핸들러 (선택사항) */
  onClose?: () => void;
}

/**
 * 알림함 벨 아이콘 버튼 및 패널
 */
export function NotificationBell({
  userId,
  refreshInterval = 30000,
  open: externalOpen,
  onClose: externalOnClose,
}: NotificationBellProps) {
  const [internalOpen, setInternalOpen] = useState(false);
  const [notifications, setNotifications] = useState<AlertItem[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [selectedNotification, setSelectedNotification] =
    useState<AlertItem | null>(null);
  const [detailModalOpen, setDetailModalOpen] = useState(false);
  const [clearAllConfirmOpen, setClearAllConfirmOpen] = useState(false);
  const [loading, setLoading] = useState(false);

  // 외부 제어 또는 내부 제어
  const isOpen = externalOpen !== undefined ? externalOpen : internalOpen;
  const handleClose = () => {
    if (externalOnClose) {
      externalOnClose();
    } else {
      setInternalOpen(false);
    }
  };
  const handleOpen = () => {
    if (externalOpen === undefined) {
      setInternalOpen(true);
    }
  };

  /**
   * 알림 목록 로드
   */
  const loadNotifications = useCallback(async () => {
    try {
      setLoading(true);
      const alerts = await notificationApi.getAlerts(userId);
      setNotifications(alerts);

      // 읽지 않은 알림 개수 계산
      const unread = alerts.filter((alert) => !alert.is_read).length;
      setUnreadCount(unread);
    } catch (error) {
      console.error('[NotificationBell] 알림 로드 실패:', error);
    } finally {
      setLoading(false);
    }
  }, [userId]);

  /**
   * 컴포넌트 마운트 시 & 주기적으로 알림 로드
   */
  useEffect(() => {
    loadNotifications();

    // 주기적 새로고침
    const intervalId = setInterval(loadNotifications, refreshInterval);

    return () => clearInterval(intervalId);
  }, [loadNotifications, refreshInterval]);

  /**
   * 알림 클릭 시 읽음 처리 및 상세 모달 열기
   */
  const handleNotificationClick = async (alert: AlertItem) => {
    // 읽지 않은 알림인 경우 읽음 처리
    if (!alert.is_read) {
      try {
        const updatedAlerts = await notificationApi.markAsRead(userId, alert.id);
        setNotifications(updatedAlerts);

        // 읽지 않은 알림 개수 업데이트
        const unread = updatedAlerts.filter((a) => !a.is_read).length;
        setUnreadCount(unread);
      } catch (error) {
        console.error('[NotificationBell] 읽음 처리 실패:', error);
      }
    }

    // 상세 모달 열기 (모든 알림 타입에 대해 동일한 모달 사용)
    setSelectedNotification(alert);
    setDetailModalOpen(true);
  };

  /**
   * 알림 삭제
   */
  const handleDelete = async (
    alertId: number,
    event: React.MouseEvent
  ) => {
    event.stopPropagation();

    try {
      const updatedAlerts = await notificationApi.deleteAlert(userId, alertId);
      setNotifications(updatedAlerts);

      // 읽지 않은 알림 개수 업데이트
      const unread = updatedAlerts.filter((a) => !a.is_read).length;
      setUnreadCount(unread);
    } catch (error) {
      console.error('[NotificationBell] 삭제 실패:', error);
    }
  };

  /**
   * 모두 읽음 처리
   */
  const handleMarkAllAsRead = async () => {
    const unreadAlerts = notifications.filter((alert) => !alert.is_read);

    for (const alert of unreadAlerts) {
      try {
        await notificationApi.markAsRead(userId, alert.id);
      } catch (error) {
        console.error('[NotificationBell] 읽음 처리 실패:', error);
      }
    }

    // 알림 목록 새로고침
    await loadNotifications();
  };

  /**
   * 모두 삭제
   */
  const handleClearAll = async () => {
    for (const alert of notifications) {
      try {
        await notificationApi.deleteAlert(userId, alert.id);
      } catch (error) {
        console.error('[NotificationBell] 삭제 실패:', error);
      }
    }

    // 알림 목록 새로고침
    await loadNotifications();
  };

  return (
    <>
      {/* 알림 벨 아이콘 버튼 (외부 제어 시에는 표시하지 않음) */}
      {externalOpen === undefined && (
        <IconButton
          onClick={handleOpen}
          aria-label="알림함"
          sx={{
            mr: { xs: 0, sm: 1 },
            ml: { xs: 1, sm: 0 },
            bgcolor: 'rgba(29, 68, 135, 0.9)',
            color: 'white',
            '&:hover': {
              bgcolor: 'rgba(29, 68, 135, 1)',
            },
            boxShadow: 2,
          }}
        >
          <Badge badgeContent={unreadCount} color="error">
            <NotificationsIcon sx={{ fontSize: { xs: 20, sm: 24 } }} />
          </Badge>
        </IconButton>
      )}

      {/* 알림함 Drawer */}
      <Drawer
        anchor="right"
        open={isOpen}
        onClose={handleClose}
        PaperProps={{
          sx: {
            width: { xs: '100%', sm: 400 },
            maxWidth: '100%',
            bgcolor: '#F8F9FA',
          },
        }}
      >
        <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
          {/* 헤더 */}
          <Box
            sx={{
              p: 2,
              bgcolor: '#1D4487',
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
                  bgcolor: 'white',
                  color: '#1D4487',
                  fontWeight: 600,
                }}
              />
            </Box>
          </Box>

          {/* 액션 버튼 영역 */}
          <Box sx={{ p: 1, borderBottom: 1, borderColor: 'divider', bgcolor: 'white' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              {/* 왼쪽: 뒤로가기 버튼 */}
              <IconButton
                size="small"
                onClick={handleClose}
                sx={{ color: 'text.secondary' }}
              >
                <ArrowBackIcon />
              </IconButton>

              {/* 오른쪽: 새로고침 버튼 */}
              <Button
                size="small"
                onClick={loadNotifications}
                disabled={loading}
                variant="outlined"
              >
                새로고침
              </Button>
            </Box>
          </Box>

          {/* 추가 액션 버튼 (모두 읽음, 모두 삭제) */}
          {notifications.length > 0 && (
            <Box sx={{ p: 1, borderBottom: 1, borderColor: 'divider', bgcolor: 'white' }}>
              <Stack direction="row" spacing={1} justifyContent="flex-end">
                {unreadCount > 0 && (
                  <Button
                    size="small"
                    startIcon={<DoneAllIcon />}
                    onClick={handleMarkAllAsRead}
                    disabled={loading}
                  >
                    모두 읽음
                  </Button>
                )}
                <Button
                  size="small"
                  color="error"
                  startIcon={<DeleteIcon />}
                  onClick={() => setClearAllConfirmOpen(true)}
                  disabled={loading}
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
                backgroundColor: 'rgba(0,0,0,0.05)',
                borderRadius: '5px',
              },
              '&::-webkit-scrollbar-thumb': {
                backgroundColor: 'rgba(0,0,0,0.3)',
                borderRadius: '5px',
                border: '2px solid rgba(0,0,0,0.05)',
                '&:hover': {
                  backgroundColor: 'rgba(0,0,0,0.5)',
                },
                '&:active': {
                  backgroundColor: 'rgba(0,0,0,0.6)',
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
                  color: 'text.secondary',
                }}
              >
                <NotificationsIcon sx={{ fontSize: 64, mb: 2, opacity: 0.3 }} />
                <Typography variant="h6" gutterBottom>
                  새로운 알림이 없습니다
                </Typography>
                <Typography variant="body2">
                  알림이 도착하면 여기에 표시됩니다
                </Typography>
              </Box>
            ) : (
              <List sx={{ p: 0 }}>
                {notifications.map((notification, index) => (
                  <React.Fragment key={notification.id}>
                    <ListItemButton
                      onClick={() => handleNotificationClick(notification)}
                      sx={{
                        bgcolor: notification.is_read
                          ? 'transparent'
                          : 'action.hover',
                        '&:hover': {
                          bgcolor: notification.is_read
                            ? 'action.hover'
                            : 'action.selected',
                        },
                      }}
                    >
                      {/* 아이콘 */}
                      <Box
                        sx={{
                          fontSize: 24,
                          mr: 2,
                          display: 'flex',
                          alignItems: 'center',
                        }}
                      >
                        {getIconByQueueName(notification.queue_name)}
                      </Box>

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
                            {!notification.is_read && (
                              <FiberManualRecordIcon
                                sx={{ fontSize: 8, color: 'primary.main' }}
                              />
                            )}
                            <Typography
                              variant="subtitle2"
                              fontWeight="bold"
                              component="span"
                            >
                              {getTitleByQueueName(notification.queue_name)}
                            </Typography>
                          </Box>
                        }
                        secondary={
                          <>
                            <Typography
                              variant="body2"
                              color="text.primary"
                              component="span"
                              sx={{ mb: 0.5, display: 'block' }}
                            >
                              {notification.message.length > 60
                                ? `${notification.message.substring(0, 60)}...`
                                : notification.message}
                            </Typography>
                            <Typography
                              variant="caption"
                              color="text.secondary"
                              component="span"
                            >
                              {formatDateTime(notification.send_time)}
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
      </Drawer>

      {/* 알림 상세 모달 */}
      <Dialog
        open={detailModalOpen}
        onClose={() => {
          setDetailModalOpen(false);
          setSelectedNotification(null);
        }}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            <Box sx={{ fontSize: 32 }}>
              {selectedNotification &&
                getIconByQueueName(selectedNotification.queue_name)}
            </Box>
            <Box>
              <Typography variant="h6" component="div">
                {selectedNotification &&
                  getTitleByQueueName(selectedNotification.queue_name)}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {selectedNotification &&
                  formatAbsoluteDateTime(selectedNotification.send_time)}
              </Typography>
            </Box>
          </Box>
        </DialogTitle>

        <DialogContent>
          {selectedNotification?.queue_name === 'leave.analyze' ? (
            // AI 휴가 추천 분석 결과 표시
            <Box>
              <Paper
                sx={{
                  p: 3,
                  bgcolor: 'grey.50',
                  borderRadius: 2,
                  border: '1px solid',
                  borderColor: 'divider',
                  mb: 2,
                }}
              >
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                  <AutoAwesomeIcon sx={{ color: 'primary.main' }} />
                  <Typography variant="h6" sx={{ fontWeight: 600 }}>
                    AI 휴가 추천 분석 결과
                  </Typography>
                </Box>
                <Typography variant="body1" sx={{ whiteSpace: 'pre-wrap' }}>
                  {selectedNotification?.message}
                </Typography>
              </Paper>

              {/* 추천 사항 요약 */}
              <Paper
                sx={{
                  p: 3,
                  bgcolor: 'background.paper',
                  borderRadius: 2,
                  border: '1px solid',
                  borderColor: 'divider',
                }}
              >
                <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 2 }}>
                  💡 추천 사항
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  • AI가 분석한 휴가 추천 결과를 확인하세요<br/>
                  • 휴가 관리 페이지에서 자세한 차트와 캘린더를 확인할 수 있습니다
                </Typography>
              </Paper>
            </Box>
          ) : (
            // 일반 알림 메시지 표시
            <Paper
              sx={{
                p: 3,
                bgcolor: 'grey.50',
                borderRadius: 2,
                border: '1px solid',
                borderColor: 'divider',
              }}
            >
              <Typography variant="body1" sx={{ whiteSpace: 'pre-wrap' }}>
                {selectedNotification?.message}
              </Typography>
            </Paper>
          )}

          {/* 메타 정보 */}
          <Box sx={{ mt: 3, display: 'flex', flexDirection: 'column', gap: 1 }}>
            <Typography variant="caption" color="text.secondary">
              알림 ID: {selectedNotification?.id}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              큐 이름: {selectedNotification?.queue_name}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              전송 시간: {selectedNotification?.send_time}
            </Typography>
          </Box>
        </DialogContent>

        <DialogActions>
          <Button
            onClick={() => {
              setDetailModalOpen(false);
              setSelectedNotification(null);
            }}
            variant="outlined"
          >
            닫기
          </Button>
          <Button
            onClick={async () => {
              if (selectedNotification) {
                await handleDelete(selectedNotification.id, {
                  stopPropagation: () => {},
                } as React.MouseEvent);
              }
              setDetailModalOpen(false);
              setSelectedNotification(null);
            }}
            color="error"
            variant="contained"
          >
            삭제
          </Button>
        </DialogActions>
      </Dialog>

      {/* 모두 삭제 확인 모달 */}
      <Dialog
        open={clearAllConfirmOpen}
        onClose={() => setClearAllConfirmOpen(false)}
        maxWidth="xs"
        fullWidth
      >
        <DialogTitle>
          모두 삭제 확인
        </DialogTitle>
        <DialogContent>
          <Typography>
            모든 알림을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button
            onClick={() => setClearAllConfirmOpen(false)}
            variant="outlined"
          >
            취소
          </Button>
          <Button
            onClick={async () => {
              setClearAllConfirmOpen(false);
              await handleClearAll();
            }}
            color="error"
            variant="contained"
            disabled={loading}
          >
            모두 삭제
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
}

export default NotificationBell;
