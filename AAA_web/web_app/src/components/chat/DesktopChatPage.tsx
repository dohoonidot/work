import { useState } from 'react';
import {
  Box,
  Drawer,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Typography,
  Chip,
  Divider,
  Button,
  IconButton,
  Tooltip,
} from '@mui/material';
import {
  Lock as LockIcon,
  Code as CodeIcon,
  Business as BusinessIcon,
  AutoAwesome as AutoAwesomeIcon,
  Chat as ChatIcon,
  Add as AddIcon,
  Search as SearchIcon,
  Description as DescriptionIcon,
  BeachAccess as BeachAccessIcon,
  EmojiEvents as EmojiEventsIcon,
  BusinessCenter as BusinessCenterIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { getArchiveIcon, getArchiveColor, getArchiveTag, getArchiveDescription } from '../../store/chatStore';
import ChatArea from './ChatArea';
import SearchDialog from './SearchDialog';
import chatService from '../../services/chatService';
import authService from '../../services/authService';
import type { Archive } from '../../types';

const SIDEBAR_WIDTH = 280;

interface DesktopChatPageProps {
  archives: Archive[];
  currentArchive: Archive | null;
  onSelectArchive: (archive: Archive) => void;
  onCreateArchive: (archiveType: string) => void;
}

export default function DesktopChatPage({
  archives,
  currentArchive,
  onSelectArchive,
  onCreateArchive,
}: DesktopChatPageProps) {
  const [searchDialogOpen, setSearchDialogOpen] = useState(false);
  const navigate = useNavigate();

  // 아이콘 가져오기
  const getIcon = (archive: Archive) => {
    const iconName = getArchiveIcon(archive);
    const color = getArchiveColor(archive, false);

    const iconProps = { sx: { color, fontSize: '1.25rem' } };

    switch (iconName) {
      case 'code':
        return <CodeIcon {...iconProps} />;
      case 'business':
        return <BusinessIcon {...iconProps} />;
      case 'auto_awesome':
        return <AutoAwesomeIcon {...iconProps} />;
      case 'lock':
        return <LockIcon {...iconProps} />;
      default:
        return <ChatIcon {...iconProps} />;
    }
  };

  return (
    <Box sx={{ display: 'flex', height: '100vh', overflow: 'hidden' }}>
      {/* 고정 사이드바 */}
      <Drawer
        variant="permanent"
        sx={{
          width: SIDEBAR_WIDTH,
          flexShrink: 0,
          '& .MuiDrawer-paper': {
            width: SIDEBAR_WIDTH,
            boxSizing: 'border-box',
            borderRight: '1px solid',
            borderColor: 'divider',
          },
        }}
      >
        <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
          {/* 헤더 */}
          <Box
            sx={{
              p: 2.5,
              background: 'linear-gradient(135deg, #1D4487 0%, #1976d2 100%)',
              color: 'white',
              position: 'relative',
            }}
          >
            <Typography variant="h5" sx={{ fontWeight: 'bold', mb: 0.5 }}>
              ASPN AI Agent
            </Typography>
            <Typography variant="caption" sx={{ opacity: 0.9 }}>
              데스크톱 웹 버전
            </Typography>
            
            {/* 검색 버튼 */}
            <Tooltip title="대화 내용 검색" placement="right">
              <IconButton
                onClick={() => setSearchDialogOpen(true)}
                sx={{
                  position: 'absolute',
                  top: 12,
                  right: 52,
                  bgcolor: 'rgba(255,255,255,0.1)',
                  color: 'white',
                  width: 32,
                  height: 32,
                  '&:hover': {
                    bgcolor: 'rgba(255,255,255,0.2)',
                  },
                }}
              >
                <SearchIcon sx={{ fontSize: 18 }} />
              </IconButton>
            </Tooltip>
            
            {/* 새 채팅방 버튼 */}
            <Tooltip title="새 채팅방 만들기" placement="right">
              <IconButton
                onClick={async () => {
                  try {
                    const user = authService.getCurrentUser();
                    if (user) {
                      const response = await chatService.createArchive(user.userId, '', '');
                      onCreateArchive('');
                    }
                  } catch (error) {
                    console.error('새 채팅방 생성 실패:', error);
                    alert('새 채팅방 생성에 실패했습니다.');
                  }
                }}
                sx={{
                  position: 'absolute',
                  top: 12,
                  right: 12,
                  bgcolor: 'rgba(255,255,255,0.1)',
                  color: 'white',
                  width: 32,
                  height: 32,
                  '&:hover': {
                    bgcolor: 'rgba(255,255,255,0.2)',
                  },
                }}
              >
                <AddIcon sx={{ fontSize: 18 }} />
              </IconButton>
            </Tooltip>
          </Box>

          <Divider />

          {/* 채팅방 목록 */}
          <Box sx={{ flex: 1, overflow: 'auto', px: 1.5 }}>
            <Typography
              variant="caption"
              sx={{
                px: 1.5,
                py: 1,
                display: 'block',
                color: 'text.secondary',
                fontWeight: 600,
                fontSize: '0.7rem',
                textTransform: 'uppercase',
                letterSpacing: '0.5px',
              }}
            >
              채팅방 목록
            </Typography>

            <List sx={{ py: 0.5 }}>
              {archives.map((archive) => {
                const isSelected = currentArchive?.archive_id === archive.archive_id;
                const color = getArchiveColor(archive, false);
                const tag = getArchiveTag(archive);
                const description = getArchiveDescription(archive);

                return (
                  <Box key={archive.archive_id}>
                    <ListItemButton
                      selected={isSelected}
                      onClick={() => onSelectArchive(archive)}
                      component="div"
                      sx={{
                        borderRadius: 2,
                        mb: 0.5,
                        py: 1.5,
                        transition: 'all 0.2s',
                        '&.Mui-selected': {
                          bgcolor: `${color}15`,
                          borderLeft: `4px solid ${color}`,
                          '&:hover': {
                            bgcolor: `${color}20`,
                          },
                        },
                        '&:hover': {
                          bgcolor: 'action.hover',
                          transform: 'translateX(2px)',
                        },
                      }}
                    >
                      <ListItemIcon sx={{ minWidth: 44 }}>
                        {getIcon(archive)}
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
                                  bgcolor: `${color}20`,
                                  color: color,
                                }}
                              />
                            )}
                          </Box>
                        }
                      />
                    </ListItemButton>

                    {/* 설명 표시 (코딩어시스턴트, SAP어시스턴트) */}
                    {description && (
                      <Box sx={{ px: 2, pb: 1 }}>
                        <Typography
                          variant="caption"
                          sx={{
                            color: 'text.secondary',
                            fontSize: '0.7rem',
                            lineHeight: 1.4,
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

          <Divider />

          {/* 업무 메뉴 섹션 */}
          <Box sx={{ px: 2, py: 1.5 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
              <BusinessCenterIcon sx={{ fontSize: 16, color: '#4A6CF7' }} />
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
            
            <List sx={{ py: 0 }}>
              {/* 전자결재 메뉴 (임시 숨김) */}
              {/* <ListItemButton
                onClick={() => navigate('/approval')}
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
                onClick={() => navigate('/leave')}
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
                  <BeachAccessIcon sx={{ fontSize: 20, color: '#6B7280' }} />
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
                onClick={() => navigate('/contest')}
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

          <Divider />

          {/* 빠른 생성 버튼 - 주석처리 (모바일 웹에서는 코딩/SAP 어시스턴트 미사용) */}
          {/* <Box sx={{ p: 2 }}>
            <Typography
              variant="caption"
              sx={{
                color: 'text.secondary',
                mb: 1,
                display: 'block',
                fontWeight: 600,
                fontSize: '0.7rem',
              }}
            >
              빠른 채팅방 생성
            </Typography>
            <Box sx={{ display: 'flex', gap: 1 }}>
              <Tooltip title="코딩어시스턴트">
                <IconButton
                  onClick={() => onCreateArchive('code')}
                  sx={{
                    flex: 1,
                    bgcolor: '#10B98115',
                    color: '#10B981',
                    borderRadius: 2,
                    '&:hover': {
                      bgcolor: '#10B98125',
                    },
                  }}
                >
                  <CodeIcon />
                </IconButton>
              </Tooltip>

              <Tooltip title="SAP어시스턴트">
                <IconButton
                  onClick={() => onCreateArchive('sap')}
                  sx={{
                    flex: 1,
                    bgcolor: '#3B82F615',
                    color: '#3B82F6',
                    borderRadius: 2,
                    '&:hover': {
                      bgcolor: '#3B82F625',
                    },
                  }}
                >
                  <BusinessIcon />
                </IconButton>
              </Tooltip>
            </Box>
          </Box> */}
        </Box>
      </Drawer>

      {/* 메인 채팅 영역 */}
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          width: `calc(100% - ${SIDEBAR_WIDTH}px)`,
          height: '100vh',
          overflow: 'hidden',
        }}
      >
        <ChatArea />
      </Box>

      {/* 검색 다이얼로그 */}
      <SearchDialog
        open={searchDialogOpen}
        onClose={() => setSearchDialogOpen(false)}
        archives={archives}
        onSelectArchive={onSelectArchive}
        onSelectMessage={(archiveId, chatId) => {
          // 메시지로 스크롤하는 기능은 ChatArea에서 구현 필요
          console.log('메시지 선택:', archiveId, chatId);
        }}
      />
    </Box>
  );
}
