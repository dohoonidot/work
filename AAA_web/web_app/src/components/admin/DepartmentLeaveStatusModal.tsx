import React, { useState, useEffect } from 'react';
import {
  Dialog,
  Box,
  Typography,
  IconButton,
  CircularProgress,
  Alert,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  useTheme,
  useMediaQuery,
} from '@mui/material';
import {
  Close as CloseIcon,
  PeopleAltOutlined as PeopleAltOutlinedIcon,
  ErrorOutline as ErrorOutlineIcon,
  Refresh as RefreshIcon,
} from '@mui/icons-material';
import authService from '../../services/authService';
import leaveService from '../../services/leaveService';
import type { EmployeeLeaveStatus, DepartmentLeaveStatusResponse } from '../../types/leave';

interface DepartmentLeaveStatusModalProps {
  open: boolean;
  onClose: () => void;
}

export const DepartmentLeaveStatusModal: React.FC<DepartmentLeaveStatusModalProps> = ({
  open,
  onClose,
}) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const isDarkTheme = theme.palette.mode === 'dark';
  const [loading, setLoading] = useState(true);
  const [employees, setEmployees] = useState<EmployeeLeaveStatus[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      loadLeaveStatusData();
    }
  }, [open]);

  const loadLeaveStatusData = async () => {
    setLoading(true);
    setError(null);

    try {
      const user = authService.getCurrentUser();
      if (!user || !user.userId) {
        setError('사용자 정보를 찾을 수 없습니다.');
        setLoading(false);
        return;
      }

      const response = await leaveService.getDepartmentLeaveStatus(user.userId);

      if (response.error) {
        setError(response.error);
      } else {
        setEmployees(response.employees);
      }
    } catch (err: any) {
      setError(err.message || '데이터 로딩 중 오류가 발생했습니다.');
    } finally {
      setLoading(false);
    }
  };

  // 같은 부서/이름을 가진 직원들을 그룹화
  const groupedEmployees = employees.reduce((acc, employee) => {
    const key = `${employee.department}_${employee.name}`;
    if (!acc[key]) {
      acc[key] = [];
    }
    acc[key].push(employee);
    return acc;
  }, {} as Record<string, EmployeeLeaveStatus[]>);

  const renderContent = () => {
    if (loading) {
      return (
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            height: '100%',
            p: 4,
          }}
        >
          <CircularProgress
            sx={{
              color: isDarkTheme ? 'rgba(255, 255, 255, 0.4)' : '#6B7280',
              mb: 2.5,
            }}
            size={40}
          />
          <Typography
            sx={{
              fontSize: '15px',
              color: isDarkTheme ? 'rgba(255, 255, 255, 0.4)' : '#6B7280',
              fontWeight: 500,
            }}
          >
            부서원 휴가 현황을 불러오는 중...
          </Typography>
        </Box>
      );
    }

    if (error) {
      return (
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            height: '100%',
            p: 4,
          }}
        >
          <Box
            sx={{
              p: 2,
              borderRadius: '50%',
              bgcolor: isDarkTheme ? '#3A2020' : '#FEF2F2',
              mb: 2.5,
            }}
          >
            <ErrorOutlineIcon sx={{ fontSize: 32, color: '#EF4444' }} />
          </Box>
          <Typography
            sx={{
              fontSize: '15px',
              color: isDarkTheme ? 'rgba(255, 255, 255, 0.4)' : '#6B7280',
              fontWeight: 500,
              textAlign: 'center',
              mb: 3,
            }}
          >
            {error}
          </Typography>
          <Button
            variant="contained"
            startIcon={<RefreshIcon sx={{ fontSize: 18 }} />}
            onClick={loadLeaveStatusData}
            sx={{
              bgcolor: isDarkTheme ? '#4A4A4A' : '#6B7280',
              color: 'white',
              px: 3,
              py: 1.5,
              borderRadius: '8px',
              textTransform: 'none',
              '&:hover': {
                bgcolor: isDarkTheme ? '#5A5A5A' : '#5B6370',
              },
            }}
          >
            다시 시도
          </Button>
        </Box>
      );
    }

    if (employees.length === 0) {
      return (
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            height: '100%',
            p: 4,
          }}
        >
          <Box
            sx={{
              p: 2,
              borderRadius: '50%',
              bgcolor: isDarkTheme ? '#3A3A3A' : '#F3F4F6',
              mb: 2.5,
            }}
          >
            <PeopleAltOutlinedIcon
              sx={{
                fontSize: 32,
                color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF',
              }}
            />
          </Box>
          <Typography
            sx={{
              fontSize: '15px',
              color: isDarkTheme ? 'rgba(255, 255, 255, 0.4)' : '#6B7280',
              fontWeight: 500,
            }}
          >
            부서원 휴가 현황 데이터가 없습니다.
          </Typography>
        </Box>
      );
    }

    // 모바일: 카드 형태로 표시
    if (isMobile) {
      return (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pb: 2 }}>
          {Object.entries(groupedEmployees).map(([key, group], groupIndex) => (
            <Box key={key} sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
              {group.map((employee, index) => (
                <Paper
                  key={`${employee.id}-${index}`}
                  sx={{
                    p: 2,
                    borderRadius: '12px',
                    bgcolor: isDarkTheme ? '#1A1A1A' : 'white',
                    border: `1px solid ${isDarkTheme ? '#404040' : '#E5E7EB'}`,
                    boxShadow: `0 2px 8px rgba(0, 0, 0, ${isDarkTheme ? 0.2 : 0.05})`,
                  }}
                >
                  {/* 헤더: 부서, 이름, 직급 */}
                  <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1.5 }}>
                    <Box>
                      <Typography sx={{ fontSize: '14px', fontWeight: 600, color: isDarkTheme ? '#FFFFFF' : '#111827' }}>
                        {employee.name}
                      </Typography>
                      <Typography sx={{ fontSize: '12px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#6B7280', mt: 0.5 }}>
                        {employee.department} {employee.jobPosition && `· ${employee.jobPosition}`}
                      </Typography>
                    </Box>
                    {employee.status && (
                      <Chip
                        label={employee.status === 'APPROVED' ? '승인' : employee.status === 'REQUESTED' ? '대기' : employee.status === 'REJECTED' ? '반려' : employee.status}
                        size="small"
                        sx={{
                          bgcolor: employee.status === 'APPROVED' ? '#20C99722' : employee.status === 'REQUESTED' ? '#FF8C0022' : employee.status === 'REJECTED' ? '#DC354522' : '#6B728022',
                          color: employee.status === 'APPROVED' ? '#20C997' : employee.status === 'REQUESTED' ? '#FF8C00' : employee.status === 'REJECTED' ? '#DC3545' : '#6B7280',
                          fontSize: '11px',
                          fontWeight: 600,
                          height: 22,
                        }}
                      />
                    )}
                  </Box>

                  {/* 구분선 */}
                  <Box sx={{ height: '1px', bgcolor: isDarkTheme ? '#404040' : '#E5E7EB', mb: 1.5 }} />

                  {/* 상세 정보 그리드 */}
                  <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 1.5 }}>
                    {/* 입사일 */}
                    <Box>
                      <Typography sx={{ fontSize: '11px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF', mb: 0.5 }}>
                        입사일
                      </Typography>
                      <Typography sx={{ fontSize: '13px', fontWeight: 500, color: isDarkTheme ? '#FFFFFF' : '#374151' }}>
                        {employee.joinDate || '-'}
                      </Typography>
                    </Box>

                    {/* 휴가 종류 */}
                    <Box>
                      <Typography sx={{ fontSize: '11px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF', mb: 0.5 }}>
                        휴가 종류
                      </Typography>
                      <Chip
                        label={employee.leaveType || '-'}
                        size="small"
                        sx={{
                          bgcolor: isDarkTheme ? '#3A3A5A' : '#EEF2FF',
                          color: isDarkTheme ? '#90CDF4' : '#4F46E5',
                          fontSize: '11px',
                          fontWeight: 600,
                          height: 22,
                        }}
                      />
                    </Box>

                    {/* 총일수 */}
                    <Box>
                      <Typography sx={{ fontSize: '11px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF', mb: 0.5 }}>
                        총일수
                      </Typography>
                      <Typography sx={{ fontSize: '13px', fontWeight: 600, color: isDarkTheme ? '#FFFFFF' : '#374151' }}>
                        {employee.totalDays.toFixed(1)}일
                      </Typography>
                    </Box>

                    {/* 사용일수 */}
                    <Box>
                      <Typography sx={{ fontSize: '11px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF', mb: 0.5 }}>
                        사용일수
                      </Typography>
                      <Typography sx={{ fontSize: '13px', fontWeight: 600, color: isDarkTheme ? 'rgba(255, 255, 255, 0.7)' : '#475569' }}>
                        {employee.usedDays.toFixed(1)}일
                      </Typography>
                    </Box>

                    {/* 잔여일수 */}
                    <Box>
                      <Typography sx={{ fontSize: '11px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF', mb: 0.5 }}>
                        잔여일수
                      </Typography>
                      <Typography sx={{ fontSize: '13px', fontWeight: 600, color: isDarkTheme ? '#FFFFFF' : '#1F2937' }}>
                        {employee.remainDays.toFixed(1)}일
                      </Typography>
                    </Box>

                    {/* 근무일수 */}
                    <Box>
                      <Typography sx={{ fontSize: '11px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF', mb: 0.5 }}>
                        근무일수
                      </Typography>
                      <Typography sx={{ fontSize: '13px', fontWeight: 500, color: isDarkTheme ? '#FFFFFF' : '#374151' }}>
                        {employee.workdaysCount || 0}일
                      </Typography>
                    </Box>
                  </Box>

                  {/* 휴가 기간 (있는 경우) */}
                  {(employee.startDate || employee.endDate) && (
                    <>
                      <Box sx={{ height: '1px', bgcolor: isDarkTheme ? '#404040' : '#E5E7EB', my: 1.5 }} />
                      <Box>
                        <Typography sx={{ fontSize: '11px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF', mb: 0.5 }}>
                          휴가 기간
                        </Typography>
                        <Typography sx={{ fontSize: '13px', fontWeight: 500, color: isDarkTheme ? '#FFFFFF' : '#374151' }}>
                          {employee.startDate ? new Date(employee.startDate).toLocaleDateString('ko-KR') : '-'} ~ {employee.endDate ? new Date(employee.endDate).toLocaleDateString('ko-KR') : '-'}
                        </Typography>
                        {employee.halfDaySlot && employee.halfDaySlot !== 'ALL' && (
                          <Typography sx={{ fontSize: '11px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF', mt: 0.5 }}>
                            {employee.halfDaySlot === 'AM' ? '오전' : employee.halfDaySlot === 'PM' ? '오후' : employee.halfDaySlot}
                          </Typography>
                        )}
                      </Box>
                    </>
                  )}

                  {/* 신청일 (있는 경우) */}
                  {employee.requestedDate && (
                    <>
                      <Box sx={{ height: '1px', bgcolor: isDarkTheme ? '#404040' : '#E5E7EB', my: 1.5 }} />
                      <Box>
                        <Typography sx={{ fontSize: '11px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF', mb: 0.5 }}>
                          신청일
                        </Typography>
                        <Typography sx={{ fontSize: '13px', fontWeight: 500, color: isDarkTheme ? '#FFFFFF' : '#374151' }}>
                          {new Date(employee.requestedDate).toLocaleDateString('ko-KR')} {new Date(employee.requestedDate).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' })}
                        </Typography>
                      </Box>
                    </>
                  )}

                  {/* 사유 (있는 경우) */}
                  {employee.reason && (
                    <>
                      <Box sx={{ height: '1px', bgcolor: isDarkTheme ? '#404040' : '#E5E7EB', my: 1.5 }} />
                      <Box>
                        <Typography sx={{ fontSize: '11px', color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF', mb: 0.5 }}>
                          사유
                        </Typography>
                        <Typography sx={{ fontSize: '13px', color: isDarkTheme ? '#FFFFFF' : '#374151', wordBreak: 'break-word' }}>
                          {employee.reason}
                        </Typography>
                      </Box>
                    </>
                  )}
                </Paper>
              ))}
            </Box>
          ))}
        </Box>
      );
    }

    // 데스크톱: 테이블 형태로 표시 (기존 코드)
    return (
      <TableContainer
        component={Paper}
        sx={{
          bgcolor: isDarkTheme ? '#1A1A1A' : 'white',
          borderRadius: '12px',
          border: `1px solid ${isDarkTheme ? '#505050' : '#E5E7EB'}`,
          boxShadow: `0 4px 10px rgba(0, 0, 0, ${isDarkTheme ? 0.2 : 0.05})`,
          maxHeight: 'calc(100vh - 200px)',
          overflow: 'auto',
        }}
      >
        <Table stickyHeader>
          <TableHead>
            <TableRow>
              <TableCell
                align="center"
                sx={{
                  bgcolor: isDarkTheme ? '#3A3A3A' : '#F8F9FA',
                  borderBottom: `1px solid ${isDarkTheme ? '#505050' : '#E5E7EB'}`,
                  fontSize: '14px',
                  fontWeight: 600,
                  color: isDarkTheme ? 'rgba(255, 255, 255, 0.7)' : '#374151',
                  py: 1.75,
                }}
              >
                부서
              </TableCell>
              <TableCell
                align="center"
                sx={{
                  bgcolor: isDarkTheme ? '#3A3A3A' : '#F8F9FA',
                  borderBottom: `1px solid ${isDarkTheme ? '#505050' : '#E5E7EB'}`,
                  fontSize: '14px',
                  fontWeight: 600,
                  color: isDarkTheme ? 'rgba(255, 255, 255, 0.7)' : '#374151',
                  py: 1.75,
                }}
              >
                이름
              </TableCell>
              <TableCell
                align="center"
                sx={{
                  bgcolor: isDarkTheme ? '#3A3A3A' : '#F8F9FA',
                  borderBottom: `1px solid ${isDarkTheme ? '#505050' : '#E5E7EB'}`,
                  fontSize: '14px',
                  fontWeight: 600,
                  color: isDarkTheme ? 'rgba(255, 255, 255, 0.7)' : '#374151',
                  py: 1.75,
                }}
              >
                입사일
              </TableCell>
              <TableCell
                align="center"
                sx={{
                  bgcolor: isDarkTheme ? '#3A3A3A' : '#F8F9FA',
                  borderBottom: `1px solid ${isDarkTheme ? '#505050' : '#E5E7EB'}`,
                  fontSize: '14px',
                  fontWeight: 600,
                  color: isDarkTheme ? 'rgba(255, 255, 255, 0.7)' : '#374151',
                  py: 1.75,
                }}
              >
                휴가종류
              </TableCell>
              <TableCell
                align="center"
                sx={{
                  bgcolor: isDarkTheme ? '#3A3A3A' : '#F8F9FA',
                  borderBottom: `1px solid ${isDarkTheme ? '#505050' : '#E5E7EB'}`,
                  fontSize: '14px',
                  fontWeight: 600,
                  color: isDarkTheme ? 'rgba(255, 255, 255, 0.7)' : '#374151',
                  py: 1.75,
                }}
              >
                총일수
              </TableCell>
              <TableCell
                align="center"
                sx={{
                  bgcolor: isDarkTheme ? '#3A3A3A' : '#F8F9FA',
                  borderBottom: `1px solid ${isDarkTheme ? '#505050' : '#E5E7EB'}`,
                  fontSize: '14px',
                  fontWeight: 600,
                  color: isDarkTheme ? 'rgba(255, 255, 255, 0.7)' : '#374151',
                  py: 1.75,
                }}
              >
                사용일수
              </TableCell>
              <TableCell
                align="center"
                sx={{
                  bgcolor: isDarkTheme ? '#3A3A3A' : '#F8F9FA',
                  borderBottom: `1px solid ${isDarkTheme ? '#505050' : '#E5E7EB'}`,
                  fontSize: '14px',
                  fontWeight: 600,
                  color: isDarkTheme ? 'rgba(255, 255, 255, 0.7)' : '#374151',
                  py: 1.75,
                }}
              >
                잔여일수
              </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {Object.entries(groupedEmployees).map(([key, group], groupIndex) => {
              const isEven = groupIndex % 2 === 0;
              return group.map((employee, index) => (
                <TableRow
                  key={`${employee.id}-${index}`}
                  sx={{
                    bgcolor: isDarkTheme
                      ? (isEven ? '#1A1A1A' : '#2D2D2D')
                      : (isEven ? 'white' : '#FAFAFA'),
                    borderBottom: `0.8px solid ${isDarkTheme ? '#404040' : '#F1F3F5'}`,
                  }}
                >
                  {index === 0 && (
                    <>
                      <TableCell
                        rowSpan={group.length}
                        align="center"
                        sx={{
                          fontSize: '13px',
                          fontWeight: 500,
                          color: isDarkTheme ? 'rgba(255, 255, 255, 0.4)' : '#4B5563',
                          py: 1.5,
                          verticalAlign: 'middle',
                        }}
                      >
                        {employee.department}
                      </TableCell>
                      <TableCell
                        rowSpan={group.length}
                        align="center"
                        sx={{
                          fontSize: '13px',
                          fontWeight: 600,
                          color: isDarkTheme ? '#FFFFFF' : '#111827',
                          py: 1.5,
                          verticalAlign: 'middle',
                        }}
                      >
                        {employee.name}
                      </TableCell>
                    </>
                  )}
                  <TableCell
                    align="center"
                    sx={{
                      fontSize: '12px',
                      color: isDarkTheme ? 'rgba(255, 255, 255, 0.5)' : '#9CA3AF',
                      fontWeight: 400,
                      py: 1.5,
                    }}
                  >
                    {employee.joinDate || '-'}
                  </TableCell>
                  <TableCell align="center" sx={{ py: 1.5 }}>
                    <Chip
                      label={employee.leaveType}
                      size="small"
                      sx={{
                        bgcolor: isDarkTheme ? '#3A3A5A' : '#EEF2FF',
                        color: isDarkTheme ? '#90CDF4' : '#4F46E5',
                        fontSize: '12px',
                        fontWeight: 600,
                        height: 24,
                        px: 1,
                      }}
                    />
                  </TableCell>
                  <TableCell align="center" sx={{ py: 1.5 }}>
                    <Box
                      sx={{
                        display: 'inline-block',
                        px: 1,
                        py: 0.5,
                        borderRadius: '6px',
                        bgcolor: isDarkTheme ? '#3A3A3A' : '#F3F4F6',
                        fontSize: '12px',
                        fontWeight: 600,
                        color: isDarkTheme ? '#FFFFFF' : '#374151',
                      }}
                    >
                      {employee.totalDays.toFixed(1)}일
                    </Box>
                  </TableCell>
                  <TableCell align="center" sx={{ py: 1.5 }}>
                    <Box
                      sx={{
                        display: 'inline-block',
                        px: 1,
                        py: 0.5,
                        borderRadius: '6px',
                        bgcolor: isDarkTheme ? '#2A3A2A' : '#F1F5F9',
                        fontSize: '12px',
                        fontWeight: 600,
                        color: isDarkTheme ? 'rgba(255, 255, 255, 0.7)' : '#475569',
                      }}
                    >
                      {employee.usedDays.toFixed(1)}일
                    </Box>
                  </TableCell>
                  <TableCell align="center" sx={{ py: 1.5 }}>
                    <Box
                      sx={{
                        display: 'inline-block',
                        px: 1,
                        py: 0.5,
                        borderRadius: '6px',
                        bgcolor: isDarkTheme ? '#3A2A3A' : '#E5E7EB',
                        fontSize: '12px',
                        fontWeight: 600,
                        color: isDarkTheme ? '#FFFFFF' : '#1F2937',
                      }}
                    >
                      {employee.remainDays.toFixed(1)}일
                    </Box>
                  </TableCell>
                </TableRow>
              ));
            })}
          </TableBody>
        </Table>
      </TableContainer>
    );
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth={isMobile ? false : 'lg'}
      fullWidth
      fullScreen={isMobile}
      PaperProps={{
        sx: {
          width: isMobile ? '100%' : '80%',
          height: isMobile ? '100%' : '80%',
          maxWidth: isMobile ? '100%' : 'none',
          maxHeight: isMobile ? '100%' : 'none',
          borderRadius: isMobile ? 0 : '20px',
          bgcolor: isDarkTheme ? '#2D2D2D' : 'white',
          boxShadow: `0 10px 20px rgba(0, 0, 0, ${isDarkTheme ? 0.3 : 0.1})`,
        },
      }}
    >
      <Box
        sx={{
          display: 'flex',
          flexDirection: 'column',
          height: '100%',
        }}
      >
        {/* 헤더 */}
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            p: 3,
            borderBottom: `1px solid ${isDarkTheme ? '#404040' : '#E5E7EB'}`,
          }}
        >
          <Box
            sx={{
              p: 1.25,
              borderRadius: '10px',
              bgcolor: isDarkTheme ? '#3A3A3A' : '#F3F4F6',
              mr: 2,
            }}
          >
            <PeopleAltOutlinedIcon
              sx={{
                fontSize: 20,
                color: isDarkTheme ? 'rgba(255, 255, 255, 0.4)' : '#6B7280',
              }}
            />
          </Box>
          <Typography
            sx={{
              fontSize: '20px',
              fontWeight: 600,
              color: isDarkTheme ? '#FFFFFF' : '#111827',
              flex: 1,
            }}
          >
            부서원 휴가 현황
          </Typography>
          <IconButton
            onClick={onClose}
            sx={{
              bgcolor: isDarkTheme ? '#3A3A3A' : '#F9FAFB',
              borderRadius: '8px',
              color: isDarkTheme ? 'rgba(255, 255, 255, 0.4)' : '#9CA3AF',
              '&:hover': {
                bgcolor: isDarkTheme ? '#4A4A4A' : '#E5E7EB',
              },
            }}
          >
            <CloseIcon sx={{ fontSize: 20 }} />
          </IconButton>
        </Box>

        {/* 메인 콘텐츠 */}
        <Box
          sx={{
            flex: 1,
            p: isMobile ? 2 : 3,
            bgcolor: isDarkTheme ? '#2D2D2D' : '#FAFAFA',
            overflow: 'auto',
          }}
        >
          {renderContent()}
        </Box>
      </Box>
    </Dialog>
  );
};

