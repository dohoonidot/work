/**
 * 선물함 컴포넌트
 * 우측 상단에 배지 아이콘으로 표시되며, 클릭 시 선물 목록 표시
 */

import React, { useState, useEffect } from 'react';
import {
  Badge,
  IconButton,
  Drawer,
  Box,
  Typography,
  List,
  ListItem,
  Divider,
  Button,
  Chip,
  CircularProgress,
  Card,
  CardContent,
  CardMedia,
  Alert,
} from '@mui/material';
import CardGiftcardIcon from '@mui/icons-material/CardGiftcard';
import CloseIcon from '@mui/icons-material/Close';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import PhoneAndroidIcon from '@mui/icons-material/PhoneAndroid';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import DeleteIcon from '@mui/icons-material/Delete';
import giftService from '../../services/giftService';
import authService from '../../services/authService';
import type { Gift } from '../../types/gift';
import dayjs from 'dayjs';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Snackbar,
} from '@mui/material';

/**
 * 선물함 아이콘 버튼
 * 헤더나 네비게이션 바에 배치
 */
export function GiftButton() {
  const [giftCount, setGiftCount] = useState(0);
  const [isOpen, setIsOpen] = useState(false);

  // 선물 개수 조회
  useEffect(() => {
    const loadGiftCount = async () => {
      try {
        const user = authService.getCurrentUser();
        if (!user) return;

        const response = await giftService.checkGifts(user.userId);
        console.log('🎁 선물 응답:', response);
        const newGiftCount = (response?.gifts || []).filter(g => g.is_new).length;
        setGiftCount(newGiftCount);
      } catch (error) {
        console.error('🎁 선물 개수 조회 실패:', error);
        setGiftCount(0); // 에러 시 개수 0으로 설정
      }
    };

    loadGiftCount();

    // 5분마다 선물 개수 새로고침
    const interval = setInterval(loadGiftCount, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  return (
    <>
      <IconButton
        onClick={() => setIsOpen(true)}
        aria-label="선물함"
        sx={{
          mr: 1,
          bgcolor: 'rgba(156, 136, 212, 0.9)',
          color: 'white',
          '&:hover': {
            bgcolor: 'rgba(156, 136, 212, 1)',
          },
          boxShadow: 2,
        }}
      >
        <Badge badgeContent={giftCount} color="error">
          <CardGiftcardIcon />
        </Badge>
      </IconButton>
      <GiftPanel
        open={isOpen}
        onClose={() => setIsOpen(false)}
        onGiftCountChange={setGiftCount}
      />
    </>
  );
}

interface GiftPanelProps {
  open: boolean;
  onClose: () => void;
  onGiftCountChange: (count: number) => void;
}

/**
 * 선물함 패널 Drawer
 */
export function GiftPanel({ open, onClose, onGiftCountChange }: GiftPanelProps) {
  const [gifts, setGifts] = useState<Gift[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // 모바일 내보내기 관련 상태
  const [mobileExportDialogOpen, setMobileExportDialogOpen] = useState(false);
  const [mobileExportLoading, setMobileExportLoading] = useState(false);
  const [mobileExportGiftUrl, setMobileExportGiftUrl] = useState<string | null>(null);

  // 삭제 관련 상태
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [giftToDelete, setGiftToDelete] = useState<Gift | null>(null);

  const [snackbarOpen, setSnackbarOpen] = useState(false);
  const [snackbarMessage, setSnackbarMessage] = useState('');
  const [snackbarSeverity, setSnackbarSeverity] = useState<'success' | 'error'>('success');

  // 선물 목록 로드
  useEffect(() => {
    if (open) {
      loadGifts();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  const loadGifts = async () => {
    try {
      setLoading(true);
      setError(null);

      const user = authService.getCurrentUser();
      if (!user) {
        setError('사용자 정보를 찾을 수 없습니다.');
        return;
      }

      const response = await giftService.checkGifts(user.userId);
      setGifts(response.gifts || []);

      // 새 선물 개수 업데이트
      const newGiftCount = (response.gifts || []).filter(g => g.is_new).length;
      onGiftCountChange(newGiftCount);
    } catch (err: any) {
      console.error('선물함 조회 실패:', err);
      setError('선물함을 불러오는데 실패했습니다.');
    } finally {
      setLoading(false);
    }
  };

  // 쿠폰 이미지 URL 가져오기 헬퍼 함수 (두 필드 모두 지원)
  const getCouponImageUrl = (gift: Gift): string | undefined => {
    return gift.coupon_img_url || gift.couponImgUrl;
  };

  // 브라우저에서 열기 핸들러
  const handleOpenInBrowser = (url: string) => {
    window.open(url, '_blank');
  };

  // 모바일로 내보내기 확인 다이얼로그 열기
  const handleOpenMobileExportDialog = (url: string) => {
    setMobileExportGiftUrl(url);
    setMobileExportDialogOpen(true);
  };

  // 모바일로 내보내기 확인 다이얼로그 닫기
  const handleCloseMobileExportDialog = () => {
    setMobileExportDialogOpen(false);
    setMobileExportGiftUrl(null);
  };

  // 모바일로 내보내기 실행
  const handleSendToMobile = async () => {
    if (!mobileExportGiftUrl) return;

    try {
      setMobileExportLoading(true);
      const response = await giftService.sendToMobile(mobileExportGiftUrl);
      
      console.log('모바일 내보내기 성공:', response);
      
      setSnackbarMessage(response.message || '모바일로 전송되었습니다.');
      setSnackbarSeverity('success');
      setSnackbarOpen(true);
      
      handleCloseMobileExportDialog();
    } catch (err: any) {
      console.error('모바일 내보내기 실패:', err);
      setSnackbarMessage(err.message || '모바일 내보내기에 실패했습니다.');
      setSnackbarSeverity('error');
      setSnackbarOpen(true);
    } finally {
      setMobileExportLoading(false);
    }
  };

  // 삭제 확인 모달 열기
  const handleOpenDeleteConfirm = (gift: Gift) => {
    setGiftToDelete(gift);
    setDeleteConfirmOpen(true);
  };

  // 삭제 확인 모달 닫기
  const handleCloseDeleteConfirm = () => {
    setDeleteConfirmOpen(false);
    setGiftToDelete(null);
  };

  // 선물 삭제 실행
  const handleDeleteGift = async () => {
    if (!giftToDelete) return;

    try {
      // 실제 삭제 API 호출 (필요시 구현)
      // 예: await giftService.deleteGift(giftToDelete.id);

      // 로컬 상태에서 제거
      setGifts(prevGifts => prevGifts.filter(gift => gift.id !== giftToDelete.id));

      // 새 선물 개수 업데이트
      const newGiftCount = gifts.filter(g => g.id !== giftToDelete.id && g.is_new).length;
      onGiftCountChange(newGiftCount);

      setSnackbarMessage('선물이 삭제되었습니다.');
      setSnackbarSeverity('success');
      setSnackbarOpen(true);

      handleCloseDeleteConfirm();
    } catch (error) {
      console.error('선물 삭제 실패:', error);
      setSnackbarMessage('선물 삭제에 실패했습니다.');
      setSnackbarSeverity('error');
      setSnackbarOpen(true);
    }
  };

  // Snackbar 닫기
  const handleCloseSnackbar = () => {
    setSnackbarOpen(false);
  };

  return (
    <Drawer
      anchor="right"
      open={open}
      onClose={onClose}
      PaperProps={{
        sx: {
          width: { xs: '100%', sm: 400 },
          bgcolor: '#F8F9FA',
        },
      }}
    >
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        {/* 헤더 */}
        <Box
          sx={{
            p: 2,
            bgcolor: '#9C88D4',
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <CardGiftcardIcon />
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              받은 선물함
            </Typography>
            <Chip
              label={`${gifts.length}개`}
              size="small"
              sx={{
                bgcolor: 'white',
                color: '#9C88D4',
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
              onClick={onClose}
              sx={{ color: 'text.secondary' }}
            >
              <ArrowBackIcon />
            </IconButton>

            {/* 오른쪽: 새로고침 버튼 */}
            <Button
              size="small"
              onClick={loadGifts}
              disabled={loading}
              variant="outlined"
            >
              새로고침
            </Button>
          </Box>
        </Box>

        {/* 선물 목록 */}
        <Box sx={{ flex: 1, overflowY: 'auto', p: 2 }}>
          {loading ? (
            <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%' }}>
              <CircularProgress />
            </Box>
          ) : error ? (
            <Alert severity="error">{error}</Alert>
          ) : gifts.length === 0 ? (
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
              <CardGiftcardIcon sx={{ fontSize: 64, mb: 2, opacity: 0.3 }} />
              <Typography variant="h6" gutterBottom>
                받은 선물이 없습니다
              </Typography>
              <Typography variant="body2">
                선물이 도착하면 여기에 표시됩니다
              </Typography>
            </Box>
          ) : (
            <List sx={{ p: 0 }}>
              {gifts.map((gift, index) => (
                <React.Fragment key={gift.id || index}>
                  <Card sx={{ mb: 2, boxShadow: 2 }}>
                    <CardContent>
                      {/* 선물 타입 & NEW 배지 & 삭제 버튼 */}
                      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1 }}>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                          <Chip
                            label={gift.gift_type || '쿠폰'}
                            color="primary"
                            size="small"
                            sx={{ fontWeight: 600 }}
                          />
                          {gift.is_new && (
                            <Chip
                              label="NEW"
                              color="error"
                              size="small"
                              sx={{ fontWeight: 600 }}
                            />
                          )}
                        </Box>
                        <IconButton
                          size="small"
                          onClick={() => handleOpenDeleteConfirm(gift)}
                          sx={{ color: 'text.secondary', '&:hover': { color: 'error.main' } }}
                        >
                          <DeleteIcon fontSize="small" />
                        </IconButton>
                      </Box>

                      {/* 선물 내용 */}
                      {gift.gift_content && (
                        <Typography variant="body1" sx={{ mb: 2 }}>
                          {gift.gift_content}
                        </Typography>
                      )}

                      {/* 쿠폰 이미지 */}
                      {getCouponImageUrl(gift) && (
                        <CardMedia
                          component="img"
                          image={getCouponImageUrl(gift)!}
                          alt="쿠폰 이미지"
                          sx={{
                            borderRadius: 1,
                            mb: 2,
                            maxHeight: 200,
                            objectFit: 'contain',
                          }}
                        />
                      )}

                      {/* 브라우저 열기 및 모바일 내보내기 버튼 */}
                      {getCouponImageUrl(gift) && (
                        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1, mt: 2 }}>
                          <Button
                            variant="contained"
                            startIcon={<OpenInNewIcon sx={{ fontSize: 16 }} />}
                            onClick={() => handleOpenInBrowser(getCouponImageUrl(gift)!)}
                            sx={{
                              bgcolor: 'grey.600',
                              color: 'white',
                              borderRadius: '10px',
                              textTransform: 'none',
                              fontWeight: 600,
                              fontSize: '15px',
                              px: 2.25,
                              py: 1.25,
                              '&:hover': {
                                bgcolor: 'grey.700',
                              },
                            }}
                          >
                            브라우저에서 열기
                          </Button>
                          <Button
                            variant="contained"
                            startIcon={<PhoneAndroidIcon sx={{ fontSize: 18 }} />}
                            onClick={() => handleOpenMobileExportDialog(getCouponImageUrl(gift)!)}
                            sx={{
                              background: 'linear-gradient(90deg, #7b8fd1 0%, #b39ddb 100%)',
                              color: 'white',
                              borderRadius: '10px',
                              textTransform: 'none',
                              fontWeight: 600,
                              fontSize: '15px',
                              px: 2.25,
                              py: 1.25,
                              boxShadow: '0px 2px 6px rgba(183, 202, 255, 0.08)',
                              '&:hover': {
                                background: 'linear-gradient(90deg, #6a7fc0 0%, #a08cc8 100%)',
                                boxShadow: '0px 4px 8px rgba(183, 202, 255, 0.12)',
                              },
                            }}
                          >
                            모바일로 내보내기
                          </Button>
                        </Box>
                      )}

                      {/* 쿠폰 만료일 */}
                      {gift.coupon_end_date && (
                        <Typography variant="body2" color="error" sx={{ mb: 1 }}>
                          만료일: {dayjs(gift.coupon_end_date).format('YYYY-MM-DD')}
                        </Typography>
                      )}

                      {/* 받은 시간 */}
                      {gift.received_at && (
                        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1 }}>
                          받은 시간: {dayjs(gift.received_at).format('YYYY-MM-DD HH:mm')}
                        </Typography>
                      )}

                      {/* 선물 확인 버튼 */}
                      {gift.gift_url && (
                        <Button
                          variant="contained"
                          color="primary"
                          fullWidth
                          endIcon={<OpenInNewIcon />}
                          href={gift.gift_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          sx={{ mt: 1 }}
                        >
                          선물 확인하기
                        </Button>
                      )}
                    </CardContent>
                  </Card>
                  {index < gifts.length - 1 && <Divider sx={{ my: 1 }} />}
                </React.Fragment>
              ))}
            </List>
          )}
        </Box>

      </Box>

      {/* 모바일 내보내기 확인 다이얼로그 */}
      <Dialog
        open={mobileExportDialogOpen}
        onClose={handleCloseMobileExportDialog}
        maxWidth="sm"
        fullWidth
        PaperProps={{
          sx: {
            borderRadius: '16px',
          },
        }}
      >
        <DialogTitle sx={{ fontSize: '1.25rem', fontWeight: 600 }}>
          모바일로 내보내기
        </DialogTitle>
        <DialogContent>
          <Typography 
            variant="body1" 
            sx={{ 
              mb: 2,
              fontSize: '15px',
              fontWeight: 500,
            }}
          >
            모바일로 내보내기는 3분~5분정도 시간이 소요됩니다. 전송하시겠습니까?
          </Typography>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button
            onClick={handleCloseMobileExportDialog}
            disabled={mobileExportLoading}
            variant="text"
            sx={{
              fontSize: '16px',
              fontWeight: 500,
              color: 'grey.600',
              '&:hover': {
                bgcolor: 'grey.100',
              },
            }}
          >
            취소
          </Button>
          <Button
            onClick={handleSendToMobile}
            disabled={mobileExportLoading}
            variant="text"
            startIcon={mobileExportLoading ? <CircularProgress size={16} /> : null}
            sx={{
              fontSize: '16px',
              fontWeight: 600,
              color: 'primary.main',
              '&:hover': {
                bgcolor: 'rgba(25, 118, 210, 0.08)',
              },
            }}
          >
            {mobileExportLoading ? '전송 중...' : '전송'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* 선물 삭제 확인 모달 */}
      <Dialog
        open={deleteConfirmOpen}
        onClose={handleCloseDeleteConfirm}
        maxWidth="xs"
        fullWidth
      >
        <DialogTitle>
          선물 삭제 확인
        </DialogTitle>
        <DialogContent>
          <Typography>
            이 선물을 삭제하시겠습니까? 삭제된 선물은 복구할 수 없습니다.
          </Typography>
          {giftToDelete && (
            <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.50', borderRadius: 1 }}>
              <Typography variant="body2" sx={{ fontWeight: 600 }}>
                {giftToDelete.gift_content || giftToDelete.gift_type || '선물'}
              </Typography>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button
            onClick={handleCloseDeleteConfirm}
            variant="outlined"
          >
            취소
          </Button>
          <Button
            onClick={handleDeleteGift}
            color="error"
            variant="contained"
          >
            삭제
          </Button>
        </DialogActions>
      </Dialog>

      {/* 성공/에러 알림 Snackbar */}
      <Snackbar
        open={snackbarOpen}
        autoHideDuration={6000}
        onClose={handleCloseSnackbar}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          onClose={handleCloseSnackbar}
          severity={snackbarSeverity}
          sx={{ width: '100%' }}
        >
          {snackbarMessage}
        </Alert>
      </Snackbar>
    </Drawer>
  );
}
