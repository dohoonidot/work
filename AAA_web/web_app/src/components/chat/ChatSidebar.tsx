import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import {
  Box,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Typography,
  Chip,
  Divider,
  useTheme,
  useMediaQuery,
} from '@mui/material';
import {
  BusinessCenter as BusinessCenterIcon,
  Description as DescriptionIcon,
  BeachAccess as BeachAccessIcon,
  EmojiEvents as EmojiEventsIcon,
} from '@mui/icons-material';
import { useChatStore } from '../../store/chatStore';
import type { Archive } from '../../types';

interface ChatSidebarProps {
  isMobile: boolean;
  onMobileMenuClose?: () => void;
}

const ChatSidebar: React.FC<ChatSidebarProps> = ({ isMobile, onMobileMenuClose }) => {
  const navigate = useNavigate();
  const location = useLocation();
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';

  const {
    archives,
    currentArchive,
    setCurrentArchive,
    setMessages,
  } = useChatStore();

  const [isLoading, setIsLoading] = useState(false);

  // 아카이브 클릭 핸들러
  const handleArchiveClick = async (archive: Archive) => {
    try {
      setIsLoading(true);
      setCurrentArchive(archive);

      // 채팅 내역 로드 (실제로는 chatService에서 가져와야 함)
      // const messages = await chatService.getArchiveDetail(archive.archive_id);
      // setMessages(messages);

      // 채팅 페이지로 이동
      navigate('/chat');

      if (isMobile && onMobileMenuClose) {
        onMobileMenuClose();
      }
    } catch (error) {
      console.error('아카이브 로드 실패:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // 업무 메뉴 클릭 핸들러
  const handleMenuClick = (path: string) => {
    navigate(path);
    if (isMobile && onMobileMenuClose) {
      onMobileMenuClose();
    }
  };

  // 아카이브 아이콘 결정
  const getArchiveIcon = (archive: Archive) => {
    switch (archive.archive_type) {
      case 'code':
        return '💻';
      case 'sap':
        return '🔧';
      default:
        return '💼';
    }
  };

  // 아카이브 태그 결정
  const getArchiveTag = (archive: Archive) => {
    switch (archive.archive_type) {
      case 'code':
        return '코딩';
      case 'sap':
        return 'SAP';
      default:
        return archive.archive_name.includes('사내업무') ? '업무' :
               archive.archive_name.includes('AI Chatbot') ? 'AI' : null;
    }
  };

  // 아카이브 설명
  const getArchiveDescription = (archive: Archive) => {
    switch (archive.archive_type) {
      case 'code':
        return '프로그래밍, 코드 리뷰, 기술 질문';
      case 'sap':
        return 'SAP 시스템, 업무 프로세스';
      default:
        return archive.archive_name.includes('사내업무')
          ? '일반 업무, 문서 작성, 커뮤니케이션'
          : null;
    }
  };

  // 색상 스킴
  const colorScheme = {
    primaryColor: '#4A6CF7',
    sidebarTextColor: isDark ? '#FFFFFF' : '#374151',
    hintTextColor: isDark ? '#9CA3AF' : '#6B7280',
    textFieldBorderColor: isDark ? '#374151' : '#E5E7EB',
  };

  return (
    <Box sx={{
      width: isMobile ? '100%' : 280,
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      bgcolor: isDark ? '#1F2937' : '#FFFFFF',
      borderRight: !isMobile ? `1px solid ${colorScheme.textFieldBorderColor}` : 'none',
    }}>
      {/* 채팅 아카이브 섹션 */}
      <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
        <Typography
          variant="subtitle2"
          sx={{
            color: colorScheme.hintTextColor,
            fontWeight: 600,
            mb: 1.5,
            fontSize: '0.8rem',
            textTransform: 'uppercase',
            letterSpacing: '0.5px',
          }}
        >
          채팅
        </Typography>

        <List sx={{ p: 0 }}>
          {archives.map((archive) => {
            const isSelected = currentArchive?.archive_id === archive.archive_id;
            const tag = getArchiveTag(archive);
            const description = getArchiveDescription(archive);

            return (
              <Box key={archive.archive_id}>
                <ListItemButton
                  selected={isSelected}
                  onClick={() => handleArchiveClick(archive)}
                  sx={{
                    borderRadius: 2,
                    mb: 0.5,
                    py: 1.5,
                    transition: 'all 0.2s',
                    '&.Mui-selected': {
                      bgcolor: isDark ? 'rgba(74, 108, 247, 0.15)' : '#e3f2fd',
                      borderLeft: isMobile ? 'none' : `4px solid ${colorScheme.primaryColor}`,
                      '&:hover': {
                        bgcolor: isDark ? 'rgba(74, 108, 247, 0.25)' : '#bbdefb',
                      },
                    },
                    '&:hover': {
                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#f5f5f5',
                      transform: 'translateX(2px)',
                    },
                  }}
                >
                  <ListItemIcon sx={{
                    minWidth: isMobile ? 32 : 44,
                    fontSize: isMobile ? '1.2rem' : '1.5rem'
                  }}>
                    {getArchiveIcon(archive)}
                  </ListItemIcon>

                  <ListItemText
                    primary={
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography
                          variant="body2"
                          sx={{
                            fontWeight: isSelected ? 600 : 400,
                            fontSize: '0.9rem',
                            flex: 1,
                          }}
                        >
                          {archive.archive_name}
                        </Typography>
                        {tag && (
                          <Chip
                            label={tag}
                            size="small"
                            sx={{
                              height: 20,
                              fontSize: '0.7rem',
                              fontWeight: 'bold',
                              bgcolor: `${colorScheme.primaryColor}20`,
                              color: colorScheme.primaryColor,
                            }}
                          />
                        )}
                      </Box>
                    }
                  />
                </ListItemButton>

                {/* 설명 표시 */}
                {description && (
                  <Box sx={{ px: 2, pb: 0.5 }}>
                    <Typography
                      variant="caption"
                      sx={{
                        color: colorScheme.hintTextColor,
                        fontSize: '0.7rem',
                        lineHeight: 1.3,
                        display: 'block',
                      }}
                    >
                      {description}
                    </Typography>
                  </Box>
                )}
              </Box>
            );
          })}
        </List>
      </Box>

      <Divider sx={{ mx: 2, borderColor: colorScheme.textFieldBorderColor }} />

      {/* 업무 메뉴 섹션 */}
      <Box sx={{ flexShrink: 0, p: 2 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
          <BusinessCenterIcon sx={{ fontSize: 16, color: colorScheme.primaryColor }} />
          <Typography
            variant="caption"
            sx={{
              color: 'text.primary',
              fontWeight: 600,
              fontSize: '0.75rem',
              textTransform: 'uppercase',
              letterSpacing: '0.5px',
            }}
          >
            업무
          </Typography>
        </Box>

        <List sx={{ p: 0 }}>
          {/* 전자결재 메뉴 (임시 숨김) */}
          {/* <ListItemButton
            onClick={() => handleMenuClick('/approval')}
            selected={location.pathname === '/approval'}
            sx={{
              borderRadius: 2,
              mb: 0.5,
              py: 1,
              '&:hover': {
                bgcolor: 'action.hover',
                transform: 'translateX(2px)',
              },
            }}
          >
            <ListItemIcon sx={{ minWidth: 40 }}>
              <DescriptionIcon sx={{ fontSize: 20, color: '#6B7280' }} />
            </ListItemIcon>
            <ListItemText
              primary={
                <Typography variant="body2" sx={{ fontSize: '0.875rem' }}>
                  전자결재
                </Typography>
              }
            />
          </ListItemButton> */}

          {/* 휴가관리 */}
          <ListItemButton
            onClick={() => handleMenuClick('/leave')}
            selected={location.pathname === '/leave'}
            sx={{
              borderRadius: 2,
              mb: 0.5,
              py: 1,
              '&:hover': {
                bgcolor: 'action.hover',
                transform: 'translateX(2px)',
              },
            }}
          >
            <ListItemIcon sx={{ minWidth: 40 }}>
              <BeachAccessIcon sx={{ fontSize: 20, color: '#10B981' }} />
            </ListItemIcon>
            <ListItemText
              primary={
                <Typography variant="body2" sx={{ fontSize: '0.875rem' }}>
                  휴가관리
                </Typography>
              }
            />
          </ListItemButton>

          {/* 사내AI 공모전 메뉴 (임시 숨김) */}
          {/* <ListItemButton
            onClick={() => handleMenuClick('/contest')}
            selected={location.pathname === '/contest'}
            sx={{
              borderRadius: 2,
              mb: 0.5,
              py: 1,
              '&:hover': {
                bgcolor: 'action.hover',
                transform: 'translateX(2px)',
              },
            }}
          >
            <ListItemIcon sx={{ minWidth: 40 }}>
              <EmojiEventsIcon sx={{ fontSize: 20, color: '#F59E0B' }} />
            </ListItemIcon>
            <ListItemText
              primary={
                <Typography variant="body2" sx={{ fontSize: '0.875rem' }}>
                  사내AI 공모전
                </Typography>
              }
            />
          </ListItemButton> */}
        </List>
      </Box>
    </Box>
  );
};

export default ChatSidebar;