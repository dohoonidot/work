import { useState } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Button,
  IconButton,
  Alert,
  CircularProgress,
  InputAdornment,
  Box,
  Typography,
  useTheme,
  useMediaQuery,
} from '@mui/material';
import {
  Close as CloseIcon,
  Lock as LockIcon,
  Person as PersonIcon,
  Visibility,
  VisibilityOff,
  LockOpen as LockOpenIcon,
} from '@mui/icons-material';
import { API_BASE_URL } from '../../utils/apiConfig';

interface PasswordChangeDialogProps {
  open: boolean;
  onClose: () => void;
}

export default function PasswordChangeDialog({ open, onClose }: PasswordChangeDialogProps) {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));

  // Form state
  const [userId, setUserId] = useState('');
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  // Visibility state
  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  // UI state
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  // Validation
  const validateForm = (): string | null => {
    if (!userId.trim()) {
      return '이메일을 입력해 주세요.';
    }
    if (!userId.includes('@')) {
      return '유효한 이메일 형식이 아닙니다.';
    }
    if (!currentPassword) {
      return '현재 비밀번호를 입력해 주세요.';
    }
    if (!newPassword) {
      return '새 비밀번호를 입력해 주세요.';
    }
    if (!confirmPassword) {
      return '새 비밀번호를 다시 입력해 주세요.';
    }
    if (newPassword !== confirmPassword) {
      return '새 비밀번호가 일치하지 않습니다.';
    }
    return null;
  };

  // Handle password change
  const handleChangePassword = async () => {
    // Validate
    const validationError = validateForm();
    if (validationError) {
      setError(validationError);
      return;
    }

    setError(null);
    setIsLoading(true);

    try {
      const response = await fetch(`${API_BASE_URL}/updatePassword`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          user_id: userId.trim(),
          password: currentPassword,
          new_password: newPassword,
        }),
      });

      const data = await response.json();

      if (response.ok && data.status_code === 200) {
        // Success
        setSuccess(true);
        setError(null);

        // Close dialog after 2 seconds
        setTimeout(() => {
          handleClose();
        }, 2000);
      } else {
        // Failure
        setError('비밀번호 변경에 실패했습니다. 입력한 정보를 확인해주세요.');
      }
    } catch (err) {
      console.error('Password change error:', err);
      setError('서버 연결에 문제가 발생했습니다. 나중에 다시 시도해주세요.');
    } finally {
      setIsLoading(false);
    }
  };

  // Handle close
  const handleClose = () => {
    if (isLoading) return; // Prevent closing during loading

    // Reset form
    setUserId('');
    setCurrentPassword('');
    setNewPassword('');
    setConfirmPassword('');
    setShowCurrentPassword(false);
    setShowNewPassword(false);
    setShowConfirmPassword(false);
    setError(null);
    setSuccess(false);
    setIsLoading(false);

    onClose();
  };

  return (
    <Dialog
      open={open}
      onClose={handleClose}
      fullScreen={isMobile}
      maxWidth="sm"
      fullWidth
      PaperProps={{
        sx: {
          borderRadius: isMobile ? 0 : 2,
        },
      }}
    >
      {/* Header */}
      <DialogTitle
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          bgcolor: 'linear-gradient(135deg, #1D4487 0%, #1976d2 100%)',
          background: 'linear-gradient(135deg, #1D4487 0%, #1976d2 100%)',
          color: 'white',
          py: 2,
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <LockIcon />
          <Typography variant="h6" sx={{ fontWeight: 600 }}>
            비밀번호 변경
          </Typography>
        </Box>

        <IconButton
          onClick={handleClose}
          disabled={isLoading}
          sx={{
            color: 'white',
            '&:hover': {
              bgcolor: 'rgba(255,255,255,0.1)',
            },
          }}
        >
          <CloseIcon />
        </IconButton>
      </DialogTitle>

      {/* Content */}
      <DialogContent sx={{ pt: 5, pb: 2, px: { xs: 2, sm: 3 } }}>
        {/* Success Alert */}
        {success && (
          <Alert severity="success" sx={{ mb: 3 }}>
            비밀번호가 성공적으로 변경되었습니다.
          </Alert>
        )}

        {/* Error Alert */}
        {error && (
          <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>
            {error}
          </Alert>
        )}

        {/* Email Field */}
        <TextField
          fullWidth
          label="이메일(아이디)"
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
          disabled={isLoading || success}
          autoFocus
          sx={{
            mt: 2,
            mb: 3,
            '& .MuiOutlinedInput-root': {
              borderRadius: '12px',
            },
          }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <PersonIcon sx={{ color: 'text.secondary' }} />
              </InputAdornment>
            ),
            sx: {
              fontSize: { xs: '16px', sm: '14px' }, // iOS zoom prevention
            },
          }}
        />

        {/* Current Password Field */}
        <TextField
          fullWidth
          label="현재 비밀번호"
          type={showCurrentPassword ? 'text' : 'password'}
          value={currentPassword}
          onChange={(e) => setCurrentPassword(e.target.value)}
          disabled={isLoading || success}
          sx={{
            mb: 3,
            '& .MuiOutlinedInput-root': {
              borderRadius: '12px',
            },
          }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <LockIcon sx={{ color: 'text.secondary' }} />
              </InputAdornment>
            ),
            endAdornment: (
              <InputAdornment position="end">
                <IconButton
                  onClick={() => setShowCurrentPassword(!showCurrentPassword)}
                  edge="end"
                  disabled={isLoading || success}
                >
                  {showCurrentPassword ? <VisibilityOff /> : <Visibility />}
                </IconButton>
              </InputAdornment>
            ),
            sx: {
              fontSize: { xs: '16px', sm: '14px' },
            },
          }}
        />

        {/* New Password Field */}
        <TextField
          fullWidth
          label="새 비밀번호"
          type={showNewPassword ? 'text' : 'password'}
          value={newPassword}
          onChange={(e) => setNewPassword(e.target.value)}
          disabled={isLoading || success}
          sx={{
            mb: 3,
            '& .MuiOutlinedInput-root': {
              borderRadius: '12px',
            },
          }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <LockOpenIcon sx={{ color: 'text.secondary' }} />
              </InputAdornment>
            ),
            endAdornment: (
              <InputAdornment position="end">
                <IconButton
                  onClick={() => setShowNewPassword(!showNewPassword)}
                  edge="end"
                  disabled={isLoading || success}
                >
                  {showNewPassword ? <VisibilityOff /> : <Visibility />}
                </IconButton>
              </InputAdornment>
            ),
            sx: {
              fontSize: { xs: '16px', sm: '14px' },
            },
          }}
        />

        {/* Confirm Password Field */}
        <TextField
          fullWidth
          label="새 비밀번호 확인"
          type={showConfirmPassword ? 'text' : 'password'}
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          disabled={isLoading || success}
          sx={{
            '& .MuiOutlinedInput-root': {
              borderRadius: '12px',
            },
          }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <LockOpenIcon sx={{ color: 'text.secondary' }} />
              </InputAdornment>
            ),
            endAdornment: (
              <InputAdornment position="end">
                <IconButton
                  onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                  edge="end"
                  disabled={isLoading || success}
                >
                  {showConfirmPassword ? <VisibilityOff /> : <Visibility />}
                </IconButton>
              </InputAdornment>
            ),
            sx: {
              fontSize: { xs: '16px', sm: '14px' },
            },
          }}
        />
      </DialogContent>

      {/* Actions */}
      <DialogActions sx={{ p: 3, gap: 1 }}>
        <Button
          onClick={handleClose}
          variant="outlined"
          disabled={isLoading}
          sx={{
            borderRadius: '12px',
            textTransform: 'none',
            fontWeight: 600,
          }}
        >
          취소
        </Button>
        <Button
          onClick={handleChangePassword}
          variant="contained"
          disabled={isLoading || success}
          sx={{
            borderRadius: '12px',
            textTransform: 'none',
            fontWeight: 600,
            background: 'linear-gradient(135deg, #1D4487 0%, #1976d2 100%)',
            '&:hover': {
              background: 'linear-gradient(135deg, #153668 0%, #1565c0 100%)',
            },
            minWidth: 120,
          }}
        >
          {isLoading ? (
            <>
              <CircularProgress size={20} sx={{ mr: 1, color: 'white' }} />
              처리 중...
            </>
          ) : (
            '비밀번호 변경'
          )}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
