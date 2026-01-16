import React, { useState } from 'react';
import {
  Box,
  Drawer,
  IconButton,
  Typography,
  Button,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  CalendarToday as CalendarIcon,
  PushPin as PushPinIcon,
  CalendarMonth as CalendarMonthIcon,
  Description as DescriptionIcon,
} from '@mui/icons-material';

interface LeaveSidebarProps {
  isExpanded: boolean;
  isPinned: boolean;
  onHover: () => void;
  onExit: () => void;
  onPinToggle: () => void;
  onCalendarOpen?: () => void;
  onNoticeOpen?: () => void;
}

export default function LeaveSidebar({
  isExpanded,
  isPinned,
  onHover,
  onExit,
  onPinToggle,
  onCalendarOpen,
  onNoticeOpen,
}: LeaveSidebarProps) {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));

  // 모바일에서는 Drawer로 표시
  if (isMobile) {
    return (
      <Drawer
        anchor="left"
        open={isExpanded}
        onClose={onExit}
        sx={{
          '& .MuiDrawer-paper': {
            width: 285,
            bgcolor: 'white',
            boxShadow: theme.shadows[3],
          },
        }}
      >
        <Box sx={{ p: 2 }}>
          <Box
            sx={{
              p: 2,
              borderRadius: '12px',
              background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
              color: 'white',
              mb: 2,
            }}
          >
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
              <CalendarIcon />
              <Typography variant="h6" fontWeight={700}>
                휴가 관리
              </Typography>
            </Box>

            <Button
              fullWidth
              variant="contained"
              startIcon={<CalendarMonthIcon />}
              onClick={onCalendarOpen}
              sx={{
                bgcolor: 'rgba(255,255,255,0.9)',
                color: '#667eea',
                mb: 1,
                '&:hover': {
                  bgcolor: 'white',
                },
              }}
            >
              휴가 캘린더
            </Button>

            <Button
              fullWidth
              variant="contained"
              startIcon={<DescriptionIcon />}
              onClick={onNoticeOpen}
              sx={{
                bgcolor: 'rgba(255,255,255,0.9)',
                color: '#667eea',
                '&:hover': {
                  bgcolor: 'white',
                },
              }}
            >
              연차휴가 사용촉진 통지서
            </Button>
          </Box>
        </Box>
      </Drawer>
    );
  }

  // 데스크톱 버전 - ChatSidebar 스타일 적용
  return (
    <Box
      onMouseEnter={!isPinned ? onHover : undefined}
      onMouseLeave={!isPinned ? onExit : undefined}
      sx={{
        width: isExpanded ? 285 : 50,
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        bgcolor: '#ffffff',
        borderRight: '1px solid #e0e0e0',
        transition: 'width 0.3s ease-in-out',
        overflow: 'hidden',
      }}
    >
      {/* 축소된 상태 */}
      {!isExpanded && (
        <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', pt: 2.5 }}>
          <Box
            sx={{
              p: 1,
              borderRadius: '10px',
              bgcolor: '#e3f2fd',
              color: '#1976d2',
            }}
          >
            <CalendarIcon sx={{ fontSize: 24 }} />
          </Box>
        </Box>
      )}

      {/* 확장된 상태 */}
      {isExpanded && (
        <>
          {/* 헤더 - ChatSidebar 스타일 */}
          <Box
            sx={{
              p: 2.5,
              color: '#333333',
              bgcolor: '#f8f9fa',
              borderBottom: '1px solid #e0e0e0',
              position: 'relative',
            }}
          >
            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 0.5 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <Box
                  sx={{
                    p: 0.75,
                    borderRadius: '8px',
                    bgcolor: '#e3f2fd',
                    color: '#1976d2',
                    display: 'flex',
                    alignItems: 'center',
                  }}
                >
                  <CalendarIcon sx={{ fontSize: 18 }} />
                </Box>
                <Typography
                  sx={{
                    fontWeight: 'bold',
                    fontSize: '1.1rem',
                    color: '#333333',
                  }}
                >
                  휴가 관리
                </Typography>
              </Box>
              <IconButton
                onClick={onPinToggle}
                size="small"
                sx={{
                  color: '#666666',
                  width: 28,
                  height: 28,
                  '&:hover': {
                    bgcolor: 'rgba(0, 0, 0, 0.04)',
                  },
                }}
              >
                <PushPinIcon
                  sx={{
                    fontSize: 16,
                    transform: isPinned ? 'rotate(0deg)' : 'rotate(45deg)',
                    transition: 'transform 0.2s',
                  }}
                />
              </IconButton>
            </Box>
            <Typography variant="caption" sx={{ opacity: 0.7, fontSize: '0.7rem', color: '#666666' }}>
              휴가 신청 및 관리
            </Typography>
          </Box>

          {/* 메뉴 버튼들 - ChatSidebar 스타일 */}
          <Box sx={{ p: 1.5, display: 'flex', flexDirection: 'column', gap: 1 }}>
            <Button
              fullWidth
              startIcon={<CalendarMonthIcon sx={{ fontSize: 18 }} />}
              onClick={onCalendarOpen}
              sx={{
                justifyContent: 'flex-start',
                py: 1.25,
                px: 2,
                borderRadius: 2,
                color: '#333333',
                bgcolor: 'transparent',
                textTransform: 'none',
                fontSize: '0.875rem',
                fontWeight: 500,
                '&:hover': {
                  bgcolor: '#f5f5f5',
                },
              }}
            >
              휴가 캘린더
            </Button>

            <Button
              fullWidth
              startIcon={<DescriptionIcon sx={{ fontSize: 18 }} />}
              onClick={onNoticeOpen}
              sx={{
                justifyContent: 'flex-start',
                py: 1.25,
                px: 2,
                borderRadius: 2,
                color: '#333333',
                bgcolor: 'transparent',
                textTransform: 'none',
                fontSize: '0.875rem',
                fontWeight: 500,
                '&:hover': {
                  bgcolor: '#f5f5f5',
                },
              }}
            >
              연차휴가 통지서
            </Button>
          </Box>
        </>
      )}
    </Box>
  );
}
