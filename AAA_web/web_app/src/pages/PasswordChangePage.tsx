import { useState } from 'react';
import {
  Box,
  Paper,
  Typography,
  TextField,
  Button,
  Alert,
  CircularProgress,
  IconButton,
  InputAdornment,
} from '@mui/material';
import {
  Visibility as VisibilityIcon,
  VisibilityOff as VisibilityOffIcon,
  LockReset as LockResetIcon,
  ArrowBack as ArrowBackIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useThemeStore } from '../store/themeStore';
import { API_BASE_URL } from '../utils/apiConfig';
import authService from '../services/authService';

export default function PasswordChangePage() {
  const { colorScheme } = useThemeStore();
  const navigate = useNavigate();

  const [formData, setFormData] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });

  const [showPassword, setShowPassword] = useState({
    current: false,
    new: false,
    confirm: false,
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  // 유효성 검사
  const validateForm = (): string | null => {
    if (!formData.currentPassword) {
      return '현재 비밀번호를 입력해주세요.';
    }

    if (!formData.newPassword) {
      return '새 비밀번호를 입력해주세요.';
    }

    if (formData.newPassword.length < 8) {
      return '새 비밀번호는 최소 8자 이상이어야 합니다.';
    }

    if (formData.newPassword === formData.currentPassword) {
      return '새 비밀번호는 현재 비밀번호와 달라야 합니다.';
    }

    if (formData.newPassword !== formData.confirmPassword) {
      return '새 비밀번호가 일치하지 않습니다.';
    }

    // 비밀번호 강도 검사
    const hasUpperCase = /[A-Z]/.test(formData.newPassword);
    const hasLowerCase = /[a-z]/.test(formData.newPassword);
    const hasNumber = /[0-9]/.test(formData.newPassword);
    const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(formData.newPassword);

    const strength = [hasUpperCase, hasLowerCase, hasNumber, hasSpecialChar].filter(
      Boolean
    ).length;

    if (strength < 3) {
      return '새 비밀번호는 대문자, 소문자, 숫자, 특수문자 중 최소 3가지를 포함해야 합니다.';
    }

    return null;
  };

  // 비밀번호 변경 처리
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess(false);

    // 유효성 검사
    const validationError = validateForm();
    if (validationError) {
      setError(validationError);
      return;
    }

    setLoading(true);

    try {
      const currentUser = authService.getCurrentUser();
      if (!currentUser) {
        setError('로그인 정보가 없습니다. 다시 로그인해주세요.');
        setTimeout(() => {
          navigate('/login');
        }, 2000);
        return;
      }

      // API 호출 (쿠키 기반 인증 사용)
      const response = await fetch(`${API_BASE_URL}/api/changePassword`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include', // 쿠키 포함
        body: JSON.stringify({
          userId: currentUser.userId,
          currentPassword: formData.currentPassword,
          newPassword: formData.newPassword,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || '비밀번호 변경에 실패했습니다.');
      }

      setSuccess(true);

      // 2초 후 로그인 페이지로 이동
      setTimeout(() => {
        authService.logout();
        navigate('/login');
      }, 2000);
    } catch (err: any) {
      console.error('Password change error:', err);
      setError(err.message || '비밀번호 변경 중 오류가 발생했습니다.');
    } finally {
      setLoading(false);
    }
  };

  // 비밀번호 강도 계산
  const calculatePasswordStrength = (): {
    level: number;
    color: string;
    label: string;
  } => {
    if (!formData.newPassword) {
      return { level: 0, color: '#E5E7EB', label: '' };
    }

    const hasUpperCase = /[A-Z]/.test(formData.newPassword);
    const hasLowerCase = /[a-z]/.test(formData.newPassword);
    const hasNumber = /[0-9]/.test(formData.newPassword);
    const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(formData.newPassword);
    const isLongEnough = formData.newPassword.length >= 8;

    let level = 0;
    if (isLongEnough) level++;
    if (hasUpperCase) level++;
    if (hasLowerCase) level++;
    if (hasNumber) level++;
    if (hasSpecialChar) level++;

    if (level <= 2) {
      return { level: 1, color: '#DC2626', label: '약함' };
    } else if (level === 3) {
      return { level: 2, color: '#F59E0B', label: '보통' };
    } else if (level === 4) {
      return { level: 3, color: '#10B981', label: '강함' };
    } else {
      return { level: 4, color: '#059669', label: '매우 강함' };
    }
  };

  const passwordStrength = calculatePasswordStrength();

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'background.default',
        p: 2,
      }}
    >
      <Paper
        elevation={4}
        sx={{
          p: 4,
          maxWidth: 500,
          width: '100%',
          borderRadius: 3,
        }}
      >
        {/* 헤더 */}
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
          <IconButton onClick={() => navigate(-1)} sx={{ mr: 1 }}>
            <ArrowBackIcon />
          </IconButton>

          <Box sx={{ flex: 1, textAlign: 'center' }}>
            <LockResetIcon
              sx={{
                fontSize: 48,
                color: colorScheme.primaryColor,
                mb: 1,
              }}
            />
            <Typography variant="h5" sx={{ fontWeight: 600, mb: 0.5 }}>
              비밀번호 변경
            </Typography>
            <Typography variant="body2" color="text.secondary">
              새로운 비밀번호를 설정해주세요
            </Typography>
          </Box>
        </Box>

        {/* 에러/성공 메시지 */}
        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        {success && (
          <Alert severity="success" sx={{ mb: 2 }}>
            비밀번호가 성공적으로 변경되었습니다. 로그인 페이지로 이동합니다...
          </Alert>
        )}

        {/* 폼 */}
        <form onSubmit={handleSubmit}>
          {/* 현재 비밀번호 */}
          <TextField
            fullWidth
            type={showPassword.current ? 'text' : 'password'}
            label="현재 비밀번호"
            value={formData.currentPassword}
            onChange={(e) =>
              setFormData({ ...formData, currentPassword: e.target.value })
            }
            disabled={loading || success}
            sx={{ mb: 2 }}
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  <IconButton
                    onClick={() =>
                      setShowPassword({ ...showPassword, current: !showPassword.current })
                    }
                    edge="end"
                  >
                    {showPassword.current ? <VisibilityOffIcon /> : <VisibilityIcon />}
                  </IconButton>
                </InputAdornment>
              ),
            }}
          />

          {/* 새 비밀번호 */}
          <TextField
            fullWidth
            type={showPassword.new ? 'text' : 'password'}
            label="새 비밀번호"
            value={formData.newPassword}
            onChange={(e) =>
              setFormData({ ...formData, newPassword: e.target.value })
            }
            disabled={loading || success}
            helperText="최소 8자, 대문자, 소문자, 숫자, 특수문자 중 3가지 이상 포함"
            sx={{ mb: 1 }}
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  <IconButton
                    onClick={() =>
                      setShowPassword({ ...showPassword, new: !showPassword.new })
                    }
                    edge="end"
                  >
                    {showPassword.new ? <VisibilityOffIcon /> : <VisibilityIcon />}
                  </IconButton>
                </InputAdornment>
              ),
            }}
          />

          {/* 비밀번호 강도 표시 */}
          {formData.newPassword && (
            <Box sx={{ mb: 2 }}>
              <Box
                sx={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 0.5,
                  mb: 0.5,
                }}
              >
                <Typography variant="caption" color="text.secondary">
                  비밀번호 강도:
                </Typography>
                <Typography
                  variant="caption"
                  sx={{
                    fontWeight: 600,
                    color: passwordStrength.color,
                  }}
                >
                  {passwordStrength.label}
                </Typography>
              </Box>

              <Box
                sx={{
                  height: 4,
                  bgcolor: '#E5E7EB',
                  borderRadius: 2,
                  overflow: 'hidden',
                }}
              >
                <Box
                  sx={{
                    height: '100%',
                    width: `${(passwordStrength.level / 4) * 100}%`,
                    bgcolor: passwordStrength.color,
                    transition: 'all 0.3s',
                  }}
                />
              </Box>
            </Box>
          )}

          {/* 새 비밀번호 확인 */}
          <TextField
            fullWidth
            type={showPassword.confirm ? 'text' : 'password'}
            label="새 비밀번호 확인"
            value={formData.confirmPassword}
            onChange={(e) =>
              setFormData({ ...formData, confirmPassword: e.target.value })
            }
            disabled={loading || success}
            error={
              formData.confirmPassword !== '' &&
              formData.newPassword !== formData.confirmPassword
            }
            helperText={
              formData.confirmPassword !== '' &&
                formData.newPassword !== formData.confirmPassword
                ? '비밀번호가 일치하지 않습니다'
                : ''
            }
            sx={{ mb: 3 }}
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  <IconButton
                    onClick={() =>
                      setShowPassword({ ...showPassword, confirm: !showPassword.confirm })
                    }
                    edge="end"
                  >
                    {showPassword.confirm ? <VisibilityOffIcon /> : <VisibilityIcon />}
                  </IconButton>
                </InputAdornment>
              ),
            }}
          />

          {/* 버튼 */}
          <Button
            type="submit"
            fullWidth
            variant="contained"
            size="large"
            disabled={loading || success}
            sx={{
              bgcolor: colorScheme.primaryColor,
              py: 1.5,
              fontWeight: 600,
              fontSize: '1rem',
              '&:hover': {
                bgcolor: colorScheme.primaryColor,
                opacity: 0.9,
              },
            }}
          >
            {loading ? (
              <CircularProgress size={24} sx={{ color: 'white' }} />
            ) : success ? (
              '변경 완료'
            ) : (
              '비밀번호 변경'
            )}
          </Button>
        </form>

        {/* 안내 */}
        <Box sx={{ mt: 3, p: 2, bgcolor: 'action.hover', borderRadius: 2 }}>
          <Typography variant="caption" sx={{ display: 'block', mb: 0.5, fontWeight: 600 }}>
            💡 안전한 비밀번호 만들기
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
            • 최소 8자 이상
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
            • 대문자, 소문자, 숫자, 특수문자 조합
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
            • 추측하기 어려운 문자열 사용
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
            • 다른 사이트와 동일한 비밀번호 사용 금지
          </Typography>
        </Box>
      </Paper>
    </Box>
  );
}
