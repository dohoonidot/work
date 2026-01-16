import React, { useState, useEffect } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Checkbox,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  ListItemIcon,
  CircularProgress,
  Box,
  Typography,
  IconButton,
  Chip,
  Alert,
  TextField,
  InputAdornment,
} from '@mui/material';
import {
  Close as CloseIcon,
  PeopleAltOutlined as PeopleIcon,
  Business as BusinessIcon,
  Email as EmailIcon,
  Refresh as RefreshIcon,
  Search as SearchIcon,
  FormatListNumbered as SequentialIcon,
  ArrowForward as ArrowForwardIcon,
} from '@mui/icons-material';
import leaveService from '../../services/leaveService';
import type { Approver } from '../../types/leave';

interface ApproverSelectionModalProps {
  open: boolean;
  onClose: () => void;
  onConfirm: (selectedApproverIds: string[], selectedApprovers: Approver[]) => void;
  initialSelectedApproverIds?: string[];
  sequentialApproval?: boolean; // 순차결재 모드 활성화 여부
}

export default function ApproverSelectionModal({
  open,
  onClose,
  onConfirm,
  initialSelectedApproverIds = [],
  sequentialApproval = false,
}: ApproverSelectionModalProps) {
  const [approverList, setApproverList] = useState<Approver[]>([]);
  const [selectedApproverIds, setSelectedApproverIds] = useState<Set<string>>(
    new Set(initialSelectedApproverIds)
  );
  // 순차결재 모드에서 선택된 승인자의 순서를 추적
  const [selectedApproverOrder, setSelectedApproverOrder] = useState<string[]>(
    initialSelectedApproverIds
  );
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchText, setSearchText] = useState('');

  useEffect(() => {
    if (open) {
      setSelectedApproverIds(new Set(initialSelectedApproverIds));
      // 순차결재 모드인 경우 초기 순서 리스트 설정
      if (sequentialApproval) {
        setSelectedApproverOrder(initialSelectedApproverIds);
      }
      setSearchText(''); // 모달 열릴 때 검색어 초기화
      loadApprovers();
    }
  }, [open, initialSelectedApproverIds, sequentialApproval]);

  const loadApprovers = async () => {
    try {
      setIsLoading(true);
      setError(null);
      
      const response = await leaveService.getApproverList();
      
      if (response.error) {
        setError(response.error);
      } else {
        setApproverList(response.approverList || []);
      }
    } catch (err: any) {
      console.error('승인자 목록 로드 실패:', err);
      setError('승인자 목록을 불러오는데 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleToggleApprover = (approverId: string) => {
    const newSelected = new Set(selectedApproverIds);
    if (newSelected.has(approverId)) {
      // 선택 해제
      newSelected.delete(approverId);
      // 순차결재 모드인 경우 순서 리스트에서도 제거
      if (sequentialApproval) {
        setSelectedApproverOrder((prev) => prev.filter((id) => id !== approverId));
      }
    } else {
      // 선택 추가
      newSelected.add(approverId);
      // 순차결재 모드인 경우 선택 순서 추적
      if (sequentialApproval) {
        setSelectedApproverOrder((prev) => [...prev, approverId]);
      }
    }
    setSelectedApproverIds(newSelected);
  };

  const handleConfirm = () => {
    // 순차결재 모드인 경우 순서가 있는 리스트 반환
    // 일반 모드인 경우 Set을 List로 변환하여 반환
    const resultIds = sequentialApproval
      ? selectedApproverOrder
      : Array.from(selectedApproverIds);

    // 선택된 승인자의 전체 정보 가져오기
    const selectedApprovers = resultIds
      .map(id => approverList.find(a => a.approverId === id))
      .filter((a): a is Approver => a !== undefined);

    onConfirm(resultIds, selectedApprovers);
    onClose();
  };

  // 검색어로 필터링된 승인자 목록
  const getFilteredApprovers = (): Approver[] => {
    if (!searchText.trim()) {
      return approverList;
    }
    
    const searchLower = searchText.toLowerCase();
    return approverList.filter((approver) => {
      return (
        approver.approverName.toLowerCase().includes(searchLower) ||
        approver.approverId.toLowerCase().includes(searchLower) ||
        approver.department.toLowerCase().includes(searchLower) ||
        approver.jobPosition.toLowerCase().includes(searchLower)
      );
    });
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="sm"
      fullWidth
      disableEnforceFocus
      disableAutoFocus
    >
      <DialogTitle>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <Box
              sx={{
                p: 1,
                borderRadius: '10px',
                bgcolor: '#1E88E5',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <PeopleIcon sx={{ color: 'white', fontSize: 20 }} />
            </Box>
            <Typography sx={{ fontSize: '18px', fontWeight: 700 }}>
              {sequentialApproval ? '승인자 선택 (순차결재)' : '승인자 선택'}
            </Typography>
          </Box>
          <IconButton onClick={onClose} size="small">
            <CloseIcon />
          </IconButton>
        </Box>
        <Typography sx={{ fontSize: '13px', color: '#6B7280', mt: 1 }}>
          {selectedApproverIds.size}명 선택됨
          {sequentialApproval && selectedApproverOrder.length > 0 && (
            <span> · 순서: {selectedApproverOrder.map((_, idx) => idx + 1).join(' → ')}</span>
          )}
        </Typography>
      </DialogTitle>

      <DialogContent>
        {/* 검색 필드 */}
        {!isLoading && !error && approverList.length > 0 && (
          <TextField
            fullWidth
            placeholder="이름, 이메일, 부서, 직급으로 검색"
            value={searchText}
            onChange={(e) => setSearchText(e.target.value)}
            sx={{ mb: 2 }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon sx={{ color: '#9CA3AF' }} />
                </InputAdornment>
              ),
            }}
          />
        )}

        {isLoading ? (
          <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', py: 4 }}>
            <CircularProgress />
            <Typography sx={{ mt: 2, color: '#6B7280' }}>승인자 목록을 불러오는 중...</Typography>
          </Box>
        ) : error ? (
          <Box>
            <Alert severity="error" sx={{ mb: 2 }}>
              {error}
            </Alert>
            <Button
              startIcon={<RefreshIcon />}
              onClick={loadApprovers}
              variant="contained"
              fullWidth
            >
              다시 시도
            </Button>
          </Box>
        ) : approverList.length === 0 ? (
          <Box sx={{ textAlign: 'center', py: 4 }}>
            <PeopleIcon sx={{ fontSize: 64, color: '#E5E7EB', mb: 2 }} />
            <Typography sx={{ color: '#6B7280' }}>승인자 목록이 없습니다.</Typography>
          </Box>
        ) : (
          <>
            {/* 선택된 승인자 표시 (모든 모드) */}
            {selectedApproverIds.size > 0 && (
              <Box sx={{ mb: 2 }}>
                <Typography sx={{ fontSize: '13px', fontWeight: 600, mb: 1, color: '#374151' }}>
                  {sequentialApproval ? '선택된 승인자 순서' : '선택된 승인자'}
                </Typography>
                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                  {sequentialApproval ? (
                    // 순차결재 모드: 순서 표시
                    selectedApproverOrder.map((approverId, index) => {
                      const approver = approverList.find((a) => a.approverId === approverId);
                      if (!approver) return null;

                      return (
                        <Chip
                          key={approverId}
                          label={
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              <Box
                                sx={{
                                  width: 24,
                                  height: 24,
                                  borderRadius: '50%',
                                  bgcolor: 'white',
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'center',
                                  fontSize: '12px',
                                  fontWeight: 700,
                                  color: '#1E88E5',
                                }}
                              >
                                {index + 1}
                              </Box>
                              <Typography sx={{ fontSize: '13px', fontWeight: 600 }}>
                                {approver.approverName}
                              </Typography>
                              {index < selectedApproverOrder.length - 1 && (
                                <ArrowForwardIcon sx={{ fontSize: 16, color: '#9CA3AF' }} />
                              )}
                            </Box>
                          }
                          sx={{
                            bgcolor: '#1E88E5',
                            color: 'white',
                            height: 36,
                            '& .MuiChip-deleteIcon': {
                              color: 'white',
                            },
                          }}
                          onDelete={() => handleToggleApprover(approverId)}
                        />
                      );
                    })
                  ) : (
                    // 일반 모드: 선택된 승인자 목록
                    Array.from(selectedApproverIds).map((approverId) => {
                      const approver = approverList.find((a) => a.approverId === approverId);
                      if (!approver) return null;

                      return (
                        <Chip
                          key={approverId}
                          label={approver.approverName}
                          sx={{
                            bgcolor: '#1E88E5',
                            color: 'white',
                            fontSize: '13px',
                            fontWeight: 600,
                            height: 32,
                            '& .MuiChip-deleteIcon': {
                              color: 'white',
                            },
                          }}
                          onDelete={() => handleToggleApprover(approverId)}
                        />
                      );
                    })
                  )}
                </Box>
              </Box>
            )}
            
            <List sx={{ maxHeight: 400, overflow: 'auto' }}>
              {getFilteredApprovers().length === 0 ? (
                <Box sx={{ textAlign: 'center', py: 4 }}>
                  <Typography sx={{ color: '#6B7280' }}>
                    검색 결과가 없습니다.
                  </Typography>
                </Box>
              ) : (
                getFilteredApprovers().map((approver) => {
                const isSelected = selectedApproverIds.has(approver.approverId);
                // 순차결재 모드에서 순서 번호 표시
                const sequenceNumber = sequentialApproval && isSelected
                  ? selectedApproverOrder.indexOf(approver.approverId) + 1
                  : null;
                
                return (
                  <ListItem
                    key={approver.approverId}
                    disablePadding
                    sx={{
                      mb: 1,
                      borderRadius: '12px',
                      border: `1px solid ${isSelected ? '#1E88E5' : '#E9ECEF'}`,
                      bgcolor: isSelected ? 'rgba(30, 136, 229, 0.1)' : '#F8F9FA',
                    }}
                  >
                    <ListItemButton
                      onClick={() => handleToggleApprover(approver.approverId)}
                      sx={{ borderRadius: '12px' }}
                    >
                      <ListItemIcon>
                        {sequentialApproval && sequenceNumber ? (
                          <Box
                            sx={{
                              width: 32,
                              height: 32,
                              borderRadius: '50%',
                              bgcolor: '#1E88E5',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              color: 'white',
                              fontSize: '14px',
                              fontWeight: 700,
                            }}
                          >
                            {sequenceNumber}
                          </Box>
                        ) : (
                          <Checkbox
                            checked={isSelected}
                            edge="start"
                            sx={{
                              color: '#1E88E5',
                              '&.Mui-checked': {
                                color: '#1E88E5',
                              },
                            }}
                          />
                        )}
                      </ListItemIcon>
                      <ListItemText
                        primary={
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Typography sx={{ fontSize: '15px', fontWeight: 600 }}>
                              {approver.approverName}
                            </Typography>
                            {approver.jobPosition && (
                              <Chip
                                label={approver.jobPosition}
                                size="small"
                                sx={{
                                  bgcolor: 'rgba(30, 136, 229, 0.1)',
                                  color: '#1E88E5',
                                  fontSize: '11px',
                                  fontWeight: 600,
                                  height: 20,
                                }}
                              />
                            )}
                          </Box>
                        }
                        secondary={
                          <Box component="div" sx={{ mt: 0.5 }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 0.5 }}>
                              <BusinessIcon sx={{ fontSize: 14, color: '#9CA3AF' }} />
                              <Typography sx={{ fontSize: '12px', color: '#6B7280' }}>
                                {approver.department}
                              </Typography>
                            </Box>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                              <EmailIcon sx={{ fontSize: 14, color: '#9CA3AF' }} />
                              <Typography
                                sx={{ fontSize: '11px', color: '#9CA3AF' }}
                                noWrap
                              >
                                {approver.approverId}
                              </Typography>
                            </Box>
                          </Box>
                        }
                        secondaryTypographyProps={{ component: 'div' }}
                      />
                    </ListItemButton>
                  </ListItem>
                );
                })
              )}
            </List>
          </>
        )}
      </DialogContent>

      <DialogActions sx={{ p: 2, pt: 1 }}>
        <Button onClick={onClose} variant="outlined" sx={{ flex: 1 }}>
          취소
        </Button>
        <Button
          onClick={handleConfirm}
          variant="contained"
          disabled={selectedApproverIds.size === 0}
          sx={{ flex: 1, bgcolor: '#1E88E5' }}
        >
          확인
        </Button>
      </DialogActions>
    </Dialog>
  );
}

