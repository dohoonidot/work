import React from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Typography,
  Box,
  Avatar,
  Chip,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  CardGiftcard as GiftIcon,
  AccessTime as AccessTimeIcon,
} from '@mui/icons-material';

interface GiftArrivalPopupProps {
  open: boolean;
  giftData: {
    gift_name?: string;
    message?: string;
    couponImgUrl?: string;
    coupon_end_date?: string;
    queue_name?: string;
    sender_name?: string;
  } | null;
  onConfirm: () => void; // 선물함으로 이동
  onClose: () => void;
}

export default function GiftArrivalPopup({
  open,
  giftData,
  onConfirm,
  onClose,
}: GiftArrivalPopupProps) {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));

  if (!giftData) {
    return null;
  }

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="sm"
      fullWidth
      fullScreen={isMobile}
      PaperProps={{
        sx: {
          borderRadius: isMobile ? 0 : 3,
          maxHeight: isMobile ? '100%' : '90vh',
        },
      }}
    >
      {/* 헤더 - 그라데이션 배경 */}
      <DialogTitle
        sx={{
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          color: 'white',
          textAlign: 'center',
          py: 3,
          borderRadius: '20px 20px 0 0',
        }}
      >
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 1.5,
          }}
        >
          <GiftIcon sx={{ fontSize: 32 }} />
          <Typography variant="h5" component="span" sx={{ fontWeight: 'bold' }}>
            선물이 도착했습니다! 🎁
          </Typography>
        </Box>
      </DialogTitle>

      {/* 콘텐츠 */}
      <DialogContent
        sx={{
          textAlign: 'center',
          py: 4,
          px: 3,
        }}
      >
        {/* 쿠폰 이미지 */}
        {giftData.couponImgUrl && (
          <Box sx={{ mb: 3 }}>
            <Avatar
              src={giftData.couponImgUrl}
              alt="쿠폰 이미지"
              sx={{
                width: 120,
                height: 120,
                mx: 'auto',
                boxShadow: 3,
                border: '3px solid',
                borderColor: 'primary.light',
              }}
              variant="rounded"
            />
          </Box>
        )}

        {/* 선물 이름 */}
        {giftData.gift_name && (
          <Typography
            variant="h6"
            sx={{
              mb: 2,
              fontWeight: 'bold',
              color: 'text.primary',
            }}
          >
            {giftData.gift_name}
          </Typography>
        )}

        {/* 메시지 */}
        {giftData.message && (
          <Typography
            variant="body1"
            sx={{
              mb: 3,
              color: 'text.secondary',
              lineHeight: 1.6,
            }}
          >
            {giftData.message}
          </Typography>
        )}

        {/* 발신자 이름 */}
        {giftData.sender_name && (
          <Typography
            variant="body2"
            sx={{
              mb: 2,
              color: 'text.secondary',
              fontStyle: 'italic',
            }}
          >
            From: {giftData.sender_name}
          </Typography>
        )}

        {/* 만료일 */}
        {giftData.coupon_end_date && (
          <Box
            sx={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 1,
              mb: 2,
            }}
          >
            <AccessTimeIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
            <Chip
              label={`만료일: ${giftData.coupon_end_date}`}
              size="small"
              color="warning"
              sx={{
                fontWeight: 600,
              }}
            />
          </Box>
        )}

        {/* 큐 이름 (디버깅용, 필요시 숨김) */}
        {giftData.queue_name && process.env.NODE_ENV === 'development' && (
          <Typography
            variant="caption"
            sx={{
              color: 'text.disabled',
              mt: 2,
              display: 'block',
            }}
          >
            Queue: {giftData.queue_name}
          </Typography>
        )}
      </DialogContent>

      {/* 액션 버튼 */}
      <DialogActions
        sx={{
          justifyContent: 'center',
          pb: 3,
          px: 3,
        }}
      >
        <Button
          onClick={onConfirm}
          variant="contained"
          color="primary"
          size="large"
          startIcon={<GiftIcon />}
          sx={{
            minWidth: 200,
            py: 1.5,
            fontSize: '1rem',
            fontWeight: 600,
            borderRadius: 2,
            boxShadow: 3,
            '&:hover': {
              boxShadow: 6,
            },
          }}
        >
          선물함에서 확인하기
        </Button>
      </DialogActions>
    </Dialog>
  );
}

