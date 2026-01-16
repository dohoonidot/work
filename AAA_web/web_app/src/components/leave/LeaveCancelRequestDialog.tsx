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
      sx={{
        '& .MuiDialog-paper': {
          borderRadius: isMobile ? 0 : '16px',
        },
      }}
    >
      <DialogTitle
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderBottom: '1px solid',
          borderColor: 'divider',
          pb: 2,
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <CancelIcon sx={{ color: '#E53E3E', fontSize: 24 }} />
          <Typography variant="h6" fontWeight={600}>
            휴가 취소 상신
          </Typography>
        </Box>
        <IconButton onClick={handleClose} size="small" disabled={loading}>
          <CloseIcon />
        </IconButton>
      </DialogTitle>

      <DialogContent sx={{ pt: 3 }}>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
            {error}
          </Alert>
        )}

        {/* 휴가 정보 카드 */}
        <Box
          sx={{
            p: 2,
            bgcolor: '#F8F9FA',
            borderRadius: '8px',
            mb: 3,
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1.5 }}>
            <EventIcon sx={{ fontSize: 16, color: '#6B7280' }} />
            <Typography variant="body1" fontWeight={600}>
              {leave.leaveType}
            </Typography>
          </Box>

          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
            <CalendarTodayIcon sx={{ fontSize: 16, color: '#6B7280' }} />
            <Typography variant="body2" color="text.secondary">
              {dayjs(leave.startDate).format('YYYY-MM-DD')} ~ {dayjs(leave.endDate).format('YYYY-MM-DD')}
            </Typography>
          </Box>

          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <AccessTimeIcon sx={{ fontSize: 16, color: '#6B7280' }} />
            <Typography variant="body2" color="text.secondary">
              {days}일
            </Typography>
          </Box>
        </Box>

        {/* 취소 사유 입력 */}
        <Box>
          <Typography variant="subtitle2" sx={{ mb: 1, fontWeight: 600 }}>
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
            sx={{ mb: 1 }}
          />
          <Typography variant="caption" color="text.secondary">
            ※ 취소 상신 후 결재자의 승인이 필요합니다.
          </Typography>
        </Box>
      </DialogContent>

      <DialogActions
        sx={{
          p: 3,
          borderTop: '1px solid',
          borderColor: 'divider',
        }}
      >
        <Button onClick={handleClose} variant="outlined" disabled={loading}>
          취소
        </Button>
        <Button
          onClick={handleSubmit}
          variant="contained"
          color="error"
          disabled={loading || !reason.trim()}
        >
          {loading ? '상신 중...' : '상신'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
