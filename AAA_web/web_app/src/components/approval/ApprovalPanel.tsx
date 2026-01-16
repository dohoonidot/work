import { useState, useEffect } from 'react';
import {
  Box,
  Drawer,
  Typography,
  List,
  ListItem,
  ListItemText,
  ListItemButton,
  Chip,
  IconButton,
  Divider,
  Button,
  Card,
  CardContent,
  Badge,
} from '@mui/material';
import {
  Close as CloseIcon,
  PushPin as PushPinIcon,
  PushPinOutlined as PushPinOutlinedIcon,
  Description as DescriptionIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon,
  HourglassEmpty as HourglassEmptyIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useThemeStore } from '../../store/themeStore';

const PANEL_WIDTH = 360;

export interface ApprovalRequest {
  id: string;
  type: 'leave' | 'document' | 'expense' | 'general';
  title: string;
  requester: string;
  requestDate: string;
  status: 'pending' | 'approved' | 'rejected';
  priority?: 'high' | 'normal' | 'low';
  summary?: string;
}

interface ApprovalPanelProps {
  open: boolean;
  onClose: () => void;
  requests?: ApprovalRequest[];
}

export default function ApprovalPanel({ open, onClose, requests = [] }: ApprovalPanelProps) {
  const { colorScheme } = useThemeStore();
  const navigate = useNavigate();
  const [isPinned, setIsPinned] = useState(false);

  // 상태별 필터링
  const pendingRequests = requests.filter((r) => r.status === 'pending');
  const approvedRequests = requests.filter((r) => r.status === 'approved');
  const rejectedRequests = requests.filter((r) => r.status === 'rejected');

  // 타입별 아이콘
  const getTypeIcon = (type: string) => {
    switch (type) {
      case 'leave':
        return '🏖️';
      case 'document':
        return '📄';
      case 'expense':
        return '💰';
      default:
        return '📋';
    }
  };

  // 타입별 색상
  const getTypeColor = (type: string) => {
    switch (type) {
      case 'leave':
        return '#10B981';
      case 'document':
        return '#3B82F6';
      case 'expense':
        return '#F59E0B';
      default:
        return '#6B7280';
    }
  };

  // 우선순위별 색상
  const getPriorityColor = (priority?: string) => {
    switch (priority) {
      case 'high':
        return '#DC2626';
      case 'normal':
        return '#3B82F6';
      case 'low':
        return '#6B7280';
      default:
        return '#6B7280';
    }
  };

  // 상태별 아이콘
  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'approved':
        return <CheckCircleIcon sx={{ fontSize: 16, color: '#10B981' }} />;
      case 'rejected':
        return <CancelIcon sx={{ fontSize: 16, color: '#DC2626' }} />;
      default:
        return <HourglassEmptyIcon sx={{ fontSize: 16, color: '#F59E0B' }} />;
    }
  };

  const handleRequestClick = (request: ApprovalRequest) => {
    // 결재 상세 페이지로 이동
    navigate(`/approval/${request.id}`);
    if (!isPinned) {
      onClose();
    }
  };

  return (
    <Drawer
      anchor="right"
      open={open}
      onClose={onClose}
      variant={isPinned ? 'persistent' : 'temporary'}
      sx={{
        '& .MuiDrawer-paper': {
          width: PANEL_WIDTH,
          boxSizing: 'border-box',
        },
      }}
    >
      <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        {/* 헤더 */}
        <Box
          sx={{
            p: 2,
            bgcolor: colorScheme.primaryColor,
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <DescriptionIcon />
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              결재 요청
            </Typography>
            <Badge badgeContent={pendingRequests.length} color="error" />
          </Box>

          <Box sx={{ display: 'flex', gap: 0.5 }}>
            {/* 고정 버튼 */}
            <IconButton
              size="small"
              onClick={() => setIsPinned(!isPinned)}
              sx={{
                color: 'white',
                '&:hover': {
                  bgcolor: 'rgba(255,255,255,0.1)',
                },
              }}
            >
              {isPinned ? <PushPinIcon fontSize="small" /> : <PushPinOutlinedIcon fontSize="small" />}
            </IconButton>

            {/* 닫기 버튼 */}
            <IconButton
              size="small"
              onClick={onClose}
              sx={{
                color: 'white',
                '&:hover': {
                  bgcolor: 'rgba(255,255,255,0.1)',
                },
              }}
            >
              <CloseIcon fontSize="small" />
            </IconButton>
          </Box>
        </Box>

        <Divider />

        {/* 결재 목록 */}
        <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
          {requests.length === 0 ? (
            <Box
              sx={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                height: '100%',
                color: 'text.secondary',
              }}
            >
              <DescriptionIcon sx={{ fontSize: 64, opacity: 0.3, mb: 2 }} />
              <Typography variant="body2">결재 요청이 없습니다</Typography>
            </Box>
          ) : (
            <>
              {/* 대기 중 */}
              {pendingRequests.length > 0 && (
                <Box sx={{ mb: 3 }}>
                  <Typography
                    variant="caption"
                    sx={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 0.5,
                      mb: 1,
                      fontWeight: 600,
                      color: '#F59E0B',
                    }}
                  >
                    <HourglassEmptyIcon sx={{ fontSize: 14 }} />
                    대기 중 ({pendingRequests.length})
                  </Typography>

                  <List sx={{ p: 0 }}>
                    {pendingRequests.map((request) => (
                      <Card
                        key={request.id}
                        sx={{
                          mb: 1,
                          cursor: 'pointer',
                          '&:hover': {
                            boxShadow: 3,
                            transform: 'translateY(-2px)',
                          },
                          transition: 'all 0.2s',
                          borderLeft: `4px solid ${getPriorityColor(request.priority)}`,
                        }}
                        onClick={() => handleRequestClick(request)}
                      >
                        <CardContent sx={{ p: 1.5, '&:last-child': { pb: 1.5 } }}>
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 0.5 }}>
                            <Typography variant="body2" sx={{ fontSize: '1.2rem' }}>
                              {getTypeIcon(request.type)}
                            </Typography>
                            <Typography
                              variant="body2"
                              sx={{
                                fontWeight: 600,
                                flex: 1,
                                overflow: 'hidden',
                                textOverflow: 'ellipsis',
                                whiteSpace: 'nowrap',
                              }}
                            >
                              {request.title}
                            </Typography>
                          </Box>

                          <Typography
                            variant="caption"
                            sx={{
                              display: 'block',
                              color: 'text.secondary',
                              mb: 0.5,
                            }}
                          >
                            요청자: {request.requester}
                          </Typography>

                          {request.summary && (
                            <Typography
                              variant="caption"
                              sx={{
                                display: 'block',
                                color: 'text.secondary',
                                mb: 0.5,
                                overflow: 'hidden',
                                textOverflow: 'ellipsis',
                                whiteSpace: 'nowrap',
                              }}
                            >
                              {request.summary}
                            </Typography>
                          )}

                          <Box sx={{ display: 'flex', gap: 0.5, mt: 1 }}>
                            <Chip
                              label={request.type}
                              size="small"
                              sx={{
                                height: 20,
                                fontSize: '0.7rem',
                                bgcolor: `${getTypeColor(request.type)}20`,
                                color: getTypeColor(request.type),
                              }}
                            />
                            <Chip
                              label={request.requestDate}
                              size="small"
                              sx={{
                                height: 20,
                                fontSize: '0.7rem',
                              }}
                            />
                          </Box>
                        </CardContent>
                      </Card>
                    ))}
                  </List>
                </Box>
              )}

              {/* 승인됨 */}
              {approvedRequests.length > 0 && (
                <Box sx={{ mb: 3 }}>
                  <Typography
                    variant="caption"
                    sx={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 0.5,
                      mb: 1,
                      fontWeight: 600,
                      color: '#10B981',
                    }}
                  >
                    <CheckCircleIcon sx={{ fontSize: 14 }} />
                    승인됨 ({approvedRequests.length})
                  </Typography>

                  <List sx={{ p: 0 }}>
                    {approvedRequests.map((request) => (
                      <ListItem
                        key={request.id}
                        sx={{
                          p: 1,
                          bgcolor: 'rgba(16, 185, 129, 0.1)',
                          borderRadius: 1,
                          mb: 0.5,
                        }}
                      >
                        <ListItemText
                          primary={
                            <Typography variant="body2" sx={{ fontSize: '0.85rem' }}>
                              {request.title}
                            </Typography>
                          }
                          secondary={
                            <Typography variant="caption">{request.requester}</Typography>
                          }
                        />
                        {getStatusIcon(request.status)}
                      </ListItem>
                    ))}
                  </List>
                </Box>
              )}

              {/* 반려됨 */}
              {rejectedRequests.length > 0 && (
                <Box>
                  <Typography
                    variant="caption"
                    sx={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 0.5,
                      mb: 1,
                      fontWeight: 600,
                      color: '#DC2626',
                    }}
                  >
                    <CancelIcon sx={{ fontSize: 14 }} />
                    반려됨 ({rejectedRequests.length})
                  </Typography>

                  <List sx={{ p: 0 }}>
                    {rejectedRequests.map((request) => (
                      <ListItem
                        key={request.id}
                        sx={{
                          p: 1,
                          bgcolor: 'rgba(220, 38, 38, 0.1)',
                          borderRadius: 1,
                          mb: 0.5,
                        }}
                      >
                        <ListItemText
                          primary={
                            <Typography variant="body2" sx={{ fontSize: '0.85rem' }}>
                              {request.title}
                            </Typography>
                          }
                          secondary={
                            <Typography variant="caption">{request.requester}</Typography>
                          }
                        />
                        {getStatusIcon(request.status)}
                      </ListItem>
                    ))}
                  </List>
                </Box>
              )}
            </>
          )}
        </Box>

        <Divider />

        {/* 하단 버튼 */}
        <Box sx={{ p: 2 }}>
          <Button
            fullWidth
            variant="contained"
            onClick={() => {
              navigate('/approval');
              if (!isPinned) onClose();
            }}
            sx={{
              bgcolor: colorScheme.primaryColor,
              '&:hover': {
                bgcolor: colorScheme.primaryColor,
                opacity: 0.9,
              },
            }}
          >
            전체 결재 목록 보기
          </Button>
        </Box>
      </Box>
    </Drawer>
  );
}
