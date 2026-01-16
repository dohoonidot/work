import React, { useState, useEffect } from 'react';
import {
  Box,
  IconButton,
  Typography,
  Button,
  Collapse,
  useTheme,
  useMediaQuery,
} from '@mui/material';
import {
  AdminPanelSettings as AdminPanelSettingsIcon,
  PeopleAltOutlined as PeopleAltOutlinedIcon,
  PushPin as PushPinIcon,
  PushPinOutlined as PushPinOutlinedIcon,
} from '@mui/icons-material';
import { DepartmentLeaveStatusModal } from './DepartmentLeaveStatusModal';

interface AdminCalendarSidebarProps {
  isExpanded: boolean;
  isPinned: boolean;
  onHover: () => void;
  onExit: () => void;
  onPinToggle: () => void;
}

export const AdminCalendarSidebar: React.FC<AdminCalendarSidebarProps> = ({
  isExpanded,
  isPinned,
  onHover,
  onExit,
  onPinToggle,
}) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const isDarkTheme = theme.palette.mode === 'dark';
  const [modalOpen, setModalOpen] = useState(false);

  // 모바일에서는 사이드바를 렌더링하지 않음
  if (isMobile) {
    return (
      <>
        <DepartmentLeaveStatusModal
          open={modalOpen}
          onClose={() => setModalOpen(false)}
        />
      </>
    );
  }

  return (
    <>
      <Box
        onMouseEnter={!isPinned ? onHover : undefined}
        onMouseLeave={!isPinned ? onExit : undefined}
        sx={{
          position: 'fixed',
          left: 0,
          top: 0,
          bottom: 0,
          width: isExpanded ? '285px' : '50px',
          height: '100%',
          background: isDarkTheme
            ? 'linear-gradient(135deg, #2D2D2D 0%, #1A1A1A 100%)'
            : 'linear-gradient(135deg, #F8F9FA 0%, #FFFFFF 100%)',
          borderRight: `1px solid ${isDarkTheme ? '#404040' : '#E9ECEF'}`,
          boxShadow: `4px 0 20px rgba(0, 0, 0, ${isDarkTheme ? 0.3 : 0.1})`,
          transition: 'width 0.3s ease-in-out',
          zIndex: 1000,
          overflow: 'hidden',
        }}
      >
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            p: 2,
            height: '100%',
            overflowY: 'auto',
          }}
        >
          {isExpanded && (
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                mb: 3,
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <Box
                  sx={{
                    p: 0.5,
                    borderRadius: '6px',
                    bgcolor: isDarkTheme ? 'rgba(156, 136, 212, 0.1)' : 'rgba(156, 136, 212, 0.1)',
                  }}
                >
                  <AdminPanelSettingsIcon
                    sx={{
                      color: '#9C88D4',
                      fontSize: 16,
                    }}
                  />
                </Box>
                <Typography
                  sx={{
                    fontSize: '14px',
                    fontWeight: 700,
                    color: isDarkTheme ? '#FFFFFF' : '#495057',
                    flex: 1,
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}
                >
                  관리자 메뉴
                </Typography>
              </Box>
              <IconButton
                onClick={onPinToggle}
                size="small"
                sx={{
                  width: 24,
                  height: 24,
                  p: 0,
                  color: isPinned
                    ? '#9C88D4'
                    : isDarkTheme
                    ? 'rgba(255, 255, 255, 0.4)'
                    : 'rgba(0, 0, 0, 0.6)',
                }}
                title={isPinned ? '사이드바 고정 해제' : '사이드바 고정'}
              >
                {isPinned ? (
                  <PushPinIcon sx={{ fontSize: 14 }} />
                ) : (
                  <PushPinOutlinedIcon sx={{ fontSize: 14 }} />
                )}
              </IconButton>
            </Box>
          )}

          {!isExpanded && (
            <Box
              sx={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                mt: 2.5,
              }}
            >
              <Box
                sx={{
                  width: 30,
                  height: 30,
                  borderRadius: '8px',
                  bgcolor: 'rgba(156, 136, 212, 0.1)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <AdminPanelSettingsIcon
                  sx={{
                    color: '#9C88D4',
                    fontSize: 18,
                  }}
                />
              </Box>
            </Box>
          )}

          {isExpanded && (
            <Button
              fullWidth
              variant="contained"
              startIcon={<PeopleAltOutlinedIcon sx={{ fontSize: 18 }} />}
              onClick={() => setModalOpen(true)}
              sx={{
                bgcolor: '#9C88D4',
                color: 'white',
                py: 1.75,
                px: 1.5,
                borderRadius: '12px',
                textTransform: 'none',
                fontSize: '14px',
                fontWeight: 600,
                boxShadow: 2,
                '&:hover': {
                  bgcolor: '#8B7BC4',
                },
              }}
            >
              부서원 휴가 현황
            </Button>
          )}
        </Box>
      </Box>

      <DepartmentLeaveStatusModal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
      />
    </>
  );
};

