import { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  IconButton,
  Chip,
  CircularProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,

  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  FormControl,
  Select,
  MenuItem,
  Alert,
  Divider,
  Pagination,
  Stack,
  Badge,
} from '@mui/material';
import {
  Event as EventIcon,
  Schedule as ScheduleIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon,
  Assignment as AssignmentIcon,
  EditCalendar as EditCalendarIcon,
  Visibility as VisibilityIcon,
  VisibilityOff as VisibilityOffIcon,
  AdminPanelSettings as AdminPanelSettingsIcon,
  Pending as PendingIcon,
  CalendarMonth as CalendarMonthIcon,
  ArrowBack as ArrowBackIcon,
  Fullscreen as FullscreenIcon,
  Menu as MenuIcon,
  ChevronLeft as ChevronLeftIcon,
  AutoAwesome as AutoAwesomeIcon,
} from '@mui/icons-material';
import LeaveCancelRequestDialog from './LeaveCancelRequestDialog';

import dayjs, { type Dayjs } from 'dayjs';
import type {
  LeaveManagementData,
  YearlyDetail,
  YearlyWholeStatus,
  LeaveStatus,
} from '../../types/leave';
import leaveService from '../../services/leaveService';
import authService from '../../services/authService';
import PersonalCalendar from '../calendar/PersonalCalendar';
import TotalCalendar from '../calendar/TotalCalendar';
import { useNavigate } from 'react-router-dom';
import ApproverSelectionModal from './ApproverSelectionModal';
import ReferenceSelectionModal from './ReferenceSelectionModal';
import LeaveRequestModal from './LeaveRequestModal';
import VacationRecommendationModal from './VacationRecommendationModal'; // Added VacationRecommendationModal
import { useThemeStore } from '../../store/themeStore';

interface DesktopLeaveManagementProps {
  leaveData: LeaveManagementData;
  onRefresh: () => void;
  waitingCount?: number;
}

type ManagementTableRow = {
  leaveType: string;
  allowedDays: number;
  usedByMonth: number[];
  totalUsed: number;
};

type ExtendedYearlyDetail = YearlyDetail & {
  originalReason?: string;
};

type LeaveRequestFormState = {
  leaveType: string;
  startDate: Dayjs;
  endDate: Dayjs;
  reason: string;
  halfDaySlot: string;
  approverIds: string[];
  ccList: Array<{ name: string; department: string }>;
  useHalfDay: boolean;
  useNextYearLeave: boolean;
};

export default function DesktopLeaveManagement({
  leaveData,
  onRefresh,
  waitingCount = 0,
}: DesktopLeaveManagementProps) {
  const navigate = useNavigate();
  const { colorScheme } = useThemeStore();
  const isDark = colorScheme.name === 'Dark';

  // is_approver 확인
  const user = authService.getCurrentUser();
  const isApprover = user?.isApprover || false;

  // 디버깅
  console.log('📍 [DesktopLeaveManagement] user:', user);
  console.log('📍 [DesktopLeaveManagement] isApprover:', isApprover);

  const [requestDialogOpen, setRequestDialogOpen] = useState(false);
  const [aiModalOpen, setAiModalOpen] = useState(false); // Added aiModalOpen state
  const [hideCanceled, setHideCanceled] = useState(false);
  const [selectedYear, setSelectedYear] = useState(dayjs().year()); // Changed to dayjs().year()
  const [totalCalendarOpen, setTotalCalendarOpen] = useState(false);
  const [detailPanelOpen, setDetailPanelOpen] = useState(false);
  const [selectedLeaveDetail, setSelectedLeaveDetail] = useState<ExtendedYearlyDetail | null>(null);
  const [managementTableDialogOpen, setManagementTableDialogOpen] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false); // 사이드바 열림/닫힘 상태 (디폴트: 닫힘)

  // 개인별 휴가 내역 페이지네이션
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  // 연도별 휴가 내역 (필터링된 데이터)
  const [yearlyDetails, setYearlyDetails] = useState(leaveData.yearlyDetails || []);
  const [yearlyLoading, setYearlyLoading] = useState(false);

  // 연도별 휴가 현황 (휴가 관리 대장용)
  const [yearlyWholeStatus, setYearlyWholeStatus] = useState(leaveData.yearlyWholeStatus || []);

  // 휴가 관리 대장 데이터 (yearlyWholeStatus에서 변환)
  const [managementTableData, setManagementTableData] = useState<ManagementTableRow[]>([]);
  const [tableLoading, setTableLoading] = useState(false);

  // 휴가 신청 폼 상태
  const [requestForm, setRequestForm] = useState<LeaveRequestFormState>({
    leaveType: '',
    startDate: dayjs(),
    endDate: dayjs(),
    reason: '',
    halfDaySlot: '',
    approverIds: [] as string[],
    ccList: [] as Array<{ name: string; department: string }>,
    useHalfDay: false,
    useNextYearLeave: false,
  });

  // 모달 상태
  const [approverModalOpen, setApproverModalOpen] = useState(false);
  const [referenceModalOpen, setReferenceModalOpen] = useState(false);
  const [isSequentialApproval, setIsSequentialApproval] = useState(false); // 순차결재 모드
  const [cancelRequestModalOpen, setCancelRequestModalOpen] = useState(false);
  const [cancelRequestLeave, setCancelRequestLeave] = useState<YearlyDetail | null>(null);
  // 승인자 목록 로드 (필요 시 ApproverSelectionModal에서 직접 로드)

  // 초기 로드 시 yearlyWholeStatus를 managementTableData로 변환
  useEffect(() => {
    if (leaveData.yearlyWholeStatus && leaveData.yearlyWholeStatus.length > 0) {
      const tableData = leaveData.yearlyWholeStatus
        .filter((item: YearlyWholeStatus) => item.leaveType !== '총계')
        .map((item: YearlyWholeStatus) => ({
          leaveType: item.leaveType || '',
          allowedDays: item.totalDays || 0,
          usedByMonth: [
            item.m01 || 0,
            item.m02 || 0,
            item.m03 || 0,
            item.m04 || 0,
            item.m05 || 0,
            item.m06 || 0,
            item.m07 || 0,
            item.m08 || 0,
            item.m09 || 0,
            item.m10 || 0,
            item.m11 || 0,
            item.m12 || 0,
          ],
          totalUsed: [
            item.m01 || 0,
            item.m02 || 0,
            item.m03 || 0,
            item.m04 || 0,
            item.m05 || 0,
            item.m06 || 0,
            item.m07 || 0,
            item.m08 || 0,
            item.m09 || 0,
            item.m10 || 0,
            item.m11 || 0,
            item.m12 || 0,
          ].reduce((sum: number, val: number) => sum + val, 0),
        }));
      setManagementTableData(tableData);
      setYearlyWholeStatus(leaveData.yearlyWholeStatus);
    }
  }, [leaveData.yearlyWholeStatus]);

  // 연도 변경 시 연도별 휴가 내역 조회
  useEffect(() => {
    loadYearlyLeaveData(selectedYear);
    loadManagementTable();
  }, [selectedYear]);

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
      } else {
        // API 응답이 없으면 기존 데이터에서 필터링
        const filtered = leaveData.yearlyDetails.filter(detail => {
          const detailYear = new Date(detail.startDate).getFullYear();
          return detailYear === year;
        });
        setYearlyDetails(filtered);
      }

      // yearlyWholeStatus 업데이트 (휴가 관리 대장용)
      if (response.yearlyWholeStatus && response.yearlyWholeStatus.length > 0) {
        setYearlyWholeStatus(response.yearlyWholeStatus);
        // yearlyWholeStatus를 managementTableData 형식으로 변환
        const tableData = response.yearlyWholeStatus
          .filter((item: YearlyWholeStatus) => item.leaveType !== '총계')
          .map((item: YearlyWholeStatus) => ({
            leaveType: item.leaveType || '',
            allowedDays: item.totalDays || 0,
            usedByMonth: [
              item.m01 || 0,
              item.m02 || 0,
              item.m03 || 0,
              item.m04 || 0,
              item.m05 || 0,
              item.m06 || 0,
              item.m07 || 0,
              item.m08 || 0,
              item.m09 || 0,
              item.m10 || 0,
              item.m11 || 0,
              item.m12 || 0,
            ],
            totalUsed: [
              item.m01 || 0,
              item.m02 || 0,
              item.m03 || 0,
              item.m04 || 0,
              item.m05 || 0,
              item.m06 || 0,
              item.m07 || 0,
              item.m08 || 0,
              item.m09 || 0,
              item.m10 || 0,
              item.m11 || 0,
              item.m12 || 0,
            ].reduce((sum: number, val: number) => sum + val, 0),
          }));
        setManagementTableData(tableData);
      } else if (leaveData.yearlyWholeStatus && leaveData.yearlyWholeStatus.length > 0) {
        // API 응답이 없으면 기존 데이터 사용
        setYearlyWholeStatus(leaveData.yearlyWholeStatus);
        const tableData = leaveData.yearlyWholeStatus
          .filter((item: YearlyWholeStatus) => item.leaveType !== '총계')
          .map((item: YearlyWholeStatus) => ({
            leaveType: item.leaveType || '',
            allowedDays: item.totalDays || 0,
            usedByMonth: [
              item.m01 || 0,
              item.m02 || 0,
              item.m03 || 0,
              item.m04 || 0,
              item.m05 || 0,
              item.m06 || 0,
              item.m07 || 0,
              item.m08 || 0,
              item.m09 || 0,
              item.m10 || 0,
              item.m11 || 0,
              item.m12 || 0,
            ],
            totalUsed: [
              item.m01 || 0,
              item.m02 || 0,
              item.m03 || 0,
              item.m04 || 0,
              item.m05 || 0,
              item.m06 || 0,
              item.m07 || 0,
              item.m08 || 0,
              item.m09 || 0,
              item.m10 || 0,
              item.m11 || 0,
              item.m12 || 0,
            ].reduce((sum: number, val: number) => sum + val, 0),
          }));
        setManagementTableData(tableData);
      }
    } catch (err) {
      console.error('연도별 휴가 내역 조회 실패:', err);
      // 에러 발생 시 기존 데이터에서 필터링
      const filtered = leaveData.yearlyDetails.filter(detail => {
        const detailYear = new Date(detail.startDate).getFullYear();
        return detailYear === selectedYear;
      });
      setYearlyDetails(filtered);

      // yearlyWholeStatus도 기존 데이터 사용
      if (leaveData.yearlyWholeStatus && leaveData.yearlyWholeStatus.length > 0) {
        setYearlyWholeStatus(leaveData.yearlyWholeStatus);
        const tableData = leaveData.yearlyWholeStatus
          .filter((item: YearlyWholeStatus) => item.leaveType !== '총계')
          .map((item: YearlyWholeStatus) => ({
            leaveType: item.leaveType || '',
            allowedDays: item.totalDays || 0,
            usedByMonth: [
              item.m01 || 0,
              item.m02 || 0,
              item.m03 || 0,
              item.m04 || 0,
              item.m05 || 0,
              item.m06 || 0,
              item.m07 || 0,
              item.m08 || 0,
              item.m09 || 0,
              item.m10 || 0,
              item.m11 || 0,
              item.m12 || 0,
            ],
            totalUsed: [
              item.m01 || 0,
              item.m02 || 0,
              item.m03 || 0,
              item.m04 || 0,
              item.m05 || 0,
              item.m06 || 0,
              item.m07 || 0,
              item.m08 || 0,
              item.m09 || 0,
              item.m10 || 0,
              item.m11 || 0,
              item.m12 || 0,
            ].reduce((sum: number, val: number) => sum + val, 0),
          }));
        setManagementTableData(tableData);
      }
    } finally {
      setYearlyLoading(false);
    }
  };

  // 휴가 관리 대장 데이터 조회 (yearlyWholeStatus 사용)
  const loadManagementTable = async () => {
    try {
      setTableLoading(true);

      // yearlyWholeStatus가 있으면 사용, 없으면 API 호출 시도
      if (yearlyWholeStatus && yearlyWholeStatus.length > 0) {
        const tableData = yearlyWholeStatus
          .filter((item: YearlyWholeStatus) => item.leaveType !== '총계')
          .map((item: YearlyWholeStatus) => ({
            leaveType: item.leaveType || '',
            allowedDays: item.totalDays || 0,
            usedByMonth: [
              item.m01 || 0,
              item.m02 || 0,
              item.m03 || 0,
              item.m04 || 0,
              item.m05 || 0,
              item.m06 || 0,
              item.m07 || 0,
              item.m08 || 0,
              item.m09 || 0,
              item.m10 || 0,
              item.m11 || 0,
              item.m12 || 0,
            ],
            totalUsed: [
              item.m01 || 0,
              item.m02 || 0,
              item.m03 || 0,
              item.m04 || 0,
              item.m05 || 0,
              item.m06 || 0,
              item.m07 || 0,
              item.m08 || 0,
              item.m09 || 0,
              item.m10 || 0,
              item.m11 || 0,
              item.m12 || 0,
            ].reduce((sum: number, val: number) => sum + val, 0),
          }));
        setManagementTableData(tableData);
        return;
      }

      // yearlyWholeStatus가 없으면 기존 데이터 사용
      if (leaveData.yearlyWholeStatus && leaveData.yearlyWholeStatus.length > 0) {
        const tableData = leaveData.yearlyWholeStatus
          .filter((item: YearlyWholeStatus) => item.leaveType !== '총계')
          .map((item: YearlyWholeStatus) => ({
            leaveType: item.leaveType || '',
            allowedDays: item.totalDays || 0,
            usedByMonth: [
              item.m01 || 0,
              item.m02 || 0,
              item.m03 || 0,
              item.m04 || 0,
              item.m05 || 0,
              item.m06 || 0,
              item.m07 || 0,
              item.m08 || 0,
              item.m09 || 0,
              item.m10 || 0,
              item.m11 || 0,
              item.m12 || 0,
            ],
            totalUsed: [
              item.m01 || 0,
              item.m02 || 0,
              item.m03 || 0,
              item.m04 || 0,
              item.m05 || 0,
              item.m06 || 0,
              item.m07 || 0,
              item.m08 || 0,
              item.m09 || 0,
              item.m10 || 0,
              item.m11 || 0,
              item.m12 || 0,
            ].reduce((sum: number, val: number) => sum + val, 0),
          }));
        setManagementTableData(tableData);
      }
    } catch (err) {
      console.error('휴가 관리 대장 조회 실패:', err);
      setManagementTableData([]);
    } finally {
      setTableLoading(false);
    }
  };

  const handleRequestDialogOpen = () => {
    setRequestDialogOpen(true);
  };

  const handleRequestDialogClose = () => {
    setRequestDialogOpen(false);
    setIsSequentialApproval(false); // 순차결재 모드 초기화
    setRequestForm({
      leaveType: '',
      startDate: dayjs(),
      endDate: dayjs(),
      reason: '',
      halfDaySlot: '',
      approverIds: [],
      ccList: [],
      useHalfDay: false,
      useNextYearLeave: false,
    });
  };

  // 취소 상신 성공 처리
  const handleCancelSuccess = () => {
    // 데이터 새로고침
    onRefresh();
    setCancelRequestModalOpen(false);
    setCancelRequestLeave(null);
  };


  const getStatusColor = (status: string) => {
    switch (status) {
      case 'APPROVED':
        return '#20C997';
      case 'REJECTED':
        return '#DC3545';
      case 'REQUESTED':
        return '#FF8C00';
      case 'CANCEL_REQUESTED':
        return '#F59E0B';
      case 'CANCELLED':
        return '#9CA3AF';
      default:
        return '#6B7280';
    }
  };

  const getStatusIcon = (status: string) => {
    const colors = {
      approved: isDark ? '#34D399' : '#20C997',
      rejected: isDark ? '#F87171' : '#DC3545',
      requested: isDark ? '#FBBF24' : '#FF8C00',
      cancelRequested: isDark ? '#FCD34D' : '#F59E0B',
      cancelled: isDark ? '#9CA3AF' : '#9CA3AF',
      default: isDark ? '#9CA3AF' : '#6B7280',
    };

    switch (status) {
      case 'APPROVED':
        return <CheckCircleIcon sx={{ color: colors.approved, fontSize: 20 }} />;
      case 'REJECTED':
        return <CancelIcon sx={{ color: colors.rejected, fontSize: 20 }} />;
      case 'REQUESTED':
        return <PendingIcon sx={{ color: colors.requested, fontSize: 20 }} />;
      case 'CANCEL_REQUESTED':
        return <PendingIcon sx={{ color: colors.cancelRequested, fontSize: 20 }} />;
      case 'CANCELLED':
        return <CancelIcon sx={{ color: colors.cancelled, fontSize: 20 }} />;
      default:
        return <ScheduleIcon sx={{ color: colors.default, fontSize: 20 }} />;
    }
  };

  // 개인별 휴가 내역 페이지네이션 로직
  const getFilteredYearlyDetails = () => {
    if (!yearlyDetails || !Array.isArray(yearlyDetails)) {
      console.log('⚠️ yearlyDetails가 배열이 아님:', yearlyDetails);
      return [];
    }
    const filtered = yearlyDetails.filter((detail: YearlyDetail) => !hideCanceled || detail.status !== 'CANCELLED');
    console.log('🔍 개인별 휴가 내역 - 전체:', yearlyDetails.length, '필터링 후:', filtered.length);
    return filtered;
  };

  const getPaginatedYearlyDetails = () => {
    const filtered = getFilteredYearlyDetails();
    const startIndex = (currentPage - 1) * itemsPerPage;
    const endIndex = startIndex + itemsPerPage;
    const paginated = filtered.slice(startIndex, endIndex);
    console.log('📄 페이지네이션 - 현재페이지:', currentPage, '시작:', startIndex, '끝:', endIndex, '결과:', paginated.length);
    return paginated;
  };

  const filteredCount = getFilteredYearlyDetails().length;
  const totalPages = Math.max(1, Math.ceil(filteredCount / itemsPerPage));
  console.log('📊 총 페이지:', totalPages, '현재 페이지:', currentPage, '전체 항목:', filteredCount);

  const handlePageChange = (page: number) => {
    setCurrentPage(page);
  };

  // 필터 변경 시 페이지 1로 리셋
  useEffect(() => {
    console.log('🔄 페이지 리셋 - 연도:', selectedYear, '취소건숨김:', hideCanceled);
    setCurrentPage(1);
  }, [selectedYear, hideCanceled, yearlyDetails]);

  return (
    <Box sx={{ height: '100vh', display: 'flex', flexDirection: 'column', bgcolor: colorScheme.backgroundColor }}>
      {/* 사이드바와 메인 컨텐츠를 감싸는 컨테이너 */}
      <Box sx={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        {/* 사이드바 */}
        <Box
          sx={{
            width: sidebarOpen ? 240 : 60,
            bgcolor: colorScheme.surfaceColor,
            borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
            display: 'flex',
            flexDirection: 'column',
            transition: 'width 0.3s ease-in-out',
            position: 'relative',
            zIndex: 1000,
          }}
        >
          {/* 사이드바 헤더 */}
          <Box
            sx={{
              p: 1.5,
              display: 'flex',
              alignItems: 'center',
              justifyContent: sidebarOpen ? 'space-between' : 'center',
              borderBottom: `1px solid ${colorScheme.textFieldBorderColor}`,
              minHeight: 64,
            }}
          >
            {sidebarOpen && (
              <Typography sx={{ fontSize: '16px', fontWeight: 600, color: colorScheme.textColor }}>
                메뉴
              </Typography>
            )}
            <IconButton
              onClick={() => setSidebarOpen(!sidebarOpen)}
              sx={{
                color: colorScheme.hintTextColor,
                '&:hover': { bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F3F4F6' },
              }}
            >
              {sidebarOpen ? <ChevronLeftIcon /> : <MenuIcon />}
            </IconButton>
          </Box>

          {/* 사이드바 메뉴 */}
          <Box sx={{ flex: 1, overflow: 'auto', py: 1 }}>
            {/* 부서 휴가 현황 메뉴 (기존) */}
            <Box
              onClick={() => setTotalCalendarOpen(true)}
              sx={{
                display: 'flex',
                alignItems: 'center',
                px: sidebarOpen ? 2 : 1.5,
                py: 1.5,
                cursor: 'pointer',
                '&:hover': {
                  bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F3F4F6',
                },
              }}
            >
              <CalendarMonthIcon sx={{ color: colorScheme.primaryColor, fontSize: 24 }} />
              {sidebarOpen && (
                <Typography
                  sx={{
                    ml: 2,
                    fontSize: '14px',
                    fontWeight: 500,
                    color: colorScheme.textColor,
                  }}
                >
                  부서 휴가 현황
                </Typography>
              )}
            </Box>

            {/* 휴가 부여 내역 메뉴 (신규 추가) */}
            <Box
              onClick={() => navigate('/leave-grant-history')}
              sx={{
                display: 'flex',
                alignItems: 'center',
                px: sidebarOpen ? 2 : 1.5,
                py: 1.5,
                cursor: 'pointer',
                '&:hover': {
                  bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F3F4F6',
                },
              }}
            >
              <AssignmentIcon sx={{ color: colorScheme.primaryColor, fontSize: 24 }} />
              {sidebarOpen && (
                <Typography
                  sx={{
                    ml: 2,
                    fontSize: '14px',
                    fontWeight: 500,
                    color: colorScheme.textColor,
                  }}
                >
                  휴가 부여 내역
                </Typography>
              )}
            </Box>
          </Box>
        </Box>

        {/* 메인 컨텐츠 영역 */}
        <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
          {/* AppBar - Flutter 스타일 */}
          <Box
            sx={{
              bgcolor: colorScheme.surfaceColor,
              borderBottom: `1px solid ${colorScheme.textFieldBorderColor}`,
              px: 2,
              py: 1.5,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
            }}
          >
            {/* 왼쪽: 뒤로가기 버튼 + 타이틀 */}
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <IconButton
                onClick={() => navigate('/chat')}
                sx={{
                  color: colorScheme.textColor,
                  '&:hover': {
                    bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.04)',
                  },
                }}
              >
                <ArrowBackIcon />
              </IconButton>
              <Typography variant="h6" sx={{ fontWeight: 600, fontSize: '18px', color: colorScheme.textColor }}>
                휴가관리
              </Typography>
            </Box>

            {/* Toolbar Buttons - Flutter 스타일 */}
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>

              {/* 관리자용 결재 버튼 - 승인자인 경우에만 표시 */}
              {isApprover && (
                <Badge
                  badgeContent={waitingCount}
                  color="error"
                  invisible={waitingCount === 0}
                  max={99}
                >
                  <Button
                    variant="contained"
                    startIcon={<AdminPanelSettingsIcon sx={{ fontSize: 18 }} />}
                    onClick={() => {
                      navigate('/admin-leave', { replace: false });
                    }}
                    sx={{
                      bgcolor: isDark ? '#8B5CF6' : '#6F42C1',
                      color: 'white',
                      fontSize: '13px',
                      fontWeight: 600,
                      textTransform: 'none',
                      borderRadius: '8px',
                      px: 2,
                      py: 0.75,
                      '&:hover': {
                        bgcolor: isDark ? '#7C3AED' : '#5a359a',
                      },
                    }}
                  >
                    관리자용 결재
                  </Button>
                </Badge>
              )}

              {/* 취소건 숨김 버튼 */}
              <Button
                variant="text"
                startIcon={
                  hideCanceled ? (
                    <VisibilityIcon sx={{ fontSize: 18 }} />
                  ) : (
                    <VisibilityOffIcon sx={{ fontSize: 18 }} />
                  )
                }
                onClick={() => setHideCanceled(!hideCanceled)}
                sx={{
                  color: colorScheme.textColor,
                  fontSize: '13px',
                  textTransform: 'none',
                }}
              >
                취소건 숨김
              </Button>

              {/* 휴가 작성 버튼 */}
              <Button
                variant="contained"
                startIcon={<EditCalendarIcon sx={{ fontSize: 18 }} />}
                onClick={handleRequestDialogOpen}
                sx={{
                  bgcolor: isDark ? '#60A5FA' : '#3B82F6',
                  color: 'white',
                  fontSize: '13px',
                  fontWeight: 600,
                  textTransform: 'none',
                  borderRadius: '8px',
                  px: 2,
                  py: 0.75,
                  '&:hover': {
                    bgcolor: isDark ? '#3B82F6' : '#2563EB',
                  },
                }}
              >
                휴가 작성
              </Button>
            </Box>
          </Box>

          {/* Main Content - Flutter 레이아웃과 동일 */}
          <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, height: '100%' }}>
              {/* 상단 영역: 내 휴가 현황 + 결재진행 현황 */}
              <Box sx={{ display: 'flex', gap: 1.5, flexShrink: 0, alignItems: 'stretch' }}>
                {/* 왼쪽: 내 휴가 현황 */}
                <Box sx={{ flex: 1, display: 'flex' }}>
                  <Card
                    sx={{
                      width: '100%',
                      borderRadius: '12px',
                      border: `1px solid ${colorScheme.textFieldBorderColor}`,
                      boxShadow: isDark ? '0 2px 8px rgba(0, 0, 0, 0.2)' : '0 2px 8px rgba(0, 0, 0, 0.04)',
                      display: 'flex',
                      flexDirection: 'column',
                      bgcolor: colorScheme.surfaceColor,
                    }}
                  >
                    <CardContent sx={{ p: 1.5, '&:last-child': { pb: 1.5 }, display: 'flex', flexDirection: 'column', flex: 1 }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', mb: 1, flexShrink: 0 }}>
                        <Box
                          sx={{
                            p: 0.75,
                            borderRadius: '8px',
                            background: isDark
                              ? 'linear-gradient(135deg, #34D399 0%, #10B981 100%)'
                              : 'linear-gradient(135deg, #20C997 0%, #17A589 100%)',
                            mr: 1,
                          }}
                        >
                          <EventIcon sx={{ color: 'white', fontSize: 14 }} />
                        </Box>
                        <Typography sx={{ fontSize: '13px', fontWeight: 700, color: colorScheme.textColor }}>
                          내 휴가 현황
                        </Typography>
                      </Box>

                      <Box sx={{ display: 'flex', gap: 1, flex: 1, alignItems: 'stretch' }}>
                        {leaveData.leaveStatus && leaveData.leaveStatus.length > 0 ? (
                          leaveData.leaveStatus.slice(0, 4).map((status: LeaveStatus, index: number) => (
                            <Box
                              key={index}
                              sx={{
                                flex: 1,
                                textAlign: 'center',
                                p: 1,
                                borderRadius: '6px',
                                bgcolor: isDark ? 'rgba(52, 211, 153, 0.15)' : 'rgba(32, 201, 151, 0.08)',
                                display: 'flex',
                                flexDirection: 'column',
                                justifyContent: 'center',
                              }}
                            >
                              <Typography sx={{ fontSize: '10px', color: colorScheme.hintTextColor, mb: 0.25, fontWeight: 500 }}>
                                {(status as any).leave_type || status.leaveType || '휴가'}
                              </Typography>
                              <Typography
                                sx={{
                                  fontSize: '16px',
                                  fontWeight: 700,
                                  color: isDark ? '#34D399' : '#20C997',
                                  lineHeight: 1.1,
                                }}
                              >
                                {(status as any).remain_days ?? status.remainDays ?? 0}
                                <Typography component="span" sx={{ fontSize: '10px', ml: 0.25 }}>
                                  일
                                </Typography>
                              </Typography>
                              <Typography sx={{ fontSize: '9px', color: colorScheme.hintTextColor, mt: 0.25 }}>
                                / {(status as any).total_days ?? status.totalDays ?? 0}일
                              </Typography>
                            </Box>
                          ))
                        ) : (
                          <Typography sx={{ fontSize: '12px', color: colorScheme.hintTextColor, textAlign: 'center', flex: 1, py: 1.5 }}>
                            휴가 정보 없음
                          </Typography>
                        )}
                      </Box>
                    </CardContent>
                  </Card>
                </Box>

                {/* 오른쪽: 결재진행 현황 */}
                <Box sx={{ flex: 1, display: 'flex' }}>
                  <Card
                    sx={{
                      width: '100%',
                      borderRadius: '12px',
                      border: `1px solid ${colorScheme.textFieldBorderColor}`,
                      boxShadow: isDark ? '0 2px 8px rgba(0, 0, 0, 0.2)' : '0 2px 8px rgba(0, 0, 0, 0.04)',
                      display: 'flex',
                      flexDirection: 'column',
                      bgcolor: colorScheme.surfaceColor,
                    }}
                  >
                    <CardContent sx={{ p: 1.5, '&:last-child': { pb: 1.5 }, display: 'flex', flexDirection: 'column', flex: 1 }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1, flexShrink: 0 }}>
                        <Box sx={{ display: 'flex', alignItems: 'center' }}>
                          <Box
                            sx={{
                              p: 0.75,
                              borderRadius: '8px',
                              background: isDark
                                ? 'linear-gradient(135deg, #60A5FA 0%, #3B82F6 100%)'
                                : 'linear-gradient(135deg, #1E88E5 0%, #1976D2 100%)',
                              mr: 1,
                            }}
                          >
                            <AssignmentIcon sx={{ color: 'white', fontSize: 14 }} />
                          </Box>
                          <Typography sx={{ fontSize: '13px', fontWeight: 700, color: colorScheme.textColor }}>
                            결재 진행 현황
                          </Typography>
                        </Box>

                        <Chip
                          label={`총 ${(leaveData.approvalStatus?.requested || 0) +
                            (leaveData.approvalStatus?.approved || 0) +
                            (leaveData.approvalStatus?.rejected || 0)
                            }건`}
                          size="small"
                          sx={{
                            bgcolor: isDark ? 'rgba(96, 165, 250, 0.2)' : 'rgba(30, 136, 229, 0.12)',
                            color: isDark ? '#60A5FA' : '#1E88E5',
                            fontSize: '10px',
                            fontWeight: 600,
                            height: 22,
                            px: 0.75,
                          }}
                        />
                      </Box>

                      <Box sx={{ display: 'flex', gap: 1, flex: 1, alignItems: 'stretch' }}>
                        {/* 대기중 */}
                        <Box sx={{ flex: 1, textAlign: 'center', p: 1, borderRadius: '6px', bgcolor: isDark ? 'rgba(251, 191, 36, 0.15)' : 'rgba(255, 140, 0, 0.08)', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 0.25, mb: 0.25 }}>
                            <ScheduleIcon sx={{ fontSize: 12, color: isDark ? '#FBBF24' : '#FF8C00' }} />
                            <Typography sx={{ fontSize: '10px', color: colorScheme.hintTextColor, fontWeight: 500 }}>대기중</Typography>
                          </Box>
                          <Typography sx={{ fontSize: '18px', fontWeight: 700, color: isDark ? '#FBBF24' : '#FF8C00', lineHeight: 1.1 }}>
                            {leaveData.approvalStatus?.requested || 0}
                          </Typography>
                        </Box>

                        {/* 승인됨 */}
                        <Box sx={{ flex: 1, textAlign: 'center', p: 1, borderRadius: '6px', bgcolor: isDark ? 'rgba(52, 211, 153, 0.15)' : 'rgba(32, 201, 151, 0.08)', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 0.25, mb: 0.25 }}>
                            <CheckCircleIcon sx={{ fontSize: 12, color: isDark ? '#34D399' : '#20C997' }} />
                            <Typography sx={{ fontSize: '10px', color: colorScheme.hintTextColor, fontWeight: 500 }}>승인됨</Typography>
                          </Box>
                          <Typography sx={{ fontSize: '18px', fontWeight: 700, color: isDark ? '#34D399' : '#20C997', lineHeight: 1.1 }}>
                            {leaveData.approvalStatus?.approved || 0}
                          </Typography>
                        </Box>

                        {/* 반려됨 */}
                        <Box sx={{ flex: 1, textAlign: 'center', p: 1, borderRadius: '6px', bgcolor: isDark ? 'rgba(248, 113, 113, 0.15)' : 'rgba(220, 53, 69, 0.08)', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 0.25, mb: 0.25 }}>
                            <CancelIcon sx={{ fontSize: 12, color: isDark ? '#F87171' : '#DC3545' }} />
                            <Typography sx={{ fontSize: '10px', color: colorScheme.hintTextColor, fontWeight: 500 }}>반려됨</Typography>
                          </Box>
                          <Typography sx={{ fontSize: '18px', fontWeight: 700, color: isDark ? '#F87171' : '#DC3545', lineHeight: 1.1 }}>
                            {leaveData.approvalStatus?.rejected || 0}
                          </Typography>
                        </Box>
                      </Box>
                    </CardContent>
                  </Card>
                </Box>
              </Box>

              {/* 하단 영역: 개인별 휴가 내역 + 달력/휴가 관리 대장 */}
              <Box sx={{ display: 'flex', gap: 1.5, flex: 1, minHeight: 0 }}>
                {/* 왼쪽: 개인별 휴가 내역 (50%) */}
                <Box sx={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
                  <Card sx={{ height: '100%', borderRadius: '16px', display: 'flex', flexDirection: 'column', bgcolor: colorScheme.surfaceColor, border: `1px solid ${colorScheme.textFieldBorderColor}` }}>
                    <CardContent sx={{ p: 2, flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', minHeight: 0 }}>
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, flexShrink: 0 }}>
                        <Typography sx={{ fontSize: '16px', fontWeight: 700, color: colorScheme.textColor }}>개인별 휴가 내역</Typography>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                          <Button
                            variant="outlined"
                            size="small"
                            startIcon={<AutoAwesomeIcon />}
                            onClick={() => setAiModalOpen(true)}
                            sx={{
                              borderRadius: '10px',
                              textTransform: 'none',
                              fontWeight: 600,
                              borderColor: '#667EEA',
                              color: '#667EEA',
                              px: 2,
                              '&:hover': {
                                borderColor: '#764BA2',
                                bgcolor: isDark ? 'rgba(102, 126, 234, 0.05)' : 'rgba(102, 126, 234, 0.05)',
                              },
                            }}
                          >
                            내 휴가계획 AI 추천
                          </Button>
                          <Chip
                            label={`${filteredCount}건${filteredCount > 0 ? ` (${currentPage}/${totalPages}페이지)` : ''}`}
                            size="small"
                            color={filteredCount > itemsPerPage ? "primary" : "default"}
                            sx={{ fontSize: '11px' }}
                          />
                          <FormControl size="small" sx={{ minWidth: 100 }}>
                            <Select
                              value={selectedYear}
                              onChange={(e) => setSelectedYear(e.target.value as number)}
                              sx={{
                                fontSize: '13px',
                                bgcolor: colorScheme.surfaceColor,
                                color: colorScheme.textColor,
                                '& .MuiOutlinedInput-notchedOutline': {
                                  borderColor: colorScheme.textFieldBorderColor,
                                },
                                '&:hover .MuiOutlinedInput-notchedOutline': {
                                  borderColor: colorScheme.textFieldBorderColor,
                                },
                                '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                  borderColor: colorScheme.textFieldBorderColor,
                                },
                                '& .MuiSelect-icon': {
                                  color: colorScheme.textColor,
                                },
                              }}
                            >
                              {[2024, 2025, 2026].map((year) => (
                                <MenuItem
                                  key={year}
                                  value={year}
                                  sx={{
                                    color: colorScheme.textColor,
                                    bgcolor: colorScheme.surfaceColor,
                                    '&:hover': {
                                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.04)',
                                    },
                                    '&.Mui-selected': {
                                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.08)',
                                      '&:hover': {
                                        bgcolor: isDark ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.12)',
                                      },
                                    },
                                  }}
                                >
                                  {year}년
                                </MenuItem>
                              ))}
                            </Select>
                          </FormControl>
                        </Box>
                      </Box>

                      <Box sx={{ flex: 1, overflow: 'auto' }}>
                        {yearlyLoading ? (
                          <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
                            <CircularProgress size={24} />
                          </Box>
                        ) : getPaginatedYearlyDetails().length > 0 ? (
                          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                            {getPaginatedYearlyDetails().map((detail: YearlyDetail, index: number) => (
                              <Box
                                key={index}
                                sx={{
                                  p: 1.5,
                                  border: '1px solid',
                                  borderColor: colorScheme.textFieldBorderColor,
                                  borderRadius: '8px',
                                  cursor: 'pointer',
                                  bgcolor: colorScheme.surfaceColor,
                                  '&:hover': {
                                    bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.02)',
                                  },
                                }}
                                onClick={() => {
                                  setSelectedLeaveDetail(detail);
                                  setDetailPanelOpen(true);
                                }}
                              >
                                <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 0.5 }}>
                                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                    {getStatusIcon(detail.status)}
                                    <Typography sx={{ fontSize: '14px', fontWeight: 600, color: colorScheme.textColor }}>
                                      {detail.leaveType}
                                    </Typography>
                                  </Box>
                                  <Chip
                                    label={
                                      detail.status === 'APPROVED' ? '승인' :
                                        detail.status === 'REJECTED' ? '반려' :
                                          detail.status === 'REQUESTED' ? '대기' :
                                            detail.status === 'CANCEL_REQUESTED' ? '취소 대기' :
                                              detail.status === 'CANCELLED' ? '취소' :
                                                '대기'
                                    }
                                    size="small"
                                    sx={{
                                      bgcolor: `${getStatusColor(detail.status)}22`,
                                      color: getStatusColor(detail.status),
                                      fontSize: '11px',
                                      height: 20,
                                    }}
                                  />
                                </Box>
                                <Typography sx={{ fontSize: '12px', color: colorScheme.hintTextColor }}>
                                  {dayjs(detail.startDate).format('YYYY-MM-DD')} ~ {dayjs(detail.endDate).format('YYYY-MM-DD')}
                                </Typography>
                                <Typography sx={{ fontSize: '12px', color: colorScheme.hintTextColor, mt: 0.5 }}>
                                  {detail.reason}
                                </Typography>
                                {detail.rejectMessage && (
                                  <Box sx={{
                                    mt: 1,
                                    p: 1,
                                    bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.03)',
                                    borderRadius: 1,
                                    border: `1px solid ${colorScheme.textFieldBorderColor}`
                                  }}>
                                    <Typography sx={{ fontSize: '11px', color: colorScheme.textColor }}>
                                      <Typography component="span" sx={{ fontWeight: 600 }}>반려 사유:</Typography> {detail.rejectMessage}
                                    </Typography>
                                  </Box>
                                )}
                              </Box>
                            ))}
                          </Box>
                        ) : (
                          <Box sx={{ textAlign: 'center', py: 4 }}>
                            <EventIcon sx={{ fontSize: 60, color: isDark ? '#4B5563' : '#E5E7EB', mb: 1 }} />
                            <Typography sx={{ color: colorScheme.hintTextColor }}>
                              {getFilteredYearlyDetails().length === 0 ? '휴가 내역이 없습니다' : '해당 페이지에 항목이 없습니다'}
                            </Typography>
                          </Box>
                        )}
                      </Box>

                      {/* 페이지네이션 */}
                      {totalPages > 1 && (
                        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 2, flexShrink: 0 }}>
                          <Stack spacing={2}>
                            <Pagination
                              count={totalPages}
                              page={currentPage}
                              onChange={(_e, page) => handlePageChange(page)}
                              color="primary"
                              size="small"
                              showFirstButton
                              showLastButton
                            />
                          </Stack>
                        </Box>
                      )}
                    </CardContent>
                  </Card>
                </Box>

                {/* 오른쪽: 달력 + 휴가 관리 대장 (50%) */}
                <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 1.5, minHeight: 0 }}>
                  {/* 위: 휴가 일정 달력 (55%) */}
                  <Box sx={{ flex: 5.5, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
                    <Card sx={{ height: '100%', borderRadius: '16px', display: 'flex', flexDirection: 'column', bgcolor: colorScheme.surfaceColor, border: `1px solid ${colorScheme.textFieldBorderColor}` }}>
                      <CardContent sx={{ p: 1, flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', minHeight: 0, '&:last-child': { pb: 1 } }}>
                        <Typography sx={{ fontSize: '14px', fontWeight: 700, mb: 0.75, flexShrink: 0, color: colorScheme.textColor }}>휴가 일정 달력</Typography>
                        <Box sx={{ flex: 1, overflow: 'hidden', minHeight: 0, display: 'flex', flexDirection: 'column' }}>
                          <PersonalCalendar
                            monthlyLeaves={leaveData.monthlyLeaves || []}
                            loading={false}
                            error={null}
                            onTotalCalendarOpen={() => setTotalCalendarOpen(true)}
                          />
                        </Box>
                      </CardContent>
                    </Card>
                  </Box>

                  {/* 아래: 휴가 관리 대장 (45%) */}
                  <Box sx={{ flex: 4.5, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
                    <Card sx={{ height: '100%', borderRadius: '16px', display: 'flex', flexDirection: 'column', bgcolor: colorScheme.surfaceColor, border: `1px solid ${colorScheme.textFieldBorderColor}` }}>
                      <CardContent sx={{ p: 2, flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', minHeight: 0 }}>
                        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2, flexShrink: 0 }}>
                          <Typography sx={{ fontSize: '16px', fontWeight: 700, color: colorScheme.textColor }}>휴가 관리 대장</Typography>
                          <IconButton
                            onClick={() => setManagementTableDialogOpen(true)}
                            size="small"
                            sx={{ p: 0.5 }}
                            title="크게 보기"
                          >
                            <FullscreenIcon />
                          </IconButton>
                        </Box>
                        <Box sx={{ flex: 1, overflow: 'auto' }}>
                          <TableContainer sx={{ maxHeight: '100%', overflowX: 'auto' }}>
                            <Table size="small" stickyHeader sx={{ borderCollapse: 'separate', minWidth: 800 }}>
                              <TableHead>
                                <TableRow>
                                  <TableCell
                                    sx={{
                                      fontSize: '11px',
                                      fontWeight: 600,
                                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.08)' : '#F9FAFB',
                                      color: colorScheme.textColor,
                                      px: 1,
                                      py: 1,
                                      borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                                      position: 'sticky',
                                      left: 0,
                                      zIndex: 3,
                                    }}
                                  >
                                    휴가종류
                                  </TableCell>
                                  <TableCell
                                    sx={{
                                      fontSize: '11px',
                                      fontWeight: 600,
                                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.08)' : '#F9FAFB',
                                      color: colorScheme.textColor,
                                      px: 1,
                                      py: 1,
                                      borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                                      textAlign: 'center',
                                    }}
                                  >
                                    허용일수
                                  </TableCell>
                                  {/* 월별 사용 현황 헤더 */}
                                  <TableCell
                                    colSpan={12}
                                    sx={{
                                      fontSize: '11px',
                                      fontWeight: 600,
                                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.08)' : '#F9FAFB',
                                      color: colorScheme.textColor,
                                      px: 0,
                                      py: 1,
                                      borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                                      textAlign: 'center',
                                    }}
                                  >
                                    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.5 }}>
                                      <Typography sx={{ fontSize: '11px', fontWeight: 600, color: colorScheme.textColor }}>
                                        월별 사용 현황
                                      </Typography>
                                      <Box sx={{ display: 'flex' }}>
                                        {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map((month) => (
                                          <Box
                                            key={month}
                                            sx={{
                                              flex: 1,
                                              fontSize: '10px',
                                              fontWeight: 500,
                                              color: colorScheme.hintTextColor,
                                              borderRight: month < 12 ? `1px solid ${colorScheme.textFieldBorderColor}` : 'none',
                                              py: 0.5,
                                            }}
                                          >
                                            {month}월
                                          </Box>
                                        ))}
                                      </Box>
                                    </Box>
                                  </TableCell>
                                  <TableCell
                                    sx={{
                                      fontSize: '11px',
                                      fontWeight: 600,
                                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.08)' : '#F9FAFB',
                                      color: colorScheme.textColor,
                                      px: 1,
                                      py: 1,
                                      textAlign: 'center',
                                    }}
                                  >
                                    사용일수
                                  </TableCell>
                                  <TableCell
                                    sx={{
                                      fontSize: '11px',
                                      fontWeight: 600,
                                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.08)' : '#F9FAFB',
                                      color: colorScheme.textColor,
                                      px: 1,
                                      py: 1,
                                      textAlign: 'center',
                                    }}
                                  >
                                    남은일수
                                  </TableCell>
                                </TableRow>
                              </TableHead>
                              <TableBody>
                                {tableLoading ? (
                                  <TableRow>
                                    <TableCell colSpan={16} align="center" sx={{ py: 4 }}>
                                      <CircularProgress size={24} />
                                    </TableCell>
                                  </TableRow>
                                ) : managementTableData && managementTableData.length > 0 ? (
                                  managementTableData.map((row: ManagementTableRow, index: number) => {
                                    const allowedDays = row.allowedDays || 0;
                                    const totalUsed = row.totalUsed || 0;
                                    const remainDays = allowedDays - totalUsed;
                                    const usedByMonth = row.usedByMonth || Array(12).fill(0);

                                    return (
                                      <TableRow
                                        key={index}
                                        hover
                                        sx={{
                                          '&:hover': {
                                            bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F3F4F6',
                                            '& .sticky-cell': {
                                              bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F3F4F6',
                                            },
                                          },
                                        }}
                                      >
                                        <TableCell
                                          className="sticky-cell"
                                          sx={{
                                            fontSize: '11px',
                                            fontWeight: 600,
                                            px: 1,
                                            py: 1,
                                            borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                                            position: 'sticky',
                                            left: 0,
                                            zIndex: 2,
                                            bgcolor: colorScheme.surfaceColor,
                                            color: colorScheme.textColor,
                                          }}
                                        >
                                          {row.leaveType || '-'}
                                        </TableCell>
                                        <TableCell
                                          sx={{
                                            fontSize: '11px',
                                            fontWeight: 600,
                                            px: 1,
                                            py: 1,
                                            borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                                            textAlign: 'center',
                                            color: colorScheme.textColor,
                                          }}
                                        >
                                          {allowedDays > 0 ? allowedDays : '-'}
                                        </TableCell>
                                        {/* 월별 사용일수 */}
                                        {usedByMonth.map((days: number, monthIndex: number) => (
                                          <TableCell
                                            key={monthIndex}
                                            sx={{
                                              fontSize: '10px',
                                              fontWeight: 600,
                                              px: 0.5,
                                              py: 1,
                                              textAlign: 'center',
                                              borderRight: monthIndex < 11 ? `1px solid ${colorScheme.textFieldBorderColor}` : 'none',
                                              color: days > 0 ? colorScheme.textColor : colorScheme.hintTextColor,
                                            }}
                                          >
                                            {days > 0 ? days : '-'}
                                          </TableCell>
                                        ))}
                                        <TableCell
                                          sx={{
                                            fontSize: '11px',
                                            fontWeight: 600,
                                            px: 1,
                                            py: 1,
                                            borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                                            textAlign: 'center',
                                            color: colorScheme.textColor,
                                          }}
                                        >
                                          {totalUsed > 0 ? totalUsed : '-'}
                                        </TableCell>
                                        <TableCell
                                          sx={{
                                            fontSize: '11px',
                                            fontWeight: 600,
                                            px: 1,
                                            py: 1,
                                            textAlign: 'center',
                                            color: remainDays > 0
                                              ? (isDark ? '#34D399' : '#059669')
                                              : (isDark ? '#F87171' : '#DC2626'),
                                          }}
                                        >
                                          {remainDays}
                                        </TableCell>
                                      </TableRow>
                                    );
                                  })
                                ) : (
                                  <TableRow>
                                    <TableCell colSpan={16} align="center" sx={{ py: 4 }}>
                                      <Typography sx={{ fontSize: '12px', color: colorScheme.hintTextColor }}>
                                        데이터가 없습니다
                                      </Typography>
                                    </TableCell>
                                  </TableRow>
                                )}
                              </TableBody>
                            </Table>
                          </TableContainer>
                        </Box>
                      </CardContent>
                    </Card>
                  </Box>
                </Box>
              </Box>
            </Box>
          </Box>


          {/* 휴가 신청 모달 - LeaveRequestModal 사용 */}
          <LeaveRequestModal
            open={requestDialogOpen}
            onClose={handleRequestDialogClose}
            onSubmit={async () => {
              // 휴가 신청 성공 후 데이터 새로고침
              onRefresh();
            }}
            userId={authService.getCurrentUser()?.userId || ''}
            leaveStatusList={leaveData.leaveStatus}
          />

          {/* 휴가 상세 정보 다이얼로그 */}
          <Dialog
            open={detailPanelOpen}
            onClose={() => setDetailPanelOpen(false)}
            maxWidth="sm"
            fullWidth
            PaperProps={{
              sx: {
                bgcolor: colorScheme.surfaceColor,
              },
            }}
          >
            <DialogTitle sx={{ borderBottom: `1px solid ${colorScheme.textFieldBorderColor}`, color: colorScheme.textColor }}>휴가 상세 정보</DialogTitle>
            <DialogContent>
              {selectedLeaveDetail && (
                <Box sx={{ pt: 2 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                    {getStatusIcon(selectedLeaveDetail.status)}
                    <Typography variant="h6" sx={{ color: colorScheme.textColor }}>{selectedLeaveDetail.leaveType}</Typography>
                    <Chip
                      label={
                        selectedLeaveDetail.status === 'APPROVED' ? '승인' :
                          selectedLeaveDetail.status === 'REJECTED' ? '반려' :
                            selectedLeaveDetail.status === 'REQUESTED' ? '대기' :
                              selectedLeaveDetail.status === 'CANCEL_REQUESTED' ? '취소 대기' :
                                selectedLeaveDetail.status === 'CANCELLED' ? '취소됨' :
                                  '대기'
                      }
                      color={
                        selectedLeaveDetail.status === 'APPROVED'
                          ? 'success'
                          : selectedLeaveDetail.status === 'REJECTED'
                            ? 'error'
                            : 'warning'
                      }
                      size="small"
                    />
                  </Box>

                  <Divider sx={{ my: 2 }} />

                  <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
                    <Box>
                      <Typography variant="caption" sx={{ color: colorScheme.hintTextColor, fontWeight: 600 }}>
                        휴가 기간
                      </Typography>
                      <Typography variant="body1" sx={{ color: colorScheme.textColor }}>
                        {dayjs(selectedLeaveDetail.startDate).format('YYYY-MM-DD')} ~{' '}
                        {dayjs(selectedLeaveDetail.endDate).format('YYYY-MM-DD')}
                      </Typography>
                      {selectedLeaveDetail.workdaysCount && (
                        <Typography variant="caption" sx={{ color: colorScheme.hintTextColor }}>
                          ({selectedLeaveDetail.workdaysCount}일 사용)
                        </Typography>
                      )}
                    </Box>

                    <Box>
                      <Typography variant="caption" sx={{ color: colorScheme.hintTextColor, fontWeight: 600 }}>
                        신청일
                      </Typography>
                      <Typography variant="body1" sx={{ color: colorScheme.textColor }}>
                        {dayjs(selectedLeaveDetail.requestedDate).format('YYYY-MM-DD')}
                      </Typography>
                    </Box>

                    {/* 사유 - 일반 상신과 취소 상신 구분 */}
                    {selectedLeaveDetail.isCancel === 1 ? (
                      <>
                        {/* 취소 상신인 경우: 원래 신청 사유와 취소 사유 구분 */}
                        <Alert severity="warning" sx={{ mb: 2 }}>
                          <Typography sx={{ fontSize: '13px', fontWeight: 600 }}>
                            이 항목은 취소 상신 건입니다.
                          </Typography>
                        </Alert>

                        {/* 원래 휴가 신청 사유 */}
                        {selectedLeaveDetail?.originalReason && (
                          <Box sx={{
                            p: 2,
                            bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.02)',
                            borderRadius: 1,
                            border: `1px solid ${colorScheme.textFieldBorderColor}`,
                            mb: 1.5
                          }}>
                            <Typography variant="caption" sx={{ color: colorScheme.hintTextColor, fontWeight: 600, display: 'block', mb: 0.5 }}>
                              원래 휴가 신청 사유
                            </Typography>
                            <Typography variant="body2" sx={{ color: colorScheme.textColor }}>
                              {selectedLeaveDetail.originalReason}
                            </Typography>
                          </Box>
                        )}

                        {/* 취소 요청 사유 */}
                        <Box sx={{
                          p: 2,
                          bgcolor: isDark ? 'rgba(237, 108, 2, 0.15)' : 'rgba(237, 108, 2, 0.08)',
                          borderRadius: 1,
                          border: '1px solid rgba(237, 108, 2, 0.3)'
                        }}>
                          <Typography variant="caption" sx={{ color: '#C77700', fontWeight: 600, display: 'block', mb: 0.5 }}>
                            취소 요청 사유
                          </Typography>
                          <Typography variant="body2" sx={{ color: colorScheme.textColor }}>
                            {selectedLeaveDetail.reason || '-'}
                          </Typography>
                        </Box>
                      </>
                    ) : (
                      /* 일반 상신인 경우 */
                      <Box>
                        <Typography variant="caption" sx={{ color: colorScheme.hintTextColor, fontWeight: 600 }}>
                          휴가 사유
                        </Typography>
                        <Typography variant="body1" sx={{ color: colorScheme.textColor, mt: 0.5 }}>
                          {selectedLeaveDetail.reason || '-'}
                        </Typography>
                      </Box>
                    )}

                    {/* 반려 사유 */}
                    {selectedLeaveDetail.rejectMessage && (
                      <Box sx={{
                        p: 2,
                        bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.03)',
                        borderRadius: 1,
                        border: `1px solid ${colorScheme.textFieldBorderColor}`
                      }}>
                        <Typography variant="caption" sx={{ color: colorScheme.hintTextColor, fontWeight: 600, display: 'block', mb: 0.5 }}>
                          반려 사유
                        </Typography>
                        <Typography variant="body2" sx={{ color: colorScheme.textColor }}>
                          {selectedLeaveDetail.rejectMessage}
                        </Typography>
                      </Box>
                    )}
                  </Box>
                </Box>
              )}
            </DialogContent>
            <DialogActions sx={{ p: 2, gap: 1, justifyContent: 'space-between' }}>
              {selectedLeaveDetail && selectedLeaveDetail.status === 'APPROVED' && (
                <Button
                  variant="contained"
                  color="warning"
                  startIcon={<CancelIcon />}
                  onClick={() => {
                    setDetailPanelOpen(false);
                    setCancelRequestLeave(selectedLeaveDetail);
                    setCancelRequestModalOpen(true);
                  }}
                >
                  취소 상신
                </Button>
              )}
              <Box sx={{ ml: 'auto' }}>
                <Button onClick={() => setDetailPanelOpen(false)} variant="outlined">닫기</Button>
              </Box>
            </DialogActions>
          </Dialog>

        </Box>
      </Box>

      {/* 전체휴가 달력 모달 */}
      <TotalCalendar
        open={totalCalendarOpen}
        onClose={() => setTotalCalendarOpen(false)}
      />

      {/* 승인자 선택 모달 */}
      <ApproverSelectionModal
        open={approverModalOpen}
        onClose={() => setApproverModalOpen(false)}
        onConfirm={(selectedIds) => {
          setRequestForm((prev) => ({ ...prev, approverIds: selectedIds }));
        }}
        initialSelectedApproverIds={requestForm.approverIds}
        sequentialApproval={isSequentialApproval}
      />

      {/* 참조자 선택 모달 */}
      <ReferenceSelectionModal
        open={referenceModalOpen}
        onClose={() => setReferenceModalOpen(false)}
        onConfirm={(selectedReferences) => {
          setRequestForm((prev) => ({ ...prev, ccList: selectedReferences }));
        }}
        currentReferences={requestForm.ccList}
      />

      {/* 휴가 관리 대장 크게 보기 모달 */}
      <Dialog
        open={managementTableDialogOpen}
        onClose={() => setManagementTableDialogOpen(false)}
        maxWidth="xl"
        fullWidth
        PaperProps={{
          sx: {
            maxHeight: '90vh',
            height: '90vh',
            bgcolor: colorScheme.surfaceColor,
          },
        }}
      >
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', pb: 2, borderBottom: `1px solid ${colorScheme.textFieldBorderColor}`, fontSize: '18px', fontWeight: 700, color: colorScheme.textColor }}>
          <Box component="span">휴가 관리 대장</Box>
          <IconButton
            onClick={() => setManagementTableDialogOpen(false)}
            size="small"
            sx={{ p: 0.5 }}
          >
            <ArrowBackIcon />
          </IconButton>
        </DialogTitle>
        <DialogContent sx={{ p: 3, overflow: 'auto' }}>
          <TableContainer sx={{ maxHeight: '100%', overflowX: 'auto' }}>
            <Table size="small" stickyHeader sx={{ borderCollapse: 'separate', minWidth: 800 }}>
              <TableHead>
                <TableRow>
                  <TableCell
                    sx={{
                      fontSize: '12px',
                      fontWeight: 600,
                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F9FAFB',
                      color: colorScheme.textColor,
                      px: 2,
                      py: 1.5,
                      borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                      position: 'sticky',
                      left: 0,
                      zIndex: 3,
                    }}
                  >
                    휴가명
                  </TableCell>
                  <TableCell
                    sx={{
                      fontSize: '12px',
                      fontWeight: 600,
                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F9FAFB',
                      color: colorScheme.textColor,
                      px: 2,
                      py: 1.5,
                      textAlign: 'center',
                    }}
                  >
                    허용일수
                  </TableCell>
                  <TableCell colSpan={12}>
                    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.5 }}>
                      <Typography sx={{ fontSize: '12px', fontWeight: 600, textAlign: 'center', color: colorScheme.textColor }}>월별 사용 현황</Typography>
                      <Box sx={{ display: 'flex' }}>
                        {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map((month) => (
                          <Box
                            key={month}
                            sx={{
                              flex: 1,
                              fontSize: '11px',
                              fontWeight: 600,
                              textAlign: 'center',
                              px: 1,
                              py: 0.5,
                              color: colorScheme.hintTextColor,
                              borderRight: month < 12 ? `1px solid ${colorScheme.textFieldBorderColor}` : 'none',
                            }}
                          >
                            {month}월
                          </Box>
                        ))}
                      </Box>
                    </Box>
                  </TableCell>
                  <TableCell
                    sx={{
                      fontSize: '12px',
                      fontWeight: 600,
                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F9FAFB',
                      color: colorScheme.textColor,
                      px: 2,
                      py: 1.5,
                      textAlign: 'center',
                    }}
                  >
                    사용일수
                  </TableCell>
                  <TableCell
                    sx={{
                      fontSize: '12px',
                      fontWeight: 600,
                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F9FAFB',
                      color: colorScheme.textColor,
                      px: 2,
                      py: 1.5,
                      textAlign: 'center',
                    }}
                  >
                    잔여일수
                  </TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {tableLoading ? (
                  <TableRow>
                    <TableCell colSpan={16} align="center" sx={{ py: 4 }}>
                      <CircularProgress size={24} />
                    </TableCell>
                  </TableRow>
                ) : managementTableData && managementTableData.length > 0 ? (
                  managementTableData.map((row: ManagementTableRow, index: number) => {
                    const allowedDays = row.allowedDays || 0;
                    const totalUsed = row.totalUsed || 0;
                    const remainDays = allowedDays - totalUsed;
                    const usedByMonth = row.usedByMonth || Array(12).fill(0);

                    return (
                      <TableRow
                        key={index}
                        hover
                        sx={{
                          '&:hover': {
                            bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F3F4F6',
                            '& .sticky-cell': {
                              bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#F3F4F6',
                            },
                          },
                        }}
                      >
                        <TableCell
                          className="sticky-cell"
                          sx={{
                            fontSize: '12px',
                            fontWeight: 600,
                            px: 2,
                            py: 1.5,
                            borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                            position: 'sticky',
                            left: 0,
                            zIndex: 2,
                            bgcolor: colorScheme.surfaceColor,
                            color: colorScheme.textColor,
                          }}
                        >
                          {row.leaveType || '-'}
                        </TableCell>
                        <TableCell
                          sx={{
                            fontSize: '12px',
                            fontWeight: 600,
                            px: 2,
                            py: 1.5,
                            borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                            textAlign: 'center',
                            color: colorScheme.textColor,
                          }}
                        >
                          {allowedDays > 0 ? allowedDays : '-'}
                        </TableCell>
                        {usedByMonth.map((days: number, monthIndex: number) => (
                          <TableCell
                            key={monthIndex}
                            sx={{
                              fontSize: '11px',
                              fontWeight: 600,
                              px: 1,
                              py: 1.5,
                              textAlign: 'center',
                              borderRight: monthIndex < 11 ? `1px solid ${colorScheme.textFieldBorderColor}` : 'none',
                              color: days > 0 ? colorScheme.textColor : colorScheme.hintTextColor,
                            }}
                          >
                            {days > 0 ? days : '-'}
                          </TableCell>
                        ))}
                        <TableCell
                          sx={{
                            fontSize: '12px',
                            fontWeight: 600,
                            px: 2,
                            py: 1.5,
                            borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                            textAlign: 'center',
                            color: colorScheme.textColor,
                          }}
                        >
                          {totalUsed > 0 ? totalUsed : '-'}
                        </TableCell>
                        <TableCell
                          sx={{
                            fontSize: '12px',
                            fontWeight: 600,
                            px: 2,
                            py: 1.5,
                            textAlign: 'center',
                            color: remainDays > 0
                              ? (isDark ? '#34D399' : '#059669')
                              : (isDark ? '#F87171' : '#DC2626'),
                          }}
                        >
                          {remainDays}
                        </TableCell>
                      </TableRow>
                    );
                  })
                ) : (
                  <TableRow>
                    <TableCell colSpan={16} align="center" sx={{ py: 4 }}>
                      <Typography sx={{ color: colorScheme.hintTextColor }}>데이터가 없습니다</Typography>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setManagementTableDialogOpen(false)} variant="contained">
            닫기
          </Button>
        </DialogActions>
      </Dialog>

      {/* 취소 상신 다이얼로그 (Flutter와 동일한 기능) */}
      <LeaveCancelRequestDialog
        open={cancelRequestModalOpen}
        onClose={() => {
          setCancelRequestModalOpen(false);
          setCancelRequestLeave(null);
        }}
        onSuccess={handleCancelSuccess}
        leave={cancelRequestLeave}
        userId={authService.getCurrentUser()?.userId || ''}
      />
      {/* AI 휴가 추천 모달 */}
      <VacationRecommendationModal
        open={aiModalOpen}
        onClose={() => setAiModalOpen(false)}
        userId={authService.getCurrentUser()?.userId || ''}
        year={selectedYear}
      />
    </Box>

  );
}
