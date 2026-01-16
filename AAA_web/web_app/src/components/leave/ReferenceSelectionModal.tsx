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
  TextField,
  InputAdornment,
  Collapse,
  Chip,
  Alert,
} from '@mui/material';
import {
  Close as CloseIcon,
  PersonAddOutlined as PersonAddIcon,
  Search as SearchIcon,
  ExpandMore as ExpandMoreIcon,
  ExpandLess as ExpandLessIcon,
  Business as BusinessIcon,
} from '@mui/icons-material';
import departmentService from '../../services/departmentService';
import type { CcPerson } from '../../types/leave';

interface ReferenceSelectionModalProps {
  open: boolean;
  onClose: () => void;
  onConfirm: (selectedReferences: CcPerson[]) => void;
  currentReferences?: CcPerson[];
}

export default function ReferenceSelectionModal({
  open,
  onClose,
  onConfirm,
  currentReferences = [],
}: ReferenceSelectionModalProps) {
  const [selectedReferences, setSelectedReferences] = useState<CcPerson[]>(currentReferences);
  const [departments, setDepartments] = useState<string[]>([]);
  const [departmentMembers, setDepartmentMembers] = useState<Map<string, CcPerson[]>>(new Map());
  const [expandedDepartments, setExpandedDepartments] = useState<Set<string>>(new Set());
  const [searchText, setSearchText] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setSelectedReferences(currentReferences);
      loadDepartments();
    }
  }, [open, currentReferences]);

  const loadDepartments = async () => {
    try {
      setIsLoading(true);
      setError(null);
      
      const deptList = await departmentService.getDepartmentList();
      setDepartments(deptList);
      
      // 각 부서의 멤버를 로드
      for (const department of deptList) {
        await loadDepartmentMembers(department);
      }
    } catch (err: any) {
      console.error('부서 목록 로드 실패:', err);
      setError('부서 목록을 불러오는데 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const loadDepartmentMembers = async (department: string) => {
    try {
      const members = await departmentService.getDepartmentMembers(department);
      const ccPersons: any[] = members.map((member) => ({
        name: member.name,
        department: member.department || department,
        userId: member.userId || member.user_id || member.name, // userId 추가 (없으면 이름 사용)
      }));

      setDepartmentMembers((prev) => {
        const newMap = new Map(prev);
        newMap.set(department, ccPersons);
        return newMap;
      });
    } catch (err: any) {
      console.error(`부서 멤버 로드 실패 (${department}):`, err);
      setDepartmentMembers((prev) => {
        const newMap = new Map(prev);
        newMap.set(department, []);
        return newMap;
      });
    }
  };

  const toggleDepartmentExpansion = (department: string) => {
    const newExpanded = new Set(expandedDepartments);
    if (newExpanded.has(department)) {
      newExpanded.delete(department);
    } else {
      newExpanded.add(department);
    }
    setExpandedDepartments(newExpanded);
  };

  const isPersonSelected = (person: CcPerson): boolean => {
    return selectedReferences.some(
      (ref) => ref.name === person.name && ref.department === person.department
    );
  };

  const togglePerson = (person: CcPerson) => {
    const isSelected = isPersonSelected(person);
    if (isSelected) {
      setSelectedReferences((prev) =>
        prev.filter((ref) => !(ref.name === person.name && ref.department === person.department))
      );
    } else {
      setSelectedReferences((prev) => [...prev, person]);
    }
  };

  // 부서 전체 선택 여부 확인
  const isDepartmentFullySelected = (department: string): boolean => {
    const members = departmentMembers.get(department) || [];
    if (members.length === 0) return false;
    return members.every((member) => isPersonSelected(member));
  };

  // 부서 전체 선택/해제
  const toggleDepartment = (department: string) => {
    const members = departmentMembers.get(department) || [];
    const isFullySelected = isDepartmentFullySelected(department);

    if (isFullySelected) {
      // 전체 해제
      setSelectedReferences((prev) =>
        prev.filter((ref) => ref.department !== department)
      );
    } else {
      // 전체 선택
      setSelectedReferences((prev) => {
        // 기존에 선택되지 않은 멤버만 추가
        const newMembers = members.filter((member) => !isPersonSelected(member));
        return [...prev, ...newMembers];
      });
    }
  };

  const getFilteredDepartments = (): string[] => {
    if (!searchText) return departments;
    
    return departments.filter((dept) => {
      if (dept.toLowerCase().includes(searchText.toLowerCase())) return true;
      const members = departmentMembers.get(dept) || [];
      return members.some((member) =>
        member.name.toLowerCase().includes(searchText.toLowerCase())
      );
    });
  };

  const getFilteredMembers = (department: string): CcPerson[] => {
    const members = departmentMembers.get(department) || [];
    if (!searchText) return members;
    
    return members.filter((member) =>
      member.name.toLowerCase().includes(searchText.toLowerCase())
    );
  };

  const handleConfirm = () => {
    onConfirm(selectedReferences);
    onClose();
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
                bgcolor: '#20C997',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <PersonAddIcon sx={{ color: 'white', fontSize: 20 }} />
            </Box>
            <Typography sx={{ fontSize: '18px', fontWeight: 700 }}>
              참조자 선택
            </Typography>
          </Box>
          <IconButton onClick={onClose} size="small">
            <CloseIcon />
          </IconButton>
        </Box>
      </DialogTitle>

      <DialogContent>
        {/* 검색 필드 */}
        <TextField
          fullWidth
          placeholder="부서명 또는 이름으로 검색"
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

        {/* 선택된 참조자 표시 */}
        {selectedReferences.length > 0 && (
          <Box
            sx={{
              p: 1.5,
              mb: 2,
              borderRadius: '12px',
              bgcolor: 'rgba(32, 201, 151, 0.1)',
              border: '1px solid rgba(32, 201, 151, 0.2)',
            }}
          >
            <Typography sx={{ fontSize: '12px', fontWeight: 600, color: '#20C997', mb: 1 }}>
              선택된 참조자 ({selectedReferences.length}명)
            </Typography>
            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
              {selectedReferences.slice(0, 5).map((ref, idx) => (
                <Chip
                  key={idx}
                  label={`${ref.name}(${ref.department})`}
                  size="small"
                  sx={{
                    bgcolor: '#20C997',
                    color: 'white',
                    fontSize: '10px',
                    height: 20,
                  }}
                />
              ))}
              {selectedReferences.length > 5 && (
                <Chip
                  label={`+${selectedReferences.length - 5}명 더`}
                  size="small"
                  sx={{
                    bgcolor: 'rgba(32, 201, 151, 0.2)',
                    color: '#20C997',
                    fontSize: '10px',
                    height: 20,
                  }}
                />
              )}
            </Box>
          </Box>
        )}

        {/* 부서 및 멤버 리스트 */}
        {isLoading ? (
          <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', py: 4 }}>
            <CircularProgress />
            <Typography sx={{ mt: 2, color: '#6B7280' }}>부서 목록을 불러오는 중...</Typography>
          </Box>
        ) : error ? (
          <Alert severity="error">{error}</Alert>
        ) : (
          <List sx={{ maxHeight: 400, overflow: 'auto' }}>
            {getFilteredDepartments().map((department) => {
              const members = getFilteredMembers(department);
              const isExpanded = expandedDepartments.has(department);
              
              if (members.length === 0 && searchText) return null;
              
              return (
                <Box key={department}>
                  <ListItem
                    disablePadding
                    sx={{
                      mb: 0.5,
                      borderRadius: '8px',
                      bgcolor: '#F8F9FA',
                    }}
                  >
                    <ListItemButton onClick={() => toggleDepartmentExpansion(department)}>
                      <ListItemIcon>
                        <Checkbox
                          checked={isDepartmentFullySelected(department)}
                          onClick={(e) => {
                            e.stopPropagation();
                            toggleDepartment(department);
                          }}
                          sx={{
                            color: '#20C997',
                            '&.Mui-checked': {
                              color: '#20C997',
                            },
                            padding: 0,
                            marginRight: 1,
                          }}
                        />
                        <BusinessIcon sx={{ color: '#6B7280', fontSize: 18 }} />
                      </ListItemIcon>
                      <ListItemText
                        primary={
                          <Typography sx={{ fontSize: '14px', fontWeight: 600 }}>
                            {department}
                          </Typography>
                        }
                        secondary={
                          <Typography sx={{ fontSize: '12px', color: '#9CA3AF' }}>
                            {members.length}명
                          </Typography>
                        }
                      />
                      {isExpanded ? (
                        <ExpandLessIcon sx={{ color: '#6B7280' }} />
                      ) : (
                        <ExpandMoreIcon sx={{ color: '#6B7280' }} />
                      )}
                    </ListItemButton>
                  </ListItem>
                  
                  <Collapse in={isExpanded} timeout="auto" unmountOnExit>
                    <List component="div" disablePadding>
                      {members.map((member, idx) => {
                        const isSelected = isPersonSelected(member);
                        
                        return (
                          <ListItem
                            key={idx}
                            disablePadding
                            sx={{
                              pl: 4,
                              mb: 0.5,
                              borderRadius: '8px',
                              bgcolor: isSelected ? 'rgba(32, 201, 151, 0.1)' : 'transparent',
                              border: `1px solid ${isSelected ? '#20C997' : 'transparent'}`,
                            }}
                          >
                            <ListItemButton onClick={() => togglePerson(member)}>
                              <ListItemIcon>
                                <Checkbox
                                  checked={isSelected}
                                  edge="start"
                                  sx={{
                                    color: '#20C997',
                                    '&.Mui-checked': {
                                      color: '#20C997',
                                    },
                                  }}
                                />
                              </ListItemIcon>
                              <ListItemText
                                primary={
                                  <Typography sx={{ fontSize: '14px', fontWeight: 500 }}>
                                    {member.name}
                                  </Typography>
                                }
                              />
                            </ListItemButton>
                          </ListItem>
                        );
                      })}
                    </List>
                  </Collapse>
                </Box>
              );
            })}
          </List>
        )}
      </DialogContent>

      <DialogActions sx={{ p: 2, pt: 1 }}>
        <Button onClick={onClose} variant="outlined" sx={{ flex: 1 }}>
          취소
        </Button>
        <Button
          onClick={handleConfirm}
          variant="contained"
          sx={{ flex: 1, bgcolor: '#20C997' }}
        >
          확인
        </Button>
      </DialogActions>
    </Dialog>
  );
}

