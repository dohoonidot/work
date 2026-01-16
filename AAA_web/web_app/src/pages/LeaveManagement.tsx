import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  IconButton,
  Chip,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  FormControl,
  Select,
  MenuItem,
  useMediaQuery,
  useTheme,
  CircularProgress,
  Alert,
  Fab,
  Drawer,
  Pagination,
} from '@mui/material';
import {
  ArrowBack as ArrowBackIcon,
  EditCalendar as EditCalendarIcon,
  Visibility as VisibilityIcon,
  VisibilityOff as VisibilityOffIcon,
  AdminPanelSettings as AdminPanelSettingsIcon,
  Event as EventIcon,
  Assignment as AssignmentIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon,
  Schedule as ScheduleIcon,
  Add as AddIcon,
  Menu as MenuIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import leaveService from '../services/leaveService';
import authService from '../services/authService';
import LeaveRequestModal from '../components/leave/LeaveRequestModal';
import LeaveCancelRequestDialog from '../components/leave/LeaveCancelRequestDialog';
import LeaveSidebar from '../components/leave/LeaveSidebar';
import PersonalCalendar from '../components/calendar/PersonalCalendar';
import type { LeaveManagementData, YearlyDetail } from '../types/leave';

export default function LeaveManagement() {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const isSmallMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const navigate = useNavigate();

  // 상태 관리
  const [leaveData, setLeaveData] = useState<LeaveManagementData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // UI 상태
  const [requestModalOpen, setRequestModalOpen] = useState(false);
  const [cancelDialogOpen, setCancelDialogOpen] = useState(false);
  const [selectedLeave, setSelectedLeave] = useState<YearlyDetail | null>(null);
  const [hideCanceled, setHideCanceled] = useState(false);
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());

  // 연도별 휴가 내역 (필터링된 데이터)
  const [yearlyDetails, setYearlyDetails] = useState<YearlyDetail[]>([]);
  const [yearlyLoading, setYearlyLoading] = useState(false);

  // 페이지네이션 상태
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = isMobile ? 5 : 10; // 모바일: 5개, 데스크톱: 10개

  // 사이드바 상태
  const [sidebarExpanded, setSidebarExpanded] = useState(false);
  const [sidebarPinned, setSidebarPinned] = useState(false);

  // 상세 보기 drawer (모바일)
  const [detailDrawerOpen, setDetailDrawerOpen] = useState(false);

  // 데이터 로드
  useEffect(() => {
    loadLeaveData();
  }, []);

  // 연도 변경 시 연도별 휴가 내역 조회
  useEffect(() => {
    if (selectedYear && leaveData) {
      loadYearlyLeaveData(selectedYear);
    }
  }, [selectedYear]);

  const loadLeaveData = async () => {
    setLoading(true);
    setError(null);

    try {
      const user = authService.getCurrentUser();
      if (!user) {
        setError('사용자 정보를 찾을 수 없습니다.');
        return;
      }

      const data = await leaveService.getLeaveManagement(user.userId);
      setLeaveData(data);

      // 초기 연도별 데이터 로드
      if (data) {
        await loadYearlyLeaveData(selectedYear);
      }
    } catch (err: any) {
      console.error('휴가관리 데이터 로드 실패:', err);
      setError('데이터를 불러오는데 실패했습니다.');
    } finally {
      setLoading(false);
    }
  };

  // 연도별 휴가 내역 조회
  const loadYearlyLeaveData = async (year: number) => {
    try {
      setYearlyLoading(true);
      const user = authService.getCurrentUser();
      if (!user) return;

      console.log('연도별 휴가 내역 조회:', year);

      const response = await leaveService.getYearlyLeave({
        userId: user.userId,
        year: year,
      });

      console.log('연도별 휴가 내역 응답:', response);

      if (response.yearlyDetails) {
        setYearlyDetails(response.yearlyDetails);
      } else if (leaveData?.yearlyDetails) {
        // API 응답이 없으면 기존 데이터에서 필터링
        const filtered = leaveData.yearlyDetails.filter(detail => {
          const detailYear = new Date(detail.startDate).getFullYear();
          return detailYear === year;
        });
        setYearlyDetails(filtered);
      }
    } catch (err: any) {
      console.error('연도별 휴가 내역 조회 실패:', err);
      // 에러 발생 시 기존 데이터에서 필터링
      if (leaveData?.yearlyDetails) {
        const filtered = leaveData.yearlyDetails.filter(detail => {
          const detailYear = new Date(detail.startDate).getFullYear();
          return detailYear === selectedYear;
        });
        setYearlyDetails(filtered);
      }
    } finally {
      setYearlyLoading(false);
    }
  };

  // 연도 변경 시 페이지 초기화
  useEffect(() => {
    setCurrentPage(1);
  }, [selectedYear]);

  // 상태 색상
  const getStatusColor = (status: string) => {
    if (status.includes('REQUESTED')) return '#FF8C00';
    if (status === 'APPROVED') return '#20C997';
    if (status === 'REJECTED') return '#DC3545';
    return '#6B7280';
  };

  // 상태 아이콘
  const getStatusIcon = (status: string) => {
    if (status === 'APPROVED') return <CheckCircleIcon sx={{ fontSize: 18 }} />;
    if (status === 'REJECTED') return <CancelIcon sx={{ fontSize: 18 }} />;
    return <ScheduleIcon sx={{ fontSize: 18 }} />;
  };

  // 상태 레이블
  const getStatusLabel = (leave: YearlyDetail) => {
    if (leave.isCancel === 1) return '🔄 취소 대기';
    if (leave.status === 'REQUESTED') return '대기';
    if (leave.status === 'APPROVED') return '승인';
    if (leave.status === 'REJECTED') return '반려';
    return leave.status;
  };

  // 취소 가능 여부 확인
  const isCancelable = (leave: YearlyDetail) => {
    return leave.status === 'APPROVED' && leave.isCancel !== 1;
  };

  // 필터링된 휴가 내역
  const getFilteredYearlyDetails = () => {
    // 연도별 조회된 데이터 사용 (있으면)
    let filtered = yearlyDetails.length > 0 ? yearlyDetails : (leaveData?.yearlyDetails || []);

    // 취소건 숨김
    if (hideCanceled) {
      filtered = filtered.filter((leave) => leave.status !== 'CANCELLED');
    }

    return filtered;
  };

  // 페이지네이션이 적용된 데이터
  const getPaginatedYearlyDetails = () => {
    const allFiltered = getFilteredYearlyDetails();
    const startIndex = (currentPage - 1) * itemsPerPage;
    const endIndex = startIndex + itemsPerPage;

    return allFiltered.slice(startIndex, endIndex);
  };

  // 총 페이지 수 계산
  const getTotalPages = () => {
    const totalItems = getFilteredYearlyDetails().length;
    return Math.ceil(totalItems / itemsPerPage);
  };

  // 페이지 변경 핸들러
  const handlePageChange = (event: React.ChangeEvent<unknown>, page: number) => {
    setCurrentPage(page);
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box sx={{
      height: isMobile ? '100dvh' : '100vh', // 모바일에서 동적 뷰포트 높이 사용
      display: 'flex',
      flexDirection: 'column',
      bgcolor: '#F5F5F5',
      overflow: 'hidden', // 전체 컨테이너에서 오버플로우 방지
    }}>
      {/* AppBar */}
      <Box
        sx={{
          bgcolor: '#F5F5F5',
          borderBottom: '1px solid',
          borderColor: 'divider',
          px: isMobile ? 1 : 2,
          py: 1.5,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          {isMobile && (
            <IconButton onClick={() => setSidebarExpanded(true)} size="small">
              <MenuIcon />
            </IconButton>
          )}
          <IconButton onClick={() => navigate('/chat')} size="small">
            <ArrowBackIcon />
          </IconButton>
          <Typography variant="h6" sx={{ fontWeight: 600, fontSize: isMobile ? '16px' : '18px' }}>
            휴가관리
          </Typography>
        </Box>

        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
          {!isSmallMobile && authService.hasAdminPermission() && (
            <Button
              size="small"
              variant="contained"
              startIcon={<AdminPanelSettingsIcon sx={{ fontSize: 16 }} />}
              onClick={() => navigate('/admin-leave')}
              sx={{
                bgcolor: '#6F42C1',
                fontSize: '12px',
                textTransform: 'none',
              }}
            >
              관리자
            </Button>
          )}

          {!isSmallMobile && (
            <Button
              size="small"
              variant="text"
              startIcon={hideCanceled ? <VisibilityIcon /> : <VisibilityOffIcon />}
              onClick={() => setHideCanceled(!hideCanceled)}
              sx={{ fontSize: '12px', textTransform: 'none' }}
            >
              취소건 숨김
            </Button>
          )}
        </Box>
      </Box>

      {/* 메인 컨텐츠 */}
      <Box sx={{
        flex: 1,
        overflow: 'auto',
        p: isMobile ? 1 : 2,
        pb: isMobile ? 4 : 2, // 모바일에서 더 넉넉한 하단 패딩
        minHeight: 0, // flexbox에서 제대로 작동하도록
        maxHeight: isMobile ? 'calc(100dvh - 80px)' : 'none', // 모바일에서 최대 높이 제한
        WebkitOverflowScrolling: 'touch', // iOS 스크롤 부드럽게
      }}>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
            {error}
          </Alert>
        )}

        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          {/* 상단 카드: 휴가 현황 + 결재 진행 */}
          <Box
            sx={{
              display: 'flex',
              gap: 2,
              flexDirection: isMobile ? 'column' : 'row',
            }}
          >
            {/* 내 휴가 현황 */}
            <Card sx={{ flex: 1, borderRadius: '16px' }}>
              <CardContent sx={{ p: isMobile ? 1.5 : 2 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                  <Box
                    sx={{
                      p: 1,
                      borderRadius: '10px',
                      background: 'linear-gradient(135deg, #20C997 0%, #17A589 100%)',
                      mr: 1.5,
                    }}
                  >
                    <EventIcon sx={{ color: 'white', fontSize: 18 }} />
                  </Box>
                  <Typography sx={{ fontSize: '14px', fontWeight: 700 }}>내 휴가 현황</Typography>
                </Box>

                <Box
                  sx={{
                    display: 'grid',
                    gridTemplateColumns: isMobile ? 'repeat(2, 1fr)' : 'repeat(4, 1fr)',
                    gap: 1,
                  }}
                >
                  {leaveData?.leaveStatus && leaveData.leaveStatus.length > 0 ? (
                    leaveData.leaveStatus.slice(0, 4).map((status, index) => (
                      <Box
                        key={index}
                        sx={{
                          textAlign: 'center',
                          p: 1.5,
                          borderRadius: '8px',
                          bgcolor: 'rgba(32, 201, 151, 0.08)',
                        }}
                      >
                        <Typography sx={{ fontSize: '10px', color: '#6B7280', mb: 0.5 }}>
                          {status.leaveType}
                        </Typography>
                        <Typography sx={{ fontSize: '18px', fontWeight: 700, color: '#20C997' }}>
                          {status.remainDays}
                          <Typography component="span" sx={{ fontSize: '10px', ml: 0.5 }}>
                            일
                          </Typography>
                        </Typography>
                        <Typography sx={{ fontSize: '9px', color: '#9CA3AF' }}>
                          / {status.totalDays}일
                        </Typography>
                      </Box>
                    ))
                  ) : (
                    <Typography sx={{ fontSize: '12px', color: '#6B7280', gridColumn: '1 / -1', textAlign: 'center', py: 2 }}>
                      휴가 정보 없음
                    </Typography>
                  )}
                </Box>
              </CardContent>
            </Card>

            {/* 결재 진행 현황 */}
            <Card sx={{ flex: 1, borderRadius: '16px' }}>
              <CardContent sx={{ p: isMobile ? 1.5 : 2 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center' }}>
                    <Box
                      sx={{
                        p: 1,
                        borderRadius: '10px',
                        background: 'linear-gradient(135deg, #1E88E5 0%, #1976D2 100%)',
                        mr: 1.5,
                      }}
                    >
                      <AssignmentIcon sx={{ color: 'white', fontSize: 18 }} />
                    </Box>
                    <Typography sx={{ fontSize: '14px', fontWeight: 700 }}>결재 진행 현황</Typography>
                  </Box>

                  <Chip
                    label={`총 ${(leaveData?.approvalStatus?.requested || 0) +
                      (leaveData?.approvalStatus?.approved || 0) +
                      (leaveData?.approvalStatus?.rejected || 0)
                      }건`}
                    size="small"
                    sx={{
                      bgcolor: 'rgba(30, 136, 229, 0.12)',
                      color: '#1E88E5',
                      fontSize: '10px',
                      height: 22,
                    }}
                  />
                </Box>

                <Box sx={{ display: 'flex', gap: 1 }}>
                  <Box sx={{ flex: 1, textAlign: 'center', p: 1.5, borderRadius: '8px', bgcolor: 'rgba(255, 140, 0, 0.08)' }}>
                    <ScheduleIcon sx={{ fontSize: 14, color: '#FF8C00', mb: 0.5 }} />
                    <Typography sx={{ fontSize: '10px', color: '#6B7280' }}>대기중</Typography>
                    <Typography sx={{ fontSize: '20px', fontWeight: 700, color: '#FF8C00' }}>
                      {leaveData?.approvalStatus?.requested || 0}
                    </Typography>
                  </Box>

                  <Box sx={{ flex: 1, textAlign: 'center', p: 1.5, borderRadius: '8px', bgcolor: 'rgba(32, 201, 151, 0.08)' }}>
                    <CheckCircleIcon sx={{ fontSize: 14, color: '#20C997', mb: 0.5 }} />
                    <Typography sx={{ fontSize: '10px', color: '#6B7280' }}>승인됨</Typography>
                    <Typography sx={{ fontSize: '20px', fontWeight: 700, color: '#20C997' }}>
                      {leaveData?.approvalStatus?.approved || 0}
                    </Typography>
                  </Box>

                  <Box sx={{ flex: 1, textAlign: 'center', p: 1.5, borderRadius: '8px', bgcolor: 'rgba(220, 53, 69, 0.08)' }}>
                    <CancelIcon sx={{ fontSize: 14, color: '#DC3545', mb: 0.5 }} />
                    <Typography sx={{ fontSize: '10px', color: '#6B7280' }}>반려됨</Typography>
                    <Typography sx={{ fontSize: '20px', fontWeight: 700, color: '#DC3545' }}>
                      {leaveData?.approvalStatus?.rejected || 0}
                    </Typography>
                  </Box>
                </Box>
              </CardContent>
            </Card>
          </Box>

          {/* 하단: 개인별 휴가 내역 */}
          <Card sx={{ borderRadius: '16px' }}>
            <CardContent sx={{ p: isMobile ? 1.5 : 2 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
                <Typography sx={{ fontSize: '15px', fontWeight: 700 }}>개인별 휴가 내역</Typography>
                <FormControl size="small" sx={{ minWidth: 100 }}>
                  <Select
                    value={selectedYear}
                    onChange={(e) => setSelectedYear(e.target.value as number)}
                    sx={{ fontSize: '13px' }}
                  >
                    {[2024, 2025, 2026].map((year) => (
                      <MenuItem key={year} value={year}>
                        {year}년
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Box>

              {isMobile ? (
                // 모바일: 카드 형식
                <>
                  <Box sx={{
                    display: 'flex',
                    flexDirection: 'column',
                    gap: 1,
                    maxHeight: 'calc(100dvh - 350px)', // 페이지네이션 공간 확보
                    overflow: 'auto',
                    pb: 1,
                  }}>
                    {getPaginatedYearlyDetails().length > 0 ? (
                      getPaginatedYearlyDetails().map((leave) => (
                        <Box
                          key={leave.id}
                          sx={{
                            p: 1.5,
                            border: '1px solid',
                            borderColor: 'divider',
                            borderRadius: '8px',
                          }}
                          onClick={() => {
                            setSelectedLeave(leave);
                            setDetailDrawerOpen(true);
                          }}
                        >
                          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 0.5 }}>
                            <Typography variant="body2" fontWeight={600}>
                              {leave.leaveType}
                            </Typography>
                            <Chip
                              label={getStatusLabel(leave)}
                              size="small"
                              sx={{
                                bgcolor: `${getStatusColor(leave.status)}22`,
                                color: getStatusColor(leave.status),
                                fontSize: '10px',
                                height: 20,
                              }}
                            />
                          </Box>
                          <Typography variant="caption" color="text.secondary">
                            {dayjs(leave.startDate).format('YYYY-MM-DD')} ~ {dayjs(leave.endDate).format('YYYY-MM-DD')}
                          </Typography>
                          <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.5 }}>
                            {leave.reason}
                          </Typography>
                        </Box>
                      ))
                    ) : (
                      <Box sx={{ textAlign: 'center', py: 4 }}>
                        <EventIcon sx={{ fontSize: 48, color: '#E5E7EB', mb: 1 }} />
                        <Typography color="text.secondary" variant="body2">
                          휴가 내역이 없습니다
                        </Typography>
                      </Box>
                    )}
                  </Box>

                  {/* 모바일 페이지네이션 */}
                  {getTotalPages() > 1 && (
                    <Box sx={{
                      display: 'flex',
                      justifyContent: 'center',
                      mt: 2,
                      pt: 1,
                      borderTop: '1px solid',
                      borderColor: 'divider',
                    }}>
                      <Pagination
                        count={getTotalPages()}
                        page={currentPage}
                        onChange={handlePageChange}
                        size="small"
                        color="primary"
                        siblingCount={0}
                        boundaryCount={1}
                        sx={{
                          '& .MuiPaginationItem-root': {
                            fontSize: '0.75rem',
                            minWidth: '28px',
                            height: '28px',
                          },
                        }}
                      />
                    </Box>
                  )}
                </>
              ) : (
                // 데스크톱: 테이블 형식
                <>
                  <TableContainer sx={{
                    maxHeight: isMobile ? 'calc(100dvh - 200px)' : 'none', // 모바일에서 최대 높이 제한
                    overflow: isMobile ? 'auto' : 'visible', // 모바일에서 스크롤 허용
                    mb: 3, // 하단 여백 추가
                  }}>
                    <Table size="small">
                      <TableHead>
                        <TableRow>
                          <TableCell sx={{ fontWeight: 600 }}>상태</TableCell>
                          <TableCell sx={{ fontWeight: 600 }}>종류</TableCell>
                          <TableCell sx={{ fontWeight: 600 }}>기간</TableCell>
                          <TableCell sx={{ fontWeight: 600 }}>일수</TableCell>
                          <TableCell sx={{ fontWeight: 600 }}>사유</TableCell>
                          <TableCell align="center" sx={{ fontWeight: 600 }}>
                            작업
                          </TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {getPaginatedYearlyDetails().length > 0 ? (
                          getPaginatedYearlyDetails().map((leave) => (
                            <TableRow key={leave.id} hover>
                              <TableCell>
                                <Chip
                                  label={getStatusLabel(leave)}
                                  size="small"
                                  sx={{
                                    bgcolor: `${getStatusColor(leave.status)}22`,
                                    color: getStatusColor(leave.status),
                                    fontSize: '11px',
                                  }}
                                />
                              </TableCell>
                              <TableCell>{leave.leaveType}</TableCell>
                              <TableCell sx={{ fontSize: '12px' }}>
                                {dayjs(leave.startDate).format('YYYY-MM-DD')} ~{' '}
                                {dayjs(leave.endDate).format('YYYY-MM-DD')}
                              </TableCell>
                              <TableCell>{leave.workdaysCount}일</TableCell>
                              <TableCell sx={{ fontSize: '12px', maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                {leave.reason}
                              </TableCell>
                              <TableCell align="center">
                                {isCancelable(leave) && (
                                  <Button
                                    size="small"
                                    color="error"
                                    variant="outlined"
                                    onClick={() => {
                                      setSelectedLeave(leave);
                                      setCancelDialogOpen(true);
                                    }}
                                  >
                                    취소 상신
                                  </Button>
                                )}
                              </TableCell>
                            </TableRow>
                          ))
                        ) : (
                          <TableRow>
                            <TableCell colSpan={6} align="center" sx={{ py: 4 }}>
                              <EventIcon sx={{ fontSize: 48, color: '#E5E7EB', mb: 1 }} />
                              <Typography color="text.secondary">휴가 내역이 없습니다</Typography>
                            </TableCell>
                          </TableRow>
                        )}
                      </TableBody>
                    </Table>
                  </TableContainer>

                  {/* 페이지네이션 */}
                  {getTotalPages() > 1 && (
                    <Box sx={{
                      display: 'flex',
                      justifyContent: 'center',
                      mt: 2,
                      mb: isMobile ? 2 : 1,
                      position: isMobile ? 'sticky' : 'static',
                      bottom: isMobile ? 0 : 'auto',
                      bgcolor: isMobile ? 'background.paper' : 'transparent',
                      borderTop: isMobile ? '1px solid' : 'none',
                      borderColor: isMobile ? 'divider' : 'transparent',
                      pt: isMobile ? 1 : 0,
                    }}>
                      <Pagination
                        count={getTotalPages()}
                        page={currentPage}
                        onChange={handlePageChange}
                        size={isMobile ? 'small' : 'medium'}
                        color="primary"
                        showFirstButton={!isMobile}
                        showLastButton={!isMobile}
                        sx={{
                          '& .MuiPaginationItem-root': {
                            fontSize: isMobile ? '0.75rem' : '0.875rem',
                          },
                        }}
                      />
                    </Box>
                  )}
                </>
              )}
            </CardContent>
          </Card>

          {/* 달력 (데스크톱만) */}
          {!isMobile && leaveData && (
            <Card sx={{ borderRadius: '16px' }}>
              <CardContent sx={{ p: 2 }}>
                <Typography sx={{ fontSize: '15px', fontWeight: 700, mb: 2 }}>휴가 일정 달력</Typography>
                <PersonalCalendar
                  monthlyLeaves={leaveData.monthlyLeaves || []}
                  loading={false}
                  error={null}
                />
              </CardContent>
            </Card>
          )}
        </Box>
      </Box>

      {/* 사이드바 (데스크톱) */}
      {!isMobile && (
        <LeaveSidebar
          isExpanded={sidebarExpanded}
          isPinned={sidebarPinned}
          onHover={() => setSidebarExpanded(true)}
          onExit={() => !sidebarPinned && setSidebarExpanded(false)}
          onPinToggle={() => setSidebarPinned(!sidebarPinned)}
        />
      )}

      {/* 사이드바 (모바일) */}
      {isMobile && (
        <LeaveSidebar
          isExpanded={sidebarExpanded}
          isPinned={false}
          onHover={() => { }}
          onExit={() => setSidebarExpanded(false)}
          onPinToggle={() => { }}
        />
      )}

      {/* FAB: 휴가 신청 */}
      <Fab
        color="primary"
        sx={{
          position: 'fixed',
          bottom: 16,
          right: 16,
          zIndex: 1000,
        }}
        onClick={() => setRequestModalOpen(true)}
      >
        <AddIcon />
      </Fab>

      {/* 휴가 신청 모달 */}
      <LeaveRequestModal
        open={requestModalOpen}
        onClose={() => setRequestModalOpen(false)}
        onSubmit={() => {
          setRequestModalOpen(false);
          loadLeaveData();
        }}
        userId={authService.getCurrentUser()?.userId || ''}
      />

      {/* 휴가 취소 상신 다이얼로그 */}
      <LeaveCancelRequestDialog
        open={cancelDialogOpen}
        onClose={() => setCancelDialogOpen(false)}
        onSuccess={() => {
          setCancelDialogOpen(false);
          loadLeaveData();
        }}
        leave={selectedLeave}
        userId={authService.getCurrentUser()?.userId || ''}
      />

      {/* 상세 정보 Drawer (모바일) */}
      <Drawer
        anchor="bottom"
        open={detailDrawerOpen}
        onClose={() => setDetailDrawerOpen(false)}
        sx={{
          '& .MuiDrawer-paper': {
            borderTopLeftRadius: '16px',
            borderTopRightRadius: '16px',
            maxHeight: '70vh',
          },
        }}
      >
        {selectedLeave && (
          <Box sx={{ p: 3 }}>
            <Typography variant="h6" fontWeight={600} gutterBottom>
              휴가 상세 정보
            </Typography>

            <Box sx={{ mt: 2 }}>
              <Typography variant="caption" color="text.secondary">
                휴가 종류
              </Typography>
              <Typography variant="body1" fontWeight={600} gutterBottom>
                {selectedLeave.leaveType}
              </Typography>

              <Typography variant="caption" color="text.secondary" sx={{ mt: 2, display: 'block' }}>
                휴가 기간
              </Typography>
              <Typography variant="body1" gutterBottom>
                {dayjs(selectedLeave.startDate).format('YYYY-MM-DD')} ~{' '}
                {dayjs(selectedLeave.endDate).format('YYYY-MM-DD')} ({selectedLeave.workdaysCount}일)
              </Typography>

              <Typography variant="caption" color="text.secondary" sx={{ mt: 2, display: 'block' }}>
                신청 사유
              </Typography>
              <Typography variant="body1" gutterBottom>
                {selectedLeave.reason}
              </Typography>

              <Typography variant="caption" color="text.secondary" sx={{ mt: 2, display: 'block' }}>
                상태
              </Typography>
              <Chip
                label={getStatusLabel(selectedLeave)}
                sx={{
                  bgcolor: `${getStatusColor(selectedLeave.status)}22`,
                  color: getStatusColor(selectedLeave.status),
                }}
              />

              {selectedLeave.rejectMessage && (
                <>
                  <Typography variant="caption" color="text.secondary" sx={{ mt: 2, display: 'block' }}>
                    반려 사유
                  </Typography>
                  <Alert severity="error" sx={{ mt: 1 }}>
                    {selectedLeave.rejectMessage}
                  </Alert>
                </>
              )}

              {isCancelable(selectedLeave) && (
                <Button
                  fullWidth
                  variant="contained"
                  color="error"
                  sx={{ mt: 3 }}
                  onClick={() => {
                    setDetailDrawerOpen(false);
                    setCancelDialogOpen(true);
                  }}
                >
                  휴가 취소 상신
                </Button>
              )}
            </Box>

            <Button fullWidth variant="outlined" sx={{ mt: 2 }} onClick={() => setDetailDrawerOpen(false)}>
              닫기
            </Button>
          </Box>
        )}
      </Drawer>
    </Box>
  );
}
