import React from 'react';
import {
  Box,
  Paper,
  Typography,
  IconButton,
  useMediaQuery,
  useTheme,
  SwipeableDrawer,
  Drawer,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Divider,
} from '@mui/material';
import {
  Menu as MenuIcon,
  Close as CloseIcon,
} from '@mui/icons-material';
import { useIsMobile, useIsTouchDevice, useKeyboardHeight, useSwipeGesture } from '../hooks/useMobile';

interface MobileDrawerProps {
  open: boolean;
  onClose: () => void;
  children: React.ReactNode;
  title?: string;
}

/**
 * 모바일 최적화된 드로어 컴포넌트
 */
export const MobileDrawer: React.FC<MobileDrawerProps> = ({
  open,
  onClose,
  children,
  title,
}) => {
  const isMobile = useIsMobile();

  if (isMobile) {
    return (
      <SwipeableDrawer
        anchor="right"
        open={open}
        onClose={onClose}
        onOpen={() => {}}
        ModalProps={{
          keepMounted: true,
        }}
        sx={{
          '& .MuiDrawer-paper': {
            width: '100%',
            maxWidth: 400,
          },
        }}
      >
        <Box sx={{ p: 2 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
            {title && (
              <Typography variant="h6" sx={{ fontWeight: 600 }}>
                {title}
              </Typography>
            )}
            <IconButton onClick={onClose}>
              <CloseIcon />
            </IconButton>
          </Box>
          <Divider sx={{ mb: 2 }} />
          {children}
        </Box>
      </SwipeableDrawer>
    );
  }

  return (
    <Drawer
      anchor="right"
      open={open}
      onClose={onClose}
      sx={{
        '& .MuiDrawer-paper': {
          width: 400,
        },
      }}
    >
      <Box sx={{ p: 2 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
          {title && (
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              {title}
            </Typography>
          )}
          <IconButton onClick={onClose}>
            <CloseIcon />
          </IconButton>
        </Box>
        <Divider sx={{ mb: 2 }} />
        {children}
      </Box>
    </Drawer>
  );
};

/**
 * 모바일 최적화된 카드 컴포넌트
 */
interface MobileCardProps {
  children: React.ReactNode;
  onClick?: () => void;
  elevation?: number;
  sx?: any;
}

export const MobileCard: React.FC<MobileCardProps> = ({
  children,
  onClick,
  elevation = 1,
  sx = {},
}) => {
  const isMobile = useIsMobile();

  return (
    <Paper
      elevation={elevation}
      onClick={onClick}
      sx={{
        borderRadius: isMobile ? 2 : 1,
        cursor: onClick ? 'pointer' : 'default',
        transition: 'all 0.2s ease-in-out',
        '&:hover': onClick ? {
          elevation: elevation + 2,
          transform: 'translateY(-2px)',
        } : {},
        ...sx,
      }}
    >
      {children}
    </Paper>
  );
};

/**
 * 모바일 최적화된 버튼 컴포넌트
 */
interface MobileButtonProps {
  children: React.ReactNode;
  onClick?: () => void;
  variant?: 'contained' | 'outlined' | 'text';
  color?: 'primary' | 'secondary' | 'error' | 'warning' | 'info' | 'success';
  size?: 'small' | 'medium' | 'large';
  fullWidth?: boolean;
  disabled?: boolean;
  startIcon?: React.ReactNode;
  endIcon?: React.ReactNode;
  sx?: any;
}

export const MobileButton: React.FC<MobileButtonProps> = ({
  children,
  onClick,
  variant = 'contained',
  color = 'primary',
  size = 'medium',
  fullWidth = false,
  disabled = false,
  startIcon,
  endIcon,
  sx = {},
}) => {
  const isMobile = useIsMobile();

  return (
    <Box
      component="button"
      onClick={onClick}
      disabled={disabled}
      sx={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 1,
        width: fullWidth ? '100%' : 'auto',
        minHeight: isMobile ? 44 : 36,
        minWidth: isMobile ? 44 : 'auto',
        padding: isMobile ? '12px 24px' : '8px 16px',
        border: variant === 'outlined' ? '1px solid' : 'none',
        borderRadius: 2,
        fontSize: isMobile ? '16px' : '14px',
        fontWeight: 600,
        cursor: disabled ? 'not-allowed' : 'pointer',
        transition: 'all 0.2s ease-in-out',
        opacity: disabled ? 0.6 : 1,
        backgroundColor: variant === 'contained' ? `${color}.main` : 'transparent',
        color: variant === 'contained' ? 'white' : `${color}.main`,
        borderColor: variant === 'outlined' ? `${color}.main` : 'transparent',
        '&:hover': !disabled ? {
          backgroundColor: variant === 'contained' ? `${color}.dark` : `${color}.light`,
          transform: 'translateY(-1px)',
        } : {},
        '&:active': !disabled ? {
          transform: 'translateY(0)',
        } : {},
        ...sx,
      }}
    >
      {startIcon}
      {children}
      {endIcon}
    </Box>
  );
};

/**
 * 모바일 최적화된 입력 필드 컴포넌트
 */
interface MobileInputProps {
  label?: string;
  placeholder?: string;
  value: string;
  onChange: (value: string) => void;
  type?: 'text' | 'email' | 'password' | 'number' | 'tel';
  multiline?: boolean;
  rows?: number;
  disabled?: boolean;
  error?: boolean;
  helperText?: string;
  startIcon?: React.ReactNode;
  endIcon?: React.ReactNode;
  sx?: any;
}

export const MobileInput: React.FC<MobileInputProps> = ({
  label,
  placeholder,
  value,
  onChange,
  type = 'text',
  multiline = false,
  rows = 1,
  disabled = false,
  error = false,
  helperText,
  startIcon,
  endIcon,
  sx = {},
}) => {
  const isMobile = useIsMobile();

  return (
    <Box sx={{ width: '100%', ...sx }}>
      {label && (
        <Typography
          variant="body2"
          sx={{
            mb: 1,
            fontWeight: 600,
            color: error ? 'error.main' : 'text.primary',
          }}
        >
          {label}
        </Typography>
      )}
      <Box
        sx={{
          position: 'relative',
          display: 'flex',
          alignItems: multiline ? 'flex-start' : 'center',
          minHeight: isMobile ? 48 : 40,
          padding: '12px 16px',
          border: `1px solid ${error ? 'error.main' : 'grey.300'}`,
          borderRadius: 2,
          backgroundColor: disabled ? 'grey.100' : 'white',
          '&:focus-within': {
            borderColor: error ? 'error.main' : 'primary.main',
            boxShadow: `0 0 0 2px ${error ? 'error.light' : 'primary.light'}`,
          },
        }}
      >
        {startIcon && (
          <Box sx={{ mr: 1, color: 'text.secondary' }}>
            {startIcon}
          </Box>
        )}
        <Box
          component={multiline ? 'textarea' : 'input'}
          type={multiline ? undefined : type}
          value={value}
          onChange={(e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => 
            onChange(e.target.value)
          }
          placeholder={placeholder}
          disabled={disabled}
          rows={multiline ? rows : undefined}
          sx={{
            flex: 1,
            border: 'none',
            outline: 'none',
            backgroundColor: 'transparent',
            fontSize: isMobile ? '16px' : '14px',
            fontFamily: 'inherit',
            color: 'text.primary',
            '&::placeholder': {
              color: 'text.secondary',
            },
            '&:disabled': {
              color: 'text.disabled',
            },
          }}
        />
        {endIcon && (
          <Box sx={{ ml: 1, color: 'text.secondary' }}>
            {endIcon}
          </Box>
        )}
      </Box>
      {helperText && (
        <Typography
          variant="caption"
          sx={{
            mt: 0.5,
            color: error ? 'error.main' : 'text.secondary',
          }}
        >
          {helperText}
        </Typography>
      )}
    </Box>
  );
};

/**
 * 모바일 최적화된 리스트 컴포넌트
 */
interface MobileListProps {
  items: Array<{
    id: string;
    title: string;
    subtitle?: string;
    icon?: React.ReactNode;
    onClick?: () => void;
  }>;
  sx?: any;
}

export const MobileList: React.FC<MobileListProps> = ({ items, sx = {} }) => {
  const isMobile = useIsMobile();

  return (
    <List sx={{ ...sx }}>
      {items.map((item, index) => (
        <React.Fragment key={item.id}>
          {item.onClick ? (
            <ListItemButton
              onClick={item.onClick}
              component="div"
              sx={{
                borderRadius: isMobile ? 2 : 1,
                mb: 1,
              }}
            >
              {item.icon && (
                <ListItemIcon sx={{ minWidth: 40 }}>
                  {item.icon}
                </ListItemIcon>
              )}
              <ListItemText
                primary={item.title}
                secondary={item.subtitle}
                primaryTypographyProps={{
                  fontSize: isMobile ? '16px' : '14px',
                  fontWeight: 600,
                }}
                secondaryTypographyProps={{
                  fontSize: isMobile ? '14px' : '12px',
                }}
              />
            </ListItemButton>
          ) : (
            <ListItem
              sx={{
                borderRadius: isMobile ? 2 : 1,
                mb: 1,
              }}
            >
              {item.icon && (
                <ListItemIcon sx={{ minWidth: 40 }}>
                  {item.icon}
                </ListItemIcon>
              )}
              <ListItemText
                primary={item.title}
                secondary={item.subtitle}
                primaryTypographyProps={{
                  fontSize: isMobile ? '16px' : '14px',
                  fontWeight: 600,
                }}
                secondaryTypographyProps={{
                  fontSize: isMobile ? '14px' : '12px',
                }}
              />
            </ListItem>
          )}
          {index < items.length - 1 && <Divider />}
        </React.Fragment>
      ))}
    </List>
  );
};

// ===== 추가 모바일 최적화 컴포넌트들 =====

/**
 * 터치 친화적인 버튼 (모바일 최적화)
 */
export const TouchFriendlyButton: React.FC<{
  onClick?: () => void;
  children: React.ReactNode;
  variant?: 'contained' | 'outlined' | 'text';
  color?: 'primary' | 'secondary' | 'error' | 'info' | 'success' | 'warning';
  size?: 'small' | 'medium' | 'large';
  fullWidth?: boolean;
  disabled?: boolean;
  startIcon?: React.ReactNode;
  endIcon?: React.ReactNode;
  sx?: any;
}> = ({
  onClick,
  children,
  variant = 'contained',
  color = 'primary',
  size = 'medium',
  fullWidth = false,
  disabled = false,
  startIcon,
  endIcon,
  sx = {},
}) => {
  const isMobile = useIsMobile();
  const isTouch = useIsTouchDevice();

  // 모바일/터치 디바이스의 경우 더 큰 터치 타겟과 패딩
  const touchTargetSize = isTouch ? 48 : 36;
  const padding = isMobile
    ? { py: 1.5, px: 3 }
    : { py: 1, px: 2 };

  return (
    <Box
      component="button"
      onClick={disabled ? undefined : onClick}
      disabled={disabled}
      sx={{
        minHeight: touchTargetSize,
        minWidth: touchTargetSize,
        width: fullWidth ? '100%' : 'auto',
        border: variant === 'outlined' ? '1px solid' : 'none',
        borderColor: variant === 'outlined' ? `${color}.main` : 'transparent',
        borderRadius: 2,
        bgcolor: variant === 'contained'
          ? `${color}.main`
          : variant === 'outlined'
            ? 'transparent'
            : 'transparent',
        color: variant === 'contained'
          ? 'white'
          : variant === 'outlined'
            ? `${color}.main`
            : `${color}.main`,
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.5 : 1,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 1,
        fontSize: isMobile ? '16px' : '14px',
        fontWeight: 600,
        textTransform: 'none',
        transition: 'all 0.2s ease-in-out',
        '&:hover': {
          bgcolor: variant === 'contained'
            ? `${color}.dark`
            : variant === 'outlined'
              ? `${color}.main`
              : `${color}.light`,
          color: variant === 'outlined' && 'white',
        },
        '&:active': {
          transform: 'scale(0.98)',
        },
        ...padding,
        ...sx,
      }}
    >
      {startIcon}
      {children}
      {endIcon}
    </Box>
  );
};

/**
 * 모바일 최적화된 카드 컴포넌트
 */
export const MobileCard: React.FC<{
  children: React.ReactNode;
  onClick?: () => void;
  elevation?: number;
  sx?: any;
}> = ({ children, onClick, elevation = 1, sx = {} }) => {
  const isMobile = useIsMobile();

  return (
    <Paper
      elevation={elevation}
      onClick={onClick}
      sx={{
        borderRadius: isMobile ? 3 : 2,
        overflow: 'hidden',
        cursor: onClick ? 'pointer' : 'default',
        transition: 'all 0.2s ease-in-out',
        '&:hover': onClick ? {
          elevation: elevation + 2,
          transform: 'translateY(-2px)',
        } : {},
        '&:active': onClick ? {
          transform: 'scale(0.98)',
        } : {},
        ...sx,
      }}
    >
      {children}
    </Paper>
  );
};

/**
 * 모바일 친화적인 다이얼로그
 */
export const MobileDialog: React.FC<{
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  actions?: React.ReactNode;
  maxWidth?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  fullScreen?: boolean;
}> = ({
  open,
  onClose,
  title,
  children,
  actions,
  maxWidth = 'sm',
  fullScreen,
}) => {
  const theme = useTheme();
  const isMobile = useIsMobile();
  const keyboardHeight = useKeyboardHeight();

  const shouldBeFullScreen = fullScreen || (isMobile && maxWidth === 'sm');

  return (
    <Box
      sx={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        zIndex: theme.zIndex.modal,
        display: open ? 'flex' : 'none',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'rgba(0, 0, 0, 0.5)',
        p: isMobile ? 2 : 3,
      }}
      onClick={onClose}
    >
      <Box
        onClick={(e) => e.stopPropagation()}
        sx={{
          width: shouldBeFullScreen ? '100%' : {
            xs: '95%',
            sm: '80%',
            md: '70%',
            lg: '60%',
            xl: '50%',
          }[maxWidth] || '80%',
          maxWidth: shouldBeFullScreen ? '100%' : '600px',
          maxHeight: shouldBeFullScreen ? '100%' : `calc(100vh - ${keyboardHeight + 64}px)`,
          bgcolor: 'background.paper',
          borderRadius: shouldBeFullScreen ? 0 : (isMobile ? 3 : 2),
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
        }}
      >
        {/* 헤더 */}
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            p: isMobile ? 3 : 2,
            borderBottom: 1,
            borderColor: 'divider',
          }}
        >
          <Typography
            variant={isMobile ? 'h6' : 'h5'}
            component="h2"
            sx={{ fontWeight: 600 }}
          >
            {title}
          </Typography>
          <IconButton
            onClick={onClose}
            size={isMobile ? 'large' : 'medium'}
          >
            <CloseIcon />
          </IconButton>
        </Box>

        {/* 컨텐츠 */}
        <Box
          sx={{
            flex: 1,
            overflow: 'auto',
            p: isMobile ? 3 : 2,
          }}
        >
          {children}
        </Box>

        {/* 액션 버튼들 */}
        {actions && (
          <Box
            sx={{
              display: 'flex',
              justifyContent: 'flex-end',
              gap: 1,
              p: isMobile ? 3 : 2,
              borderTop: 1,
              borderColor: 'divider',
              flexWrap: 'wrap',
            }}
          >
            {actions}
          </Box>
        )}
      </Box>
    </Box>
  );
};

/**
 * 스와이프 제스처가 가능한 리스트 아이템
 */
export const SwipeableListItem: React.FC<{
  children: React.ReactNode;
  onSwipeLeft?: () => void;
  onSwipeRight?: () => void;
  leftAction?: React.ReactNode;
  rightAction?: React.ReactNode;
  sx?: any;
}> = ({
  children,
  onSwipeLeft,
  onSwipeRight,
  leftAction,
  rightAction,
  sx = {},
}) => {
  const isTouch = useIsTouchDevice();

  // 터치 디바이스가 아니면 일반 리스트 아이템으로 렌더링
  if (!isTouch) {
    return (
      <Box sx={{ ...sx }}>
        {children}
      </Box>
    );
  }

  // 스와이프 제스처 훅 사용
  const { swipeRef, isSwiping, swipeOffset } = useSwipeGesture({
    onSwipeLeft,
    onSwipeRight,
  });

  return (
    <Box sx={{ position: 'relative', overflow: 'hidden', ...sx }}>
      {/* 배경 액션들 */}
      <Box
        sx={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          px: 2,
        }}
      >
        {leftAction && (
          <Box sx={{ display: 'flex', alignItems: 'center' }}>
            {leftAction}
          </Box>
        )}
        {rightAction && (
          <Box sx={{ display: 'flex', alignItems: 'center' }}>
            {rightAction}
          </Box>
        )}
      </Box>

      {/* 메인 컨텐츠 */}
      <Box
        ref={swipeRef}
        sx={{
          position: 'relative',
          zIndex: 1,
          transform: `translateX(${swipeOffset}px)`,
          transition: isSwiping ? 'none' : 'transform 0.3s ease-out',
          bgcolor: 'background.paper',
        }}
      >
        {children}
      </Box>
    </Box>
  );
};

/**
 * 모바일 최적화된 그리드 레이아웃
 */
export const ResponsiveGrid: React.FC<{
  children: React.ReactNode;
  columns?: {
    xs?: number;
    sm?: number;
    md?: number;
    lg?: number;
    xl?: number;
  };
  spacing?: number;
  sx?: any;
}> = ({
  children,
  columns = { xs: 1, sm: 2, md: 3, lg: 4 },
  spacing = 2,
  sx = {},
}) => {
  const theme = useTheme();

  return (
    <Box
      sx={{
        display: 'grid',
        gridTemplateColumns: {
          xs: `repeat(${columns.xs || 1}, 1fr)`,
          sm: `repeat(${columns.sm || columns.xs || 2}, 1fr)`,
          md: `repeat(${columns.md || columns.sm || 3}, 1fr)`,
          lg: `repeat(${columns.lg || columns.md || 4}, 1fr)`,
          xl: `repeat(${columns.xl || columns.lg || 4}, 1fr)`,
        },
        gap: theme.spacing(spacing),
        ...sx,
      }}
    >
      {children}
    </Box>
  );
};

/**
 * 키보드 높이를 고려한 컨테이너
 */
export const KeyboardAwareContainer: React.FC<{
  children: React.ReactNode;
  sx?: any;
}> = ({ children, sx = {} }) => {
  const keyboardHeight = useKeyboardHeight();

  return (
    <Box
      sx={{
        pb: keyboardHeight > 0 ? `${keyboardHeight + 16}px` : 2,
        transition: 'padding-bottom 0.3s ease-in-out',
        ...sx,
      }}
    >
      {children}
    </Box>
  );
};

/**
 * 모바일 네비게이션 바 (하단 탭)
 */
export const MobileBottomNav: React.FC<{
  value: number;
  onChange: (value: number) => void;
  items: Array<{
    label: string;
    icon: React.ReactNode;
    badge?: number;
  }>;
}> = ({ value, onChange, items }) => {
  const isMobile = useIsMobile();

  if (!isMobile) return null;

  return (
    <Paper
      elevation={8}
      sx={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        zIndex: 1000,
        borderRadius: 0,
      }}
    >
      <Box
        sx={{
          display: 'flex',
          height: 64,
        }}
      >
        {items.map((item, index) => (
          <Box
            key={index}
            component="button"
            onClick={() => onChange(index)}
            sx={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              py: 1,
              px: 0.5,
              color: value === index ? 'primary.main' : 'text.secondary',
              bgcolor: 'transparent',
              border: 'none',
              cursor: 'pointer',
              position: 'relative',
              '&:hover': {
                bgcolor: 'action.hover',
              },
            }}
          >
            <Box sx={{ position: 'relative' }}>
              {item.icon}
              {item.badge && item.badge > 0 && (
                <Box
                  sx={{
                    position: 'absolute',
                    top: -8,
                    right: -8,
                    bgcolor: 'error.main',
                    color: 'white',
                    borderRadius: '50%',
                    width: 18,
                    height: 18,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '11px',
                    fontWeight: 'bold',
                  }}
                >
                  {item.badge > 99 ? '99+' : item.badge}
                </Box>
              )}
            </Box>
            <Typography
              variant="caption"
              sx={{
                mt: 0.5,
                fontSize: '11px',
                fontWeight: value === index ? 600 : 400,
              }}
            >
              {item.label}
            </Typography>
          </Box>
        ))}
      </Box>
    </Paper>
  );
};
