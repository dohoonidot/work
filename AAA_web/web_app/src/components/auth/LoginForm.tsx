import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  TextField,
  Button,
  Box,
  Alert,
  CircularProgress,
  InputAdornment,
  IconButton
} from '@mui/material';
import { Person, Lock, Visibility, VisibilityOff } from '@mui/icons-material';
import authService from '../../services/authService';
import PasswordChangeDialog from './PasswordChangeDialog';

interface LoginFormProps {
  onLoginSuccess: () => void;
}

export default function LoginForm({ onLoginSuccess }: LoginFormProps) {
  const navigate = useNavigate();
  const [userId, setUserId] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [passwordChangeDialogOpen, setPasswordChangeDialogOpen] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const response = await authService.login({ user_id: userId, password });

      // 디버깅: 로그인 응답 확인
      console.log('🔐 [LoginForm] 로그인 응답:', response);
      console.log('🔐 [LoginForm] is_approver:', response.is_approver);

      if (response.status_code === 200) {
        // 개인정보 동의 여부 확인
        if (response.is_agreed === 0) {
          // TODO: 개인정보 동의 팝업 표시
          console.log('개인정보 동의 필요');
        }

        // SPA 방식으로 이동 (로그 유지됨)
        navigate('/chat');
      } else {
        setError('로그인에 실패했습니다.');
      }
    } catch (err: any) {
      setError(err.response?.data?.message || '로그인에 실패했습니다.');
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !loading) {
      handleSubmit(e as any);
    }
  };

  return (
    <Box
      component="form"
      onSubmit={handleSubmit}
      sx={{
        display: 'flex',
        flexDirection: 'column',
        gap: 3,
        width: '100%',
      }}
    >
      {error && (
        <Alert
          severity="error"
          sx={{
            borderRadius: 2,
            fontSize: '0.875rem',
          }}
        >
          {error}
        </Alert>
      )}

      <TextField
        label="아이디"
        value={userId}
        onChange={(e) => setUserId(e.target.value)}
        required
        fullWidth
        autoFocus
        disabled={loading}
        onKeyPress={handleKeyPress}
        InputProps={{
          startAdornment: (
            <InputAdornment position="start">
              <Person color="action" />
            </InputAdornment>
          ),
        }}
        sx={{
          '& .MuiOutlinedInput-root': {
            fontSize: { xs: '16px', sm: '14px' }, // 모바일에서 줌 방지
          },
        }}
      />

      <TextField
        label="비밀번호"
        type={showPassword ? 'text' : 'password'}
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        required
        fullWidth
        disabled={loading}
        onKeyPress={handleKeyPress}
        InputProps={{
          startAdornment: (
            <InputAdornment position="start">
              <Lock color="action" />
            </InputAdornment>
          ),
          endAdornment: (
            <InputAdornment position="end">
              <IconButton
                onClick={() => setShowPassword(!showPassword)}
                edge="end"
                disabled={loading}
              >
                {showPassword ? <VisibilityOff /> : <Visibility />}
              </IconButton>
            </InputAdornment>
          ),
        }}
        sx={{
          '& .MuiOutlinedInput-root': {
            fontSize: { xs: '16px', sm: '14px' }, // 모바일에서 줌 방지
          },
        }}
      />

      <Button
        type="submit"
        variant="contained"
        size="large"
        fullWidth
        disabled={loading || !userId.trim() || !password.trim()}
        sx={{
          mt: 1,
          minHeight: 48,
          fontSize: '1rem',
          fontWeight: 600,
          background: 'linear-gradient(135deg, #1D4487 0%, #1976d2 100%)',
          '&:hover': {
            background: 'linear-gradient(135deg, #1976d2 0%, #1D4487 100%)',
          },
          '&:disabled': {
            background: '#e0e0e0',
            color: '#9e9e9e',
          },
        }}
      >
        {loading ? (
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <CircularProgress size={20} color="inherit" />
            로그인 중...
          </Box>
        ) : (
          '로그인'
        )}
      </Button>

      <Button
        variant="text"
        size="small"
        onClick={() => setPasswordChangeDialogOpen(true)}
        sx={{
          alignSelf: 'center',
          fontSize: '0.75rem',
          color: 'text.secondary',
          textTransform: 'none',
        }}
      >
        비밀번호 변경
      </Button>

      {/* Password Change Dialog */}
      <PasswordChangeDialog
        open={passwordChangeDialogOpen}
        onClose={() => setPasswordChangeDialogOpen(false)}
      />
    </Box>
  );
}
