import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  Chip,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Alert,
  CircularProgress,
  Divider,
  useMediaQuery,
  useTheme,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Drawer,
  Checkbox,
  Pagination,
  Stack,
} from '@mui/material';
import {
  ArrowBack as ArrowBackIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon,
  Schedule as ScheduleIcon,
  Person as PersonIcon,
  CalendarToday as CalendarTodayIcon,
  AccessTime as AccessTimeIcon,
  ChevronLeft as ChevronLeftIcon,
  ChevronRight as ChevronRightIcon,
  Fullscreen as FullscreenIcon,
  Close as CloseIcon,
  Today as TodayIcon,
  CalendarMonth as CalendarMonthIcon,
  EventNote as EventNoteIcon,
  Menu as MenuIcon,
  PeopleAltOutlined as PeopleAltOutlinedIcon,
  AdminPanelSettings as AdminPanelSettingsIcon,
  FilterList as FilterListIcon,
  FilterListOff as FilterListOffIcon,
  Refresh as RefreshIcon,
  CheckBoxOutlineBlank as CheckBoxOutlineBlankIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import authService from '../services/authService';
import leaveService from '../services/leaveService';
import type { AdminManagementApiResponse } from '../types/leave';
import { AdminCalendarSidebar } from '../components/admin/AdminCalendarSidebar';
import { DepartmentLeaveStatusModal } from '../components/admin/DepartmentLeaveStatusModal';

/**
 * 취소사유가 포함된 reason 파싱하여 UI 표시
 * Flutter admin_leave_approval_screen.dart의 _buildReasonText와 동일한 로직
 */
const parseReasonWithCancelReason = (reason: string) => {
  if (!reason || !reason.includes('취소사유:')) {
    return { hasCancelReason: false, cancelReason: '', originalReason: reason };
  }

  // "취소사유:"로 분리
  const parts = reason.split('취소사유:');
  if (parts.length < 2) {
    return { hasCancelReason: false, cancelReason: '', originalReason: reason };
  }

  const afterCancel = parts[1].trim();

  // "\n\n\n"으로 취소사유와 원래 사유 분리
  const cancelParts = afterCancel.split('\n\n\n');
  const cancelReason = cancelParts[0]?.trim() || '';
  const originalReason = cancelParts[1]?.trim() || '';

  return {
    hasCancelReason: true,
    cancelReason,
    originalReason,
  };
};

/**
 * 취소사유 UI 컴포넌트
 */
const RenderReasonWithCancelHighlight: React.FC<{ reason: string; maxLines?: number }> = ({ reason, maxLines }) => {
  const parsed = parseReasonWithCancelReason(reason);

  if (!parsed.hasCancelReason) {
    // 일반 사유만 표시
    return (
      <Typography
        variant="body2"
        color="text.secondary"
        sx={{
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          display: '-webkit-box',
          WebkitLineClamp: maxLines || 3,
          WebkitBoxOrient: 'vertical',
          wordBreak: 'break-word',
          whiteSpace: 'pre-wrap',
        }}
      >
        {reason}
      </Typography>
    );
  }

  // 취소사유 + 원래 사유 표시
  return (
    <Box>
      {/* 취소사유 섹션 */}
      <Box
        sx={{
          p: 1.5,
          mb: 1.5,
          bgcolor: 'rgba(220, 53, 69, 0.1)',
          borderRadius: '8px',
          border: '1px solid rgba(220, 53, 69, 0.3)',
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1 }}>
          <Typography
            variant="caption"
            sx={{
              fontSize: '12px',
              fontWeight: 700,
              color: '#DC3545',
            }}
          >
            취소사유
          </Typography>
        </Box>
        <Typography
          variant="body2"
          sx={{
            mt: 0.5,
            fontSize: '13px',
            color: '#495057',
            whiteSpace: 'pre-wrap',
            wordBreak: 'break-word',
          }}
        >
          {parsed.cancelReason}
        </Typography>
      </Box>

      {/* 원래 사유 섹션 */}
      {parsed.originalReason && (
        <Box>
          <Typography
            variant="caption"
            color="text.secondary"
            sx={{ display: 'block', mb: 0.5, fontSize: '12px', fontWeight: 600 }}
          >
            신청 사유
          </Typography>
          <Typography
            variant="body2"
            color="text.secondary"
            sx={{
              fontSize: '13px',
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-word',
            }}
          >
            {parsed.originalReason}
          </Typography>
        </Box>
      )}
    </Box>
  );
};

const AdminLeaveApprovalPage: React.FC = () => {
  const navigate = useNavigate();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const isDark = theme.palette.mode === 'dark';

  // 상태 관리
  const [currentTab, setCurrentTab] = useState<'pending' | 'all'>('pending');
  const [statusFilter, setStatusFilter] = useState<string | null>('REQUESTED');
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [adminData, setAdminData] = useState<AdminManagementApiResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // ===== 고급 필터링 상태 =====
  const [showAdvancedFilters, setShowAdvancedFilters] = useState(false);
  const [departmentFilter, setDepartmentFilter] = useState<string>('');
  const [positionFilter, setPositionFilter] = useState<string>('');
  const [leaveTypeFilters, setLeaveTypeFilters] = useState<Set<string>>(new Set());
  const [dateRangeFilter, setDateRangeFilter] = useState<{ start: Date | null, end: Date | null }>({
    start: null,
    end: null
  });
  const [nameSearchFilter, setNameSearchFilter] = useState('');

  // 필터 옵션 데이터
  const availableDepartments = [
    '개발팀', '디자인팀', '마케팅팀', '영업팀', '인사팀', '재무팀'
  ];
  const availablePositions = [
    '사원', '대리', '과장', '차장', '부장', '이사'
  ];
  const availableLeaveTypes = [
    '연차', '반차', '병가', '경조사', '출산휴가', '육아휴가', '기타'
  ];

  // 승인/반려 다이얼로그
  const [approvalDialog, setApprovalDialog] = useState(false);
  const [selectedLeave, setSelectedLeave] = useState<any | null>(null);
  const [approvalAction, setApprovalAction] = useState<'approve' | 'reject' | null>(null);
  const [rejectMessage, setRejectMessage] = useState('');
  const [actionLoading, setActionLoading] = useState(false);

  // 달력 관련 상태
  const [selectedDate, setSelectedDate] = useState(new Date());

  // 페이지네이션 상태
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = isMobile ? 5 : 10; // 모바일: 5개, 데스크톱: 10개
  const [currentCalendarDate, setCurrentCalendarDate] = useState(new Date());
  const [calendarLeaves, setCalendarLeaves] = useState<any[]>([]);

  // 전체보기 모달 상태
  const [fullscreenModalOpen, setFullscreenModalOpen] = useState(false);
  const [modalCalendarDate, setModalCalendarDate] = useState(new Date());
  const [modalSelectedDate, setModalSelectedDate] = useState(new Date());

  // 사이드바 상태
  const [sidebarExpanded, setSidebarExpanded] = useState(false);
  const [sidebarPinned, setSidebarPinned] = useState(false);
  const [mobileDrawerOpen, setMobileDrawerOpen] = useState(false);

  // 연도/월 선택 다이얼로그 상태
  const [yearMonthPickerOpen, setYearMonthPickerOpen] = useState(false);

  // 부서원 휴가 현황 모달 상태
  const [departmentStatusModalOpen, setDepartmentStatusModalOpen] = useState(false);

  // 상세 모달 상태
  const [detailModalOpen, setDetailModalOpen] = useState(false);
  const [selectedDetailLeave, setSelectedDetailLeave] = useState<any | null>(null);

  // ===== 일괄 작업 상태 =====
  const [isBatchMode, setIsBatchMode] = useState(false);
  const [selectedItems, setSelectedItems] = useState<Set<number>>(new Set());
  const [isBatchProcessing, setIsBatchProcessing] = useState(false);

  // ===== 일괄 작업 메서드들 =====

  const toggleBatchMode = () => {
    setIsBatchMode(!isBatchMode);
    if (isBatchMode) {
      setSelectedItems(new Set());
    }
  };

  const toggleSelectAll = (items: any[]) => {
    if (selectedItems.size === items.length) {
      setSelectedItems(new Set());
    } else {
      setSelectedItems(new Set(items.map(item => item.id)));
    }
  };

  const toggleItemSelection = (itemId: number) => {
    const newSelection = new Set(selectedItems);
    if (newSelection.has(itemId)) {
      newSelection.delete(itemId);
    } else {
      newSelection.add(itemId);
    }
    setSelectedItems(newSelection);
  };

  const batchApprove = async () => {
    if (selectedItems.size === 0) return;

    setIsBatchProcessing(true);
    let successCount = 0;

    for (const itemId of selectedItems) {
      try {
        await leaveService.approveLeaveRequest({
          id: itemId,
          approverId: authService.getCurrentUser()?.userId || '',
          isApproved: 'APPROVED',
        });
        successCount++;
      } catch (error) {
        console.error('일괄 승인 실패 (ID: ${itemId}):', error);
      }
    }

    if (successCount > 0) {
      // 데이터 새로고침
      await loadAdminData();
      setSelectedItems(new Set());
      setIsBatchMode(false);
    }

    setIsBatchProcessing(false);
  };

  const batchReject = async (reason: string) => {
    if (selectedItems.size === 0) return;

    setIsBatchProcessing(true);
    let successCount = 0;

    for (const itemId of selectedItems) {
      try {
        await leaveService.approveLeaveRequest({
          id: itemId,
          approverId: authService.getCurrentUser()?.userId || '',
          isApproved: 'REJECTED',
          rejectMessage: reason,
        });
        successCount++;
      } catch (error) {
        console.error('일괄 반려 실패 (ID: ${itemId}):', error);
      }
    }

    if (successCount > 0) {
      // 데이터 새로고침
      await loadAdminData();
      setSelectedItems(new Set());
      setIsBatchMode(false);
    }

    setIsBatchProcessing(false);
  };

  const showBatchRejectDialog = () => {
    const reason = prompt('반려 사유를 입력해주세요:');
    if (reason && reason.trim()) {
      batchReject(reason.trim());
    }
  };

  // ===== 필터링 로직 =====

  // 필터 적용 함수
  const applyFilters = (items: any[]) => {
    return items.filter((item) => {
      // 부서 필터
      if (departmentFilter && departmentFilter !== '전체') {
        if (item.department !== departmentFilter) return false;
      }

      // 직급 필터
      if (positionFilter && positionFilter !== '전체') {
        if (item.job_position !== positionFilter) return false;
      }

      // 휴가 유형 필터 (다중 선택)
      if (leaveTypeFilters.size > 0) {
        if (!item.leave_type || !leaveTypeFilters.has(item.leave_type)) {
          return false;
        }
      }

      // 날짜 범위 필터
      if (dateRangeFilter.start && dateRangeFilter.end) {
        const requestDate = new Date(item.requested_date);
        if (requestDate < dateRangeFilter.start || requestDate > dateRangeFilter.end) {
          return false;
        }
      }

      // 이름 검색 필터
      if (nameSearchFilter.trim()) {
        const name = item.name?.toLowerCase() || '';
        if (!name.includes(nameSearchFilter.toLowerCase())) {
          return false;
        }
      }

      return true;
    });
  };

  // 필터 초기화
  const resetFilters = () => {
    setDepartmentFilter('');
    setPositionFilter('');
    setLeaveTypeFilters(new Set());
    setDateRangeFilter({ start: null, end: null });
    setNameSearchFilter('');
  };

  // 필터가 적용되었는지 확인
  const hasActiveFilters = departmentFilter ||
    positionFilter ||
    leaveTypeFilters.size > 0 ||
    dateRangeFilter.start ||
    dateRangeFilter.end ||
    nameSearchFilter.trim();

  // 필터 요약 텍스트
  const getActiveFiltersSummary = () => {
    const filters = [];
    if (departmentFilter) filters.push(`부서: ${departmentFilter}`);
    if (positionFilter) filters.push(`직급: ${positionFilter}`);
    if (leaveTypeFilters.size > 0) filters.push(`휴가유형: ${leaveTypeFilters.size}개`);
    if (dateRangeFilter.start && dateRangeFilter.end) filters.push('날짜범위');
    if (nameSearchFilter.trim()) filters.push('이름검색');
    return filters.join(', ');
  };

  // 관리자 권한 확인 및 초기 데이터 로드
  useEffect(() => {
    // 권한이 없어도 화면은 표시하고 경고만 표시
    if (!authService.hasAdminPermission()) {
      setError('관리자 권한이 필요합니다.');
      setLoading(false);
      return;
    }

    loadAdminData();
  }, [navigate]);

  // 연도 변경 시 결재 대기 목록만 업데이트
  useEffect(() => {
    if (adminData) {
      loadYearlyWaitingList(selectedYear);
    }
  }, [selectedYear]);

  const loadAdminData = async () => {
    try {
      setLoading(true);
      setError(null);

      const user = authService.getCurrentUser();
      if (!user) {
        throw new Error('사용자 정보를 찾을 수 없습니다.');
      }

      const currentMonth = dayjs().format('YYYY-MM');
      const response = await leaveService.getAdminManagementData({
        approverId: user.userId,
        month: currentMonth,
      });

      console.log('관리자 데이터 응답:', response);
      console.log('waiting_leaves 샘플:', response.waiting_leaves?.[0]);
      console.log('monthly_leaves 샘플:', response.monthly_leaves?.[0]);

      setAdminData(response);

      // 초기 달력 데이터 설정
      if (response.monthly_leaves) {
        setCalendarLeaves(response.monthly_leaves);
      }
    } catch (err: any) {
      console.error('관리자 데이터 로드 실패:', err);
      setError(err.message || '관리자 데이터를 불러오는데 실패했습니다.');
    } finally {
      setLoading(false);
    }
  };

  // 연도별 결재 대기 목록만 로드
  const loadYearlyWaitingList = async (year: number) => {
    try {
      const user = authService.getCurrentUser();
      if (!user) {
        console.error('사용자 정보가 없습니다.');
        return;
      }

      console.log('loadYearlyWaitingList 호출됨 - year:', year, 'userId:', user.userId);

      const response = await leaveService.getAdminYearlyLeave({
        approverId: user.userId,
        year: year,
      });

      console.log('연도별 결재 대기 목록 응답:', response);
      console.log('approval_status:', response.approval_status);
      console.log('yearly_details 개수:', response.yearly_details?.length || 0);

      // 기존 adminData를 유지하면서 yearly_details와 approval_status만 업데이트
      setAdminData(prev => ({
        ...prev,
        approval_status: response.approval_status || [],
        waiting_leaves: response.yearly_details || [],
      }));

      console.log('adminData 업데이트 완료');
    } catch (err: any) {
      console.error('연도별 데이터 로드 실패:', err);
      console.error('에러 상세:', err.response?.data);
      console.error('에러 상태:', err.response?.status);
      setError(`연도별 데이터를 불러오는데 실패했습니다: ${err.message}`);
    }
  };

  // 탭 변경 핸들러
  const handleTabChange = (tab: 'pending' | 'all') => {
    setCurrentTab(tab);
    if (tab === 'pending') {
      setStatusFilter('REQUESTED');
    } else {
      setStatusFilter(null);
    }
  };

  // 통계 카드 클릭 핸들러
  const handleStatusCardClick = (status: string) => {
    if (status === 'REQUESTED') {
      setCurrentTab('pending');
      setStatusFilter('REQUESTED');
    } else {
      setCurrentTab('all');
      setStatusFilter(statusFilter === status ? null : status);
    }
  };

  // 승인 처리
  const handleApprove = async () => {
    if (!selectedLeave) return;

    setActionLoading(true);
    try {
      const user = authService.getCurrentUser();
      if (!user) return;

      // 취소 상신인지 일반 상신인지 확인
      const isCancelRequest = selectedLeave.status &&
        selectedLeave.status.toUpperCase().includes('CANCEL') &&
        selectedLeave.status.toUpperCase().includes('REQUESTED');

      if (isCancelRequest) {
        // 취소 상신 승인 (항상 APPROVED)
        await leaveService.processCancelApproval({
          id: selectedLeave.id,
          approverId: user.userId,
        });
      } else {
        // 일반 휴가 승인
        await leaveService.processAdminApproval({
          id: selectedLeave.id,
          approverId: user.userId,
          isApproved: 'APPROVED',
        });
      }

      setApprovalDialog(false);
      setSelectedLeave(null);
      loadAdminData();
    } catch (err: any) {
      console.error('승인 처리 실패:', err);
      setError('승인 처리에 실패했습니다.');
    } finally {
      setActionLoading(false);
    }
  };

  // 반려 처리 (일반 휴가만 가능, 취소 상신은 반려 불가)
  const handleReject = async () => {
    if (!selectedLeave || !rejectMessage.trim()) {
      setError('반려 사유를 입력해주세요.');
      return;
    }

    setActionLoading(true);
    try {
      const user = authService.getCurrentUser();
      if (!user) return;

      // 일반 휴가 반려만 처리
      await leaveService.processAdminApproval({
        id: selectedLeave.id,
        approverId: user.userId,
        isApproved: 'REJECTED',
        rejectMessage: rejectMessage.trim(),
      });

      setApprovalDialog(false);
      setSelectedLeave(null);
      setRejectMessage('');
      loadAdminData();
    } catch (err: any) {
      console.error('반려 처리 실패:', err);
      setError('반려 처리에 실패했습니다.');
    } finally {
      setActionLoading(false);
    }
  };

  // 필터링된 휴가 신청 목록
  const getFilteredLeaves = (): any[] => {
    if (!adminData) return [];

    // 전체 결재 목록에서는 waiting_leaves와 monthly_leaves를 모두 포함
    let list: any[] = [];
    if (currentTab === 'all') {
      // 전체 탭에서는 waiting_leaves(대기/승인/반려)와 monthly_leaves(달력 데이터)를 합침
      // monthly_leaves는 과거 데이터를 포함할 수 있으므로 우선순위를 높임
      list = [
        ...(adminData.monthly_leaves || []),
        ...(adminData.waiting_leaves || [])
      ];
      // 중복 제거 (ID 기준) - monthly_leaves 우선
      const uniqueList = list.filter((item, index, self) =>
        index === self.findIndex((t) => t.id === item.id)
      );
      list = uniqueList;
    } else {
      // 대기 탭에서는 waiting_leaves만
      list = [...(adminData.waiting_leaves || [])];
    }

    if (currentTab === 'pending') {
      list = list.filter((leave) => leave.status && leave.status.toUpperCase().includes('REQUESTED'));
    }

    if (statusFilter) {
      if (statusFilter === 'REQUESTED') {
        list = list.filter((leave) => leave.status && leave.status.toUpperCase().includes('REQUESTED'));
      } else {
        list = list.filter((leave) => leave.status === statusFilter);
      }
    }

    // 고급 필터 적용
    if (hasActiveFilters) {
      list = applyFilters(list);
    }

    return list;
  };

  // 통계 추출
  const getStats = () => {
    let requested = 0;
    let approved = 0;
    let rejected = 0;

    if (adminData?.approval_status && Array.isArray(adminData.approval_status)) {
      adminData.approval_status.forEach((item: any) => {
        if (item.status === 'REQUESTED') requested = item.count;
        if (item.status === 'APPROVED') approved = item.count;
        if (item.status === 'REJECTED') rejected = item.count;
      });
    }

    return { requested, approved, rejected };
  };

  // 페이지네이션 적용된 목록 가져오기
  const getPaginatedLeaves = () => {
    const filtered = getFilteredLeaves();
    const startIndex = (currentPage - 1) * itemsPerPage;
    const endIndex = startIndex + itemsPerPage;
    return filtered.slice(startIndex, endIndex);
  };

  // 전체 페이지 수 계산
  const totalPages = Math.ceil(getFilteredLeaves().length / itemsPerPage);

  // 페이지 변경 핸들러
  const handlePageChange = (page: number) => {
    setCurrentPage(page);
  };

  // 필터 변경 시 페이지 1로 리셋
  useEffect(() => {
    setCurrentPage(1);
  }, [currentTab, statusFilter, departmentFilter, positionFilter, leaveTypeFilters, dateRangeFilter, nameSearchFilter]);

  // 달력 생성 함수
  const generateCalendar = (date: Date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const firstDayWeekday = firstDay.getDay();
    const daysInMonth = lastDay.getDate();

    const calendar: (Date | null)[][] = [];
    let week: (Date | null)[] = [];

    // 이전 달 날짜로 첫 주 시작 부분 채우기
    const prevMonthLastDay = new Date(year, month, 0);
    for (let i = firstDayWeekday - 1; i >= 0; i--) {
      const day = prevMonthLastDay.getDate() - i;
      week.push(new Date(year, month - 1, day));
    }

    // 현재 달 날짜
    for (let day = 1; day <= daysInMonth; day++) {
      week.push(new Date(year, month, day));
      if (week.length === 7) {
        calendar.push([...week]);
        week = [];
      }
    }

    // 다음 달 날짜로 마지막 주 채우기
    if (week.length > 0) {
      let nextDay = 1;
      while (week.length < 7) {
        week.push(new Date(year, month + 1, nextDay));
        nextDay++;
      }
      calendar.push(week);
    }

    return calendar;
  };

  // 해당 날짜의 휴가 정보 조회
  const getLeavesForDate = (date: Date) => {
    return calendarLeaves.filter((leave: any) => {
      const startDate = new Date(leave.start_date);
      const endDate = new Date(leave.end_date);
      const targetDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());

      const startLocal = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate());
      const endLocal = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());

      return targetDate >= startLocal && targetDate <= endLocal;
    });
  };

  // 선택된 날짜의 상세 정보
  const getSelectedDateDetails = () => {
    return getLeavesForDate(selectedDate);
  };

  // 월 변경 핸들러
  const handleMonthChange = async (direction: 'prev' | 'next') => {
    const newDate = new Date(currentCalendarDate);
    if (direction === 'prev') {
      newDate.setMonth(newDate.getMonth() - 1);
    } else {
      newDate.setMonth(newDate.getMonth() + 1);
    }
    setCurrentCalendarDate(newDate);

    // 월 변경 시 부서별 달력 API 호출
    try {
      const user = authService.getCurrentUser();
      if (!user) return;

      const month = dayjs(newDate).format('YYYY-MM');
      const response = await leaveService.getAdminDeptCalendar({
        approverId: user.userId,
        month: month,
      });

      if (response.monthlyLeaves) {
        setCalendarLeaves(response.monthlyLeaves);
      }
    } catch (err: any) {
      console.error('부서별 달력 조회 실패:', err);
    }
  };

  // 상태 색상
  const getStatusColor = (status: string, isCancel?: number) => {
    // status가 undefined일 경우 기본값 반환
    if (!status) return '#6B7280';

    // 취소 상신 상태 우선 처리
    if (isCancel === 1 && status === 'REQUESTED') return '#E53E3E'; // 취소 상신 대기: 빨간색 계열
    if (status === 'CANCEL_REQUESTED') return '#E53E3E'; // 취소 상신 대기: 빨간색 계열
    if (status === 'CANCELLED') return '#6C757D'; // 상신취소: 회색
    if (status.includes('REQUESTED')) return '#FF8C00'; // 일반 승인 대기: 주황색
    if (status === 'APPROVED') return '#20C997'; // 승인됨: 초록색
    if (status === 'REJECTED') return '#DC3545'; // 반려됨: 빨간색
    return '#6B7280'; // 기본: 회색
  };

  // 상태 레이블
  const getStatusLabel = (leave: any) => {
    // status가 없을 경우 기본값 반환
    if (!leave.status) return '알 수 없음';

    // 취소 상신 상태 우선 처리
    if (leave.isCancel === 1 && leave.status === 'REQUESTED') return '🔄 취소 상신 대기';
    if (leave.status === 'CANCEL_REQUESTED') return '🔄 취소 상신 대기';
    if (leave.status === 'CANCELLED') return '상신취소';
    if (leave.status === 'REQUESTED') return '승인 대기';
    if (leave.status === 'APPROVED') return '승인됨';
    if (leave.status === 'REJECTED') return '반려됨';
    return leave.status;
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  const stats = getStats();

  return (
    <Box sx={{ height: '100vh', display: 'flex', flexDirection: 'column', bgcolor: '#F5F5F5', position: 'relative' }}>
      {/* 데스크톱 사이드바 */}
      {!isMobile && (
        <AdminCalendarSidebar
          isExpanded={sidebarExpanded}
          isPinned={sidebarPinned}
          onHover={() => setSidebarExpanded(true)}
          onExit={() => {
            if (!sidebarPinned) {
              setSidebarExpanded(false);
            }
          }}
          onPinToggle={() => {
            setSidebarPinned(!sidebarPinned);
            if (!sidebarPinned) {
              setSidebarExpanded(true);
            }
          }}
        />
      )}

      {/* 모바일 Drawer 사이드바 */}
      {isMobile && (
        <Drawer
          anchor="left"
          open={mobileDrawerOpen}
          onClose={() => setMobileDrawerOpen(false)}
          PaperProps={{
            sx: {
              width: 285,
              background: theme.palette.mode === 'dark'
                ? 'linear-gradient(135deg, #2D2D2D 0%, #1A1A1A 100%)'
                : 'linear-gradient(135deg, #F8F9FA 0%, #FFFFFF 100%)',
            },
          }}
        >
          <Box
            sx={{
              display: 'flex',
              flexDirection: 'column',
              p: 2,
              height: '100%',
            }}
          >
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
                    bgcolor: 'rgba(156, 136, 212, 0.1)',
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
                    color: theme.palette.mode === 'dark' ? '#FFFFFF' : '#495057',
                  }}
                >
                  관리자 메뉴
                </Typography>
              </Box>
              <IconButton
                onClick={() => setMobileDrawerOpen(false)}
                size="small"
                sx={{
                  color: theme.palette.mode === 'dark' ? 'rgba(255, 255, 255, 0.7)' : '#6C757D',
                }}
              >
                <CloseIcon sx={{ fontSize: 20 }} />
              </IconButton>
            </Box>

            <Button
              fullWidth
              variant="contained"
              startIcon={<PeopleAltOutlinedIcon sx={{ fontSize: 18 }} />}
              onClick={() => {
                setMobileDrawerOpen(false);
                setDepartmentStatusModalOpen(true);
              }}
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
          </Box>
        </Drawer>
      )}

      {/* AppBar - Flutter 스타일 */}
      <Box
        sx={{
          bgcolor: isDark ? '#4C1D95' : '#9C88D4',
          color: 'white',
          px: 2,
          py: 1.5,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          ml: !isMobile ? (sidebarExpanded ? '285px' : '50px') : 0,
          transition: 'margin-left 0.3s ease-in-out',
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          {isMobile && (
            <IconButton
              onClick={() => setMobileDrawerOpen(true)}
              sx={{ color: 'white', mr: 0.5 }}
            >
              <MenuIcon />
            </IconButton>
          )}
          <IconButton onClick={() => navigate('/chat')} sx={{ color: 'white' }}>
            <ArrowBackIcon />
          </IconButton>
          <Typography variant="h6" sx={{ fontWeight: 600 }}>
            관리자 - 휴가 결재 관리
          </Typography>
        </Box>

        {/* 탭 버튼 */}
        <Box sx={{ display: 'flex', gap: 1, alignItems: 'center' }}>
          {/* 휴가관리 버튼 - 일반 휴가관리 화면으로 이동 */}
          <Button
            variant="outlined"
            size="small"
            startIcon={<EventNoteIcon sx={{ fontSize: 16 }} />}
            onClick={() => navigate('/leave', { state: { fromAdmin: true } })}
            sx={{
              bgcolor: 'rgba(255,255,255,0.15)',
              color: 'white',
              borderColor: 'rgba(255,255,255,0.5)',
              mr: 1,
              '&:hover': {
                bgcolor: 'rgba(255,255,255,0.25)',
                borderColor: 'white',
              },
            }}
          >
            휴가관리
          </Button>
          <Button
            variant={currentTab === 'pending' ? 'contained' : 'outlined'}
            size="small"
            onClick={() => handleTabChange('pending')}
            sx={{
              bgcolor: currentTab === 'pending' ? 'white' : 'transparent',
              color: currentTab === 'pending' ? '#9C88D4' : 'white',
              borderColor: 'white',
              '&:hover': {
                bgcolor: currentTab === 'pending' ? 'white' : 'rgba(255,255,255,0.1)',
              },
            }}
          >
            대기 중
          </Button>
          <Button
            variant={currentTab === 'all' ? 'contained' : 'outlined'}
            size="small"
            onClick={() => handleTabChange('all')}
            sx={{
              bgcolor: currentTab === 'all' ? 'white' : 'transparent',
              color: currentTab === 'all' ? '#9C88D4' : 'white',
              borderColor: 'white',
              '&:hover': {
                bgcolor: currentTab === 'all' ? 'white' : 'rgba(255,255,255,0.1)',
              },
            }}
          >
            전체
          </Button>

        </Box>
      </Box>

      {/* 메인 컨텐츠 */}
      <Box sx={{
        flex: 1,
        overflow: 'auto',
        px: isMobile ? 1 : 2,
        pt: 2,
        pb: 0,
        ml: !isMobile ? (sidebarExpanded ? '285px' : '50px') : 0,
        transition: 'margin-left 0.3s ease-in-out'
      }}>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
            {error}
          </Alert>
        )}

        {/* 통계 카드 */}
        <Box sx={{ display: 'flex', gap: 2, flexDirection: isMobile ? 'column' : 'row', mb: 3 }}>
          {/* 결재 대기 */}
          <Card
            sx={{
              flex: 1,
              cursor: 'pointer',
              border: statusFilter === 'REQUESTED' ? '2px solid #FF8C00' : '1px solid #E0E0E0',
            }}
            onClick={() => handleStatusCardClick('REQUESTED')}
          >
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                <ScheduleIcon sx={{ color: '#FF8C00' }} />
                <Typography variant="subtitle2">결재 대기</Typography>
              </Box>
              <Typography variant="h4" sx={{ color: '#FF8C00', fontWeight: 700 }}>
                {stats.requested}
              </Typography>
            </CardContent>
          </Card>

          {/* 승인 완료 */}
          <Card
            sx={{
              flex: 1,
              cursor: 'pointer',
              border: statusFilter === 'APPROVED' ? '2px solid #20C997' : '1px solid #E0E0E0',
            }}
            onClick={() => handleStatusCardClick('APPROVED')}
          >
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                <CheckCircleIcon sx={{ color: '#20C997' }} />
                <Typography variant="subtitle2">승인 완료</Typography>
              </Box>
              <Typography variant="h4" sx={{ color: '#20C997', fontWeight: 700 }}>
                {stats.approved}
              </Typography>
            </CardContent>
          </Card>

          {/* 반려 처리 */}
          <Card
            sx={{
              flex: 1,
              cursor: 'pointer',
              border: statusFilter === 'REJECTED' ? '2px solid #DC3545' : '1px solid #E0E0E0',
            }}
            onClick={() => handleStatusCardClick('REJECTED')}
          >
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                <CancelIcon sx={{ color: '#DC3545' }} />
                <Typography variant="subtitle2">반려 처리</Typography>
              </Box>
              <Typography variant="h4" sx={{ color: '#DC3545', fontWeight: 700 }}>
                {stats.rejected}
              </Typography>
            </CardContent>
          </Card>
        </Box>

        {/* 메인 컨텐츠 영역 */}
        {isMobile ? (
          /* 모바일: 결재 목록만 표시 (세로 스크롤) */
          <Box sx={{
            flex: 1,
            overflow: 'auto',
            px: 2,
            pb: 2,
            '&::-webkit-scrollbar': {
              width: '8px',
            },
            '&::-webkit-scrollbar-track': {
              background: '#f1f1f1',
              borderRadius: '10px',
            },
            '&::-webkit-scrollbar-thumb': {
              background: '#9C88D4',
              borderRadius: '10px',
            },
            '&::-webkit-scrollbar-thumb:hover': {
              background: '#8A72C8',
            },
          }}>
            <Card sx={{ borderRadius: '16px', mt: 2 }}>
              <CardContent sx={{ p: 2, '&:last-child': { pb: 2 } }}>
                <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1.5 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    {/* 일괄 작업 모드일 때 전체 선택 체크박스 */}
                    {isBatchMode && (
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Checkbox
                          checked={selectedItems.size === getPaginatedLeaves().length && getPaginatedLeaves().length > 0}
                          onChange={() => toggleSelectAll(getPaginatedLeaves())}
                          sx={{ p: 0 }}
                        />
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                          전체 선택
                        </Typography>
                      </Box>
                    )}
                    <Typography variant="h6" sx={{ fontWeight: 600, fontSize: '16px' }}>
                      {currentTab === 'pending' ? '결재 대기 목록' : '전체 결재 목록'}
                    </Typography>
                  </Box>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <FormControl size="small" sx={{ minWidth: 100 }}>
                      <Select
                        value={selectedYear}
                        onChange={(e) => setSelectedYear(e.target.value as number)}
                        sx={{ fontSize: '13px', height: '32px' }}
                      >
                        {[2024, 2025, 2026].map((year) => (
                          <MenuItem key={year} value={year}>
                            {year}년
                          </MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                    <Chip
                      label={`${getFilteredLeaves().length}건 (${currentPage}/${totalPages})`}
                      color="primary"
                      size="small"
                      sx={{ fontSize: '11px' }}
                    />
                  </Box>
                </Box>


                {/* 결재 목록 - 스크롤 가능 */}
                <Box sx={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 1,
                  flex: 1,
                  overflowY: 'auto',
                  pr: 1,
                  '&::-webkit-scrollbar': {
                    width: '6px',
                  },
                  '&::-webkit-scrollbar-track': {
                    background: '#f1f1f1',
                    borderRadius: '10px',
                  },
                  '&::-webkit-scrollbar-thumb': {
                    background: '#9C88D4',
                    borderRadius: '10px',
                  },
                  '&::-webkit-scrollbar-thumb:hover': {
                    background: '#8A72C8',
                  },
                }}>
                  {getPaginatedLeaves().length === 0 ? (
                    <Box sx={{ textAlign: 'center', py: 8 }}>
                      <Typography variant="h6" color="text.secondary">
                        {getFilteredLeaves().length === 0 ? '결재 대기 중인 항목이 없습니다' : '해당 페이지에 항목이 없습니다'}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                        {getFilteredLeaves().length === 0 ? '새로운 휴가 신청이 있을 때 이곳에 표시됩니다' : '다른 페이지를 확인해주세요'}
                      </Typography>
                    </Box>
                  ) : (
                    getPaginatedLeaves().map((leave: any, index: number) => (
                      <Card
                        key={leave.id || `leave-batch-${index}`}
                        onClick={() => {
                          if (!isBatchMode) {
                            setSelectedDetailLeave(leave);
                            setDetailModalOpen(true);
                          }
                        }}
                        sx={{
                          borderRadius: '8px',
                          border: leave.status?.includes('REQUESTED')
                            ? (leave.isCancel === 1 ? '2px solid #E53E3E' : '2px solid #FF8C00')
                            : '1px solid #E0E0E0',
                          cursor: isBatchMode ? 'default' : 'pointer',
                          flexShrink: 0, // 요소 크기 고정 - 압축 방지
                          minHeight: 'fit-content', // 최소 높이를 내용에 맞게
                          '&:hover': {
                            boxShadow: isBatchMode ? 0 : 2,
                          },
                        }}
                      >
                        <CardContent sx={{ p: 1.5, '&:last-child': { pb: 1.5 } }}>
                          {/* 일괄 작업 모드일 때 체크박스 */}
                          {isBatchMode && (
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                              <Checkbox
                                checked={selectedItems.has(leave.id)}
                                onChange={() => toggleItemSelection(leave.id)}
                                sx={{ p: 0 }}
                              />
                            </Box>
                          )}
                          {/* 첫 번째 줄: 상태 + 휴가일수 */}
                          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1 }}>
                            <Chip
                              label={getStatusLabel(leave)}
                              size="small"
                              sx={{
                                bgcolor: `${getStatusColor(leave.status)}22`,
                                color: getStatusColor(leave.status),
                                fontSize: '11px',
                                fontWeight: 600,
                              }}
                            />
                            <Chip
                              label={`${leave.leave_type}${leave.half_day_slot === 'AM' ? ' (오전반차)' :
                                  leave.half_day_slot === 'PM' ? ' (오후반차)' :
                                    leave.half_day_slot === 'ALL' ? ' (종일연차)' : ''
                                }`}
                              size="small"
                              sx={{
                                bgcolor: '#9C88D422',
                                color: '#9C88D4',
                              }}
                            />
                            {leave.half_day_slot && (
                              <Chip
                                label={leave.half_day_slot === 'AM' ? '오전 반차' : leave.half_day_slot === 'PM' ? '오후 반차' : leave.half_day_slot}
                                size="small"
                                sx={{
                                  bgcolor: '#FF8C0022',
                                  color: '#FF8C00',
                                  fontSize: '10px',
                                }}
                              />
                            )}
                            {leave.is_canceled === 1 && (
                              <Chip
                                label="취소 상신"
                                size="small"
                                sx={{
                                  bgcolor: '#FF8C0022',
                                  color: '#FF8C00',
                                  fontSize: '10px',
                                }}
                              />
                            )}
                            <Chip
                              label={`${Math.floor(leave.workdays_count)}일`}
                              sx={{
                                bgcolor: '#9C88D4',
                                color: 'white',
                                fontWeight: 700,
                                ml: 'auto',
                              }}
                            />
                          </Box>

                          {/* 신청자 정보 */}
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2, p: 1.5, bgcolor: '#F8F9FA', borderRadius: '12px' }}>
                            <Box
                              sx={{
                                width: 40,
                                height: 40,
                                bgcolor: '#9C88D422',
                                borderRadius: '50%',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                              }}
                            >
                              <PersonIcon sx={{ color: '#9C88D4', fontSize: 20 }} />
                            </Box>
                            <Box sx={{ flex: 1 }}>
                              <Typography variant="body1" fontWeight={600}>
                                {leave.name}
                              </Typography>
                              <Typography variant="caption" color="text.secondary">
                                {leave.department} | {leave.job_position}
                              </Typography>
                            </Box>
                          </Box>

                          {/* 기간 */}
                          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.5, mb: 1.5 }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              <CalendarTodayIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                              <Typography variant="body2" fontWeight={600}>
                                {dayjs(leave.start_date).format('YYYY.MM.DD')} - {dayjs(leave.end_date).format('YYYY.MM.DD')}
                              </Typography>
                            </Box>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, ml: 3 }}>
                              <AccessTimeIcon sx={{ fontSize: 14, color: 'text.secondary' }} />
                              <Typography variant="caption" color="text.secondary">
                                신청: {dayjs(leave.requested_date).format('MM.DD HH:mm')}
                              </Typography>
                            </Box>
                          </Box>

                          {/* 휴가 잔여일 정보 */}
                          <Box sx={{ display: 'flex', gap: 1, mb: 1.5, flexWrap: 'wrap' }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                              <Typography variant="caption" color="text.secondary">
                                총 휴가일:
                              </Typography>
                              <Typography variant="caption" fontWeight={600}>
                                {leave.total_days}일
                              </Typography>
                            </Box>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                              <Typography variant="caption" color="text.secondary">
                                잔여일:
                              </Typography>
                              <Typography variant="caption" fontWeight={600} sx={{ color: leave.remain_days < 5 ? '#DC3545' : 'inherit' }}>
                                {leave.remain_days}일
                              </Typography>
                            </Box>
                            {leave.join_date && (
                              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                <Typography variant="caption" color="text.secondary">
                                  입사일:
                                </Typography>
                                <Typography variant="caption" fontWeight={600}>
                                  {dayjs(leave.join_date).format('YYYY.MM.DD')}
                                </Typography>
                              </Box>
                            )}
                          </Box>

                          {/* 사유 */}
                          {leave.reason && (
                            <Box sx={{ mb: 1.5 }}>
                              <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                                사유:
                              </Typography>
                              <RenderReasonWithCancelHighlight reason={leave.reason} maxLines={2} />
                            </Box>
                          )}

                          {/* 반려 사유 (있는 경우) */}
                          {leave.reject_message && (
                            <Box sx={{ mb: 1.5, p: 1, bgcolor: 'rgba(0, 0, 0, 0.03)', borderRadius: '8px', border: '1px solid rgba(0, 0, 0, 0.12)' }}>
                              <Typography variant="caption" sx={{ display: 'block', mb: 0.5, fontWeight: 600, color: 'text.secondary' }}>
                                반려 사유:
                              </Typography>
                              <Typography
                                variant="body2"
                                sx={{
                                  color: 'text.primary',
                                  overflow: 'hidden',
                                  textOverflow: 'ellipsis',
                                  display: '-webkit-box',
                                  WebkitLineClamp: 2,
                                  WebkitBoxOrient: 'vertical',
                                  wordBreak: 'break-word',
                                }}
                              >
                                {leave.reject_message}
                              </Typography>
                            </Box>
                          )}

                          {/* 승인/반려 버튼 */}
                          {leave.status && leave.status.toUpperCase().includes('REQUESTED') && (
                            <>
                              <Divider sx={{ my: 2 }} />
                              <Box sx={{ display: 'flex', gap: 1.5 }}>
                                {/* 취소 상신: 취소 승인 버튼만 */}
                                {leave.status.toUpperCase().includes('CANCEL') && (
                                  <Button
                                    fullWidth
                                    variant="contained"
                                    color="warning"
                                    startIcon={<CheckCircleIcon />}
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      setSelectedLeave(leave);
                                      setApprovalAction('approve');
                                      setApprovalDialog(true);
                                    }}
                                  >
                                    취소 승인
                                  </Button>
                                )}

                                {/* 일반 상신: 반려 + 승인 버튼 */}
                                {!leave.status.toUpperCase().includes('CANCEL') && (
                                  <>
                                    <Button
                                      fullWidth
                                      variant="contained"
                                      color="error"
                                      startIcon={<CancelIcon />}
                                      onClick={(e) => {
                                        e.stopPropagation();
                                        setSelectedLeave(leave);
                                        setApprovalAction('reject');
                                        setApprovalDialog(true);
                                      }}
                                    >
                                      반려
                                    </Button>
                                    <Button
                                      fullWidth
                                      variant="contained"
                                      color="success"
                                      startIcon={<CheckCircleIcon />}
                                      onClick={(e) => {
                                        e.stopPropagation();
                                        setSelectedLeave(leave);
                                        setApprovalAction('approve');
                                        setApprovalDialog(true);
                                      }}
                                    >
                                      승인
                                    </Button>
                                  </>
                                )}
                              </Box>
                            </>
                          )}
                        </CardContent>
                      </Card>
                    ))
                  )}
                </Box>

                {/* 페이지네이션 */}
                {totalPages > 1 && (
                  <Box sx={{ display: 'flex', justifyContent: 'center', mt: 2 }}>
                    <Stack spacing={2}>
                      <Pagination
                        count={totalPages}
                        page={currentPage}
                        onChange={(e, page) => handlePageChange(page)}
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

            {/* 모바일: 달력 영역 */}
            <Card sx={{ borderRadius: '16px', mt: 2 }}>
              <CardContent sx={{ p: 1.5, '&:last-child': { pb: 1.5 } }}>
                {/* 달력 헤더 */}
                <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1, pb: 0.5, borderBottom: '1px solid #F1F3F5' }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Box
                      sx={{
                        p: 0.75,
                        borderRadius: '6px',
                        background: 'linear-gradient(135deg, #9C88D4 0%, #8A72C8 100%)',
                      }}
                    >
                      <CalendarTodayIcon sx={{ color: 'white', fontSize: 14 }} />
                    </Box>
                    <Typography variant="subtitle1" sx={{ fontSize: '15px', fontWeight: 600 }}>
                      부서원 휴가 일정
                    </Typography>
                  </Box>
                  <IconButton
                    size="small"
                    onClick={() => {
                      setModalCalendarDate(new Date(currentCalendarDate));
                      setModalSelectedDate(new Date(selectedDate));
                      setFullscreenModalOpen(true);
                    }}
                    sx={{
                      color: '#9C88D4',
                      '&:hover': {
                        bgcolor: '#9C88D422',
                      },
                    }}
                  >
                    <FullscreenIcon fontSize="small" />
                  </IconButton>
                </Box>

                {/* 월 네비게이션 */}
                <Box
                  sx={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    mb: 0.5,
                    px: 0.75,
                    py: 0.25,
                    bgcolor: '#F8F9FA',
                    borderRadius: '6px',
                    border: '1px solid #E9ECEF',
                  }}
                >
                  <IconButton
                    size="small"
                    onClick={() => handleMonthChange('prev')}
                    sx={{ color: '#6C757D' }}
                  >
                    <ChevronLeftIcon fontSize="small" />
                  </IconButton>
                  <Typography variant="body2" sx={{ fontWeight: 600, color: '#495057' }}>
                    {dayjs(currentCalendarDate).format('YYYY년 M월')}
                  </Typography>
                  <IconButton
                    size="small"
                    onClick={() => handleMonthChange('next')}
                    sx={{ color: '#6C757D' }}
                  >
                    <ChevronRightIcon fontSize="small" />
                  </IconButton>
                </Box>

                {/* 요일 헤더 */}
                <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 0.3, mb: 0.3 }}>
                  {['일', '월', '화', '수', '목', '금', '토'].map((day, index) => (
                    <Box
                      key={day}
                      sx={{
                        textAlign: 'center',
                        py: 0.5,
                        fontSize: '10px',
                        fontWeight: 600,
                        color: index === 0 ? '#E53E3E' : index === 6 ? '#3182CE' : '#6C757D80',
                      }}
                    >
                      {day}
                    </Box>
                  ))}
                </Box>

                {/* 달력 그리드 */}
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.3 }}>
                  {generateCalendar(currentCalendarDate).map((week, weekIndex) => (
                    <Box
                      key={weekIndex}
                      sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 0.3 }}
                    >
                      {week.map((date, dayIndex) => {
                        if (!date) return <Box key={dayIndex} />;

                        const isCurrentMonth = date.getMonth() === currentCalendarDate.getMonth();
                        const isToday =
                          date.getDate() === new Date().getDate() &&
                          date.getMonth() === new Date().getMonth() &&
                          date.getFullYear() === new Date().getFullYear();
                        const isSelected =
                          date.getDate() === selectedDate.getDate() &&
                          date.getMonth() === selectedDate.getMonth() &&
                          date.getFullYear() === selectedDate.getFullYear();
                        const dayLeaves = getLeavesForDate(date);
                        const hasLeave = dayLeaves.length > 0;
                        const weekday = date.getDay();

                        return (
                          <Box
                            key={dayIndex}
                            onClick={() => setSelectedDate(date)}
                            sx={{
                              aspectRatio: '1',
                              minHeight: '36px',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              borderRadius: '3px',
                              cursor: 'pointer',
                              bgcolor: isSelected
                                ? '#9C88D4'
                                : isToday
                                  ? '#9C88D480'
                                  : hasLeave && isCurrentMonth
                                    ? '#20C99726'
                                    : 'transparent',
                              '&:hover': {
                                bgcolor: isSelected ? '#9C88D4' : '#9C88D420',
                              },
                            }}
                          >
                            <Typography
                              variant="caption"
                              sx={{
                                fontSize: '11px',
                                fontWeight: isSelected || isToday ? 700 : 500,
                                color: isSelected
                                  ? 'white'
                                  : !isCurrentMonth
                                    ? '#ADB5BD'
                                    : weekday === 0
                                      ? '#E53E3E'
                                      : weekday === 6
                                        ? '#3182CE'
                                        : '#495057',
                              }}
                            >
                              {date.getDate()}
                            </Typography>
                          </Box>
                        );
                      })}
                    </Box>
                  ))}
                </Box>

                {/* 선택된 날짜의 휴가 내역 */}
                {getLeavesForDate(selectedDate).length > 0 && (
                  <Box sx={{ mt: 1.5, pt: 1.5, borderTop: '1px solid #E9ECEF' }}>
                    <Typography variant="subtitle2" sx={{ mb: 1, fontWeight: 600 }}>
                      {dayjs(selectedDate).format('M월 D일')} 휴가 내역
                    </Typography>
                    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.75 }}>
                      {getLeavesForDate(selectedDate).map((leave: any, index: number) => (
                        <Box
                          key={index}
                          sx={{
                            p: 1,
                            borderRadius: '6px',
                            bgcolor: '#F8F9FA',
                            border: '1px solid #E9ECEF',
                          }}
                        >
                          <Typography variant="caption" sx={{ fontWeight: 600, display: 'block' }}>
                            {leave.name} ({leave.department})
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            {leave.leave_type}
                          </Typography>
                        </Box>
                      ))}
                    </Box>
                  </Box>
                )}
              </CardContent>
            </Card>
          </Box>
        ) : (
          /* 데스크톱: 50:50 분할 레이아웃 */
          <Box sx={{ display: 'flex', gap: 2, height: 'calc(100vh - 280px)' }}>
            {/* 왼쪽: 결재 목록 (50%) */}
            <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
              <Card sx={{ borderRadius: '16px', flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                <CardContent sx={{ display: 'flex', flexDirection: 'column', flex: 1, overflow: 'hidden' }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2, flexShrink: 0 }}>
                    <Typography variant="h6" sx={{ fontWeight: 600 }}>
                      {currentTab === 'pending' ? '결재 대기 목록' : '전체 결재 목록'}
                    </Typography>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                      <FormControl size="small" sx={{ minWidth: 100 }}>
                        <Select
                          value={selectedYear}
                          onChange={(e) => setSelectedYear(e.target.value as number)}
                          sx={{ fontSize: '13px', height: '32px' }}
                        >
                          {[2024, 2025, 2026].map((year) => (
                            <MenuItem key={year} value={year}>
                              {year}년
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                      <Chip
                        label={`${getFilteredLeaves().length}건 (${currentPage}/${totalPages}페이지)`}
                        color="primary"
                        size="small"
                      />
                    </Box>
                  </Box>

                  {/* 결재 목록 - 스크롤 가능 */}
                  <Box sx={{
                    flex: 1,
                    overflowY: 'auto',
                    display: 'flex',
                    flexDirection: 'column',
                    gap: 2,
                    pr: 1,
                    '&::-webkit-scrollbar': {
                      width: '8px',
                    },
                    '&::-webkit-scrollbar-track': {
                      background: '#f1f1f1',
                      borderRadius: '10px',
                    },
                    '&::-webkit-scrollbar-thumb': {
                      background: '#9C88D4',
                      borderRadius: '10px',
                    },
                    '&::-webkit-scrollbar-thumb:hover': {
                      background: '#8A72C8',
                    },
                  }}>
                    {getPaginatedLeaves().length === 0 ? (
                      <Box sx={{ textAlign: 'center', py: 8 }}>
                        <Typography variant="h6" color="text.secondary">
                          {getFilteredLeaves().length === 0 ? '결재 대기 중인 항목이 없습니다' : '해당 페이지에 항목이 없습니다'}
                        </Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                          {getFilteredLeaves().length === 0 ? '새로운 휴가 신청이 있을 때 이곳에 표시됩니다' : '다른 페이지를 확인해주세요'}
                        </Typography>
                      </Box>
                    ) : (
                      getPaginatedLeaves().map((leave: any, index: number) => (
                        <Card
                          key={leave.id || `leave-${index}`}
                          onClick={() => {
                            setSelectedDetailLeave(leave);
                            setDetailModalOpen(true);
                          }}
                          sx={{
                            borderRadius: '8px',
                            border: leave.status?.includes('REQUESTED') ? '1px solid #FF8C00' : '1px solid #E0E0E0',
                            cursor: 'pointer',
                            p: 0,
                            flexShrink: 0, // 요소 크기 고정 - 압축 방지
                            minHeight: 'fit-content', // 최소 높이를 내용에 맞게
                            '&:hover': {
                              boxShadow: 2,
                            },
                          }}
                        >
                          <CardContent sx={{ p: 1.5, '&:last-child': { pb: 1.5 } }}> {/* padding 줄임 */}
                            {/* 상태 및 휴가 타입 */}
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2, flexWrap: 'wrap' }}>
                              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, flexWrap: 'wrap' }}>
                                <Chip
                                  label={getStatusLabel(leave)}
                                  size="small"
                                  sx={{
                                    bgcolor: `${getStatusColor(leave.status, leave.isCancel)}22`,
                                    color: getStatusColor(leave.status, leave.isCancel),
                                    fontSize: '10px',
                                    fontWeight: 600,
                                    height: '20px',
                                    '& .MuiChip-label': { px: 0.5 },
                                  }}
                                />
                                <Chip
                                  label={`${leave.leave_type}${leave.half_day_slot === 'AM' ? ' (오전반차)' :
                                      leave.half_day_slot === 'PM' ? ' (오후반차)' :
                                        leave.half_day_slot === 'ALL' ? ' (종일연차)' : ''
                                    }`}
                                  size="small"
                                  sx={{
                                    bgcolor: '#9C88D422',
                                    color: '#9C88D4',
                                    fontSize: '10px',
                                    height: '20px',
                                    '& .MuiChip-label': { px: 0.5 },
                                  }}
                                />
                                {leave.half_day_slot && (
                                  <Chip
                                    label={leave.half_day_slot === 'AM' ? '오전' : leave.half_day_slot === 'PM' ? '오후' : leave.half_day_slot}
                                    size="small"
                                    sx={{
                                      bgcolor: '#FF8C0022',
                                      color: '#FF8C00',
                                      fontSize: '9px',
                                      height: '18px',
                                      '& .MuiChip-label': { px: 0.3 },
                                    }}
                                  />
                                )}
                                {leave.is_canceled === 1 && (
                                  <Chip
                                    label="취소"
                                    size="small"
                                    sx={{
                                      bgcolor: '#FF8C0022',
                                      color: '#FF8C00',
                                      fontSize: '9px',
                                      height: '18px',
                                      '& .MuiChip-label': { px: 0.3 },
                                    }}
                                  />
                                )}
                              </Box>
                              <Chip
                                label={`${Math.floor(leave.workdays_count)}일`}
                                sx={{
                                  bgcolor: '#9C88D4',
                                  color: 'white',
                                  fontWeight: 700,
                                  fontSize: '12px',
                                  height: '22px',
                                  '& .MuiChip-label': { px: 0.8 },
                                }}
                              />
                            </Box>

                            {/* 두 번째 줄: 신청자 + 기간 한 줄로 */}
                            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1 }}>
                              {/* 신청자 정보 */}
                              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <Box
                                  sx={{
                                    width: 28,
                                    height: 28,
                                    bgcolor: '#9C88D422',
                                    borderRadius: '50%',
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                  }}
                                >
                                  <PersonIcon sx={{ color: '#9C88D4', fontSize: 14 }} />
                                </Box>
                                <Box>
                                  <Typography variant="body2" fontWeight={600} sx={{ lineHeight: 1.2 }}>
                                    {leave.name}
                                  </Typography>
                                  <Typography variant="caption" color="text.secondary" sx={{ fontSize: '10px', lineHeight: 1.2 }}>
                                    {leave.department} | {leave.job_position}
                                  </Typography>
                                </Box>
                              </Box>

                              {/* 기간 정보 */}
                              <Box sx={{ textAlign: 'right' }}>
                                <Typography variant="caption" fontWeight={600} sx={{ fontSize: '11px' }}>
                                  {dayjs(leave.start_date).format('MM.DD')}-{dayjs(leave.end_date).format('MM.DD')}
                                </Typography>
                                <Typography variant="caption" color="text.secondary" sx={{ fontSize: '9px', display: 'block' }}>
                                  {dayjs(leave.requested_date).format('MM.DD HH:mm')}
                                </Typography>
                              </Box>
                            </Box>


                            {/* 세 번째 줄: 휴가 정보 + 사유 */}
                            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1 }}>
                              <Box sx={{ display: 'flex', gap: 0.8, flexWrap: 'wrap' }}>
                                <Typography variant="caption" color="text.secondary" sx={{ fontSize: '10px' }}>
                                  총:{leave.total_days}일
                                </Typography>
                                <Typography variant="caption" color="text.secondary" sx={{ fontSize: '10px' }}>
                                  잔:{leave.remain_days}일
                                </Typography>
                                {leave.join_date && (
                                  <Typography variant="caption" color="text.secondary" sx={{ fontSize: '10px' }}>
                                    {dayjs(leave.join_date).format('YY.MM.DD')}입사
                                  </Typography>
                                )}
                              </Box>
                              {leave.reason && (
                                <Typography
                                  variant="caption"
                                  color="text.secondary"
                                  sx={{
                                    fontSize: '10px',
                                    maxWidth: '120px',
                                    overflow: 'hidden',
                                    textOverflow: 'ellipsis',
                                    whiteSpace: 'nowrap',
                                  }}
                                >
                                  {leave.reason}
                                </Typography>
                              )}
                            </Box>

                            {/* 반려 사유 (있는 경우) */}
                            {leave.reject_message && (
                              <Box sx={{ p: 0.5, bgcolor: 'rgba(0, 0, 0, 0.03)', borderRadius: '4px', border: '1px solid rgba(0, 0, 0, 0.12)' }}>
                                <Typography
                                  variant="caption"
                                  sx={{
                                    color: 'text.primary',
                                    fontSize: '9px',
                                    overflow: 'hidden',
                                    textOverflow: 'ellipsis',
                                    display: '-webkit-box',
                                    WebkitLineClamp: 1,
                                    WebkitBoxOrient: 'vertical',
                                    wordBreak: 'break-word',
                                  }}
                                >
                                  <Typography component="span" sx={{ fontWeight: 600 }}>반려 사유:</Typography> {leave.reject_message}
                                </Typography>
                              </Box>
                            )}

                            {/* 승인/반려 버튼 */}
                            {leave.status && leave.status.toUpperCase().includes('REQUESTED') && (
                              <>
                                <Divider sx={{ my: 2 }} />
                                <Box sx={{ display: 'flex', gap: 1.5 }}>
                                  {/* 취소 상신: 취소 승인 버튼만 */}
                                  {leave.status.toUpperCase().includes('CANCEL') && (
                                    <Button
                                      fullWidth
                                      variant="contained"
                                      color="warning"
                                      startIcon={<CheckCircleIcon />}
                                      onClick={(e) => {
                                        e.stopPropagation();
                                        setSelectedLeave(leave);
                                        setApprovalAction('approve');
                                        setApprovalDialog(true);
                                      }}
                                    >
                                      취소 승인
                                    </Button>
                                  )}

                                  {/* 일반 상신: 반려 + 승인 버튼 */}
                                  {!leave.status.toUpperCase().includes('CANCEL') && (
                                    <>
                                      <Button
                                        fullWidth
                                        variant="contained"
                                        color="error"
                                        startIcon={<CancelIcon />}
                                        onClick={(e) => {
                                          e.stopPropagation();
                                          setSelectedLeave(leave);
                                          setApprovalAction('reject');
                                          setApprovalDialog(true);
                                        }}
                                      >
                                        반려
                                      </Button>
                                      <Button
                                        fullWidth
                                        variant="contained"
                                        color="success"
                                        startIcon={<CheckCircleIcon />}
                                        onClick={(e) => {
                                          e.stopPropagation();
                                          setSelectedLeave(leave);
                                          setApprovalAction('approve');
                                          setApprovalDialog(true);
                                        }}
                                      >
                                        승인
                                      </Button>
                                    </>
                                  )}
                                </Box>
                              </>
                            )}
                          </CardContent>
                        </Card>
                      ))
                    )}
                  </Box>

                  {/* 페이지네이션 */}
                  {totalPages > 1 && (
                    <Box sx={{ display: 'flex', justifyContent: 'center', mt: 2, flexShrink: 0 }}>
                      <Stack spacing={2}>
                        <Pagination
                          count={totalPages}
                          page={currentPage}
                          onChange={(e, page) => handlePageChange(page)}
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

            {/* 오른쪽: 달력 영역 (50%) - Flutter와 동일 */}
            <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 1.5, height: '100%' }}>
              {/* 달력 (60%) - 높이 조정 */}
              <Box sx={{ flex: 6, minHeight: 0, display: 'flex' }}>
                <Card sx={{ borderRadius: '16px', width: '100%', display: 'flex', flexDirection: 'column' }}>
                  <CardContent sx={{ flex: 1, display: 'flex', flexDirection: 'column', p: 1.5, '&:last-child': { pb: 1.5 } }}>
                    {/* 달력 헤더 */}
                    <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1, pb: 0.5, borderBottom: '1px solid #F1F3F5', flexShrink: 0 }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Box
                          sx={{
                            p: 0.75,
                            borderRadius: '6px',
                            background: 'linear-gradient(135deg, #9C88D4 0%, #8A72C8 100%)',
                          }}
                        >
                          <CalendarTodayIcon sx={{ color: 'white', fontSize: 14 }} />
                        </Box>
                        <Typography variant="subtitle1" sx={{ fontSize: '15px', fontWeight: 600 }}>
                          부서원 휴가 일정
                        </Typography>
                      </Box>
                      <IconButton
                        size="small"
                        onClick={() => {
                          setModalCalendarDate(new Date(currentCalendarDate));
                          setModalSelectedDate(new Date(selectedDate));
                          setFullscreenModalOpen(true);
                        }}
                        sx={{
                          color: '#9C88D4',
                          '&:hover': {
                            bgcolor: '#9C88D422',
                          },
                        }}
                      >
                        <FullscreenIcon fontSize="small" />
                      </IconButton>
                    </Box>

                    {/* 월 네비게이션 */}
                    <Box
                      sx={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        mb: 0.5,
                        px: 0.75,
                        py: 0.25,
                        bgcolor: '#F8F9FA',
                        borderRadius: '6px',
                        border: '1px solid #E9ECEF',
                        flexShrink: 0,
                      }}
                    >
                      <IconButton
                        size="small"
                        onClick={() => handleMonthChange('prev')}
                        sx={{ color: '#6C757D' }}
                      >
                        <ChevronLeftIcon fontSize="small" />
                      </IconButton>
                      <Typography variant="body2" sx={{ fontWeight: 600, color: '#495057' }}>
                        {dayjs(currentCalendarDate).format('YYYY년 M월')}
                      </Typography>
                      <IconButton
                        size="small"
                        onClick={() => handleMonthChange('next')}
                        sx={{ color: '#6C757D' }}
                      >
                        <ChevronRightIcon fontSize="small" />
                      </IconButton>
                    </Box>

                    {/* 요일 헤더 */}
                    <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 0.3, mb: 0.3, flexShrink: 0 }}>
                      {['일', '월', '화', '수', '목', '금', '토'].map((day, index) => (
                        <Box
                          key={day}
                          sx={{
                            textAlign: 'center',
                            py: 0.5,
                            fontSize: '10px',
                            fontWeight: 600,
                            color: index === 0 ? '#E53E3E' : index === 6 ? '#3182CE' : '#6C757D80',
                          }}
                        >
                          {day}
                        </Box>
                      ))}
                    </Box>

                    {/* 달력 그리드 */}
                    <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 0.3, minHeight: 0 }}>
                      {generateCalendar(currentCalendarDate).map((week, weekIndex) => (
                        <Box
                          key={weekIndex}
                          sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 0.3, flex: 1, minHeight: 0 }}
                        >
                          {week.map((date, dayIndex) => {
                            if (!date) return <Box key={dayIndex} />;

                            const isCurrentMonth = date.getMonth() === currentCalendarDate.getMonth();
                            const isToday =
                              date.getDate() === new Date().getDate() &&
                              date.getMonth() === new Date().getMonth() &&
                              date.getFullYear() === new Date().getFullYear();
                            const isSelected =
                              date.getDate() === selectedDate.getDate() &&
                              date.getMonth() === selectedDate.getMonth() &&
                              date.getFullYear() === selectedDate.getFullYear();
                            const dayLeaves = getLeavesForDate(date);
                            const hasLeave = dayLeaves.length > 0;
                            const weekday = date.getDay();

                            return (
                              <Box
                                key={dayIndex}
                                onClick={() => setSelectedDate(date)}
                                sx={{
                                  height: '100%',
                                  width: '100%',
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'center',
                                  borderRadius: '3px',
                                  cursor: 'pointer',
                                  minHeight: '28px',
                                  bgcolor: isSelected
                                    ? '#9C88D4'
                                    : isToday
                                      ? '#9C88D480'
                                      : hasLeave && isCurrentMonth
                                        ? '#20C99726'
                                        : 'transparent',
                                  '&:hover': {
                                    bgcolor: isSelected ? '#9C88D4' : '#9C88D420',
                                  },
                                }}
                              >
                                <Typography
                                  variant="caption"
                                  sx={{
                                    fontSize: '10px',
                                    fontWeight: isSelected || isToday ? 700 : 500,
                                    color: isSelected
                                      ? 'white'
                                      : !isCurrentMonth
                                        ? '#ADB5BD'
                                        : weekday === 0
                                          ? '#E53E3E'
                                          : weekday === 6
                                            ? '#3182CE'
                                            : '#495057',
                                  }}
                                >
                                  {date.getDate()}
                                </Typography>
                              </Box>
                            );
                          })}
                        </Box>
                      ))}
                    </Box>
                  </CardContent>
                </Card>
              </Box>

              {/* 선택된 날짜 상세 (40%) - 높이 조정 */}
              <Box sx={{ flex: 4, minHeight: 0, display: 'flex' }}>
                <Card sx={{ borderRadius: '16px', width: '100%', display: 'flex', flexDirection: 'column' }}>
                  <CardContent sx={{ flex: 1, display: 'flex', flexDirection: 'column', p: 1.5, '&:last-child': { pb: 1.5 } }}>
                    <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1, fontSize: '14px', flexShrink: 0 }}>
                      {dayjs(selectedDate).format('YYYY.MM.DD')} 휴가 내역
                    </Typography>

                    <Box sx={{ flex: 1, overflow: 'auto', minHeight: 0, pr: 0.5 }}>
                      {getSelectedDateDetails().length === 0 ? (
                        <Box sx={{ textAlign: 'center', py: 4 }}>
                          <Typography variant="body2" color="text.secondary">
                            해당 날짜에 휴가 일정이 없습니다
                          </Typography>
                        </Box>
                      ) : (
                        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                          {getSelectedDateDetails().map((leave: any, index: number) => (
                            <Card
                              key={index}
                              sx={{
                                p: 1,
                                bgcolor: '#F8F9FA',
                                border: '1px solid #E9ECEF',
                                borderRadius: '6px',
                              }}
                            >
                              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 0.5 }}>
                                <PersonIcon sx={{ fontSize: 16, color: '#9C88D4' }} />
                                <Typography variant="body2" fontWeight={600}>
                                  {leave.name}
                                </Typography>
                              </Box>
                              <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 0.5 }}>
                                {leave.department} · {leave.job_position}
                              </Typography>
                              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                <Chip
                                  label={`${leave.leave_type}${leave.half_day_slot === 'AM' ? ' (오전반차)' :
                                      leave.half_day_slot === 'PM' ? ' (오후반차)' :
                                        leave.half_day_slot === 'ALL' ? ' (종일연차)' : ''
                                    }`}
                                  size="small"
                                  sx={{
                                    fontSize: '10px',
                                    height: '20px',
                                    bgcolor: '#20C99722',
                                    color: '#20C997',
                                  }}
                                />
                                <Typography variant="caption" color="text.secondary">
                                  {dayjs(leave.start_date).format('MM.DD')} ~ {dayjs(leave.end_date).format('MM.DD')}
                                </Typography>
                              </Box>
                            </Card>
                          ))}
                        </Box>
                      )}
                    </Box>
                  </CardContent>
                </Card>
              </Box>
            </Box>
          </Box>
        )}
      </Box>

      {/* 승인/반려 다이얼로그 */}
      <Dialog
        open={approvalDialog}
        onClose={() => !actionLoading && setApprovalDialog(false)}
        maxWidth="sm"
        fullWidth
        fullScreen={isMobile}
      >
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          {approvalAction === 'approve' ? (
            <CheckCircleIcon sx={{ color: '#20C997' }} />
          ) : (
            <CancelIcon sx={{ color: '#DC3545' }} />
          )}
          <Typography variant="h6" component="span" fontWeight={600}>
            {approvalAction === 'approve' ? '휴가 승인' : '휴가 반려'}
          </Typography>
        </DialogTitle>
        <DialogContent>
          {selectedLeave && (
            <Box sx={{ pt: 2 }}>
              <Box sx={{ mb: 2, p: 2, bgcolor: '#F5F5F5', borderRadius: '8px' }}>
                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                  신청자
                </Typography>
                <Typography variant="body1" fontWeight={600}>
                  {selectedLeave.name} ({selectedLeave.department} · {selectedLeave.job_position})
                </Typography>

                <Typography variant="subtitle2" color="text.secondary" sx={{ mt: 2 }} gutterBottom>
                  휴가 종류
                </Typography>
                <Typography variant="body1">
                  {selectedLeave.leave_type}
                  {selectedLeave.is_cancel === 1 && (
                    <Chip label="취소 상신" size="small" color="warning" sx={{ ml: 1 }} />
                  )}
                </Typography>

                <Typography variant="subtitle2" color="text.secondary" sx={{ mt: 2 }} gutterBottom>
                  휴가 기간
                </Typography>
                <Typography variant="body1">
                  {dayjs(selectedLeave.start_date).format('YYYY-MM-DD')} ~ {dayjs(selectedLeave.end_date).format('YYYY-MM-DD')} ({Math.floor(selectedLeave.workdays_count)}일)
                </Typography>

                <Typography variant="subtitle2" color="text.secondary" sx={{ mt: 2 }} gutterBottom>
                  신청일
                </Typography>
                <Typography variant="body1">
                  {dayjs(selectedLeave.requested_date).format('YYYY-MM-DD HH:mm')}
                </Typography>

                <Typography variant="subtitle2" color="text.secondary" sx={{ mt: 2 }} gutterBottom>
                  사유
                </Typography>
                {selectedLeave.reason ? (
                  <RenderReasonWithCancelHighlight reason={selectedLeave.reason} />
                ) : (
                  <Typography variant="body1">사유 없음</Typography>
                )}
              </Box>

              {approvalAction === 'reject' && (
                <TextField
                  label="반려 사유"
                  multiline
                  rows={3}
                  fullWidth
                  value={rejectMessage}
                  onChange={(e) => setRejectMessage(e.target.value)}
                  placeholder="반려 사유를 입력하세요"
                  required
                  sx={{ mt: 2 }}
                />
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions sx={{ p: 3 }}>
          <Button onClick={() => setApprovalDialog(false)} variant="outlined" disabled={actionLoading}>
            취소
          </Button>
          <Button
            onClick={approvalAction === 'approve' ? handleApprove : handleReject}
            variant="contained"
            color={approvalAction === 'approve' ? 'success' : 'error'}
            disabled={actionLoading}
          >
            {actionLoading ? '처리 중...' : approvalAction === 'approve' ? '승인하기' : '반려하기'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* 전체보기 모달 */}
      <Dialog
        open={fullscreenModalOpen}
        onClose={() => setFullscreenModalOpen(false)}
        maxWidth={false}
        fullScreen={isMobile}
        PaperProps={{
          sx: {
            width: isMobile ? '100%' : '90%',
            height: isMobile ? '100%' : '90%',
            maxWidth: isMobile ? '100%' : '90vw',
            maxHeight: isMobile ? '100%' : '90vh',
            borderRadius: isMobile ? 0 : '20px',
            bgcolor: theme.palette.mode === 'dark' ? '#2D2D2D' : 'white',
          },
        }}
      >
        {/* 헤더 */}
        <Box
          sx={{
            p: 2.5,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            borderBottom: '1px solid',
            borderColor: theme.palette.mode === 'dark' ? '#404040' : '#F1F3F5',
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
            <Box
              sx={{
                p: 1,
                borderRadius: '10px',
                background: 'linear-gradient(135deg, #9C88D4 0%, #8A72C8 100%)',
              }}
            >
              <CalendarMonthIcon sx={{ color: 'white', fontSize: 20 }} />
            </Box>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              부서원 휴가 일정 (전체보기)
            </Typography>
          </Box>
          <IconButton onClick={() => setFullscreenModalOpen(false)}>
            <CloseIcon />
          </IconButton>
        </Box>

        {/* 메인 콘텐츠 */}
        <Box sx={{
          display: 'flex',
          flexDirection: isMobile ? 'column' : 'row',
          height: 'calc(100% - 80px)',
          overflow: 'auto',
        }}>
          {/* 달력 영역 (70%) */}
          <Box
            sx={{
              flex: isMobile ? 'none' : 7,
              p: isMobile ? 1.5 : 2.5,
              display: 'flex',
              flexDirection: 'column',
              minHeight: isMobile ? 'auto' : 0,
            }}
          >
            {/* 월 네비게이션 */}
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                mb: 2,
              }}
            >
              <IconButton
                onClick={() => {
                  const newDate = new Date(modalCalendarDate);
                  newDate.setMonth(newDate.getMonth() - 1);
                  setModalCalendarDate(newDate);
                }}
                sx={{ color: '#6C757D' }}
              >
                <ChevronLeftIcon sx={{ fontSize: 32 }} />
              </IconButton>

              <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 1 }}>
                <Box
                  onClick={() => setYearMonthPickerOpen(true)}
                  sx={{
                    px: 2,
                    py: 1,
                    bgcolor: theme.palette.mode === 'dark' ? '#3A3A3A' : '#F8F9FA',
                    borderRadius: '8px',
                    border: '1px solid',
                    borderColor: theme.palette.mode === 'dark' ? '#505050' : '#E9ECEF',
                    cursor: 'pointer',
                    '&:hover': {
                      bgcolor: theme.palette.mode === 'dark' ? '#4A4A4A' : '#E9ECEF',
                    },
                    transition: 'background-color 0.2s',
                  }}
                >
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Typography variant="h5" sx={{ fontWeight: 600 }}>
                      {dayjs(modalCalendarDate).format('YYYY년 M월')}
                    </Typography>
                    <CalendarMonthIcon sx={{ color: '#6C757D', fontSize: 20 }} />
                  </Box>
                </Box>
                <Button
                  variant="contained"
                  startIcon={<TodayIcon sx={{ fontSize: 16 }} />}
                  onClick={() => {
                    const today = new Date();
                    setModalCalendarDate(today);
                    setModalSelectedDate(today);
                    setSelectedDate(today);
                  }}
                  sx={{
                    bgcolor: '#9C88D4',
                    color: 'white',
                    fontSize: '13px',
                    '&:hover': {
                      bgcolor: '#8A72C8',
                    },
                  }}
                >
                  오늘
                </Button>
              </Box>

              <IconButton
                onClick={() => {
                  const newDate = new Date(modalCalendarDate);
                  newDate.setMonth(newDate.getMonth() + 1);
                  setModalCalendarDate(newDate);
                }}
                sx={{ color: '#6C757D' }}
              >
                <ChevronRightIcon sx={{ fontSize: 32 }} />
              </IconButton>
            </Box>

            {/* 달력 */}
            <Box
              sx={{
                flex: 1,
                bgcolor: theme.palette.mode === 'dark' ? '#3A3A3A' : '#F8F9FA',
                borderRadius: '12px',
                border: '1px solid',
                borderColor: theme.palette.mode === 'dark' ? '#505050' : '#E9ECEF',
                p: 2,
                display: 'flex',
                flexDirection: 'column',
              }}
            >
              {/* 요일 헤더 */}
              <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 1, mb: 1 }}>
                {['일', '월', '화', '수', '목', '금', '토'].map((day, index) => (
                  <Box
                    key={day}
                    sx={{
                      height: 40,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      bgcolor: theme.palette.mode === 'dark' ? '#2D2D2D' : 'white',
                      borderRadius: '6px',
                    }}
                  >
                    <Typography
                      sx={{
                        fontSize: '14px',
                        fontWeight: 700,
                        color:
                          index === 0
                            ? '#E53E3E'
                            : index === 6
                              ? '#3182CE'
                              : theme.palette.mode === 'dark'
                                ? '#9E9E9E'
                                : '#6C757D',
                      }}
                    >
                      {day}
                    </Typography>
                  </Box>
                ))}
              </Box>

              {/* 달력 그리드 */}
              <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 0.5 }}>
                {generateCalendar(modalCalendarDate).map((week, weekIndex) => (
                  <Box
                    key={weekIndex}
                    sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 0.5, flex: 1 }}
                  >
                    {week.map((date, dayIndex) => {
                      if (!date) return <Box key={dayIndex} />;

                      const isCurrentMonth = date.getMonth() === modalCalendarDate.getMonth();
                      const isToday =
                        date.getDate() === new Date().getDate() &&
                        date.getMonth() === new Date().getMonth() &&
                        date.getFullYear() === new Date().getFullYear();
                      const isSelected =
                        date.getDate() === modalSelectedDate.getDate() &&
                        date.getMonth() === modalSelectedDate.getMonth() &&
                        date.getFullYear() === modalSelectedDate.getFullYear();
                      const dayLeaves = getLeavesForDate(date);
                      const hasLeave = dayLeaves.length > 0;
                      const weekday = date.getDay();

                      return (
                        <Box
                          key={dayIndex}
                          onClick={() => {
                            setModalSelectedDate(date);
                            setSelectedDate(date);
                          }}
                          sx={{
                            position: 'relative',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            cursor: 'pointer',
                            borderRadius: '8px',
                            bgcolor: isSelected
                              ? '#9C88D4'
                              : isToday
                                ? 'rgba(156, 136, 212, 0.3)'
                                : hasLeave && isCurrentMonth
                                  ? 'rgba(32, 201, 151, 0.1)'
                                  : theme.palette.mode === 'dark'
                                    ? 'transparent'
                                    : 'white',
                            boxShadow: isSelected ? '0 2px 8px rgba(156, 136, 212, 0.3)' : 'none',
                            '&:hover': {
                              bgcolor: isSelected
                                ? '#9C88D4'
                                : theme.palette.mode === 'dark'
                                  ? 'rgba(255, 255, 255, 0.05)'
                                  : 'rgba(156, 136, 212, 0.1)',
                            },
                          }}
                        >
                          <Typography
                            sx={{
                              fontSize: '16px',
                              fontWeight: isSelected || isToday ? 700 : 500,
                              color: !isCurrentMonth
                                ? '#9E9E9E'
                                : isSelected || isToday
                                  ? 'white'
                                  : weekday === 0
                                    ? '#E53E3E'
                                    : weekday === 6
                                      ? '#3182CE'
                                      : theme.palette.mode === 'dark'
                                        ? '#D5D5D5'
                                        : '#495057',
                            }}
                          >
                            {date.getDate()}
                          </Typography>
                          {hasLeave && !isSelected && !isToday && isCurrentMonth && (
                            <Box
                              sx={{
                                position: 'absolute',
                                bottom: 4,
                                width: 5,
                                height: 5,
                                borderRadius: '50%',
                                bgcolor: '#20C997',
                              }}
                            />
                          )}
                        </Box>
                      );
                    })}
                  </Box>
                ))}
              </Box>
            </Box>
          </Box>

          {/* 상세정보 영역 (30%) */}
          <Box
            sx={{
              flex: isMobile ? 'none' : 3,
              p: isMobile ? 1.5 : 2.5,
              borderLeft: isMobile ? 'none' : '1px solid',
              borderTop: isMobile ? '1px solid' : 'none',
              borderColor: theme.palette.mode === 'dark' ? '#404040' : '#F1F3F5',
              display: 'flex',
              flexDirection: 'column',
              minHeight: isMobile ? 'auto' : 0,
            }}
          >
            {/* 헤더 */}
            <Box
              sx={{
                p: 2,
                bgcolor: 'rgba(156, 136, 212, 0.1)',
                borderRadius: '12px',
                mb: 2,
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
                <EventNoteIcon sx={{ color: '#9C88D4', fontSize: 20 }} />
                <Typography variant="h6" sx={{ fontWeight: 600 }}>
                  {dayjs(modalSelectedDate).format('YYYY년 M월 D일')}
                </Typography>
              </Box>
            </Box>

            {/* 상세 내용 */}
            <Box sx={{ flex: 1, overflow: 'auto' }}>
              {getLeavesForDate(modalSelectedDate).length === 0 ? (
                <Box
                  sx={{
                    height: '100%',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <CalendarTodayIcon sx={{ fontSize: 64, color: '#9E9E9E', mb: 2 }} />
                  <Typography sx={{ fontSize: '16px', color: '#9E9E9E', textAlign: 'center' }}>
                    선택된 날짜에
                    <br />
                    휴가 일정이 없습니다.
                  </Typography>
                </Box>
              ) : (
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
                  {getLeavesForDate(modalSelectedDate).map((leave: any, index: number) => {
                    const statusColor =
                      leave.status === 'APPROVED'
                        ? '#20C997'
                        : leave.status === 'REQUESTED'
                          ? '#FF8C00'
                          : leave.status === 'REJECTED'
                            ? '#DC3545'
                            : '#6C757D';

                    const statusLabel =
                      leave.status === 'APPROVED'
                        ? '승인됨'
                        : leave.status === 'REQUESTED'
                          ? (leave.isCancel === 1 ? '취소 상신 대기' : '승인 대기')
                          : leave.status === 'REJECTED'
                            ? '반려됨'
                            : '취소됨';

                    return (
                      <Card
                        key={leave.id || index}
                        sx={{
                          borderRadius: '12px',
                          border: '1px solid',
                          borderColor: theme.palette.mode === 'dark' ? '#404040' : '#E9ECEF',
                        }}
                      >
                        <CardContent sx={{ p: 2 }}>
                          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1.5 }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              <Box
                                sx={{
                                  width: 8,
                                  height: 8,
                                  borderRadius: '50%',
                                  bgcolor: statusColor,
                                }}
                              />
                              <Typography sx={{ fontSize: '15px', fontWeight: 600 }}>
                                {leave.name}
                              </Typography>
                            </Box>
                            <Chip
                              label={statusLabel}
                              size="small"
                              sx={{
                                bgcolor: `${statusColor}22`,
                                color: statusColor,
                                fontSize: '11px',
                                fontWeight: 600,
                                height: 22,
                              }}
                            />
                          </Box>
                          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.75 }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              <Typography sx={{ fontSize: '12px', color: '#9E9E9E', minWidth: 60 }}>
                                부서/직급
                              </Typography>
                              <Typography sx={{ fontSize: '13px', fontWeight: 500 }}>
                                {leave.department} | {leave.job_position}
                              </Typography>
                            </Box>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              <Typography sx={{ fontSize: '12px', color: '#9E9E9E', minWidth: 60 }}>
                                휴가 종류
                              </Typography>
                              <Typography sx={{ fontSize: '13px', fontWeight: 500 }}>
                                {leave.leave_type}
                                {leave.half_day_slot && leave.half_day_slot === 'AM' && ' (오전반차)'}
                                {leave.half_day_slot && leave.half_day_slot === 'PM' && ' (오후반차)'}
                                {leave.half_day_slot && leave.half_day_slot === 'ALL' && ' (종일연차)'}
                              </Typography>
                            </Box>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              <Typography sx={{ fontSize: '12px', color: '#9E9E9E', minWidth: 60 }}>
                                기간
                              </Typography>
                              <Typography sx={{ fontSize: '13px', fontWeight: 500 }}>
                                {dayjs(leave.start_date).format('YYYY.MM.DD')} ~ {dayjs(leave.end_date).format('YYYY.MM.DD')}
                              </Typography>
                            </Box>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                              <Typography sx={{ fontSize: '12px', color: '#9E9E9E', minWidth: 60 }}>
                                일수
                              </Typography>
                              <Typography sx={{ fontSize: '13px', fontWeight: 500 }}>
                                {Math.floor(leave.workdays_count)}일
                              </Typography>
                            </Box>
                            {leave.reason && (
                              <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1, mt: 0.5 }}>
                                <Typography sx={{ fontSize: '12px', color: '#9E9E9E', minWidth: 60 }}>
                                  사유
                                </Typography>
                                <Typography sx={{ fontSize: '13px', fontWeight: 500, flex: 1 }}>
                                  {leave.reason}
                                </Typography>
                              </Box>
                            )}
                          </Box>
                        </CardContent>
                      </Card>
                    );
                  })}
                </Box>
              )}
            </Box>
          </Box>
        </Box>
      </Dialog>

      {/* 연도/월 선택 다이얼로그 */}
      <Dialog
        open={yearMonthPickerOpen}
        onClose={() => setYearMonthPickerOpen(false)}
        maxWidth="xs"
        fullWidth
        PaperProps={{
          sx: {
            borderRadius: '16px',
          },
        }}
      >
        <DialogTitle sx={{ pb: 1 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <CalendarMonthIcon sx={{ color: '#9C88D4', fontSize: 20 }} />
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              연도 및 월 선택
            </Typography>
          </Box>
        </DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, pt: 2 }}>
            <FormControl fullWidth>
              <InputLabel>연도</InputLabel>
              <Select
                value={dayjs(modalCalendarDate).year()}
                label="연도"
                onChange={(e) => {
                  const newDate = new Date(modalCalendarDate);
                  newDate.setFullYear(Number(e.target.value));
                  setModalCalendarDate(newDate);
                }}
                sx={{
                  '& .MuiOutlinedInput-root': {
                    borderRadius: '8px',
                  },
                }}
              >
                {Array.from({ length: 11 }, (_, i) => 2020 + i).map((year) => (
                  <MenuItem key={year} value={year}>
                    {year}년
                  </MenuItem>
                ))}
              </Select>
            </FormControl>

            <FormControl fullWidth>
              <InputLabel>월</InputLabel>
              <Select
                value={dayjs(modalCalendarDate).month() + 1}
                label="월"
                onChange={(e) => {
                  const newDate = new Date(modalCalendarDate);
                  newDate.setMonth(Number(e.target.value) - 1);
                  setModalCalendarDate(newDate);
                }}
                sx={{
                  '& .MuiOutlinedInput-root': {
                    borderRadius: '8px',
                  },
                }}
              >
                {Array.from({ length: 12 }, (_, i) => i + 1).map((month) => (
                  <MenuItem key={month} value={month}>
                    {month}월
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Box>
        </DialogContent>
        <DialogActions sx={{ p: 2, pt: 1 }}>
          <Button
            onClick={() => setYearMonthPickerOpen(false)}
            sx={{
              color: '#6C757D',
              '&:hover': {
                bgcolor: 'rgba(108, 117, 125, 0.1)',
              },
            }}
          >
            취소
          </Button>
          <Button
            onClick={async () => {
              // 선택한 연도/월로 달력 데이터 로드
              try {
                const user = authService.getCurrentUser();
                if (!user) return;

                const month = dayjs(modalCalendarDate).format('YYYY-MM');
                const response = await leaveService.getAdminDeptCalendar({
                  approverId: user.userId,
                  month: month,
                });

                if (response.monthlyLeaves) {
                  setCalendarLeaves(response.monthlyLeaves);
                }
              } catch (err: any) {
                console.error('부서별 달력 조회 실패:', err);
              }
              setYearMonthPickerOpen(false);
            }}
            variant="contained"
            sx={{
              bgcolor: '#9C88D4',
              '&:hover': {
                bgcolor: '#8A72C8',
              },
            }}
          >
            확인
          </Button>
        </DialogActions>
      </Dialog>

      {/* 부서원 휴가 현황 모달 */}
      <DepartmentLeaveStatusModal
        open={departmentStatusModalOpen}
        onClose={() => setDepartmentStatusModalOpen(false)}
      />

      {/* 상세 모달 */}
      <Dialog
        open={detailModalOpen}
        onClose={() => setDetailModalOpen(false)}
        maxWidth="md"
        fullWidth
        fullScreen={isMobile}
        PaperProps={{
          sx: {
            borderRadius: isMobile ? 0 : '16px',
            maxHeight: isMobile ? '100%' : '90vh',
          },
        }}
      >
        <DialogTitle sx={{ pb: 1 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <EventNoteIcon sx={{ color: '#9C88D4', fontSize: 24 }} />
              <Typography variant="h6" sx={{ fontWeight: 600 }}>
                휴가 신청 상세 정보
              </Typography>
            </Box>
            <IconButton
              onClick={() => setDetailModalOpen(false)}
              sx={{
                color: 'text.secondary',
                '&:hover': {
                  bgcolor: 'action.hover',
                },
              }}
            >
              <CloseIcon />
            </IconButton>
          </Box>
        </DialogTitle>
        <DialogContent dividers sx={{
          maxHeight: isMobile ? 'none' : '70vh',
          overflowY: 'auto',
          '&::-webkit-scrollbar': {
            width: '8px',
          },
          '&::-webkit-scrollbar-track': {
            background: '#f1f1f1',
            borderRadius: '10px',
          },
          '&::-webkit-scrollbar-thumb': {
            background: '#9C88D4',
            borderRadius: '10px',
          },
          '&::-webkit-scrollbar-thumb:hover': {
            background: '#8A72C8',
          },
        }}>
          {selectedDetailLeave && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
              {/* 상태 및 휴가 타입 */}
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap' }}>
                <Chip
                  label={getStatusLabel(selectedDetailLeave)}
                  size="medium"
                  sx={{
                    bgcolor: `${getStatusColor(selectedDetailLeave.status, selectedDetailLeave.isCancel)}22`,
                    color: getStatusColor(selectedDetailLeave.status, selectedDetailLeave.isCancel),
                    fontSize: '13px',
                    fontWeight: 600,
                    height: '32px',
                  }}
                />
                <Chip
                  label={`${selectedDetailLeave.leave_type}${selectedDetailLeave.half_day_slot === 'AM' ? ' (오전반차)' :
                      selectedDetailLeave.half_day_slot === 'PM' ? ' (오후반차)' :
                        selectedDetailLeave.half_day_slot === 'ALL' ? ' (종일연차)' : ''
                    }`}
                  size="medium"
                  sx={{
                    bgcolor: '#9C88D422',
                    color: '#9C88D4',
                    fontSize: '13px',
                    height: '32px',
                  }}
                />
                <Chip
                  label={`${Math.floor(selectedDetailLeave.workdays_count)}일`}
                  size="medium"
                  sx={{
                    bgcolor: '#9C88D4',
                    color: 'white',
                    fontWeight: 700,
                    fontSize: '13px',
                    height: '32px',
                  }}
                />
                {selectedDetailLeave.half_day_slot && (
                  <Chip
                    label={selectedDetailLeave.half_day_slot === 'AM' ? '오전 반차' : selectedDetailLeave.half_day_slot === 'PM' ? '오후 반차' : selectedDetailLeave.half_day_slot}
                    size="medium"
                    sx={{
                      bgcolor: '#FF8C0022',
                      color: '#FF8C00',
                      fontSize: '13px',
                      height: '32px',
                    }}
                  />
                )}
              </Box>

              <Divider />

              {/* 신청자 정보 */}
              <Box>
                <Typography variant="subtitle2" sx={{ mb: 1.5, color: 'text.secondary', fontWeight: 600 }}>
                  신청자 정보
                </Typography>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, p: 2, bgcolor: '#F8F9FA', borderRadius: '12px' }}>
                  <Box
                    sx={{
                      width: 56,
                      height: 56,
                      bgcolor: '#9C88D422',
                      borderRadius: '50%',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <PersonIcon sx={{ color: '#9C88D4', fontSize: 28 }} />
                  </Box>
                  <Box sx={{ flex: 1 }}>
                    <Typography variant="h6" fontWeight={600} sx={{ mb: 0.5 }}>
                      {selectedDetailLeave.name}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      {selectedDetailLeave.department} | {selectedDetailLeave.job_position}
                    </Typography>
                  </Box>
                </Box>
              </Box>

              {/* 휴가 기간 */}
              <Box>
                <Typography variant="subtitle2" sx={{ mb: 1.5, color: 'text.secondary', fontWeight: 600 }}>
                  휴가 기간
                </Typography>
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, p: 2, bgcolor: '#F8F9FA', borderRadius: '12px' }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
                    <CalendarTodayIcon sx={{ color: '#9C88D4', fontSize: 20 }} />
                    <Typography variant="body1" fontWeight={600}>
                      {dayjs(selectedDetailLeave.start_date).format('YYYY년 MM월 DD일')} - {dayjs(selectedDetailLeave.end_date).format('YYYY년 MM월 DD일')}
                    </Typography>
                  </Box>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, ml: 4 }}>
                    <AccessTimeIcon sx={{ color: 'text.secondary', fontSize: 16 }} />
                    <Typography variant="body2" color="text.secondary">
                      신청일: {dayjs(selectedDetailLeave.requested_date).format('YYYY년 MM월 DD일 HH:mm')}
                    </Typography>
                  </Box>
                </Box>
              </Box>

              {/* 사유 */}
              {selectedDetailLeave.reason && (
                <Box>
                  <Typography variant="subtitle2" sx={{ mb: 1.5, color: 'text.secondary', fontWeight: 600 }}>
                    사유
                  </Typography>
                  <Box sx={{ p: 2, bgcolor: '#F8F9FA', borderRadius: '12px' }}>
                    <RenderReasonWithCancelHighlight reason={selectedDetailLeave.reason} />
                  </Box>
                </Box>
              )}

              {/* 반려 사유 */}
              {(selectedDetailLeave.reject_message || selectedDetailLeave.rejection_reason) && (
                <Box>
                  <Typography variant="subtitle2" sx={{ mb: 1.5, color: 'text.secondary', fontWeight: 600 }}>
                    반려 사유
                  </Typography>
                  <Box sx={{ p: 2, bgcolor: 'rgba(0, 0, 0, 0.03)', borderRadius: '12px', border: '1px solid rgba(0, 0, 0, 0.12)' }}>
                    <Typography variant="body1" sx={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word', color: 'text.primary' }}>
                      {selectedDetailLeave.reject_message || selectedDetailLeave.rejection_reason}
                    </Typography>
                  </Box>
                </Box>
              )}

              {/* 추가 정보 */}
              <Box>
                <Typography variant="subtitle2" sx={{ mb: 1.5, color: 'text.secondary', fontWeight: 600 }}>
                  추가 정보
                </Typography>
                <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 2 }}>
                  <Box sx={{ p: 1.5, bgcolor: '#F8F9FA', borderRadius: '8px' }}>
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                      상태
                    </Typography>
                    <Typography variant="body2" fontWeight={600}>
                      {getStatusLabel(selectedDetailLeave)}
                    </Typography>
                  </Box>
                  <Box sx={{ p: 1.5, bgcolor: '#F8F9FA', borderRadius: '8px' }}>
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                      휴가 일수
                    </Typography>
                    <Typography variant="body2" fontWeight={600}>
                      {Math.floor(selectedDetailLeave.workdays_count)}일
                    </Typography>
                  </Box>
                  {selectedDetailLeave.isCancel === 1 && (
                    <Box sx={{ p: 1.5, bgcolor: '#FFF3E0', borderRadius: '8px', border: '1px solid #FFE0B2' }}>
                      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                        취소 상신 여부
                      </Typography>
                      <Typography variant="body2" fontWeight={600} sx={{ color: '#FF8C00' }}>
                        취소 상신
                      </Typography>
                    </Box>
                  )}
                  <Box sx={{ p: 1.5, bgcolor: '#F8F9FA', borderRadius: '8px' }}>
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                      총 휴가일
                    </Typography>
                    <Typography variant="body2" fontWeight={600}>
                      {selectedDetailLeave.total_days || 0}일
                    </Typography>
                  </Box>
                  <Box sx={{ p: 1.5, bgcolor: '#F8F9FA', borderRadius: '8px' }}>
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                      잔여일
                    </Typography>
                    <Typography variant="body2" fontWeight={600} sx={{ color: (selectedDetailLeave.remain_days || 0) < 5 ? '#DC3545' : 'inherit' }}>
                      {selectedDetailLeave.remain_days || 0}일
                    </Typography>
                  </Box>
                  {selectedDetailLeave.half_day_slot && (
                    <Box sx={{ p: 1.5, bgcolor: '#F8F9FA', borderRadius: '8px' }}>
                      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                        반차 시간
                      </Typography>
                      <Typography variant="body2" fontWeight={600}>
                        {selectedDetailLeave.half_day_slot === 'AM' ? '오전' : selectedDetailLeave.half_day_slot === 'PM' ? '오후' : selectedDetailLeave.half_day_slot}
                      </Typography>
                    </Box>
                  )}
                  {selectedDetailLeave.join_date && (
                    <Box sx={{ p: 1.5, bgcolor: '#F8F9FA', borderRadius: '8px' }}>
                      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                        입사일
                      </Typography>
                      <Typography variant="body2" fontWeight={600}>
                        {dayjs(selectedDetailLeave.join_date).format('YYYY년 MM월 DD일')}
                      </Typography>
                    </Box>
                  )}
                  {selectedDetailLeave.is_canceled === 1 && (
                    <Box sx={{ p: 1.5, bgcolor: '#FFF3E0', borderRadius: '8px', border: '1px solid #FFE0B2' }}>
                      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                        취소 상신 여부
                      </Typography>
                      <Typography variant="body2" fontWeight={600} sx={{ color: '#FF8C00' }}>
                        취소 상신
                      </Typography>
                    </Box>
                  )}
                </Box>
              </Box>
            </Box>
          )}
        </DialogContent>
        <DialogActions sx={{ p: 2, borderTop: '1px solid #E0E0E0' }}>
          {selectedDetailLeave && selectedDetailLeave.status?.toUpperCase().includes('REQUESTED') && (
            <Box sx={{ display: 'flex', gap: 1.5, width: '100%' }}>
              {/* 취소 상신: 취소 승인 버튼만 */}
              {selectedDetailLeave.status.toUpperCase().includes('CANCEL') && (
                <Button
                  fullWidth
                  variant="contained"
                  color="warning"
                  startIcon={<CheckCircleIcon />}
                  onClick={() => {
                    setDetailModalOpen(false);
                    setSelectedLeave(selectedDetailLeave);
                    setApprovalAction('approve');
                    setApprovalDialog(true);
                  }}
                >
                  취소 승인
                </Button>
              )}

              {/* 일반 상신: 반려 + 승인 버튼 */}
              {!selectedDetailLeave.status.toUpperCase().includes('CANCEL') && (
                <>
                  <Button
                    fullWidth
                    variant="outlined"
                    color="error"
                    startIcon={<CancelIcon />}
                    onClick={() => {
                      setDetailModalOpen(false);
                      setSelectedLeave(selectedDetailLeave);
                      setApprovalAction('reject');
                      setApprovalDialog(true);
                    }}
                  >
                    반려
                  </Button>
                  <Button
                    fullWidth
                    variant="contained"
                    color="success"
                    startIcon={<CheckCircleIcon />}
                    onClick={() => {
                      setDetailModalOpen(false);
                      setSelectedLeave(selectedDetailLeave);
                      setApprovalAction('approve');
                      setApprovalDialog(true);
                    }}
                  >
                    승인
                  </Button>
                </>
              )}
            </Box>
          )}
          {(!selectedDetailLeave || !selectedDetailLeave.status?.includes('REQUESTED')) && (
            <Button
              variant="outlined"
              onClick={() => setDetailModalOpen(false)}
              sx={{ width: '100%' }}
            >
              닫기
            </Button>
          )}
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default AdminLeaveApprovalPage;
