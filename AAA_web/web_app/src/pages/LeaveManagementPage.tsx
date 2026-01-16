import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Container,
  Paper,
  CircularProgress,
  Alert,
  Card,
  CardContent,
  Chip,
  Button,
  Grid,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Tabs,
  Tab,
  useMediaQuery,
  useTheme,
  Badge,
  Divider,
  Menu,
  MenuItem,
  ListItemIcon,
  ListItemText,
} from '@mui/material';
import {
  Event as EventIcon,
  Add as AddIcon,
  CalendarMonth as CalendarIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon,
  Pending as PendingIcon,
  AdminPanelSettings as AdminPanelSettingsIcon,
  ArrowBack as ArrowBackIcon,
  AutoAwesome as AutoAwesomeIcon,
  MoreVert as MoreVertIcon,
  Assignment as AssignmentIcon,
} from '@mui/icons-material';
import dayjs from 'dayjs';
import MobileMainLayout from '../components/layout/MobileMainLayout';
import DesktopLeaveManagement from '../components/leave/DesktopLeaveManagement';
import TotalCalendar from '../components/calendar/TotalCalendar';
import LeaveRequestModal from '../components/leave/LeaveRequestModal';
import VacationRecommendationModal from '../components/leave/VacationRecommendationModal';
import leaveService from '../services/leaveService';
import authService from '../services/authService';
import { useNavigate, useLocation } from 'react-router-dom';
import { useThemeStore } from '../store/themeStore';
import type {
  LeaveManagementData,
  LeaveCancelRequest,
  ApprovalStatus,
} from '../types/leave';
import { createLogger } from '../utils/logger';

const logger = createLogger('LeaveManagementPage');

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`leave-tabpanel-${index}`}
      aria-labelledby={`leave-tab-${index}`}
      {...other}
    >
      {value === index && <Box sx={{ p: 3 }}>{children}</Box>}
    </div>
  );
}

export default function LeaveManagementPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md')); // < 900px = 모바일
  const user = authService.getCurrentUser(); // 사용자 정보
  const { colorScheme } = useThemeStore();
  const isDark = colorScheme.name === 'Dark';

  // 관리자 화면에서 넘어왔는지 확인
  const fromAdmin = (location.state as any)?.fromAdmin || false;
  const [tabValue, setTabValue] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [leaveData, setLeaveData] = useState<LeaveManagementData | null>(null);
  const [waitingCount, setWaitingCount] = useState(0); // 관리자 대기 건수

  const [requestDialogOpen, setRequestDialogOpen] = useState(false);
  const [cancelRequestModalOpen, setCancelRequestModalOpen] = useState(false);
  const [cancelRequestLeave, setCancelRequestLeave] = useState<any>(null);
  const [detailModalOpen, setDetailModalOpen] = useState(false); // 휴가 상세 모달
  const [selectedLeave, setSelectedLeave] = useState<any>(null); // 선택된 휴가
  const [cancelReasonDialogOpen, setCancelReasonDialogOpen] = useState(false); // 취소 사유 입력 다이얼로그
  const [cancelReason, setCancelReason] = useState(''); // 취소 사유
  const [recommendationOpen, setRecommendationOpen] = useState(false);
  const [hideCanceled, setHideCanceled] = useState(false);

  // 모바일 드롭다운 메뉴 상태
  const [menuAnchorEl, setMenuAnchorEl] = useState<null | HTMLElement>(null);
  const menuOpen = Boolean(menuAnchorEl);

  const handleMenuOpen = (event: React.MouseEvent<HTMLElement>) => {
    setMenuAnchorEl(event.currentTarget);
  };

  const handleMenuClose = () => {
    setMenuAnchorEl(null);
  };

  // is_approver 확인
  const isApprover = user?.isApprover || false;

  // 승인자인 경우 관리자 휴가관리 화면으로 리다이렉트 (관리자 화면에서 온 경우 제외)
  useEffect(() => {
    if (isApprover && !fromAdmin) {
      console.log('🔄 [LeaveManagementPage] 승인자이므로 관리자 화면으로 리다이렉트');
      navigate('/admin-leave', { replace: true });
    }
  }, [isApprover, fromAdmin, navigate]);

  useEffect(() => {
    loadLeaveData();
  }, []);

  const loadLeaveData = async () => {
    try {
      setLoading(true);
      setError(null);

      const user = authService.getCurrentUser();
      if (!user) {
        setError('사용자 정보를 찾을 수 없습니다.');
        return;
      }

      logger.dev('휴가관리 데이터 로드 시작:', user.userId);

      // Flutter와 동일한 API 호출
      const data = await leaveService.getLeaveManagement(user.userId) as any;
      logger.dev('휴가관리 데이터 응답 (전체):', data);
      logger.dev('응답 타입:', typeof data);
      logger.dev('응답 키들:', Object.keys(data || {}));

      // 실제 API 응답 구조 확인
      logger.dev('data.leave_status:', data.leave_status);
      logger.dev('data.approval_status:', data.approval_status);
      logger.dev('data.yearly_whole_status:', data.yearly_whole_status);
      logger.dev('data.monthly_leaves:', data.monthly_leaves);
      logger.dev('data.yearly_details:', data.yearly_details);

      // camelCase 필드도 확인
      logger.dev('data.leaveStatus:', data.leaveStatus);
      logger.dev('data.approvalStatus:', data.approvalStatus);
      logger.dev('data.yearlyWholeStatus:', data.yearlyWholeStatus);
      logger.dev('data.monthlyLeaves:', data.monthlyLeaves);
      logger.dev('data.yearlyDetails:', data.yearlyDetails);

      // API 응답 구조에 맞게 데이터 처리
      // 실제 API 응답에서 사용되는 필드명 확인 후 매핑
      const actualLeaveStatus = data.leave_status || data.leaveStatus || [];
      const actualApprovalStatus = data.approval_status || data.approvalStatus;
      const actualYearlyDetails = data.yearly_details || data.yearlyDetails || [];
      const actualYearlyWholeStatus = data.yearly_whole_status || data.yearlyWholeStatus || [];
      const actualMonthlyLeaves = data.monthly_leaves || data.monthlyLeaves || [];

      logger.dev('실제 데이터 매핑 결과:');
      logger.dev('actualLeaveStatus:', actualLeaveStatus);
      logger.dev('actualApprovalStatus:', actualApprovalStatus);
      logger.dev('actualYearlyDetails:', actualYearlyDetails);
      logger.dev('actualYearlyWholeStatus:', actualYearlyWholeStatus);
      logger.dev('actualMonthlyLeaves:', actualMonthlyLeaves);

      // API 응답 구조에 맞게 approval_status 처리 (배열 형태)
      let approvalStatus: ApprovalStatus;
      if (Array.isArray(actualApprovalStatus)) {
        // 배열 형태: [{ status: "REQUESTED", count: 2 }, { status: "APPROVED", count: 5 }, { status: "REJECTED", count: 1 }]
        const statusArray = actualApprovalStatus as any[];
        approvalStatus = {
          requested: statusArray.find(item => item.status === 'REQUESTED')?.count || 0,
          approved: statusArray.find(item => item.status === 'APPROVED')?.count || 0,
          rejected: statusArray.find(item => item.status === 'REJECTED')?.count || 0,
        };
      } else if (actualApprovalStatus && typeof actualApprovalStatus === 'object') {
        // 객체 형태: { "REQUESTED": 2, "APPROVED": 5, "REJECTED": 1 }
        approvalStatus = {
          requested: (actualApprovalStatus as any).REQUESTED || 0,
          approved: (actualApprovalStatus as any).APPROVED || 0,
          rejected: (actualApprovalStatus as any).REJECTED || 0,
        };
      } else {
        // 기본값
        approvalStatus = { requested: 0, approved: 0, rejected: 0 };
      }

      // 데이터 구조 확인 및 기본값 설정 (Flutter와 동일)
      const safeData: LeaveManagementData = {
        leaveStatus: actualLeaveStatus,
        approvalStatus: approvalStatus,
        yearlyDetails: actualYearlyDetails,
        yearlyWholeStatus: actualYearlyWholeStatus,
        monthlyLeaves: actualMonthlyLeaves,
      };

      setLeaveData(safeData);

      // 메인 API에서 이미 leaveStatus 데이터를 제공하므로 별도 호출 불필요
      logger.dev('휴가관리 데이터 로드 완료 - leaveStatus:', safeData.leaveStatus);

      // 관리자 대기 건수 조회
      if (user && user.userId) {
        try {
          logger.dev('[LeaveManagementPage] 대기 건수 조회 시작, userId:', user.userId);
          const count = await leaveService.getWaitingLeavesCount(user.userId);
          logger.dev('[LeaveManagementPage] 대기 건수 조회 완료:', count);
          setWaitingCount(count);
          logger.dev('[LeaveManagementPage] waitingCount state 설정 완료:', count);
        } catch (err) {
          logger.error('[LeaveManagementPage] 대기 건수 조회 실패:', err);
          setWaitingCount(0);
        }
      }

    } catch (err: any) {
      logger.error('휴가관리 데이터 로드 실패:', err);
      logger.error('에러 상세:', err.response?.data);
      setError(err.response?.data?.message || err.message || '휴가관리 데이터를 불러오는데 실패했습니다.');
    } finally {
      setLoading(false);
    }
  };


  const handleTabChange = (_event: React.SyntheticEvent, newValue: number) => {
    setTabValue(newValue);
  };

  const handleRequestDialogOpen = () => {
    setRequestDialogOpen(true);
  };

  const handleRequestDialogClose = () => {
    setRequestDialogOpen(false);
  };


  // 휴가 취소 상신 다이얼로그 열기
  const handleOpenCancelDialog = () => {
    setCancelReasonDialogOpen(true);
  };

  // 휴가 취소 상신 처리 (Flutter와 동일 - detail modal용)
  const handleDetailModalCancelRequest = async () => {
    // 취소 사유는 선택사항으로 변경
    // if (!cancelReason.trim()) {
    //   alert('취소 사유를 입력해주세요.');
    //   return;
    // }

    if (!user?.userId) {
      alert('사용자 정보를 찾을 수 없습니다.');
      return;
    }

    if (!selectedLeave?.id) {
      alert('휴가 정보를 찾을 수 없습니다.');
      return;
    }

    try {
      const response = await leaveService.requestLeaveCancel({
        id: selectedLeave.id,
        userId: user.userId,
        reason: cancelReason.trim(),
      });

      if (response.error) {
        alert(`취소 상신 실패: ${response.error}`);
        return;
      }

      alert('휴가 취소 상신이 완료되었습니다.');
      setCancelReasonDialogOpen(false);
      setDetailModalOpen(false);
      setCancelReason('');
      loadLeaveData(); // 데이터 새로고침
    } catch (error: any) {
      alert(`취소 상신 중 오류가 발생했습니다: ${error.message}`);
    }
  };



  // 취소 상신 처리
  const handleCancelRequest = async () => {
    if (!cancelRequestLeave) return;

    try {
      const user = authService.getCurrentUser();
      if (!user) {
        setError('사용자 정보를 찾을 수 없습니다.');
        return;
      }

      const cancelRequest: LeaveCancelRequest = {
        id: cancelRequestLeave.id,
        userId: user.userId,
      };

      const response = await leaveService.cancelLeaveRequestNew(cancelRequest);

      if (response.error) {
        setError(`취소 상신 실패: ${response.error}`);
        return;
      }

      // 성공 시 데이터 갱신
      loadLeaveData();
      setCancelRequestModalOpen(false);
      setCancelRequestLeave(null);
      setError(null);
      alert('취소 상신이 완료되었습니다.');
    } catch (error: any) {
      logger.error('취소 상신 실패:', error);
      setError(error.message || '취소 상신에 실패했습니다.');
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'APPROVED':
        return <CheckCircleIcon sx={{ color: 'success.main' }} />;
      case 'REJECTED':
        return <CancelIcon sx={{ color: 'error.main' }} />;
      case 'REQUESTED':
        return <PendingIcon sx={{ color: 'warning.main' }} />;
      case 'CANCELLED':
      case 'CANCEL_REQUESTED':
        return <CancelIcon sx={{ color: 'grey.500' }} />;
      default:
        return <PendingIcon sx={{ color: 'grey.500' }} />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'APPROVED':
        return 'success';
      case 'REJECTED':
        return 'error';
      case 'REQUESTED':
        return 'warning';
      case 'CANCELLED':
      case 'CANCEL_REQUESTED':
        return 'grey';
      default:
        return 'default';
    }
  };

  const formatDate = (dateString: string) => {
    return dayjs(dateString).format('YYYY-MM-DD');
  };

  const calculateDays = (startDate: string, endDate: string) => {
    return dayjs(endDate).diff(dayjs(startDate), 'day') + 1;
  };


  // 데스크톱 UI
  if (!isMobile) {
    if (loading) {
      return (
        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
          <CircularProgress />
        </Box>
      );
    }

    if (error) {
      return (
        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', p: 3 }}>
          <Alert severity="error" sx={{ maxWidth: 600 }}>
            {error}
            <Button onClick={loadLeaveData} sx={{ mt: 2 }}>
              다시 시도
            </Button>
          </Alert>
        </Box>
      );
    }

    if (leaveData) {
      return <DesktopLeaveManagement leaveData={leaveData} onRefresh={loadLeaveData} waitingCount={waitingCount} />;
    }

    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <Typography>휴가 관리 데이터를 불러오는 중...</Typography>
      </Box>
    );
  }

  // 모바일 UI
  return (
    <MobileMainLayout hideAppBar={true}>
      <Container maxWidth="md" sx={{ py: 2, height: '100vh', overflow: 'auto', paddingBottom: '80px', bgcolor: colorScheme.backgroundColor }}>
        <Paper elevation={3} sx={{ borderRadius: 3, bgcolor: colorScheme.surfaceColor, border: `1px solid ${colorScheme.textFieldBorderColor}` }}>
          {/* 헤더 */}
          <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <IconButton onClick={() => navigate('/chat')} sx={{ color: 'primary.main' }}>
                  <ArrowBackIcon />
                </IconButton>
                <Box sx={{ p: 1.5, borderRadius: 2, bgcolor: 'primary.light', color: 'primary.contrastText' }}>
                  <EventIcon sx={{ fontSize: 24 }} />
                </Box>
                <Typography variant="h5" component="h1" sx={{ fontWeight: 'bold', color: 'primary.main' }}>
                  휴가 관리
                </Typography>
              </Box>
              {/* 드롭다운 메뉴 버튼 */}
              <Badge badgeContent={isApprover ? waitingCount : 0} color="error" invisible={!isApprover || waitingCount === 0} max={99}>
                <IconButton
                  onClick={handleMenuOpen}
                  sx={{
                    bgcolor: 'primary.main',
                    color: 'white',
                    '&:hover': { bgcolor: 'primary.dark' },
                  }}
                >
                  <MoreVertIcon />
                </IconButton>
              </Badge>
              <Menu
                anchorEl={menuAnchorEl}
                open={menuOpen}
                onClose={handleMenuClose}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                transformOrigin={{ vertical: 'top', horizontal: 'right' }}
                PaperProps={{
                  sx: {
                    mt: 1,
                    minWidth: 200,
                    borderRadius: 2,
                    boxShadow: '0 4px 20px rgba(0,0,0,0.15)',
                  },
                }}
              >
                <MenuItem
                  onClick={() => {
                    handleMenuClose();
                    handleRequestDialogOpen();
                  }}
                >
                  <ListItemIcon>
                    <AddIcon sx={{ color: 'primary.main' }} />
                  </ListItemIcon>
                  <ListItemText primary="휴가 신청" />
                </MenuItem>
                <MenuItem
                  onClick={() => {
                    handleMenuClose();
                    setRecommendationOpen(true);
                  }}
                >
                  <ListItemIcon>
                    <AutoAwesomeIcon sx={{ color: '#FF8F00' }} />
                  </ListItemIcon>
                  <ListItemText primary="AI 휴가 추천" />
                </MenuItem>
                <MenuItem
                  onClick={() => {
                    handleMenuClose();
                    navigate('/leave-grant-history');
                  }}
                >
                  <ListItemIcon>
                    <AssignmentIcon sx={{ color: 'primary.main' }} />
                  </ListItemIcon>
                  <ListItemText primary="휴가 부여 내역" />
                </MenuItem>
                {/* 승인자인 경우에만 관리자 휴가관리 메뉴 표시 */}
                {isApprover && (
                  <MenuItem
                    onClick={() => {
                      handleMenuClose();
                      navigate('/admin-leave', { replace: false });
                    }}
                  >
                    <ListItemIcon>
                      <Badge badgeContent={waitingCount} color="error" invisible={waitingCount === 0} max={99}>
                        <AdminPanelSettingsIcon sx={{ color: '#6F42C1' }} />
                      </Badge>
                    </ListItemIcon>
                    <ListItemText primary="관리자 휴가관리" />
                  </MenuItem>
                )}
              </Menu>
            </Box>
          </Box>

          {loading && (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
              <CircularProgress />
            </Box>
          )}

          {error && (
            <Alert severity="error" sx={{ m: 3 }}>
              {error}
            </Alert>
          )}

          {!loading && !error && leaveData && (
            <>
              {/* 휴가 현황 요약 */}
              <Box sx={{ p: 2 }}>
                <Grid container spacing={2}>
                  <Grid size={{ xs: 12, md: 6 }}>
                    <Card sx={{ p: 2, bgcolor: colorScheme.surfaceColor, border: `1px solid ${colorScheme.textFieldBorderColor}` }}>
                      <Typography variant="subtitle1" sx={{ mb: 1.5, fontWeight: 600, color: colorScheme.textColor }}>
                        내 휴가 현황
                      </Typography>
                      <Grid container spacing={1}>
                        {leaveData.leaveStatus && leaveData.leaveStatus.length > 0 ? (
                          leaveData.leaveStatus.map((status, index) => (
                            <Grid size={6} key={index}>
                              <Box sx={{ textAlign: 'center', p: 1 }}>
                                <Typography variant="body2" sx={{ color: colorScheme.hintTextColor }} gutterBottom>
                                  {(status as any).leave_type || status.leaveType || '휴가'}
                                </Typography>
                                <Typography variant="h6" sx={{ fontWeight: 'bold', color: isDark ? '#60A5FA' : '#1976D2' }}>
                                  {(status as any).remain_days || status.remainDays || 0}일
                                </Typography>
                                <Typography variant="caption" sx={{ color: colorScheme.hintTextColor }}>
                                  총 {(status as any).total_days || status.totalDays || 0}일
                                </Typography>
                              </Box>
                            </Grid>
                          ))
                        ) : (
                          <Grid size={12}>
                            <Box sx={{ textAlign: 'center', py: 2 }}>
                              <Typography variant="body2" color="text.secondary">
                                휴가 잔여량 정보가 없습니다
                              </Typography>
                            </Box>
                          </Grid>
                        )}
                      </Grid>
                    </Card>
                  </Grid>

                  <Grid size={{ xs: 12, md: 6 }}>
                    <Card sx={{ p: 2, bgcolor: colorScheme.surfaceColor, border: `1px solid ${colorScheme.textFieldBorderColor}` }}>
                      <Typography variant="subtitle1" sx={{ mb: 1.5, fontWeight: 600, color: colorScheme.textColor }}>
                        결재진행 현황
                      </Typography>
                      <Grid container spacing={1}>
                        <Grid size={4}>
                          <Box sx={{ textAlign: 'center', p: 1 }}>
                            <Typography variant="body2" sx={{ color: colorScheme.hintTextColor }} gutterBottom>
                              대기중
                            </Typography>
                            <Typography variant="h6" sx={{ fontWeight: 'bold', color: isDark ? '#FBBF24' : '#FF8C00' }}>
                              {leaveData.approvalStatus?.requested || 0}
                            </Typography>
                          </Box>
                        </Grid>
                        <Grid size={4}>
                          <Box sx={{ textAlign: 'center', p: 1 }}>
                            <Typography variant="body2" sx={{ color: colorScheme.hintTextColor }} gutterBottom>
                              승인됨
                            </Typography>
                            <Typography variant="h6" sx={{ fontWeight: 'bold', color: isDark ? '#34D399' : '#20C997' }}>
                              {leaveData.approvalStatus?.approved || 0}
                            </Typography>
                          </Box>
                        </Grid>
                        <Grid size={4}>
                          <Box sx={{ textAlign: 'center', p: 1 }}>
                            <Typography variant="body2" sx={{ color: colorScheme.hintTextColor }} gutterBottom>
                              반려됨
                            </Typography>
                            <Typography variant="h6" sx={{ fontWeight: 'bold', color: isDark ? '#F87171' : '#DC3545' }}>
                              {leaveData.approvalStatus?.rejected || 0}
                            </Typography>
                          </Box>
                        </Grid>
                      </Grid>
                    </Card>
                  </Grid>
                </Grid>
              </Box>

              {/* 탭: 휴가내역 / 달력 */}
              <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
                <Tabs value={tabValue} onChange={handleTabChange} variant="fullWidth">
                  <Tab label="휴가내역" icon={<EventIcon sx={{ fontSize: 18 }} />} iconPosition="start" />
                  <Tab label="달력" icon={<CalendarIcon sx={{ fontSize: 18 }} />} iconPosition="start" />
                </Tabs>
              </Box>

              {/* 휴가내역 탭 */}
              <TabPanel value={tabValue} index={0}>
                <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
                  <Button
                    variant="outlined"
                    size="small"
                    onClick={() => setHideCanceled(!hideCanceled)}
                    sx={{ fontSize: 12, borderRadius: 999 }}
                  >
                    {hideCanceled ? '취소건 숨김 해제' : '취소건 숨김'}
                  </Button>
                </Box>

                {!leaveData.monthlyLeaves || leaveData.monthlyLeaves.length === 0 ? (
                  <Box sx={{ textAlign: 'center', py: 4 }}>
                    <EventIcon sx={{ fontSize: 80, color: 'grey.300', mb: 2 }} />
                    <Typography variant="h6" color="text.secondary">
                      휴가 내역이 없습니다
                    </Typography>
                  </Box>
                ) : (
                  <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                    {[...leaveData.monthlyLeaves]
                      .filter((leave: any) => !hideCanceled || leave.status !== 'CANCELLED')
                      .reverse()
                      .map((leave: any, index) => (
                      <Card
                        key={index}
                        sx={{
                          borderRadius: 2,
                          cursor: 'pointer',
                          '&:hover': { boxShadow: 3, bgcolor: 'action.hover' },
                        }}
                        onClick={() => {
                          setSelectedLeave(leave);
                          setDetailModalOpen(true);
                        }}
                      >
                        <CardContent>
                          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1 }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              {getStatusIcon(leave.status)}
                              <Typography variant="h6" sx={{ fontWeight: 600 }}>
                                {leave.leave_type || leave.leaveType}
                              </Typography>
                            </Box>
                            <Chip
                              label={
                                leave.status === 'APPROVED' ? '승인' :
                                  leave.status === 'REJECTED' ? '반려' :
                                    leave.status === 'CANCELLED' ? '취소' :
                                      '대기'
                              }
                              color={getStatusColor(leave.status) as any}
                              size="small"
                            />
                          </Box>
                          <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                            {formatDate(leave.start_date || leave.startDate)} ~ {formatDate(leave.end_date || leave.endDate)}
                            {leave.half_day_slot && leave.half_day_slot !== 'ALL' && (
                              <span style={{ marginLeft: 8 }}>
                                ({leave.half_day_slot === 'AM' ? '오전반차' : '오후반차'})
                              </span>
                            )}
                          </Typography>
                          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                            사유: {leave.reason}
                          </Typography>
                          {leave.reject_message && (
                            <Box sx={{ mt: 1, p: 1.5, bgcolor: 'rgba(0, 0, 0, 0.03)', borderRadius: 1, border: '1px solid rgba(0, 0, 0, 0.12)' }}>
                              <Typography variant="body2" sx={{ fontSize: '13px' }}>
                                <Typography component="span" sx={{ fontWeight: 600 }}>반려 사유:</Typography> {leave.reject_message}
                              </Typography>
                            </Box>
                          )}
                        </CardContent>
                      </Card>
                      ))}
                  </Box>
                )}
              </TabPanel>

              {/* 달력 탭 */}
              <TabPanel value={tabValue} index={1}>
                <Box sx={{
                  display: 'flex',
                  flexDirection: 'column',
                  height: isMobile ? 'auto' : 'calc(100vh - 400px)',
                  minHeight: isMobile ? 'auto' : '600px',
                  overflow: isMobile ? 'visible' : 'hidden'
                }}>
                  <TotalCalendar open={true} onClose={() => { }} embedded={true} />
                </Box>
              </TabPanel>
            </>
          )}
        </Paper>

        {/* 취소 상신 확인 모달 */}
        <Dialog
          open={cancelRequestModalOpen}
          onClose={() => setCancelRequestModalOpen(false)}
          maxWidth="sm"
          fullWidth
        >
          <DialogTitle sx={{ pb: 1 }}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              취소 상신 확인
            </Typography>
          </DialogTitle>
          <DialogContent sx={{ pb: 2 }}>
            <Box sx={{ mb: 2 }}>
              <Typography sx={{ mb: 2, color: '#374151' }}>
                다음 휴가를 취소하시겠습니까?
              </Typography>
              {cancelRequestLeave && (
                <Card sx={{ p: 2, bgcolor: '#F9FAFB', border: '1px solid #E5E7EB' }}>
                  <Typography sx={{ fontSize: '14px', fontWeight: 600, color: '#1F2937', mb: 1 }}>
                    {cancelRequestLeave.leave_type || cancelRequestLeave.leaveType}
                  </Typography>
                  <Typography sx={{ fontSize: '13px', color: '#6B7280', mb: 1 }}>
                    {formatDate(cancelRequestLeave.start_date || cancelRequestLeave.startDate)} ~ {formatDate(cancelRequestLeave.end_date || cancelRequestLeave.endDate)}
                    <span style={{ marginLeft: 8, fontWeight: 600 }}>
                      ({calculateDays(cancelRequestLeave.start_date || cancelRequestLeave.startDate, cancelRequestLeave.end_date || cancelRequestLeave.endDate)}일)
                    </span>
                  </Typography>
                  <Typography sx={{ fontSize: '13px', color: '#6B7280' }}>
                    {cancelRequestLeave.reason}
                  </Typography>
                </Card>
              )}
            </Box>
            <Alert severity="warning" sx={{ mb: 2 }}>
              취소 상신 후 승인이 완료되면 해당 휴가는 취소됩니다.
            </Alert>
          </DialogContent>
          <DialogActions sx={{ px: 3, pb: 2 }}>
            <Button
              onClick={() => {
                setCancelRequestModalOpen(false);
                setCancelRequestLeave(null);
              }}
              variant="outlined"
            >
              취소
            </Button>
            <Button
              onClick={handleCancelRequest}
              variant="contained"
              color="warning"
              startIcon={<CancelIcon />}
            >
              취소 상신
            </Button>
          </DialogActions>
        </Dialog>

        {/* 휴가 신청 모달 */}
        <LeaveRequestModal
          open={requestDialogOpen}
          onClose={handleRequestDialogClose}
          onSubmit={loadLeaveData}
          userId={user?.userId || ''}
          leaveStatusList={leaveData?.leaveStatus || []}
        />

        <VacationRecommendationModal
          open={recommendationOpen}
          onClose={() => setRecommendationOpen(false)}
          userId={user?.userId || ''}
          year={new Date().getFullYear()}
        />

        {/* 휴가 취소 사유 입력 다이얼로그 */}
        <Dialog
          open={cancelReasonDialogOpen}
          onClose={() => {
            setCancelReasonDialogOpen(false);
            setCancelReason('');
          }}
          maxWidth="sm"
          fullWidth
        >
          <DialogTitle>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
              <CancelIcon sx={{ fontSize: 28, color: '#E53E3E' }} />
              <Typography sx={{ fontSize: 18, fontWeight: 600, color: '#1F2937' }}>
                휴가 취소 상신
              </Typography>
            </Box>
          </DialogTitle>
          <DialogContent sx={{ pt: 3 }}>
            <Typography sx={{ fontSize: 14, fontWeight: 600, color: '#374151', mb: 2 }}>
              취소 사유를 입력해주세요:
            </Typography>
            <TextField
              fullWidth
              multiline
              rows={4}
              value={cancelReason}
              onChange={(e: React.ChangeEvent<HTMLInputElement>) => setCancelReason(e.target.value)}
              placeholder="취소 사유를 입력하세요"
              sx={{
                '& .MuiOutlinedInput-root': {
                  fontSize: 14,
                  bgcolor: '#F9FAFB',
                },
              }}
            />
            <Typography sx={{ fontSize: 11, color: '#6B7280', mt: 1 }}>
              ※ 취소 상신 후 결재자의 승인이 필요합니다.
            </Typography>
          </DialogContent>
          <DialogActions sx={{ p: 2, gap: 1 }}>
            <Button
              onClick={() => {
                setCancelReasonDialogOpen(false);
                setCancelReason('');
              }}
              variant="outlined"
              sx={{ fontWeight: 600 }}
            >
              취소
            </Button>
            <Button
              onClick={handleDetailModalCancelRequest}
              variant="contained"
              color="error"
              sx={{ fontWeight: 600 }}
            >
              취소 상신
            </Button>
          </DialogActions>
        </Dialog>

        {/* 휴가 상세 모달 */}
        <Dialog open={detailModalOpen} onClose={() => setDetailModalOpen(false)} maxWidth="sm" fullWidth>
          <DialogTitle sx={{ pb: 1, borderBottom: 1, borderColor: 'divider', fontWeight: 600, fontSize: '1.25rem' }}>
            휴가 상세 정보
          </DialogTitle>
          <DialogContent sx={{ pt: 3 }}>
            {selectedLeave && (
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  {getStatusIcon(selectedLeave.status)}
                  <Box sx={{ fontSize: '1.25rem', fontWeight: 600 }}>
                    {selectedLeave.leave_type || selectedLeave.leaveType}
                  </Box>
                  <Chip
                    label={
                      selectedLeave.status === 'APPROVED' ? '승인' :
                        selectedLeave.status === 'REJECTED' ? '반려' :
                          selectedLeave.status === 'CANCELLED' ? '취소됨' :
                            '대기'
                    }
                    color={getStatusColor(selectedLeave.status) as any}
                    size="small"
                  />
                </Box>

                <Divider />

                <Box>
                  <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>
                    휴가 기간
                  </Typography>
                  <Typography variant="body1" sx={{ mt: 0.5 }}>
                    {formatDate(selectedLeave.start_date || selectedLeave.startDate)} ~ {formatDate(selectedLeave.end_date || selectedLeave.endDate)}
                  </Typography>
                  {selectedLeave.half_day_slot && selectedLeave.half_day_slot !== 'ALL' && (
                    <Typography variant="caption" sx={{ color: 'text.secondary', mt: 0.5 }}>
                      ({selectedLeave.half_day_slot === 'AM' ? '오전반차' : '오후반차'})
                    </Typography>
                  )}
                </Box>

                <Box>
                  <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>
                    휴가 사유
                  </Typography>
                  <Typography variant="body1" sx={{ mt: 0.5 }}>
                    {selectedLeave.reason || '-'}
                  </Typography>
                </Box>

                {(selectedLeave.reject_message || selectedLeave.rejectMessage) && (
                  <Box sx={{ p: 2, bgcolor: 'rgba(0, 0, 0, 0.03)', borderRadius: 1, border: '1px solid rgba(0, 0, 0, 0.12)' }}>
                    <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600, display: 'block', mb: 0.5 }}>
                      반려 사유
                    </Typography>
                    <Typography variant="body2" sx={{ color: 'text.primary' }}>
                      {selectedLeave.reject_message || selectedLeave.rejectMessage}
                    </Typography>
                  </Box>
                )}
              </Box>
            )}
          </DialogContent>
          <DialogActions sx={{ p: 2 }}>
            {/* 승인된 건에 대해서만 취소 상신 버튼 표시 */}
            {selectedLeave?.status?.toUpperCase() === 'APPROVED' && (
              <Button
                onClick={handleOpenCancelDialog}
                variant="outlined"
                color="error"
                startIcon={<CancelIcon />}
                sx={{
                  fontWeight: 600,
                  borderWidth: 2,
                  '&:hover': {
                    borderWidth: 2,
                    bgcolor: 'rgba(229, 62, 62, 0.04)',
                  },
                }}
              >
                휴가 취소 상신
              </Button>
            )}
            <Button onClick={() => setDetailModalOpen(false)} variant="contained">
              닫기
            </Button>
          </DialogActions>
        </Dialog>
      </Container>
    </MobileMainLayout>
  );
}
