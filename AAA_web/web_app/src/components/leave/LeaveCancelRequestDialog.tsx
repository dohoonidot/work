import React, { useState } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  TextField,
  Box,
  Typography,
  IconButton,
  Alert,
  useMediaQuery,
  useTheme,
  alpha,
} from '@mui/material';
import {
  Close as CloseIcon,
  CancelOutlined as CancelIcon,
  Event as EventIcon,
  CalendarToday as CalendarTodayIcon,
  AccessTime as AccessTimeIcon,
} from '@mui/icons-material';
import dayjs from 'dayjs';
import leaveService from '../../services/leaveService';
import type { YearlyDetail } from '../../types/leave';

interface LeaveCancelRequestDialogProps {
  open: boolean;
  onClose: () => void;
  onSuccess: () => void;
  leave: YearlyDetail | null;
  userId: string;
}

export default function LeaveCancelRequestDialog({
  open,
  onClose,
  onSuccess,
  leave,
  userId,
}: LeaveCancelRequestDialogProps) {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const isDark = theme.palette.mode === 'dark';

  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async () => {
    if (!leave) return;

    if (!reason.trim()) {
      setError('취소 사유를 입력해주세요.');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const result = await leaveService.requestLeaveCancel({
        id: leave.id,
        userId: userId,
        reason: reason.trim(),
      });

      if (result.error) {
        setError(result.error);
      } else {
        handleClose();
        onSuccess();
      }
    } catch (err: any) {
      console.error('휴가 취소 상신 실패:', err);
      setError(err.response?.data?.error || '휴가 취소 상신 중 오류가 발생했습니다.');
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    setReason('');
    setError(null);
    onClose();
  };

  if (!leave) return null;

  // 일수 계산 (workdaysCount가 있으면 사용, 없으면 날짜 차이로 계산)
  const days = leave.workdaysCount ||
    dayjs(leave.endDate).diff(dayjs(leave.startDate), 'day') + 1;

  return (
    <Dialog
      open={open}
      onClose={!loading ? handleClose : undefined}
      maxWidth="sm"
      fullWidth
      fullScreen={isMobile}
      PaperProps={{
        sx: {
          borderRadius: isMobile ? 0 : '16px',
          bgcolor: isDark ? '#1E1E1E' : '#FFFFFF',
          backgroundImage: 'none',
        },
      }}
    >
      <DialogTitle
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderBottom: '1px solid',
          borderColor: isDark ? alpha('#FFFFFF', 0.12) : 'divider',
          pb: 2,
          bgcolor: isDark ? '#1E1E1E' : '#FFFFFF',
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <CancelIcon sx={{ color: isDark ? '#F87171' : '#E53E3E', fontSize: 24 }} />
          <Typography
            variant="h6"
            fontWeight={600}
            sx={{ color: isDark ? '#F5F5F5' : 'inherit' }}
          >
            휴가 취소 상신
          </Typography>
        </Box>
        <IconButton
          onClick={handleClose}
          size="small"
          disabled={loading}
          sx={{ color: isDark ? alpha('#FFFFFF', 0.7) : 'inherit' }}
        >
          <CloseIcon />
        </IconButton>
      </DialogTitle>

      <DialogContent
        sx={{
          pt: 3,
          bgcolor: isDark ? '#1E1E1E' : '#FFFFFF',
        }}
      >
        {error && (
          <Alert
            severity="error"
            sx={{
              mb: 2,
              bgcolor: isDark ? alpha('#F87171', 0.15) : undefined,
              color: isDark ? '#F87171' : undefined,
              '& .MuiAlert-icon': {
                color: isDark ? '#F87171' : undefined,
              },
            }}
            onClose={() => setError(null)}
          >
            {error}
          </Alert>
        )}

        {/* 휴가 정보 카드 */}
        <Box
          sx={{
            p: 2,
            bgcolor: isDark ? alpha('#FFFFFF', 0.05) : '#F8F9FA',
            borderRadius: '8px',
            mb: 3,
            border: isDark ? `1px solid ${alpha('#FFFFFF', 0.1)}` : 'none',
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1.5 }}>
            <EventIcon sx={{ fontSize: 16, color: isDark ? alpha('#FFFFFF', 0.6) : '#6B7280' }} />
            <Typography
              variant="body1"
              fontWeight={600}
              sx={{ color: isDark ? '#F5F5F5' : 'inherit' }}
            >
              {leave.leaveType}
            </Typography>
          </Box>

          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
            <CalendarTodayIcon sx={{ fontSize: 16, color: isDark ? alpha('#FFFFFF', 0.6) : '#6B7280' }} />
            <Typography
              variant="body2"
              sx={{ color: isDark ? alpha('#FFFFFF', 0.7) : 'text.secondary' }}
            >
              {dayjs(leave.startDate).format('YYYY-MM-DD')} ~ {dayjs(leave.endDate).format('YYYY-MM-DD')}
            </Typography>
          </Box>

          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <AccessTimeIcon sx={{ fontSize: 16, color: isDark ? alpha('#FFFFFF', 0.6) : '#6B7280' }} />
            <Typography
              variant="body2"
              sx={{ color: isDark ? alpha('#FFFFFF', 0.7) : 'text.secondary' }}
            >
              {days}일
            </Typography>
          </Box>
        </Box>

        {/* 취소 사유 입력 */}
        <Box>
          <Typography
            variant="subtitle2"
            sx={{
              mb: 1,
              fontWeight: 600,
              color: isDark ? '#F5F5F5' : 'inherit',
            }}
          >
            취소 사유를 입력해주세요 *
          </Typography>
          <TextField
            multiline
            rows={4}
            fullWidth
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="예: 일정 변경으로 인한 휴가 취소"
            disabled={loading}
            sx={{
              mb: 1,
              '& .MuiOutlinedInput-root': {
                bgcolor: isDark ? alpha('#FFFFFF', 0.05) : '#FFFFFF',
                '& fieldset': {
                  borderColor: isDark ? alpha('#FFFFFF', 0.2) : undefined,
                },
                '&:hover fieldset': {
                  borderColor: isDark ? alpha('#FFFFFF', 0.3) : undefined,
                },
                '&.Mui-focused fieldset': {
                  borderColor: isDark ? '#60A5FA' : undefined,
                },
              },
              '& .MuiInputBase-input': {
                color: isDark ? '#F5F5F5' : 'inherit',
                '&::placeholder': {
                  color: isDark ? alpha('#FFFFFF', 0.5) : undefined,
                  opacity: 1,
                },
              },
            }}
          />
          <Typography
            variant="caption"
            sx={{ color: isDark ? alpha('#FFFFFF', 0.6) : 'text.secondary' }}
          >
            ※ 취소 상신 후 결재자의 승인이 필요합니다.
          </Typography>
        </Box>
      </DialogContent>

      <DialogActions
        sx={{
          p: 3,
          borderTop: '1px solid',
          borderColor: isDark ? alpha('#FFFFFF', 0.12) : 'divider',
          bgcolor: isDark ? '#1E1E1E' : '#FFFFFF',
        }}
      >
        <Button
          onClick={handleClose}
          variant="outlined"
          disabled={loading}
          sx={{
            borderColor: isDark ? alpha('#FFFFFF', 0.3) : undefined,
            color: isDark ? alpha('#FFFFFF', 0.8) : undefined,
            '&:hover': {
              borderColor: isDark ? alpha('#FFFFFF', 0.5) : undefined,
              bgcolor: isDark ? alpha('#FFFFFF', 0.05) : undefined,
            },
          }}
        >
          취소
        </Button>
        <Button
          onClick={handleSubmit}
          variant="contained"
          color="error"
          disabled={loading || !reason.trim()}
          sx={{
            bgcolor: isDark ? '#DC2626' : undefined,
            '&:hover': {
              bgcolor: isDark ? '#B91C1C' : undefined,
            },
            '&.Mui-disabled': {
              bgcolor: isDark ? alpha('#DC2626', 0.3) : undefined,
              color: isDark ? alpha('#FFFFFF', 0.5) : undefined,
            },
          }}
        >
          {loading ? '상신 중...' : '상신'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
