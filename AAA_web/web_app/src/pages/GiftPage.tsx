import React, { useState, useEffect } from 'react';
import { 
  Box, 
  Typography, 
  Container, 
  Paper, 
  CircularProgress, 
  Alert,
  Card,
  CardContent,
  Chip,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  CardMedia,
  CardActions,
  Snackbar,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  CardGiftcard as GiftIcon,
  Close as CloseIcon,
  AccessTime as AccessTimeIcon,
  OpenInNew as OpenInNewIcon,
  ArrowBack as ArrowBackIcon,
  PhoneAndroid as PhoneAndroidIcon,
} from '@mui/icons-material';
import MobileMainLayout from '../components/layout/MobileMainLayout';
import giftService from '../services/giftService';
import type { Gift } from '../types/gift';
import authService from '../services/authService';
import { useNavigate } from 'react-router-dom';

export default function GiftPage() {
  const navigate = useNavigate();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const [gifts, setGifts] = useState<Gift[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedGift, setSelectedGift] = useState<Gift | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  
  // 모바일 내보내기 관련 상태
  const [mobileExportDialogOpen, setMobileExportDialogOpen] = useState(false);
  const [mobileExportLoading, setMobileExportLoading] = useState(false);
  const [mobileExportGiftUrl, setMobileExportGiftUrl] = useState<string | null>(null);
  const [snackbarOpen, setSnackbarOpen] = useState(false);
  const [snackbarMessage, setSnackbarMessage] = useState('');
  const [snackbarSeverity, setSnackbarSeverity] = useState<'success' | 'error'>('success');

  useEffect(() => {
    loadGifts();
  }, []);

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
      console.log('받은 선물 목록:', response);
      console.log('받은 선물 개수:', response.gifts?.length || 0);
      
      if (response.gifts && response.gifts.length > 0) {
        console.log('첫 번째 선물 데이터:', response.gifts[0]);
        console.log('선물 필드들:', Object.keys(response.gifts[0]));
        // 쿠폰 이미지 URL 필드 확인
        response.gifts.forEach((gift, index) => {
          console.log(`선물 ${index + 1}:`, {
            coupon_img_url: gift.coupon_img_url,
            couponImgUrl: gift.couponImgUrl,
            hasCouponImage: !!(gift.coupon_img_url || gift.couponImgUrl),
            allFields: gift
          });
        });
      }
      
      setGifts(response.gifts || []);
    } catch (err: any) {
      console.error('선물 목록 로드 실패:', err);
      setError(err.response?.data?.message || '선물 목록을 불러오는데 실패했습니다.');
    } finally {
      setLoading(false);
    }
  };

  const handleGiftClick = (gift: Gift) => {
    setSelectedGift(gift);
    setDialogOpen(true);
  };

  const handleCloseDialog = () => {
    setDialogOpen(false);
    setSelectedGift(null);
  };


  // 브라우저에서 열기 핸들러
  const handleOpenInBrowser = (url: string, event?: React.MouseEvent) => {
    if (event) {
      event.stopPropagation(); // 카드 클릭 이벤트 방지
    }
    window.open(url, '_blank');
  };

  // 모바일로 내보내기 확인 다이얼로그 열기
  const handleOpenMobileExportDialog = (url: string, event?: React.MouseEvent) => {
    if (event) {
      event.stopPropagation(); // 카드 클릭 이벤트 방지
    }
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

  // Snackbar 닫기
  const handleCloseSnackbar = () => {
    setSnackbarOpen(false);
  };

  // 쿠폰 이미지 URL 가져오기 헬퍼 함수 (두 필드 모두 지원)
  const getCouponImageUrl = (gift: Gift): string | undefined => {
    const url = gift.coupon_img_url || gift.couponImgUrl;
    if (!url) {
      console.log('쿠폰 이미지 URL 없음:', {
        coupon_img_url: gift.coupon_img_url,
        couponImgUrl: gift.couponImgUrl,
        giftId: gift.id
      });
    }
    return url;
  };

  return (
    <MobileMainLayout>
      <Container maxWidth="md" sx={{ py: 4 }}>
        <Paper elevation={3} sx={{ p: 4, borderRadius: 3 }}>
          {/* 헤더 */}
          <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
            {/* 뒤로가기 버튼 */}
            <IconButton
              onClick={() => navigate('/chat')}
              sx={{
                mr: 1,
                color: 'primary.main',
              }}
            >
              <ArrowBackIcon />
            </IconButton>

            <Box
              sx={{
                p: 2,
                borderRadius: 2,
                bgcolor: 'primary.light',
                color: 'primary.contrastText',
                mr: 2,
              }}
            >
              <GiftIcon sx={{ fontSize: 32 }} />
            </Box>
            <Box>
              <Typography variant="h4" component="h1" sx={{ fontWeight: 'bold', color: 'primary.main' }}>
                받은선물함
              </Typography>
              <Typography variant="body2" color="text.secondary">
                받은 선물을 확인하세요
              </Typography>
            </Box>
          </Box>

          {/* 로딩 상태 */}
          {loading && (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
              <CircularProgress />
            </Box>
          )}

          {/* 에러 상태 */}
          {error && (
            <Alert severity="error" sx={{ mb: 3 }}>
              {error}
            </Alert>
          )}

          {/* 선물 목록 */}
          {!loading && !error && (
            <>
              {gifts.length === 0 ? (
                <Box sx={{ textAlign: 'center', py: 6 }}>
                  <GiftIcon sx={{ fontSize: 80, color: 'grey.300', mb: 2 }} />
                  <Typography variant="h6" color="text.secondary" gutterBottom>
                    받은 선물이 없습니다
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    선물이 도착하면 여기에 표시됩니다
                  </Typography>
                </Box>
              ) : (
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                  {gifts.map((gift, index) => (
                    <Card
                      key={gift.id ? `gift-${gift.id}` : `gift-index-${index}`}
                      sx={{
                        borderRadius: 2,
                        boxShadow: 1,
                        cursor: 'pointer',
                        '&:hover': {
                          boxShadow: 3,
                          transform: 'translateY(-2px)',
                          transition: 'all 0.2s ease-in-out',
                        },
                      }}
                      onClick={() => handleGiftClick(gift)}
                    >
                      {/* 헤더 */}
                      <CardContent sx={{ pb: 1 }}>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                          <GiftIcon sx={{ color: 'grey.600', fontSize: 20 }} />
                          <Typography variant="h6" sx={{ fontWeight: 600, flexGrow: 1 }}>
                            받은 선물
                          </Typography>
                          <Chip
                            label={gift.gift_type || '쿠폰'}
                            size="small"
                            sx={{
                              fontSize: 12,
                              fontWeight: 600,
                              bgcolor: 'grey.200',
                              color: 'grey.700',
                            }}
                          />
                        </Box>

                        {/* 선물 내용 */}
                        {gift.gift_content && (
                          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                            {gift.gift_content}
                          </Typography>
                        )}

                        {/* 쿠폰 이미지 */}
                        {getCouponImageUrl(gift) && (
                          <Box sx={{ mb: 2 }}>
                            <CardMedia
                              component="img"
                              height="200"
                              image={getCouponImageUrl(gift)!}
                              alt="쿠폰 이미지"
                              sx={{
                                borderRadius: 1,
                                objectFit: 'contain',
                                bgcolor: 'grey.50',
                              }}
                            />
                          </Box>
                        )}

                        {/* 받은 시간 */}
                        {gift.received_at && (
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mt: 1, mb: 1 }}>
                            <AccessTimeIcon sx={{ fontSize: 12, color: 'grey.500' }} />
                            <Typography variant="caption" color="text.secondary">
                              {gift.received_at}
                            </Typography>
                          </Box>
                        )}
                      </CardContent>

                      {/* 브라우저 열기 및 모바일 내보내기 버튼 */}
                      {(() => {
                        const couponImageUrl = getCouponImageUrl(gift);
                        console.log(`선물 ${gift.id} 버튼 표시 체크:`, {
                          couponImageUrl,
                          hasUrl: !!couponImageUrl,
                          giftData: gift
                        });
                        
                        if (!couponImageUrl) {
                          return null;
                        }
                        
                        return (
                        <CardActions 
                          sx={{ 
                            px: 2, 
                            py: 1.5, 
                            flexDirection: isMobile ? 'column' : 'row', 
                            gap: 1,
                            borderTop: '1px solid',
                            borderColor: 'divider',
                            bgcolor: 'grey.50',
                          }}
                          onClick={(e) => e.stopPropagation()}
                        >
                          <Button
                            variant="contained"
                              startIcon={<OpenInNewIcon sx={{ fontSize: 16 }} />}
                            onClick={(e) => {
                              e.stopPropagation();
                                handleOpenInBrowser(couponImageUrl, e);
                            }}
                            sx={{
                              bgcolor: 'grey.600',
                              color: 'white',
                                borderRadius: '10px',
                              textTransform: 'none',
                              fontWeight: 600,
                                fontSize: '15px',
                              flex: isMobile ? 1 : 'none',
                              width: isMobile ? '100%' : 'auto',
                              minWidth: isMobile ? 'auto' : 150,
                                px: 2.25, // 18px
                                py: 1.25, // 10px
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
                            onClick={(e) => {
                              e.stopPropagation();
                                handleOpenMobileExportDialog(couponImageUrl, e);
                            }}
                            sx={{
                                background: 'linear-gradient(90deg, #7b8fd1 0%, #b39ddb 100%)',
                              color: 'white',
                                borderRadius: '10px',
                              textTransform: 'none',
                              fontWeight: 600,
                                fontSize: '15px',
                              flex: isMobile ? 1 : 'none',
                              width: isMobile ? '100%' : 'auto',
                              minWidth: isMobile ? 'auto' : 150,
                                px: 2.25, // 18px
                                py: 1.25, // 10px
                                boxShadow: '0px 2px 6px rgba(183, 202, 255, 0.08)',
                              '&:hover': {
                                  background: 'linear-gradient(90deg, #6a7fc0 0%, #a08cc8 100%)',
                                  boxShadow: '0px 4px 8px rgba(183, 202, 255, 0.12)',
                              },
                            }}
                          >
                            모바일로 내보내기
                          </Button>
                        </CardActions>
                        );
                      })()}

                      {/* 선물 확인 링크 */}
                      {gift.gift_url && (
                        <CardActions sx={{ px: 2, py: 1.5 }}>
                          <Button
                            variant="contained"
                            startIcon={<OpenInNewIcon />}
                            onClick={(e) => {
                              e.stopPropagation();
                              window.open(gift.gift_url, '_blank');
                            }}
                            sx={{
                              bgcolor: 'primary.main',
                              color: 'white',
                              borderRadius: 1,
                              textTransform: 'none',
                              fontWeight: 600,
                              width: '100%',
                            }}
                          >
                            선물 확인하기
                          </Button>
                        </CardActions>
                      )}
                    </Card>
                  ))}
                </Box>
              )}
            </>
          )}
        </Paper>

        {/* 선물 상세 다이얼로그 */}
        <Dialog
          open={dialogOpen}
          onClose={handleCloseDialog}
          maxWidth="lg"
          fullWidth
          fullScreen={window.innerWidth < 768} // 모바일에서는 전체 화면
          PaperProps={{
            sx: { 
              borderRadius: 3,
              maxHeight: '90vh', // 최대 높이 제한
            }
          }}
        >
          <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <GiftIcon color="primary" />
              <Typography component="span" sx={{ fontWeight: 600, fontSize: '1.25rem' }}>
                선물 상세
              </Typography>
            </Box>
            <IconButton onClick={handleCloseDialog} size="small">
              <CloseIcon />
            </IconButton>
          </DialogTitle>
          
          <DialogContent sx={{ 
            overflowY: 'auto', // 세로 스크롤 가능
            maxHeight: '70vh', // 최대 높이 제한
            p: 3,
          }}>
            {selectedGift && (
              <Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                  <GiftIcon sx={{ color: 'grey.600', fontSize: 20 }} />
                  <Typography variant="h6" sx={{ fontWeight: 600, flexGrow: 1 }}>
                    받은 선물
                  </Typography>
                  <Chip
                    label={selectedGift.gift_type || '쿠폰'}
                    size="small"
                    sx={{
                      fontSize: 12,
                      fontWeight: 600,
                      bgcolor: 'grey.200',
                      color: 'grey.700',
                    }}
                  />
                </Box>
                
                {/* 선물 내용 */}
                {selectedGift.gift_content && (
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    {selectedGift.gift_content}
                  </Typography>
                )}

                {/* 쿠폰 이미지 - 확대 가능 */}
                {getCouponImageUrl(selectedGift) && (
                  <Box sx={{ mb: 2 }}>
                    <CardMedia
                      component="img"
                      image={getCouponImageUrl(selectedGift)!}
                      alt="쿠폰 이미지"
                      sx={{
                        borderRadius: 1,
                        objectFit: 'contain',
                        bgcolor: 'grey.50',
                        width: '100%',
                        height: 'auto',
                        maxHeight: '500px', // 최대 높이 제한
                        cursor: 'pointer',
                        '&:hover': {
                          transform: 'scale(1.02)',
                          transition: 'transform 0.2s ease-in-out',
                        },
                      }}
                      onClick={() => {
                        // 이미지 클릭 시 새 창에서 확대 보기
                        const imageUrl = getCouponImageUrl(selectedGift);
                        if (imageUrl) {
                          window.open(imageUrl, '_blank');
                        }
                      }}
                    />
                    <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block', textAlign: 'center' }}>
                      이미지를 클릭하면 확대해서 볼 수 있습니다
                    </Typography>
                  </Box>
                )}

                {/* 쿠폰 이미지가 있을 때 브라우저 열기 및 모바일 내보내기 버튼 */}
                {getCouponImageUrl(selectedGift) && (
                  <Box sx={{ mb: 2, display: 'flex', flexDirection: isMobile ? 'column' : 'row', gap: 1 }}>
                    <Button
                      variant="contained"
                      startIcon={<OpenInNewIcon sx={{ fontSize: 16 }} />}
                      onClick={() => {
                        const imageUrl = getCouponImageUrl(selectedGift);
                        if (imageUrl) {
                          handleOpenInBrowser(imageUrl);
                        }
                      }}
                      sx={{
                        bgcolor: 'grey.600',
                        color: 'white',
                        borderRadius: '10px',
                        textTransform: 'none',
                        fontWeight: 600,
                        fontSize: '15px',
                        flex: 1,
                        px: 2.25, // 18px
                        py: 1.25, // 10px
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
                      onClick={() => {
                        const imageUrl = getCouponImageUrl(selectedGift);
                        if (imageUrl) {
                          handleOpenMobileExportDialog(imageUrl);
                        }
                      }}
                      sx={{
                        background: 'linear-gradient(90deg, #7b8fd1 0%, #b39ddb 100%)',
                        color: 'white',
                        borderRadius: '10px',
                        textTransform: 'none',
                        fontWeight: 600,
                        fontSize: '15px',
                        flex: 1,
                        px: 2.25, // 18px
                        py: 1.25, // 10px
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

                {/* 선물 확인 링크 */}
                {selectedGift.gift_url && (
                  <Box sx={{ mb: 2 }}>
                    <Button
                      variant="contained"
                      startIcon={<OpenInNewIcon />}
                      onClick={() => window.open(selectedGift.gift_url, '_blank')}
                      sx={{
                        bgcolor: 'primary.main',
                        color: 'white',
                        borderRadius: 1,
                        textTransform: 'none',
                        fontWeight: 600,
                        width: '100%',
                      }}
                    >
                      선물 확인하기
                    </Button>
                  </Box>
                )}

                {/* 받은 시간 */}
                {selectedGift.received_at && (
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                    <AccessTimeIcon sx={{ fontSize: 12, color: 'grey.500' }} />
                    <Typography variant="caption" color="text.secondary">
                      {selectedGift.received_at}
                    </Typography>
                  </Box>
                )}
              </Box>
            )}
          </DialogContent>
          
          <DialogActions>
            <Button onClick={handleCloseDialog} variant="contained">
              확인
            </Button>
          </DialogActions>
        </Dialog>

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
      </Container>
    </MobileMainLayout>
  );
}