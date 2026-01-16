import { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  ListItemSecondaryAction,
  Switch,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  IconButton,
  Alert,
  Chip,
  useTheme,
  useMediaQuery,
  Paper,
  Grid,
} from '@mui/material';
import {
  AccountCircle as AccountIcon,
  Palette as PaletteIcon,
  Notifications as NotificationsIcon,
  Security as SecurityIcon,
  Info as InfoIcon,
  Close as CloseIcon,
  Description as DescriptionIcon,
  Logout as LogoutIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon,
} from '@mui/icons-material';
import MobileMainLayout from '../components/layout/MobileMainLayout';
import authService from '../services/authService';
import settingsService from '../services/settingsService';
import { useThemeStore, AppThemeMode } from '../store/themeStore';
import { useNavigate } from 'react-router-dom';

// 테마 타입 정의
type ThemeMode = 'light' | 'dark' | 'system';

// 개인정보 동의서 내용
const PRIVACY_CONTENT = {
  title: '개인정보 수집·이용 동의서',
  sections: [
    {
      title: '1. 개인정보 수집 및 이용 목적',
      content: 'ASPN AI Agent 서비스 제공을 위해 필요한 최소한의 개인정보를 수집합니다. 수집된 정보는 서비스 제공, 고객 지원, 서비스 개선 목적으로만 사용됩니다.'
    },
    {
      title: '2. 수집하는 개인정보 항목',
      content: '필수: 사용자 ID, 이메일 주소, 이름\n선택: 프로필 사진, 연락처'
    },
    {
      title: '3. 개인정보 보유 및 이용 기간',
      content: '개인정보는 서비스 이용 기간 동안 보유하며, 회원 탈퇴 시 즉시 삭제됩니다.'
    },
    {
      title: '4. 개인정보 제3자 제공',
      content: '개인정보는 법령에 의해 요구되는 경우를 제외하고는 제3자에게 제공되지 않습니다.'
    },
    {
      title: '5. 개인정보 처리의 위탁',
      content: '개인정보 처리는 회사 내부에서만 수행되며, 외부 위탁은 하지 않습니다.'
    },
    {
      title: '6. 개인정보의 안전성 확보 조치',
      content: '개인정보는 암호화되어 저장되며, 접근 권한이 있는 직원만이 처리할 수 있습니다.'
    }
  ]
};

export default function SettingsPage() {
  const navigate = useNavigate();
  const { themeMode: currentThemeMode, setThemeMode } = useThemeStore();
  const [notifications, setNotifications] = useState(true);
  const [privacyAgreed, setPrivacyAgreed] = useState(false);
  const [privacyDialogOpen, setPrivacyDialogOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [userInfo, setUserInfo] = useState<any>(null);

  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));

  // 테마 모드를 문자열로 변환
  const themeMode = currentThemeMode === AppThemeMode.LIGHT
    ? 'light'
    : currentThemeMode === AppThemeMode.CODING_DARK
      ? 'dark'
      : 'system';

  useEffect(() => {
    loadUserInfo();
    loadPrivacyStatus();
  }, []);

  const loadUserInfo = async () => {
    try {
      const user = authService.getCurrentUser();
      if (user) {
        setUserInfo(user);
      }
    } catch (err) {
      console.error('사용자 정보 로드 실패:', err);
    }
  };

  const loadPrivacyStatus = async () => {
    try {
      const user = authService.getCurrentUser();
      if (!user) return;

      console.log('개인정보 동의 상태 확인:', user.userId);
      const response = await settingsService.checkPrivacyAgreement(user.userId);

      console.log('개인정보 동의 상태 응답:', response);
      setPrivacyAgreed(response.is_agreed === 1);
    } catch (err: any) {
      console.error('개인정보 동의 상태 로드 실패:', err);
      console.error('에러 상세:', err.response?.data);
    }
  };

  const handlePrivacyAgreement = async (isAgreed: boolean) => {
    try {
      setLoading(true);
      setError(null);

      const user = authService.getCurrentUser();
      if (!user) {
        setError('사용자 정보를 찾을 수 없습니다.');
        return;
      }

      console.log('개인정보 동의 상태 업데이트:', { userId: user.userId, isAgreed });
      const response = await settingsService.updatePrivacyAgreement(user.userId, isAgreed);

      console.log('개인정보 동의 상태 업데이트 응답:', response);

      if (response.success) {
        setPrivacyAgreed(isAgreed);
        setPrivacyDialogOpen(false);
        alert(isAgreed ? '개인정보 수집·이용에 동의하셨습니다.' : '개인정보 수집·이용 동의를 철회하셨습니다.');
      } else {
        setError(response.error || '개인정보 동의 상태 업데이트에 실패했습니다.');
      }
    } catch (err: any) {
      console.error('개인정보 동의 상태 업데이트 실패:', err);
      setError(err.response?.data?.message || err.message || '개인정보 동의 상태 업데이트 중 오류가 발생했습니다.');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    if (window.confirm('로그아웃 하시겠습니까?')) {
      authService.logout();
      window.location.href = '/login';
    }
  };

  const handleThemeChange = (newTheme: ThemeMode) => {
    // 문자열을 AppThemeMode로 변환
    const appThemeMode = newTheme === 'light'
      ? AppThemeMode.LIGHT
      : newTheme === 'dark'
        ? AppThemeMode.CODING_DARK
        : AppThemeMode.SYSTEM;

    setThemeMode(appThemeMode);
    settingsService.updateThemeSettings(newTheme);
    console.log('테마 변경:', newTheme);
  };

  const handleNotificationChange = (enabled: boolean) => {
    setNotifications(enabled);
    // TODO: 실제 알림 설정 로직 구현
    console.log('알림 설정 변경:', enabled);
  };

  const PrivacySection = ({ title, content }: { title: string; content: string }) => (
    <Box sx={{ mb: 3 }}>
      <Typography variant="h6" sx={{ fontWeight: 'bold', mb: 1, color: '#1F2937' }}>
        {title}
      </Typography>
      <Typography variant="body2" sx={{ color: '#4B5563', lineHeight: 1.6 }}>
        {content}
      </Typography>
    </Box>
  );

  return (
    <MobileMainLayout
      hideAppBar={false}
      hideSidebarOnDesktop={true}
      title="환경 설정"
      showBackButton={true}
      onBackClick={() => navigate('/chat')}
    >
      <Box sx={{ height: '100vh', overflow: 'auto', p: { xs: 2, md: 3 } }}>
        {/* 헤더 */}
        <Box sx={{ mb: 3 }}>
          <Typography variant="body1" color="text.secondary">
            계정 정보와 앱 설정을 관리하세요
          </Typography>
        </Box>

        {error && (
          <Alert severity="error" sx={{ mb: 3 }}>
            {error}
          </Alert>
        )}

        {/* 내 계정정보 섹션 */}
        <Card sx={{ mb: 3 }}>
          <CardContent>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
              <AccountIcon sx={{ color: 'primary.main', mr: 1 }} />
              <Typography variant="h6" sx={{ fontWeight: 600 }}>
                내 계정정보
              </Typography>
            </Box>

            {userInfo && (
              <Box sx={{ mb: 2 }}>
                <Grid container spacing={2}>
                  <Grid size={{ xs: 12, sm: 6 }}>
                    <Box sx={{ p: 2, bgcolor: 'grey.50', borderRadius: 2 }}>
                      <Typography variant="body2" color="text.secondary" gutterBottom>
                        사용자 ID
                      </Typography>
                      <Typography variant="body1" sx={{ fontWeight: 600 }}>
                        {userInfo.userId}
                      </Typography>
                    </Box>
                  </Grid>
                  <Grid size={{ xs: 12, sm: 6 }}>
                    <Box sx={{ p: 2, bgcolor: 'grey.50', borderRadius: 2 }}>
                      <Typography variant="body2" color="text.secondary" gutterBottom>
                        이름
                      </Typography>
                      <Typography variant="body1" sx={{ fontWeight: 600 }}>
                        {userInfo.name || '정보 없음'}
                      </Typography>
                    </Box>
                  </Grid>
                </Grid>
              </Box>
            )}

            {/* 계정 정보 안내 메시지 */}
            <Alert severity="info" sx={{ mb: 2 }}>
              현재 로그인된 계정 정보입니다. 계정 변경은 로그아웃 후 다시 로그인하세요.
            </Alert>

            {/* 로그아웃 버튼 */}
            <Button
              variant="outlined"
              color="error"
              startIcon={<LogoutIcon />}
              onClick={handleLogout}
              fullWidth
              sx={{ mt: 1 }}
            >
              로그아웃
            </Button>
          </CardContent>
        </Card>

        {/* 테마 설정 섹션 */}
        <Card sx={{ mb: 3 }}>
          <CardContent>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
              <PaletteIcon sx={{ color: 'primary.main', mr: 1 }} />
              <Typography variant="h6" sx={{ fontWeight: 600 }}>
                테마 설정
              </Typography>
            </Box>

            <Grid container spacing={2}>
              {[
                { value: 'light', label: '라이트', color: '#FFFFFF' },
                { value: 'dark', label: '다크', color: '#1F2937' },
                { value: 'system', label: '시스템', color: '#6B7280' },
              ].map((theme) => (
                <Grid size={4} key={theme.value}>
                  <Paper
                    sx={{
                      p: 2,
                      textAlign: 'center',
                      cursor: 'pointer',
                      border: themeMode === theme.value ? 2 : 1,
                      borderColor: themeMode === theme.value ? 'primary.main' : 'grey.300',
                      bgcolor: theme.color,
                      color: theme.value === 'light' ? 'text.primary' : 'white',
                    }}
                    onClick={() => handleThemeChange(theme.value as ThemeMode)}
                  >
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                      {theme.label}
                    </Typography>
                  </Paper>
                </Grid>
              ))}
            </Grid>
          </CardContent>
        </Card>

        {/* 알림 설정 섹션 */}
        <Card sx={{ mb: 3 }}>
          <CardContent>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
              <NotificationsIcon sx={{ color: 'primary.main', mr: 1 }} />
              <Typography variant="h6" sx={{ fontWeight: 600 }}>
                알림 설정
              </Typography>
            </Box>

            <List>
              <ListItem>
                <ListItemIcon>
                  <NotificationsIcon />
                </ListItemIcon>
                <ListItemText
                  primary="푸시 알림"
                  secondary="새로운 메시지와 알림을 받습니다"
                />
                <ListItemSecondaryAction>
                  <Switch
                    checked={notifications}
                    onChange={(e) => handleNotificationChange(e.target.checked)}
                  />
                </ListItemSecondaryAction>
              </ListItem>
            </List>
          </CardContent>
        </Card>

        {/* 개인정보 설정 섹션 */}
        <Card sx={{ mb: 3 }}>
          <CardContent>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
              <SecurityIcon sx={{ color: 'primary.main', mr: 1 }} />
              <Typography variant="h6" sx={{ fontWeight: 600 }}>
                개인정보 설정
              </Typography>
            </Box>

            <Box sx={{ mb: 2 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                <Typography variant="body1" sx={{ mr: 1 }}>
                  개인정보 수집·이용 동의
                </Typography>
                <Chip
                  icon={privacyAgreed ? <CheckCircleIcon /> : <CancelIcon />}
                  label={privacyAgreed ? '동의함' : '동의 안함'}
                  color={privacyAgreed ? 'success' : 'error'}
                  size="small"
                />
              </Box>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                서비스 이용을 위해 개인정보 수집·이용에 동의가 필요합니다.
              </Typography>
            </Box>

            <Button
              variant="outlined"
              startIcon={<DescriptionIcon />}
              onClick={() => setPrivacyDialogOpen(true)}
              fullWidth
              sx={{ mb: 2 }}
            >
              개인정보 수집·이용 동의서 보기
            </Button>

            <Alert severity="info">
              개인정보는 서비스 제공을 위해 필요한 최소한의 정보만 수집하며, 안전하게 보호됩니다.
            </Alert>
          </CardContent>
        </Card>

        {/* 앱 정보 섹션 */}
        <Card>
          <CardContent>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
              <InfoIcon sx={{ color: 'primary.main', mr: 1 }} />
              <Typography variant="h6" sx={{ fontWeight: 600 }}>
                앱 정보
              </Typography>
            </Box>

            <List>
              <ListItem>
                <ListItemText
                  primary="버전"
                  secondary="1.0.0"
                />
              </ListItem>
              <ListItem>
                <ListItemText
                  primary="빌드 번호"
                  secondary="20241021"
                />
              </ListItem>
              <ListItem>
                <ListItemText
                  primary="개발사"
                  secondary="ASPN"
                />
              </ListItem>
            </List>
          </CardContent>
        </Card>

        {/* 개인정보 동의서 다이얼로그 */}
        <Dialog
          open={privacyDialogOpen}
          onClose={() => setPrivacyDialogOpen(false)}
          maxWidth="md"
          fullWidth
          fullScreen={isMobile}
        >
          <DialogTitle sx={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            background: 'linear-gradient(135deg, #4A90E2 0%, #7BB3F0 100%)',
            color: 'white',
            borderRadius: '20px 20px 0 0',
          }}>
            <Box sx={{ display: 'flex', alignItems: 'center' }}>
              <SecurityIcon sx={{ mr: 1 }} />
              <Typography component="span" sx={{ fontWeight: 'bold', fontSize: '1.25rem' }}>
                개인정보 수집·이용 동의서
              </Typography>
            </Box>
            <IconButton onClick={() => setPrivacyDialogOpen(false)} sx={{ color: 'white' }}>
              <CloseIcon />
            </IconButton>
          </DialogTitle>

          <DialogContent dividers sx={{ p: 3 }}>
            {PRIVACY_CONTENT.sections.map((section, index) => (
              <PrivacySection
                key={index}
                title={section.title}
                content={section.content}
              />
            ))}
          </DialogContent>

          <DialogActions sx={{ p: 3, gap: 1 }}>
            <Button
              onClick={() => handlePrivacyAgreement(true)}
              variant="contained"
              color="primary"
              disabled={loading}
              startIcon={<CheckCircleIcon />}
            >
              동의함
            </Button>
          </DialogActions>
        </Dialog>
      </Box>
    </MobileMainLayout>
  );
}