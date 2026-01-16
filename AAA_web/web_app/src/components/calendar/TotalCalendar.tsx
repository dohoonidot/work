import { useState, useEffect } from 'react';
import { useSwipeable } from 'react-swipeable';
import {
  Box,
  Typography,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Grid,
  CircularProgress,
  Alert,
  ToggleButton,
  ToggleButtonGroup,
  Collapse,
  Paper,
  List,
  Chip,
  useMediaQuery,
  useTheme,
  Pagination,
  Select,
  MenuItem,
  FormControl,
} from '@mui/material';
import {
  ChevronLeft as ChevronLeftIcon,
  ChevronRight as ChevronRightIcon,
  CalendarMonth as CalendarIcon,
  Close as CloseIcon,
  Today as TodayIcon,
  ExpandMore as ExpandMoreIcon,
  ExpandLess as ExpandLessIcon,
  Groups as GroupsIcon,
  EventNote as EventNoteIcon,
  CheckCircleOutline as CheckCircleOutlineIcon,
  RemoveCircleOutline as RemoveCircleOutlineIcon,
  BusinessCenter as BusinessCenterIcon,
  Person as PersonIcon,
} from '@mui/icons-material';
import dayjs from 'dayjs';
import isBetween from 'dayjs/plugin/isBetween';
import leaveService from '../../services/leaveService';
import authService from '../../services/authService';
import type { TotalCalendarLeave, MonthlyLeave } from '../../types/leave';

dayjs.extend(isBetween);

interface TotalCalendarProps {
  open: boolean;
  onClose: () => void;
  selectedDate?: Date;
  onDateSelected?: (date: Date) => void;
  embedded?: boolean; // true일 때 Dialog 없이 직접 렌더링
}

export default function TotalCalendar({
  open,
  onClose,
  selectedDate: initialSelectedDate,
  onDateSelected,
  embedded = false
}: TotalCalendarProps) {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const isDark = theme.palette.mode === 'dark';
  const surface = isDark ? '#0F172A' : '#F8F9FA';
  const panelBg = isDark ? '#111827' : 'white';
  const panelBorder = isDark ? 'rgba(255,255,255,0.08)' : '#E9ECEF';
  const panelText = isDark ? '#E5E7EB' : '#111827';
  const panelSubText = isDark ? '#9CA3AF' : '#6B7280';

  const [selectedDate, setSelectedDate] = useState<Date>(initialSelectedDate || new Date());
  const [currentCalendarDate, setCurrentCalendarDate] = useState(dayjs(selectedDate));
  const [pageIndex, setPageIndex] = useState(0);
  const [selectedDateDetails, setSelectedDateDetails] = useState<any[]>([]);

  // 뷰 모드 관리
  const [isMyVacationView, setIsMyVacationView] = useState(true); // true: 내 휴가 내역, false: 부서 휴가 현황
  const [selectedDepartments, setSelectedDepartments] = useState<Set<string>>(new Set());
  const [selectedEmployees, setSelectedEmployees] = useState<Set<string>>(new Set());
  const [expandedDepartments, setExpandedDepartments] = useState<Set<string>>(new Set());

  // 부서 휴가 현황 데이터
  const [totalCalendarLeaves, setTotalCalendarLeaves] = useState<TotalCalendarLeave[]>([]);
  const [departmentEmployees, setDepartmentEmployees] = useState<Map<string, string[]>>(new Map());
  const [isDepartmentDataLoading, setIsDepartmentDataLoading] = useState(false);

  // 내 휴가 내역 데이터
  const [myMonthlyLeaves, setMyMonthlyLeaves] = useState<MonthlyLeave[]>([]);

  // 슬라이드 패널 관리
  const [isDetailPanelVisible, setIsDetailPanelVisible] = useState(false);

  // 상세내역 페이지네이션
  const [detailPage, setDetailPage] = useState(1);
  const detailItemsPerPage = 5;

  // 년월 선택 다이얼로그
  const [yearMonthDialogOpen, setYearMonthDialogOpen] = useState(false);
  const [selectedYear, setSelectedYear] = useState(currentCalendarDate.year());
  const [selectedMonth, setSelectedMonth] = useState(currentCalendarDate.month() + 1); // dayjs는 0-11, UI는 1-12

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // 초기 페이지 인덱스 계산 (2020년 1월 기준)
  useEffect(() => {
    // embedded 모드거나 open이 true일 때 데이터 로드
    if (open || embedded) {
      const monthsFromBase = (currentCalendarDate.year() - 2020) * 12 + (currentCalendarDate.month());
      setPageIndex(monthsFromBase);
      loadMonthlyCalendarData(currentCalendarDate);
      // 부서 휴가 현황 모드일 경우 API 호출
      if (!isMyVacationView) {
        loadDepartmentCalendarData(currentCalendarDate);
      }
    }
  }, [open, embedded, isMyVacationView]);

  // 월 변경 시 데이터 로드
  useEffect(() => {
    if (open || embedded) {
      loadMonthlyCalendarData(currentCalendarDate);
      if (!isMyVacationView) {
        loadDepartmentCalendarData(currentCalendarDate);
      }
    }
  }, [currentCalendarDate, open, embedded, isMyVacationView]);

  // 상세내역 변경 시 페이지 초기화
  useEffect(() => {
    setDetailPage(1);
  }, [selectedDateDetails]);

  // 내 휴가 내역 데이터 로드
  const loadMonthlyCalendarData = async (monthDate: dayjs.Dayjs) => {
    try {
      setLoading(true);
      setError(null);

      const user = authService.getCurrentUser();
      if (!user) {
        setError('사용자 정보를 찾을 수 없습니다.');
        return;
      }

      const month = monthDate.format('YYYY-MM');
      console.log('월별 달력 데이터 로드:', month);

      const response = await leaveService.getMonthlyCalendar({
        userId: user.userId,
        month: month,
      });

      console.log('월별 달력 응답:', response);

      if (response.monthlyLeaves) {
        setMyMonthlyLeaves(response.monthlyLeaves);
      }
    } catch (err: any) {
      console.error('월별 달력 로드 실패:', err);
      setError(err.response?.data?.message || '월별 달력 데이터를 불러오는데 실패했습니다.');
    } finally {
      setLoading(false);
    }
  };

  // 부서 휴가 현황 데이터 로드
  const loadDepartmentCalendarData = async (monthDate: dayjs.Dayjs) => {
    setIsDepartmentDataLoading(true);
    try {
      const month = monthDate.format('YYYY-MM');
      console.log('부서 휴가 현황 데이터 로드:', month);

      const response = await leaveService.getTotalCalendar(month);
      console.log('부서 휴가 현황 응답:', response);

      setTotalCalendarLeaves(response.monthlyLeaves || []);

      // 부서별 직원 그룹핑
      const deptMap = new Map<string, Set<string>>();
      (response.monthlyLeaves || []).forEach(leave => {
        if (!deptMap.has(leave.department)) {
          deptMap.set(leave.department, new Set());
        }
        deptMap.get(leave.department)!.add(leave.name);
      });

      const deptEmployeesMap = new Map<string, string[]>();
      deptMap.forEach((employees, dept) => {
        deptEmployeesMap.set(dept, Array.from(employees).sort());
      });

      setDepartmentEmployees(deptEmployeesMap);
    } catch (err: any) {
      console.error('부서 휴가 현황 로드 실패:', err);
    } finally {
      setIsDepartmentDataLoading(false);
    }
  };

  // 페이지 변경 핸들러
  const handlePageChange = (newIndex: number) => {
    setPageIndex(newIndex);
    const newDate = dayjs('2020-01').add(newIndex, 'month');
    setCurrentCalendarDate(newDate);
  };

  // 이전 달로 이동
  const handlePrevMonth = () => {
    if (pageIndex > 0) {
      handlePageChange(pageIndex - 1);
    }
  };

  // 다음 달로 이동
  const handleNextMonth = () => {
    handlePageChange(pageIndex + 1);
  };

  // 오늘로 이동
  const handleGoToToday = () => {
    const today = dayjs();
    const monthsFromBase = (today.year() - 2020) * 12 + today.month();
    handlePageChange(monthsFromBase);
    setSelectedDate(today.toDate());
    updateSelectedDateDetails(today.toDate());
    onDateSelected?.(today.toDate());
  };

  // 날짜 선택 핸들러
  const handleDateClick = (date: Date) => {
    setSelectedDate(date);
    updateSelectedDateDetails(date);
    if (!isMyVacationView) {
      setIsDetailPanelVisible(true);
    }
    onDateSelected?.(date);
  };

  // 년월 선택 다이얼로그 핸들러
  const handleYearMonthClick = () => {
    setSelectedYear(currentCalendarDate.year());
    setSelectedMonth(currentCalendarDate.month() + 1);
    setYearMonthDialogOpen(true);
  };

  const handleYearMonthConfirm = () => {
    const newDate = dayjs(`${selectedYear}-${selectedMonth.toString().padStart(2, '0')}-01`);
    setCurrentCalendarDate(newDate);
    setSelectedDate(newDate.toDate());
    updateSelectedDateDetails(newDate.toDate());
    setYearMonthDialogOpen(false);
  };

  const handleYearMonthCancel = () => {
    setYearMonthDialogOpen(false);
  };

  // 선택된 날짜의 상세 정보 업데이트
  const updateSelectedDateDetails = (date: Date) => {
    const dateDayjs = dayjs(date);
    let filteredLeaves: any[] = [];

    if (isMyVacationView) {
      // 내 휴가 내역 모드
      filteredLeaves = myMonthlyLeaves.filter(leave => {
        const startDate = dayjs(leave.startDate);
        const endDate = dayjs(leave.endDate);
        return dateDayjs.isBetween(startDate, endDate, 'day', '[]') ||
          dateDayjs.isSame(startDate, 'day') ||
          dateDayjs.isSame(endDate, 'day');
      }).map((leave: MonthlyLeave) => ({
        status: leave.status,
        vacationType: leave.leaveType,
        reason: leave.reason,
        startDate: leave.startDate,
        endDate: leave.endDate,
      }));
    } else {
      // 부서 휴가 현황 모드
      if (selectedEmployees.size === 0) {
        setSelectedDateDetails([]);
        return;
      }

      filteredLeaves = totalCalendarLeaves
        .filter(leave => {
          // 이름과 부서를 함께 확인하여 동명이인 문제 해결
          const employeeKey = `${leave.name}|${leave.department}`;
          return selectedEmployees.has(employeeKey);
        })
        .filter(leave => {
          const startDate = dayjs(leave.startDate);
          const endDate = dayjs(leave.endDate);
          return dateDayjs.isBetween(startDate, endDate, 'day', '[]') ||
            dateDayjs.isSame(startDate, 'day') ||
            dateDayjs.isSame(endDate, 'day');
        })
        .map((leave: TotalCalendarLeave) => ({
          status: 'APPROVED',
          vacationType: leave.leaveType,
          employeeName: leave.name,
          department: leave.department,
          startDate: leave.startDate,
          endDate: leave.endDate,
        }));
    }

    // 상태별 우선순위 정렬
    filteredLeaves.sort((a, b) => {
      const statusPriority: { [key: string]: number } = {
        'REQUESTED': 1,
        'PENDING': 1,
        'APPROVED': 2,
        'REJECTED': 3,
        'CANCELLED': 4,
      };
      const priorityA = statusPriority[a.status?.toUpperCase() || ''] || 5;
      const priorityB = statusPriority[b.status?.toUpperCase() || ''] || 5;
      return priorityA - priorityB;
    });

    setSelectedDateDetails(filteredLeaves);
  };

  // 뷰 모드 전환
  const handleViewModeChange = (isMyVacation: boolean) => {
    setIsMyVacationView(isMyVacation);
    if (!isMyVacation) {
      setSelectedDepartments(new Set());
      setSelectedEmployees(new Set());
      setExpandedDepartments(new Set());
      loadDepartmentCalendarData(currentCalendarDate);
    }
    updateSelectedDateDetails(selectedDate);
  };

  // 부서 선택/해제
  const toggleDepartmentSelection = (deptName: string) => {
    const newSelectedDepartments = new Set(selectedDepartments);
    const newSelectedEmployees = new Set(selectedEmployees);
    const employees = departmentEmployees.get(deptName) || [];

    if (newSelectedDepartments.has(deptName)) {
      newSelectedDepartments.delete(deptName);
      // 해당 부서의 모든 직원 제거 (이름|부서 형식)
      employees.forEach(emp => {
        newSelectedEmployees.delete(`${emp}|${deptName}`);
      });
    } else {
      newSelectedDepartments.add(deptName);
      // 해당 부서의 모든 직원 추가 (이름|부서 형식)
      employees.forEach(emp => {
        newSelectedEmployees.add(`${emp}|${deptName}`);
      });
    }

    setSelectedDepartments(newSelectedDepartments);
    setSelectedEmployees(newSelectedEmployees);
    updateSelectedDateDetails(selectedDate);
  };

  // 부서 확장/축소
  const toggleDepartmentExpansion = (deptName: string) => {
    const newExpanded = new Set(expandedDepartments);
    if (newExpanded.has(deptName)) {
      newExpanded.delete(deptName);
    } else {
      newExpanded.add(deptName);
    }
    setExpandedDepartments(newExpanded);
  };

  // 직원 선택/해제 (부서 정보 포함)
  const toggleEmployeeSelection = (employeeName: string, department: string) => {
    const newSelectedEmployees = new Set(selectedEmployees);
    const employeeKey = `${employeeName}|${department}`;

    if (newSelectedEmployees.has(employeeKey)) {
      newSelectedEmployees.delete(employeeKey);
    } else {
      newSelectedEmployees.add(employeeKey);
    }
    setSelectedEmployees(newSelectedEmployees);
    updateSelectedDateDetails(selectedDate);
  };

  // 전체 선택
  const handleSelectAll = () => {
    const allDepartments = new Set(departmentEmployees.keys());
    const allEmployees = new Set<string>();
    departmentEmployees.forEach((employees, dept) => {
      employees.forEach(emp => allEmployees.add(`${emp}|${dept}`));
    });
    setSelectedDepartments(allDepartments);
    setSelectedEmployees(allEmployees);
    updateSelectedDateDetails(selectedDate);
  };

  // 선택 해제
  const handleSelectNone = () => {
    setSelectedDepartments(new Set());
    setSelectedEmployees(new Set());
    updateSelectedDateDetails(selectedDate);
  };

  // 달력 그리드 생성
  const generateCalendarDays = (monthDate: dayjs.Dayjs) => {
    const startOfMonth = monthDate.startOf('month');
    const endOfMonth = monthDate.endOf('month');
    const startOfWeek = startOfMonth.startOf('week');
    const endOfWeek = endOfMonth.endOf('week');

    const days: Array<{
      date: Date;
      isCurrentMonth: boolean;
      isToday: boolean;
      leaves: any[];
    }> = [];

    let currentDay = startOfWeek;

    while (currentDay.isBefore(endOfWeek) || currentDay.isSame(endOfWeek, 'day')) {
      const dayDate = currentDay.toDate();
      const isCurrentMonth = currentDay.isSame(monthDate, 'month');
      const isToday = currentDay.isSame(dayjs(), 'day');

      // 필터링된 휴가 데이터 사용
      let dayLeaves: any[] = [];
      if (isMyVacationView) {
        dayLeaves = myMonthlyLeaves.filter((leave: MonthlyLeave) => {
          const startDate = dayjs(leave.startDate);
          const endDate = dayjs(leave.endDate);
          return currentDay.isBetween(startDate, endDate, 'day', '[]') ||
            currentDay.isSame(startDate, 'day') ||
            currentDay.isSame(endDate, 'day');
        });
      } else {
        if (selectedEmployees.size > 0) {
          dayLeaves = totalCalendarLeaves
            .filter(leave => {
              // 이름과 부서를 함께 확인하여 동명이인 문제 해결
              const employeeKey = `${leave.name}|${leave.department}`;
              return selectedEmployees.has(employeeKey);
            })
            .filter((leave: TotalCalendarLeave) => {
              const startDate = dayjs(leave.startDate);
              const endDate = dayjs(leave.endDate);
              return currentDay.isBetween(startDate, endDate, 'day', '[]') ||
                currentDay.isSame(startDate, 'day') ||
                currentDay.isSame(endDate, 'day');
            });
        }
      }

      days.push({
        date: dayDate,
        isCurrentMonth,
        isToday,
        leaves: dayLeaves,
      });

      currentDay = currentDay.add(1, 'day');
    }

    return days;
  };

  // 날짜 셀 렌더링
  const renderDateCell = (day: any) => {
    const hasLeaves = day.leaves.length > 0;
    const isSelected = dayjs(day.date).isSame(dayjs(selectedDate), 'day');
    const weekday = day.date.getDay();
    const isSunday = weekday === 0;
    const isSaturday = weekday === 6;

    // 상태별 색상 결정
    let leaveColor: string | null = null;
    if (hasLeaves) {
      const pendingCount = day.leaves.filter((l: any) =>
        l.status?.toUpperCase() === 'PENDING' || l.status?.toUpperCase() === 'REQUESTED'
      ).length;
      const approvedCount = day.leaves.filter((l: any) =>
        l.status?.toUpperCase() === 'APPROVED'
      ).length;
      const rejectedCount = day.leaves.filter((l: any) =>
        l.status?.toUpperCase() === 'REJECTED'
      ).length;
      const cancelledCount = day.leaves.filter((l: any) =>
        l.status?.toUpperCase() === 'CANCELLED'
      ).length;

      if (pendingCount > 0) {
        leaveColor = '#FF8C00'; // 대기중
      } else if (approvedCount > 0) {
        leaveColor = '#20C997'; // 승인됨
      } else if (rejectedCount > 0) {
        leaveColor = '#DC3545'; // 반려됨
      } else if (cancelledCount > 0) {
        leaveColor = '#6C757D'; // 취소됨
      }
    }

    return (
      <Box
        key={day.date.toISOString()}
        onClick={() => handleDateClick(day.date)}
        sx={{
          width: '100%',
          height: '100%',
          minHeight: isMobile ? 0 : '28px',
          display: 'flex',
          flexDirection: isMobile ? 'column' : 'row',
          alignItems: 'center',
          justifyContent: isMobile ? 'flex-start' : 'center',
          cursor: 'pointer',
          border: isMobile ? '1px solid' : 'none',
          borderColor: isMobile ? panelBorder : 'transparent',
          borderRadius: isMobile ? 0 : '3px',
          margin: 0,
          backgroundColor: isSelected
            ? (isMobile ? '#1E88E5' : (isDark ? '#6D63B5' : '#9C88D4'))
            : day.isToday
              ? (isMobile ? '#1E88E5' : (isDark ? '#6D63B580' : '#9C88D480'))
              : (hasLeaves && day.isCurrentMonth && leaveColor)
                ? `${leaveColor}26`
                : (isMobile ? 'transparent' : (day.isCurrentMonth ? (isDark ? 'rgba(255,255,255,0.02)' : 'white') : 'transparent')),
          color: !day.isCurrentMonth
            ? (isDark ? '#64748B' : '#9CA3AF')
            : isSelected || day.isToday
              ? 'white'
              : isSunday
                ? '#E53E3E'
                : isSaturday
                  ? '#3182CE'
                  : '#495057',
          '&:hover': {
            backgroundColor: isSelected
              ? (isMobile ? '#1E88E5' : (isDark ? '#6D63B5' : '#9C88D4'))
              : (isMobile ? (isDark ? 'rgba(255,255,255,0.06)' : '#F3F4F6') : (isDark ? 'rgba(109, 99, 181, 0.2)' : 'rgba(156, 136, 212, 0.1)')),
          },
          position: 'relative',
          p: isMobile ? 0.5 : 0,
          boxShadow: isMobile ? 'none' : (isSelected ? '0 2px 8px rgba(156, 136, 212, 0.3)' : 'none'),
        }}
      >
        <Typography
          sx={{
            fontSize: isMobile ? '11px' : '16px',
            fontWeight: isSelected || day.isToday ? 700 : 500,
            mb: isMobile ? 0.25 : 0,
            lineHeight: 1.2,
          }}
        >
          {day.date.getDate()}
        </Typography>

        {/* 데스크톱뷰: 관리자용 달력과 동일하게 점으로 표시 */}
        {!isMobile && hasLeaves && !isSelected && !day.isToday && day.isCurrentMonth && (
          <Box
            sx={{
              position: 'absolute',
              bottom: 4,
              width: 5,
              height: 5,
              borderRadius: '50%',
              bgcolor: leaveColor || '#20C997',
            }}
          />
        )}

        {/* 모바일뷰: 기존 텍스트 표시 유지 */}
        {isMobile && hasLeaves && day.isCurrentMonth && (
          <Box
            sx={{
              position: 'absolute',
              left: 1,
              right: 1,
              bottom: 1,
              maxHeight: '28px',
              overflow: 'hidden',
              width: 'calc(100% - 2px)',
            }}
          >
            {day.leaves.slice(0, 2).map((leave: any, idx: number) => {
              const isApproved = leave.status?.toUpperCase() === 'APPROVED';
              if (!isApproved && isMyVacationView) return null;

              let displayText = '';
              if (isMyVacationView) {
                displayText = leave.reason || leave.leaveType;
              } else {
                if (leave.name && leave.department) {
                  displayText = leave.name;
                } else if (leave.employeeName && leave.department) {
                  displayText = leave.employeeName;
                } else {
                  displayText = leave.reason || leave.leaveType || leave.vacationType || '';
                }
              }

              return (
                <Typography
                  key={idx}
                  sx={{
                    fontSize: '9px',
                    fontWeight: 500,
                    color: isSelected || day.isToday ? 'white' : panelText,
                    lineHeight: 1.1,
                    mb: 0.25,
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                    width: '100%',
                  }}
                >
                  {displayText}
                </Typography>
              );
            })}
            {day.leaves.length > 2 && (
              <Typography
                sx={{
                  fontSize: '8px',
                  color: isSelected || day.isToday ? 'white' : panelSubText,
                  fontWeight: 600,
                  lineHeight: 1,
                }}
              >
                +{day.leaves.length - 2}
              </Typography>
            )}
          </Box>
        )}
      </Box>
    );
  };

  // 달력 월 렌더링
  const renderMonthCalendar = (monthDate: dayjs.Dayjs) => {
    const calendarDays = generateCalendarDays(monthDate);

    // 주(week) 단위로 그룹화 (관리자용 달력과 동일한 구조)
    const weeks: typeof calendarDays[] = [];
    for (let i = 0; i < calendarDays.length; i += 7) {
      weeks.push(calendarDays.slice(i, i + 7));
    }

    return (
      <Box
        sx={{
          flex: 1, // 남은 공간 모두 차지하도록 flex: 1 설정
          minHeight: 0, // flexbox에서 필수
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
        }}
      >
        {/* 요일 헤더 - 관리자용과 동일한 스타일 (데스크톱뷰) */}
        {!isMobile ? (
          <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 1, mb: 1, flexShrink: 0 }}>
            {['일', '월', '화', '수', '목', '금', '토'].map((day, index) => {
              const isSunday = index === 0;
              const isSaturday = index === 6;
              return (
                <Box
                  key={day}
                  sx={{
                    height: 40,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    bgcolor: isDark ? '#1F2937' : 'white',
                    borderRadius: '6px',
                  }}
                >
                  <Typography
                    sx={{
                      fontSize: '14px',
                      fontWeight: 700,
                      color: isSunday
                        ? '#E53E3E'
                        : isSaturday
                          ? '#3182CE'
                          : (isDark ? '#9CA3AF' : '#6C757D'),
                    }}
                  >
                    {day}
                  </Typography>
                </Box>
              );
            })}
          </Box>
        ) : (
          <Grid container spacing={0} sx={{ mb: 0, flexShrink: 0 }}>
            {['일', '월', '화', '수', '목', '금', '토'].map((day, index) => {
              const isSunday = index === 0;
              const isSaturday = index === 6;
              return (
                <Grid size={12 / 7} key={day} sx={{ display: 'flex' }}>
                  <Box
                    sx={{
                      width: '100%',
                      height: 32,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      bgcolor: isDark ? '#1F2937' : 'white',
                      borderRadius: 0,
                      borderBottom: `1px solid ${panelBorder}`,
                    }}
                  >
                    <Typography
                      sx={{
                        fontSize: '12px',
                        fontWeight: 700,
                        color: isSunday
                          ? '#E53E3E'
                          : isSaturday
                            ? '#3182CE'
                            : (isDark ? '#9CA3AF' : '#6C757D'),
                      }}
                    >
                      {day}
                    </Typography>
                  </Box>
                </Grid>
              );
            })}
          </Grid>
        )}

        {/* 달력 그리드 - 관리자용 달력과 동일한 구조 (데스크톱뷰) */}
        {!isMobile ? (
          <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 0.5, minHeight: 0 }}>
            {weeks.map((week, weekIndex) => (
              <Box
                key={weekIndex}
                sx={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 0.5, flex: 1, minHeight: 0 }}
              >
                {week.map((day, dayIndex) => (
                  <Box
                    key={dayIndex}
                    sx={{
                      height: '100%',
                      width: '100%',
                      display: 'flex',
                    }}
                  >
                    {renderDateCell(day)}
                  </Box>
                ))}
              </Box>
            ))}
          </Box>
        ) : (
          // 모바일뷰는 기존 Grid 구조 유지
          <Grid container spacing={0} sx={{ flex: 1, minHeight: 0, overflow: 'auto' }}>
            {calendarDays.map((day, index) => (
              <Grid
                size={12 / 7}
                key={index}
                sx={{
                  display: 'flex',
                  minHeight: '48px',
                  aspectRatio: '1',
                }}
              >
                {renderDateCell(day)}
              </Grid>
            ))}
          </Grid>
        )}
      </Box>
    );
  };

  // 상세내역 페이지네이션 헬퍼 함수
  const getPaginatedDetails = () => {
    const startIndex = (detailPage - 1) * detailItemsPerPage;
    const endIndex = startIndex + detailItemsPerPage;
    return selectedDateDetails.slice(startIndex, endIndex);
  };

  const getDetailTotalPages = () => {
    return Math.ceil(selectedDateDetails.length / detailItemsPerPage);
  };

  // 메인 컨텐츠 (Dialog 내부 또는 직접 렌더링)
  const renderContent = () => (
    <>
      {/* 헤더 */}
      <DialogTitle
        sx={{
          p: isMobile ? 1 : 2.5,
          borderBottom: `1px solid ${panelBorder}`,
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: isMobile ? 'wrap' : 'nowrap', gap: 1 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flex: 1, minWidth: 0 }}>
            <Box
              sx={{
                p: isMobile ? 0.75 : 1,
                borderRadius: '8px',
                background: 'linear-gradient(135deg, #1E88E5 0%, #1976D2 100%)',
                flexShrink: 0,
              }}
            >
              <CalendarIcon sx={{ color: 'white', fontSize: isMobile ? 18 : 20 }} />
            </Box>
            <Typography
              sx={{
                fontSize: isMobile ? '16px' : '20px',
                fontWeight: 600,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {isMobile ? '전체보기' : '휴가 일정 달력 (전체보기)'}
            </Typography>
          </Box>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexShrink: 0 }}>
            {!isMobile && (
              <Box>
                <ToggleButtonGroup
                  value={isMyVacationView ? 'my' : 'dept'}
                  exclusive
                  onChange={(_, value) => {
                    if (value !== null) {
                      handleViewModeChange(value === 'my');
                    }
                  }}
                  sx={{
                    bgcolor: isDark ? '#111827' : '#F8F9FA',
                    borderRadius: '8px',
                    border: `1px solid ${panelBorder}`,
                  }}
                >
                  <ToggleButton value="my" sx={{ px: 2, py: 1 }}>
                    <Typography sx={{ fontSize: '14px', fontWeight: 600 }}>
                      내 휴가 내역
                    </Typography>
                  </ToggleButton>
                  <ToggleButton value="dept" sx={{ px: 2, py: 1 }}>
                    <Typography sx={{ fontSize: '14px', fontWeight: 600 }}>
                      부서 휴가 현황
                    </Typography>
                  </ToggleButton>
                </ToggleButtonGroup>
              </Box>
            )}
            <IconButton onClick={onClose} size="small">
              <CloseIcon />
            </IconButton>
          </Box>
          {isMobile && (
            <Box sx={{ width: '100%', mt: 1 }}>
              <ToggleButtonGroup
                value={isMyVacationView ? 'my' : 'dept'}
                exclusive
                onChange={(_, value) => {
                  if (value !== null) {
                    handleViewModeChange(value === 'my');
                  }
                }}
                fullWidth
                sx={{
                  bgcolor: isDark ? '#111827' : '#F8F9FA',
                  borderRadius: '8px',
                  border: `1px solid ${panelBorder}`,
                }}
              >
                <ToggleButton value="my" sx={{ px: 1.5, py: 0.75, flex: 1 }}>
                  <Typography sx={{ fontSize: '13px', fontWeight: 600 }}>
                    내 휴가 내역
                  </Typography>
                </ToggleButton>
                <ToggleButton value="dept" sx={{ px: 1.5, py: 0.75, flex: 1 }}>
                  <Typography sx={{ fontSize: '13px', fontWeight: 600 }}>
                    부서 휴가 현황
                  </Typography>
                </ToggleButton>
              </ToggleButtonGroup>
            </Box>
          )}
        </Box>
      </DialogTitle>

      <DialogContent sx={{ p: 0, display: 'flex', flexDirection: 'column', overflow: isMobile ? 'visible' : 'hidden', height: isMobile ? 'auto' : 'calc(100% - 80px)' }}>
        <Box sx={{ display: 'flex', flex: 1, overflow: isMobile ? 'visible' : 'hidden', flexDirection: isMobile ? 'column' : 'row', width: '100%' }}>
          {/* 달력 영역 - 관리자용과 동일하게 70% (flex: 7) */}
          <Box sx={{ flex: isMobile ? 'none' : 7, p: isMobile ? 1 : 2.5, display: 'flex', flexDirection: 'column', overflow: 'hidden', minWidth: 0 }}>
            {/* 네비게이션 */}
            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: isMobile ? 1.5 : 2.5, px: isMobile ? 0.5 : 0 }}>
              <IconButton
                onClick={handlePrevMonth}
                disabled={loading}
                sx={{ width: isMobile ? 36 : 48, height: isMobile ? 36 : 48 }}
              >
                <ChevronLeftIcon sx={{ fontSize: isMobile ? 24 : 32 }} />
              </IconButton>

              <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: isMobile ? 0.5 : 1, flex: 1, mx: 1 }}>
                <Box
                  onClick={handleYearMonthClick}
                  sx={{
                    px: isMobile ? 1.5 : 2,
                    py: isMobile ? 0.75 : 1,
                    bgcolor: isDark ? '#111827' : '#F8F9FA',
                    borderRadius: '8px',
                    border: `1px solid ${panelBorder}`,
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 0.5,
                    '&:hover': {
                      bgcolor: isDark ? 'rgba(255,255,255,0.08)' : '#E9ECEF',
                    },
                  }}
                >
                  <Typography sx={{ fontSize: isMobile ? '16px' : '24px', fontWeight: 600, whiteSpace: 'nowrap' }}>
                    {currentCalendarDate.format('YYYY년 MM월')}
                  </Typography>
                  {!isMobile && <CalendarIcon sx={{ fontSize: 20, color: panelSubText }} />}
                </Box>
                {!isMobile && (
                  <Button
                    startIcon={<TodayIcon />}
                    onClick={handleGoToToday}
                    variant="contained"
                    sx={{
                      bgcolor: '#1E88E5',
                      borderRadius: '8px',
                      textTransform: 'none',
                    }}
                  >
                    오늘
                  </Button>
                )}
              </Box>

              <IconButton
                onClick={handleNextMonth}
                disabled={loading}
                sx={{ width: isMobile ? 36 : 48, height: isMobile ? 36 : 48 }}
              >
                <ChevronRightIcon sx={{ fontSize: isMobile ? 24 : 32 }} />
              </IconButton>
              {isMobile && (
                <Button
                  startIcon={<TodayIcon />}
                  onClick={handleGoToToday}
                  variant="contained"
                  size="small"
                  sx={{
                    bgcolor: '#1E88E5',
                    borderRadius: '8px',
                    textTransform: 'none',
                    minWidth: 'auto',
                    px: 1,
                  }}
                >
                  오늘
                </Button>
              )}
            </Box>

            {/* 달력 - 관리자용과 동일한 스타일 */}
            <Box
              sx={{
                flex: 1,
                overflow: 'auto',
                bgcolor: surface,
                borderRadius: '12px',
                border: '1px solid',
                borderColor: panelBorder,
                p: 2,
                display: 'flex',
                flexDirection: 'column',
              }}
              {...useSwipeable({
                onSwipedLeft: () => handleNextMonth(),
                onSwipedRight: () => handlePrevMonth(),
                trackMouse: true,
              })}
            >
              {loading ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
                  <CircularProgress />
                </Box>
              ) : error ? (
                <Alert severity="error">{error}</Alert>
              ) : (
                renderMonthCalendar(currentCalendarDate)
              )}
            </Box>
          </Box>


          {/* 우측 패널 - 관리자용과 동일하게 30% (flex: 3) */}
          <Box sx={{
            flex: isMobile ? 'none' : 3,
            display: 'flex',
            flexDirection: 'column',
            overflow: isMobile ? 'visible' : 'hidden',
            borderTop: isMobile ? `1px solid ${panelBorder}` : 'none',
            borderLeft: isMobile ? 'none' : `1px solid ${panelBorder}`,
            height: isMobile ? 'auto' : 'auto', // 고정값 제거, Flexbox로 자동 조정
            minHeight: isMobile ? 'auto' : 'none',
            maxHeight: isMobile ? 'none' : 'none', // 모바일에서 높이 제한 제거
            minWidth: isMobile ? 'auto' : '300px', // 최소 너비 보장
          }}>
            {isMyVacationView ? (
              // 내 휴가 내역 패널
              <Box sx={{ p: isMobile ? 1.5 : 2.5, height: '100%', display: 'flex', flexDirection: 'column' }}>
                {/* 스크롤 가능한 상세내역 영역 */}
                <Box sx={{ flex: 1, overflow: 'auto', minHeight: 0 }}>
                  <Box
                    sx={{
                      p: isMobile ? 1.5 : 2,
                      bgcolor: 'rgba(30, 136, 229, 0.1)',
                      borderRadius: '12px',
                      mb: isMobile ? 1.5 : 2,
                    }}
                  >
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                      <EventNoteIcon sx={{ color: '#1E88E5', fontSize: isMobile ? 18 : 20 }} />
                      <Typography sx={{ fontSize: isMobile ? '14px' : '18px', fontWeight: 600, color: panelText, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {dayjs(selectedDate).format('YYYY년 MM월 DD일')}
                      </Typography>
                    </Box>
                  </Box>

                  {selectedDateDetails.length === 0 ? (
                    <Box sx={{ textAlign: 'center', py: isMobile ? 4 : 8 }}>
                      <CalendarIcon sx={{ fontSize: isMobile ? 48 : 64, color: panelSubText, mb: 1.5 }} />
                      <Typography sx={{ color: panelSubText, fontSize: isMobile ? '13px' : '14px' }}>
                        선택된 날짜에<br />휴가 일정이 없습니다.
                      </Typography>
                    </Box>
                  ) : (
                    <>
                      <List sx={{ p: 0, mb: 1 }}>
                        {getPaginatedDetails().map((detail, index) => {
                          const status = detail.status?.toUpperCase() || 'PENDING';
                          const statusColor =
                            status === 'REQUESTED' || status === 'PENDING'
                              ? '#FF8C00'
                              : status === 'APPROVED'
                                ? '#20C997'
                                : status === 'REJECTED'
                                  ? '#DC3545'
                                  : '#6C757D';

                          return (
                            <Paper
                              key={index}
                              sx={{
                                p: isMobile ? 1 : 1.5,
                                mb: isMobile ? 0.75 : 1,
                                bgcolor: `${statusColor}0D`,
                                border: `1px solid ${statusColor}33`,
                                borderRadius: '8px',
                              }}
                            >
                              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.75, mb: isMobile ? 0.5 : 0.75, flexWrap: 'wrap' }}>
                                <Chip
                                  label={
                                    status === 'REQUESTED' || status === 'PENDING'
                                      ? '대기'
                                      : status === 'APPROVED'
                                        ? '승인'
                                        : status === 'REJECTED'
                                          ? '반려'
                                          : '취소'
                                  }
                                  size="small"
                                  sx={{
                                    bgcolor: statusColor,
                                    color: 'white',
                                    fontSize: isMobile ? '10px' : '11px',
                                    fontWeight: 700,
                                    height: isMobile ? 20 : 22,
                                  }}
                                />
                                <Typography sx={{ fontSize: isMobile ? '12px' : '13px', fontWeight: 600, color: panelText, flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                  {detail.vacationType}
                                </Typography>
                              </Box>
                              {detail.reason && (
                                <Typography sx={{ fontSize: isMobile ? '11px' : '12px', color: panelSubText, mb: 0.5, wordBreak: 'break-word' }}>
                                  사유: {detail.reason}
                                </Typography>
                              )}
                              {detail.startDate && detail.endDate && (
                                <Typography sx={{ fontSize: isMobile ? '10px' : '11px', color: panelSubText, wordBreak: 'break-word' }}>
                                  기간: {dayjs(detail.startDate).format('YYYY.MM.DD')} ~{' '}
                                  {dayjs(detail.endDate).format('YYYY.MM.DD')}
                                </Typography>
                              )}
                            </Paper>
                          );
                        })}
                      </List>

                      {/* 페이지네이션 */}
                      {getDetailTotalPages() > 1 && (
                        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 1, mb: 1, borderTop: `1px solid ${panelBorder}`, pt: 1 }}>
                          <Pagination
                            count={getDetailTotalPages()}
                            page={detailPage}
                            onChange={(_, page) => setDetailPage(page)}
                            color="primary"
                            size="small"
                            siblingCount={0}
                            boundaryCount={1}
                          />
                        </Box>
                      )}
                    </>
                  )}
                </Box>
              </Box>
            ) : (
              // 부서 휴가 현황 패널
              <Box sx={{ display: 'flex', height: '100%', overflow: 'hidden', position: 'relative', flexDirection: isMobile ? 'column' : 'row' }}>
                {/* 부서 선택 패널 */}
                <Box
                  sx={{
                    width: isDetailPanelVisible && !isMobile ? 0 : '100%',
                    height: isMobile && isDetailPanelVisible ? 0 : 'auto',
                    overflow: 'hidden',
                    transition: isMobile ? 'height 0.3s ease-in-out' : 'width 0.3s ease-in-out',
                    borderRight: isMobile ? 'none' : `1px solid ${panelBorder}`,
                    borderBottom: isMobile ? `1px solid ${panelBorder}` : 'none',
                  }}
                >
                  <Box sx={{
                    p: isMobile ? 1.5 : 2.5,
                    height: '100%',
                    display: 'flex',
                    flexDirection: 'column',
                    minHeight: 0,
                  }}>
                    {/* 헤더 (상단 고정) */}
                    <Box
                      sx={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 1,
                        pb: isMobile ? 1 : 1.5,
                        borderBottom: `1px solid ${panelBorder}`,
                        flexShrink: 0,
                      }}
                    >
                      <Box
                        sx={{
                          p: isMobile ? 0.5 : 0.75,
                          bgcolor: 'rgba(30, 136, 229, 0.1)',
                          borderRadius: '8px',
                          flexShrink: 0,
                        }}
                      >
                        <GroupsIcon sx={{ color: '#1E88E5', fontSize: isMobile ? 16 : 18 }} />
                      </Box>
                      <Typography sx={{ fontSize: isMobile ? '14px' : '16px', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        부서 선택
                      </Typography>
                    </Box>

                    {/* 부서 목록 (중간 스크롤 영역) */}
                    <Box sx={{
                      flex: 1,
                      overflow: 'auto',
                      my: isMobile ? 1.5 : 2,
                      minHeight: 0,
                    }}>
                      {isDepartmentDataLoading ? (
                        <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
                          <CircularProgress size={24} />
                        </Box>
                      ) : departmentEmployees.size === 0 ? (
                        <Box sx={{ textAlign: 'center', py: 4 }}>
                          <Typography sx={{ color: panelSubText }}>
                            부서 데이터를 불러오는 중...<br />또는 휴가 일정이 없습니다.
                          </Typography>
                        </Box>
                      ) : (
                        <Box>
                          {Array.from(departmentEmployees.keys())
                            .sort()
                            .map(deptName => {
                              const employees = departmentEmployees.get(deptName) || [];
                              const isDeptSelected = selectedDepartments.has(deptName);
                              const isExpanded = expandedDepartments.has(deptName);

                              return (
                                <Paper
                                  key={deptName}
                                  sx={{
                                    mb: isMobile ? 0.75 : 1,
                                    bgcolor: isDeptSelected
                                      ? 'rgba(30, 136, 229, 0.08)'
                                      : (isDark ? '#0B1220' : '#F8FAFC'),
                                    border: `1.5px solid ${isDeptSelected
                                      ? 'rgba(30, 136, 229, 0.3)'
                                      : (isDark ? 'rgba(255,255,255,0.12)' : '#E2E8F0')
                                      }`,
                                    borderRadius: '12px',
                                  }}
                                >
                                  {/* 부서 헤더 */}
                                  <Box sx={{ display: 'flex' }}>
                                    <Box
                                      onClick={() => toggleDepartmentSelection(deptName)}
                                      sx={{
                                        p: isMobile ? 1 : 1.5,
                                        display: 'flex',
                                        alignItems: 'center',
                                        cursor: 'pointer',
                                        borderRight: `1px solid ${panelBorder}`,
                                        flexShrink: 0,
                                      }}
                                    >
                                      <Box
                                        sx={{
                                          width: isMobile ? 18 : 20,
                                          height: isMobile ? 18 : 20,
                                          border: '2px solid',
                                          borderColor: isDeptSelected ? '#1E88E5' : (isDark ? '#334155' : '#CBD5E1'),
                                          bgcolor: isDeptSelected ? '#1E88E5' : 'transparent',
                                          borderRadius: '4px',
                                          display: 'flex',
                                          alignItems: 'center',
                                          justifyContent: 'center',
                                        }}
                                      >
                                        {isDeptSelected && (
                                          <CheckCircleOutlineIcon sx={{ fontSize: isMobile ? 12 : 14, color: 'white' }} />
                                        )}
                                      </Box>
                                    </Box>
                                    <Box
                                      onClick={() => toggleDepartmentExpansion(deptName)}
                                      sx={{
                                        flex: 1,
                                        p: isMobile ? 1 : 1.5,
                                        display: 'flex',
                                        alignItems: 'center',
                                        cursor: 'pointer',
                                        minWidth: 0,
                                      }}
                                    >
                                      <BusinessCenterIcon
                                        sx={{ fontSize: isMobile ? 14 : 16, color: panelSubText, mr: isMobile ? 1 : 1.5, flexShrink: 0 }}
                                      />
                                      <Box sx={{ flex: 1, minWidth: 0 }}>
                                        <Typography
                                          sx={{
                                            fontSize: isMobile ? '13px' : '14px',
                                            fontWeight: 600,
                                            color: isDeptSelected ? '#1E88E5' : panelText,
                                            overflow: 'hidden',
                                            textOverflow: 'ellipsis',
                                            whiteSpace: 'nowrap',
                                          }}
                                        >
                                          {deptName}
                                        </Typography>
                                        <Typography sx={{ fontSize: isMobile ? '11px' : '12px', color: panelSubText }}>
                                          {employees.length}명
                                        </Typography>
                                      </Box>
                                      {isExpanded ? (
                                        <ExpandLessIcon sx={{ color: panelSubText, fontSize: isMobile ? 18 : 20, flexShrink: 0 }} />
                                      ) : (
                                        <ExpandMoreIcon sx={{ color: panelSubText, fontSize: isMobile ? 18 : 20, flexShrink: 0 }} />
                                      )}
                                    </Box>
                                  </Box>

                                  {/* 직원 목록 */}
                                  <Collapse in={isExpanded}>
                                    <Box>
                                      {employees.map(employeeName => {
                                        // 이름과 부서를 함께 확인하여 동명이인 문제 해결
                                        const employeeKey = `${employeeName}|${deptName}`;
                                        const isEmpSelected = selectedEmployees.has(employeeKey);
                                        return (
                                          <Box
                                            key={employeeKey}
                                            onClick={() => toggleEmployeeSelection(employeeName, deptName)}
                                            sx={{
                                              display: 'flex',
                                              alignItems: 'center',
                                              p: isMobile ? 0.75 : 1,
                                              pl: isMobile ? 3 : 4,
                                              cursor: 'pointer',
                                              bgcolor: isEmpSelected
                                                ? 'rgba(30, 136, 229, 0.05)'
                                                : 'transparent',
                                              '&:hover': {
                                                bgcolor: 'rgba(30, 136, 229, 0.05)',
                                              },
                                            }}
                                          >
                                            <Box
                                              sx={{
                                                width: isMobile ? 14 : 16,
                                                height: isMobile ? 14 : 16,
                                                border: '1.5px solid',
                                                borderColor: isEmpSelected ? '#1E88E5' : (isDark ? '#334155' : '#CBD5E1'),
                                                bgcolor: isEmpSelected ? '#1E88E5' : 'transparent',
                                                borderRadius: '3px',
                                                display: 'flex',
                                                alignItems: 'center',
                                                justifyContent: 'center',
                                                mr: 0.75,
                                                flexShrink: 0,
                                              }}
                                            >
                                              {isEmpSelected && (
                                                <CheckCircleOutlineIcon
                                                  sx={{ fontSize: isMobile ? 9 : 10, color: 'white' }}
                                                />
                                              )}
                                            </Box>
                                            <PersonIcon sx={{ fontSize: isMobile ? 14 : 16, color: panelSubText, mr: 0.75, flexShrink: 0 }} />
                                            <Typography
                                              sx={{
                                                fontSize: isMobile ? '12px' : '13px',
                                                color: isEmpSelected ? '#1E88E5' : panelText,
                                                overflow: 'hidden',
                                                textOverflow: 'ellipsis',
                                                whiteSpace: 'nowrap',
                                                flex: 1,
                                              }}
                                            >
                                              {employeeName}
                                            </Typography>
                                          </Box>
                                        );
                                      })}
                                    </Box>
                                  </Collapse>
                                </Paper>
                              );
                            })}
                        </Box>
                      )}
                    </Box>

                    {/* 전체 선택/해제 버튼 (하단 고정) */}
                    {departmentEmployees.size > 0 && (
                      <Box sx={{
                        display: 'flex',
                        gap: isMobile ? 1 : 1.5,
                        pt: isMobile ? 1 : 1.5,
                        borderTop: `1px solid ${panelBorder}`,
                        flexShrink: 0,
                      }}>
                        <Button
                          startIcon={<CheckCircleOutlineIcon sx={{ fontSize: isMobile ? 16 : 18 }} />}
                          onClick={handleSelectAll}
                          fullWidth
                          variant="contained"
                          size={isMobile ? 'small' : 'medium'}
                          sx={{
                            bgcolor: '#10B981',
                            borderRadius: '10px',
                            textTransform: 'none',
                            fontWeight: 600,
                            fontSize: isMobile ? '12px' : '14px',
                          }}
                        >
                          전체 선택
                        </Button>
                        <Button
                          startIcon={<RemoveCircleOutlineIcon sx={{ fontSize: isMobile ? 16 : 18 }} />}
                          onClick={handleSelectNone}
                          fullWidth
                          variant="outlined"
                          size={isMobile ? 'small' : 'medium'}
                          sx={{
                            borderColor: isDark ? '#334155' : '#CBD5E1',
                            color: panelSubText,
                            borderRadius: '10px',
                            textTransform: 'none',
                            fontWeight: 600,
                            fontSize: isMobile ? '12px' : '14px',
                          }}
                        >
                          선택 해제
                        </Button>
                      </Box>
                    )}
                  </Box>
                </Box>

                {/* 상세 패널 */}
                <Box
                  sx={{
                    width: isDetailPanelVisible && !isMobile ? '100%' : isMobile ? '100%' : 0,
                    height: isMobile && isDetailPanelVisible ? 'auto' : isMobile ? 0 : 'auto',
                    overflow: 'hidden',
                    transition: isMobile ? 'height 0.3s ease-in-out' : 'width 0.3s ease-in-out',
                    bgcolor: panelBg,
                    boxShadow: isMobile ? (isDark ? '0 -2px 10px rgba(0,0,0,0.4)' : '0 -2px 10px rgba(0,0,0,0.1)') : (isDark ? '-2px 0 10px rgba(0,0,0,0.4)' : '-2px 0 10px rgba(0,0,0,0.1)'),
                    borderTop: isMobile ? `1px solid ${panelBorder}` : 'none',
                  }}
                >
                  <Box sx={{ p: isMobile ? 1 : 2.5, height: '100%', display: 'flex', flexDirection: 'column' }}>
                    {/* 패널 헤더 */}
                    <Box
                      sx={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        mb: isMobile ? 1 : 2,
                        pb: isMobile ? 1 : 2,
                        borderBottom: `1px solid ${panelBorder}`,
                        flexShrink: 0,
                      }}
                    >
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.75, flex: 1, minWidth: 0 }}>
                        <Box
                          sx={{
                            p: isMobile ? 0.5 : 0.75,
                            bgcolor: 'rgba(30, 136, 229, 0.1)',
                            borderRadius: '8px',
                            flexShrink: 0,
                          }}
                        >
                          <EventNoteIcon sx={{ color: '#1E88E5', fontSize: isMobile ? 14 : 16 }} />
                        </Box>
                        <Box sx={{ flex: 1, minWidth: 0 }}>
                          <Typography sx={{ fontSize: isMobile ? '13px' : '14px', fontWeight: 600, color: panelText, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            휴가 상세 내역
                          </Typography>
                          <Typography sx={{ fontSize: isMobile ? '11px' : '12px', color: panelSubText, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {dayjs(selectedDate).format('YYYY년 MM월 DD일')}
                          </Typography>
                        </Box>
                      </Box>
                      <IconButton
                        onClick={() => setIsDetailPanelVisible(false)}
                        size="small"
                        sx={{ flexShrink: 0 }}
                      >
                        <CloseIcon sx={{ fontSize: isMobile ? 18 : 20 }} />
                      </IconButton>
                    </Box>

                    {/* 스크롤 가능한 상세내역 영역 */}
                    <Box sx={{ flex: 1, overflow: 'auto', minHeight: 0 }}>
                      {/* 상세 내용 */}
                      {selectedDateDetails.length === 0 ? (
                        <Box sx={{ textAlign: 'center', py: isMobile ? 4 : 8 }}>
                          <CalendarIcon sx={{ fontSize: isMobile ? 36 : 48, color: panelSubText, mb: 1 }} />
                          <Typography sx={{ color: panelSubText, fontSize: isMobile ? '12px' : '14px' }}>
                            선택된 날짜에<br />휴가 일정이 없습니다.
                          </Typography>
                        </Box>
                      ) : (
                        <>
                          <List sx={{ p: 0, mb: 1 }}>
                            {getPaginatedDetails().map((detail, index) => (
                              <Paper
                                key={index}
                                sx={{
                                  p: isMobile ? 1 : 2,
                                  mb: isMobile ? 0.75 : 1.5,
                                  bgcolor: 'rgba(30, 136, 229, 0.05)',
                                  border: '1px solid rgba(30, 136, 229, 0.2)',
                                  borderRadius: '8px',
                                }}
                              >
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.75, mb: isMobile ? 0.75 : 1, flexWrap: 'wrap' }}>
                                  <Typography sx={{ fontSize: isMobile ? '13px' : '14px', fontWeight: 700, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1, minWidth: 0 }}>
                                    {detail.employeeName || '신청자'}
                                  </Typography>
                                  {detail.department && (
                                    <Typography sx={{ fontSize: isMobile ? '11px' : '12px', color: panelSubText, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                      ({detail.department})
                                    </Typography>
                                  )}
                                  <Chip
                                    label={detail.vacationType}
                                    size="small"
                                    sx={{
                                      bgcolor: 'rgba(30, 136, 229, 0.1)',
                                      color: '#1E88E5',
                                      fontSize: isMobile ? '10px' : '11px',
                                      fontWeight: 600,
                                      height: isMobile ? 20 : 24,
                                    }}
                                  />
                                </Box>
                                {detail.startDate && detail.endDate && (
                                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, flexWrap: 'wrap' }}>
                                    <CalendarIcon sx={{ fontSize: isMobile ? 14 : 16, color: panelSubText, flexShrink: 0 }} />
                                    <Typography sx={{ fontSize: isMobile ? '12px' : '13px', fontWeight: 600, color: panelText, wordBreak: 'break-word' }}>
                                      {dayjs(detail.startDate).format('YYYY.MM.DD')} ~{' '}
                                      {dayjs(detail.endDate).format('YYYY.MM.DD')}
                                    </Typography>
                                  </Box>
                                )}
                              </Paper>
                            ))}
                          </List>

                          {/* 상세내역 페이지네이션 */}
                          {getDetailTotalPages() > 1 && (
                            <Box sx={{ display: 'flex', justifyContent: 'center', mt: 1, mb: 1, borderTop: `1px solid ${panelBorder}`, pt: 1 }}>
                              <Pagination
                                count={getDetailTotalPages()}
                                page={detailPage}
                                onChange={(_, page) => setDetailPage(page)}
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
                      )}
                    </Box>
                  </Box>
                </Box>
              </Box>
            )}
          </Box>
        </Box>
      </DialogContent>

      {/* 년월 선택 다이얼로그 */}
      <Dialog
        open={yearMonthDialogOpen}
        onClose={handleYearMonthCancel}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle sx={{ fontWeight: 600 }}>
          연도 및 월 선택
        </DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', gap: 2, mt: 1 }}>
            <FormControl fullWidth>
              <Typography sx={{ mb: 1, fontWeight: 500 }}>연도</Typography>
              <Select
                value={selectedYear}
                onChange={(e) => setSelectedYear(Number(e.target.value))}
              >
                {Array.from({ length: 10 }, (_, i) => {
                  const year = new Date().getFullYear() - 2 + i; // 현재 연도 ±2년
                  return (
                    <MenuItem key={year} value={year}>
                      {year}년
                    </MenuItem>
                  );
                })}
              </Select>
            </FormControl>
            <FormControl fullWidth>
              <Typography sx={{ mb: 1, fontWeight: 500 }}>월</Typography>
              <Select
                value={selectedMonth}
                onChange={(e) => setSelectedMonth(Number(e.target.value))}
              >
                {Array.from({ length: 12 }, (_, i) => (
                  <MenuItem key={i + 1} value={i + 1}>
                    {i + 1}월
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleYearMonthCancel}>취소</Button>
          <Button onClick={handleYearMonthConfirm} variant="contained">
            확인
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );

  // embedded 모드: Dialog 없이 Box로 감싸서 반환
  if (embedded) {
    return (
      <Box
        sx={{
          width: '100%',
          height: isMobile ? 'auto' : '100%',
          display: 'flex',
          flexDirection: 'column',
          overflow: isMobile ? 'visible' : 'hidden',
          bgcolor: 'background.paper',
        }}
      >
        {renderContent()}
      </Box>
    );
  }

  // 일반 모드: Dialog로 감싸서 반환
  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth={false}
      fullWidth
      fullScreen={isMobile}
      PaperProps={{
        sx: {
          maxHeight: isMobile ? '100%' : '90vh',
          height: isMobile ? '100%' : '90vh',
          width: isMobile ? '100%' : '90vw',
          maxWidth: isMobile ? '100%' : '90vw',
          borderRadius: isMobile ? 0 : '20px',
          m: isMobile ? 0 : 0, // 관리자용과 동일하게 여백 제거
        },
      }}
    >
      {renderContent()}
    </Dialog>
  );
}
