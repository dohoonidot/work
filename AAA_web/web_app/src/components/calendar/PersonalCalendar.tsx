import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  IconButton,
  Card,
  CardContent,
  Chip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Grid,
  CircularProgress,
  Alert,
  Slide,
  Paper,
  List,
  ListItem,
  ListItemText,
  Divider,
  useMediaQuery,
  useTheme,
} from '@mui/material';
import {
  ChevronLeft as ChevronLeftIcon,
  ChevronRight as ChevronRightIcon,
  CalendarMonth as CalendarIcon,
  Fullscreen as FullscreenIcon,
  Close as CloseIcon,
  EventNote as EventNoteIcon,
} from '@mui/icons-material';
import dayjs from 'dayjs';
import leaveService from '../../services/leaveService';
import authService from '../../services/authService';
import type { MonthlyLeave, CalendarDay } from '../../types/leave';

interface PersonalCalendarProps {
  monthlyLeaves?: MonthlyLeave[]; // 초기 데이터 (선택사항)
  loading?: boolean;
  error?: string | null;
  onTotalCalendarOpen?: () => void;
  onMonthChange?: (month: string, leaves: MonthlyLeave[]) => void; // 월 변경 콜백
}

export default function PersonalCalendar({
  monthlyLeaves: initialMonthlyLeaves = [],
  loading: initialLoading = false,
  error: initialError = null,
  onTotalCalendarOpen,
  onMonthChange
}: PersonalCalendarProps) {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const isDark = theme.palette.mode === 'dark';
  const [currentDate, setCurrentDate] = useState(dayjs());
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [selectedDateDetails, setSelectedDateDetails] = useState<MonthlyLeave[]>([]);
  const [detailDialogOpen, setDetailDialogOpen] = useState(false);
  const [slidePanelOpen, setSlidePanelOpen] = useState(false);
  const [fullCalendarOpen, setFullCalendarOpen] = useState(false);

  // 월별 달력 데이터 상태
  const [monthlyLeaves, setMonthlyLeaves] = useState<MonthlyLeave[]>(initialMonthlyLeaves);
  const [loading, setLoading] = useState(initialLoading);
  const [error, setError] = useState<string | null>(initialError);

  // 월별 달력 데이터 로드
  useEffect(() => {
    loadMonthlyCalendar();
  }, [currentDate]);

  // 초기 데이터가 변경되면 업데이트
  useEffect(() => {
    if (initialMonthlyLeaves.length > 0) {
      setMonthlyLeaves(initialMonthlyLeaves);
    }
  }, [initialMonthlyLeaves]);

  const loadMonthlyCalendar = async () => {
    try {
      setLoading(true);
      setError(null);

      const user = authService.getCurrentUser();
      if (!user) {
        setError('사용자 정보를 찾을 수 없습니다.');
        return;
      }

      const month = currentDate.format('YYYY-MM');
      console.log('월별 달력 데이터 로드:', month);

      const response = await leaveService.getMonthlyCalendar({
        userId: user.userId,
        month: month,
      });

      console.log('월별 달력 응답:', response);

      if (response.monthlyLeaves) {
        setMonthlyLeaves(response.monthlyLeaves);
        // 콜백 호출
        onMonthChange?.(month, response.monthlyLeaves);
      }
    } catch (err: any) {
      console.error('월별 달력 로드 실패:', err);
      setError(err.response?.data?.message || '월별 달력 데이터를 불러오는데 실패했습니다.');
    } finally {
      setLoading(false);
    }
  };

  // 달력 그리드 생성
  const generateCalendarDays = (): CalendarDay[] => {
    const startOfMonth = currentDate.startOf('month');
    const endOfMonth = currentDate.endOf('month');
    const startOfWeek = startOfMonth.startOf('week');
    const endOfWeek = endOfMonth.endOf('week');

    const days: CalendarDay[] = [];
    let currentDay = startOfWeek;

    while (currentDay.isBefore(endOfWeek) || currentDay.isSame(endOfWeek, 'day')) {
      const dayDate = currentDay.toDate();
      const isCurrentMonth = currentDay.isSame(currentDate, 'month');
      const isToday = currentDay.isSame(dayjs(), 'day');

      // 해당 날짜의 휴가 찾기 - Flutter와 동일한 로직 (날짜 부분만 비교)
      const dayLeaves = monthlyLeaves.filter(leave => {
        if (!leave.startDate || !leave.endDate) return false;

        // 날짜 부분만 추출하여 비교 (타임존 문제 방지)
        const startDate = dayjs(leave.startDate).startOf('day');
        const endDate = dayjs(leave.endDate).startOf('day');
        const currentDate = currentDay.startOf('day');

        // endDate까지 포함하여 표시 (inclusive)
        return (
          currentDate.isSame(startDate, 'day') ||
          currentDate.isSame(endDate, 'day') ||
          (currentDate.isAfter(startDate, 'day') && currentDate.isBefore(endDate, 'day'))
        );
      });
      // 승인된 건만 표시
      const approvedLeaves = dayLeaves.filter(l => l.status?.toUpperCase() === 'APPROVED');

      days.push({
        date: dayDate,
        isCurrentMonth,
        isToday,
        leaves: approvedLeaves,
      });

      currentDay = currentDay.add(1, 'day');
    }

    return days;
  };

  const calendarDays = generateCalendarDays();
  const cardBg = isDark ? '#0F172A' : 'white';
  const panelBg = isDark ? '#111827' : 'white';
  const panelBorder = isDark ? 'rgba(255,255,255,0.08)' : '#F1F3F5';
  const panelText = isDark ? '#E5E7EB' : '#1A1D1F';
  const panelSubText = isDark ? '#9CA3AF' : '#6C757D';
  const emptyIcon = isDark ? '#374151' : '#E5E7EB';

  const handlePrevMonth = () => {
    setCurrentDate(prev => prev.subtract(1, 'month'));
  };

  const handleNextMonth = () => {
    setCurrentDate(prev => prev.add(1, 'month'));
  };

  const handleDateClick = (day: CalendarDay) => {
    setSelectedDate(day.date);

    // 선택된 날짜의 모든 휴가 내역 표시 (승인/대기/반려 모두) - Flutter와 동일한 로직
    const selectedDateDetails = monthlyLeaves.filter(leave => {
      if (!leave.startDate || !leave.endDate) return false;

      // 날짜 부분만 추출하여 비교 (타임존 문제 방지)
      const startDate = dayjs(leave.startDate).startOf('day');
      const endDate = dayjs(leave.endDate).startOf('day');
      const clickedDate = dayjs(day.date).startOf('day');

      // endDate까지 포함하여 표시 (inclusive)
      return (
        clickedDate.isSame(startDate, 'day') ||
        clickedDate.isSame(endDate, 'day') ||
        (clickedDate.isAfter(startDate, 'day') && clickedDate.isBefore(endDate, 'day'))
      );
    });

    if (selectedDateDetails.length > 0) {
      setSelectedDateDetails(selectedDateDetails);
      setSlidePanelOpen(true);
    } else {
      setSelectedDateDetails([]);
      setSlidePanelOpen(false);
    }
  };

  const getStatusColor = (status: string) => {
    // Flutter와 동일한 우선순위: 대기중 > 승인됨 > 반려됨 > 취소됨
    switch (status.toUpperCase()) {
      case 'REQUESTED':
      case 'PENDING':
        return 'warning'; // 대기중 - 최우선
      case 'APPROVED':
        return 'success'; // 승인됨
      case 'REJECTED':
        return 'error'; // 반려됨
      case 'CANCELLED':
        return 'default'; // 취소됨 - 최하위
      default:
        return 'default';
    }
  };

  const getStatusLabel = (status: string) => {
    const labels: { [key: string]: string } = {
      REQUESTED: '신청',
      APPROVED: '승인',
      REJECTED: '반려',
      PENDING: '대기중',
      CANCELLED: '취소됨',
    };
    return labels[status] || status;
  };

  const renderCalendarDay = (day: CalendarDay) => {
    const hasLeaves = day.leaves.length > 0;
    const isWeekend = day.date.getDay() === 0 || day.date.getDay() === 6;

    // Flutter와 동일한 상태별 우선순위 색상 결정
    // 승인된 건만 표시하므로 색상은 승인 색상만 사용
    const leaveColor = hasLeaves ? '#20C997' : '';

    return (
      <Box
        key={day.date.toISOString()}
        sx={{
          width: '100%',
          height: '100%',
          minHeight: isMobile ? '28px' : '40px', // 데스크톱뷰에서 최소 높이 40px
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: hasLeaves ? 'pointer' : 'default',
          border: '1px solid',
          borderColor: isDark ? 'rgba(255,255,255,0.08)' : 'divider',
          backgroundColor: day.isToday
            ? (isDark ? 'primary.dark' : 'primary.light')
            : isWeekend
              ? (isDark ? 'rgba(255,255,255,0.04)' : 'grey.50')
              : (isDark ? 'transparent' : 'white'),
          color: day.isCurrentMonth
            ? (day.isToday ? 'primary.contrastText' : (isDark ? 'grey.100' : 'text.primary'))
            : (isDark ? 'grey.600' : 'text.disabled'),
          '&:hover': hasLeaves ? {
            backgroundColor: isDark ? 'primary.dark' : 'primary.light',
            color: 'primary.contrastText',
          } : {},
          position: 'relative',
          p: isMobile ? 0.5 : 0.75, // 데스크톱뷰에서 패딩 조정
          overflow: 'visible',
        }}
        onClick={() => handleDateClick(day)}
      >
        <Typography
          component="span"
          sx={{
            fontWeight: day.isToday ? 'bold' : 600,
            fontSize: '0.8rem',
            lineHeight: 1,
            textAlign: 'center',
            display: 'block',
            color: 'inherit',
            zIndex: 1,
          }}
        >
          {day.date.getDate()}
        </Typography>

        {hasLeaves && (
          <Box
            sx={{
              position: 'absolute',
              bottom: '2px',
              left: '50%',
              transform: 'translateX(-50%)',
              width: '4px',
              height: '4px',
              borderRadius: '50%',
              backgroundColor: leaveColor,
              zIndex: 2,
            }}
          />
        )}
      </Box>
    );
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ m: 2 }}>
        {error}
      </Alert>
    );
  }

  return (
    <>
      <Card sx={{ borderRadius: 2, position: 'relative', bgcolor: cardBg }}>
        {/* 배경 오버레이 (패널이 열려있을 때) */}
        {slidePanelOpen && (
          <Box
            onClick={() => setSlidePanelOpen(false)}
            sx={{
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              bgcolor: 'rgba(0, 0, 0, 0.3)',
              zIndex: 999,
              borderRadius: 2,
            }}
          />
        )}

        <CardContent
          sx={{
            p: 0.75,
            '&:last-child': { pb: 0.75 },
            height: '100%',
            display: 'flex',
            flexDirection: 'column',
            minHeight: 0
          }}
          onClick={(e) => {
            // 패널이 열려있고, 패널이 아닌 영역을 클릭한 경우 패널 닫기
            if (slidePanelOpen && !(e.target as HTMLElement).closest('[data-panel-content]')) {
              setSlidePanelOpen(false);
            }
          }}
        >
          {/* 달력 헤더 */}
          <Box sx={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            mb: 0.75,
            flexShrink: 0
          }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
              <CalendarIcon color="primary" sx={{ fontSize: 14 }} />
            <Typography variant="subtitle1" sx={{ fontWeight: 600, fontSize: '0.75rem', color: panelText }}>
              {currentDate.format('YYYY년 MM월')}
            </Typography>
            </Box>

            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.25 }}>
              <IconButton
                onClick={handlePrevMonth}
                size="small"
                sx={{ p: 0.25, width: 24, height: 24 }}
              >
                <ChevronLeftIcon sx={{ fontSize: 16, color: panelText }} />
              </IconButton>

              <IconButton
                onClick={handleNextMonth}
                size="small"
                sx={{ p: 0.25, width: 24, height: 24 }}
              >
                <ChevronRightIcon sx={{ fontSize: 16, color: panelText }} />
              </IconButton>

              <IconButton
                onClick={() => onTotalCalendarOpen?.()}
                size="small"
                sx={{ p: 0.25, width: 24, height: 24 }}
                title="전체휴가 보기"
              >
                <FullscreenIcon sx={{ fontSize: 14, color: panelText }} />
              </IconButton>
            </Box>
          </Box>

          {/* 요일 헤더 */}
          <Grid container spacing={0} sx={{ mb: 0.25, flexShrink: 0 }}>
            {['일', '월', '화', '수', '목', '금', '토'].map((day) => (
              <Grid size={12 / 7} key={day}>
                <Box sx={{
                  textAlign: 'center',
                  py: 0.25,
                  fontWeight: 'bold',
                  fontSize: '0.65rem',
                  color: day === '일'
                    ? 'error.main'
                    : day === '토'
                      ? 'primary.main'
                      : (isDark ? 'grey.500' : 'text.secondary')
                }}>
                  {day}
                </Box>
              </Grid>
            ))}
          </Grid>

          {/* 달력 그리드 */}
          <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
            <Box sx={{
              flex: 1,
              minHeight: 0,
              display: 'grid',
              gridTemplateColumns: 'repeat(7, 1fr)',
              gridAutoRows: isMobile ? '1fr' : 'minmax(40px, 1fr)', // 데스크톱뷰에서 최소 높이 40px
              gap: 0,
              alignContent: 'stretch',
            }}>
              {calendarDays.map((day, index) => (
                <Box key={index} sx={{ display: 'flex', minHeight: 0, width: '100%' }}>
                  {renderCalendarDay(day)}
                </Box>
              ))}
            </Box>
          </Box>
        </CardContent>

        {/* 슬라이드 패널 - Flutter와 동일한 스타일 */}
        <Slide direction="left" in={slidePanelOpen} mountOnEnter unmountOnExit>
          <Paper
            data-panel-content
            onClick={(e) => e.stopPropagation()}
            sx={{
              position: 'absolute',
              top: 0,
              right: 0,
              width: '400px',
              height: '100%',
              zIndex: 1000,
              borderRadius: '16px 0 0 16px',
              boxShadow: isDark ? '-4px 0 20px rgba(0,0,0,0.4)' : '-4px 0 20px rgba(0,0,0,0.1)',
              bgcolor: panelBg,
            }}
          >
            <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
              {/* 패널 헤더 - Flutter와 동일 */}
              <Box sx={{
                px: 1.5,
                py: 1,
                borderBottom: `1px solid ${panelBorder}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                borderRadius: '16px 0 0 0',
              }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Box
                    sx={{
                      p: 0.5,
                      bgcolor: isDark ? 'rgba(30, 136, 229, 0.2)' : 'rgba(30, 136, 229, 0.1)',
                      borderRadius: '6px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <EventNoteIcon sx={{ color: '#1E88E5', fontSize: 14 }} />
                  </Box>
                  <Typography sx={{ fontSize: '12px', fontWeight: 600, color: panelText }}>
                    {selectedDate && `${dayjs(selectedDate).format('YYYY년 MM월 DD일')}`}
                  </Typography>
                </Box>
                <IconButton
                  onClick={() => setSlidePanelOpen(false)}
                  size="small"
                  sx={{
                    p: 0,
                    minWidth: 20,
                    minHeight: 20,
                    color: panelSubText,
                  }}
                >
                  <CloseIcon sx={{ fontSize: 16, color: panelSubText }} />
                </IconButton>
              </Box>

              {/* 휴가 내역 리스트 - Flutter와 동일한 스타일 */}
              <Box sx={{ flex: 1, overflow: 'auto', p: 1.5 }}>
                {selectedDateDetails.length === 0 ? (
                  <Box sx={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    height: '100%',
                    p: 2
                  }}>
                    <CalendarIcon sx={{ fontSize: 48, color: emptyIcon, mb: 1 }} />
                    <Typography sx={{ fontSize: '12px', color: panelSubText, textAlign: 'center' }}>
                      휴가 일정이 없습니다
                    </Typography>
                  </Box>
                ) : (
                  <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                    {selectedDateDetails
                      .sort((a, b) => {
                        // Flutter와 동일한 상태별 우선순위 정렬: 대기중 → 승인됨 → 반려됨 → 취소됨
                        const statusPriority: { [key: string]: number } = {
                          'REQUESTED': 1,
                          'PENDING': 1,
                          '대기': 1,
                          '대기중': 1,
                          'APPROVED': 2,
                          '승인': 2,
                          '승인됨': 2,
                          'REJECTED': 3,
                          '반려': 3,
                          '반려됨': 3,
                          'CANCELLED': 4,
                          '취소': 4,
                          '취소됨': 4,
                        };
                        const statusA = (a.status || '').toUpperCase();
                        const statusB = (b.status || '').toUpperCase();
                        const priorityA = statusPriority[statusA] || 5;
                        const priorityB = statusPriority[statusB] || 5;
                        return priorityA - priorityB;
                      })
                      .map((leave, index) => {
                        const status = (leave.status || '').toUpperCase();
                        const isPending = status === 'REQUESTED' || status === 'PENDING' || status === '대기' || status === '대기중';
                        const isApproved = status === 'APPROVED' || status === '승인' || status === '승인됨';
                        const isRejected = status === 'REJECTED' || status === '반려' || status === '반려됨';
                        const isCancelled = status === 'CANCELLED' || status === '취소' || status === '취소됨';

                        let statusColor = '#1E88E5';
                        if (isPending) statusColor = '#FF8C00';
                        else if (isApproved) statusColor = '#20C997';
                        else if (isRejected) statusColor = '#DC3545';
                        else if (isCancelled) statusColor = '#6C757D';

                        return (
                          <Paper
                            key={index}
                            sx={{
                              p: 1.5,
                              mb: 1,
                              bgcolor: `${statusColor}0D`,
                              borderRadius: '8px',
                              border: `1px solid ${statusColor}33`,
                            }}
                          >
                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.75 }}>
                              {/* 상태 배지와 휴가 종류 - Flutter와 동일한 레이아웃 */}
                              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.75 }}>
                                <Chip
                                  label={getStatusLabel(leave.status)}
                                  size="small"
                                  sx={{
                                    bgcolor: statusColor,
                                    color: 'white',
                                    fontSize: '11px',
                                    fontWeight: 700,
                                    height: 22,
                                    px: 1.25,
                                    py: 0.5,
                                    borderRadius: '15px',
                                  }}
                                />
                                  <Typography sx={{
                                  fontSize: '13px',
                                  fontWeight: 600,
                                  color: panelText,
                                  flex: 1,
                                }}>
                                  {leave.leaveType || '휴가'}
                                </Typography>
                              </Box>

                              {/* 사유 - Flutter와 동일한 순서 */}
                              {leave.reason && leave.reason.trim() && (
                                <Typography sx={{
                                  fontSize: '10px',
                                  color: panelSubText,
                                  lineHeight: 1.4,
                                  maxHeight: '2.8em',
                                  overflow: 'hidden',
                                  textOverflow: 'ellipsis',
                                  display: '-webkit-box',
                                  WebkitLineClamp: 2,
                                  WebkitBoxOrient: 'vertical',
                                }}>
                                  사유: {leave.reason}
                                </Typography>
                              )}

                              {/* 기간 - Flutter와 동일한 형식 */}
                              {leave.startDate && leave.endDate && (
                                <Typography sx={{
                                  fontSize: '10px',
                                  color: panelSubText,
                                }}>
                                  기간: {dayjs(leave.startDate).format('YYYY.MM.DD')} ~ {dayjs(leave.endDate).format('YYYY.MM.DD')}
                                  {leave.halfDaySlot && leave.halfDaySlot !== 'ALL' && ` (${leave.halfDaySlot === 'AM' ? '오전' : leave.halfDaySlot === 'PM' ? '오후' : leave.halfDaySlot})`}
                                </Typography>
                              )}

                              {/* 반려 사유 - 있으면 표시 */}
                              {leave.rejectMessage && leave.rejectMessage.trim() && (
                                <Box sx={{
                                  mt: 0.5,
                                  p: 0.75,
                                  bgcolor: '#DC354520',
                                  borderRadius: '6px',
                                  border: '1px solid #DC354533',
                                }}>
                                  <Typography sx={{
                                    fontSize: '10px',
                                    color: '#DC3545',
                                    fontWeight: 600,
                                  }}>
                                    반려 사유: {leave.rejectMessage}
                                  </Typography>
                                </Box>
                              )}
                            </Box>
                          </Paper>
                        );
                      })}
                  </Box>
                )}
              </Box>
            </Box>
          </Paper>
        </Slide>
      </Card>

      {/* 휴가 상세 다이얼로그 */}
      <Dialog
        open={detailDialogOpen}
        onClose={() => setDetailDialogOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>
          {selectedDate && dayjs(selectedDate).format('YYYY년 MM월 DD일')} 휴가 내역
        </DialogTitle>
        <DialogContent>
          {selectedDateDetails.map((leave, index) => (
            <Card key={index} sx={{ mb: 2 }}>
              <CardContent sx={{ p: 2 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                  <Typography variant="h6" sx={{ fontWeight: 600 }}>
                    {leave.leaveType}
                  </Typography>
                  <Chip
                    label={getStatusLabel(leave.status)}
                    color={getStatusColor(leave.status) as any}
                    size="small"
                  />
                </Box>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                  {dayjs(leave.startDate).format('MM/DD')} - {dayjs(leave.endDate).format('MM/DD')}
                  {leave.halfDaySlot && ` (${leave.halfDaySlot})`}
                </Typography>
                <Typography variant="body2">
                  {leave.reason}
                </Typography>
                {leave.rejectMessage && (
                  <Alert severity="error" sx={{ mt: 1 }}>
                    반려 사유: {leave.rejectMessage}
                  </Alert>
                )}
              </CardContent>
            </Card>
          ))}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDetailDialogOpen(false)}>
            닫기
          </Button>
        </DialogActions>
      </Dialog>

    </>
  );
}
