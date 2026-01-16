import React from 'react';
import { Box, Typography, Grid, Paper } from '@mui/material';
import dayjs from 'dayjs';

interface VacationCalendarGridProps {
    recommendedDates: string[];
    isDarkTheme: boolean;
}

const VacationCalendarGrid: React.FC<VacationCalendarGridProps> = ({
    recommendedDates,
    isDarkTheme,
}) => {
    const currentYear = recommendedDates.length > 0
        ? dayjs(recommendedDates[0]).year()
        : dayjs().year();

    // 특정 월의 일수 및 시작 요일 계산
    const getDaysInMonth = (month: number) => {
        const firstDay = dayjs(`${currentYear}-${month + 1}-01`);
        const daysInMonth = firstDay.daysInMonth();
        const startDay = firstDay.day(); // 0: 일요일
        return { daysInMonth, startDay };
    };

    const renderMonth = (month: number) => {
        const { daysInMonth, startDay } = getDaysInMonth(month);
        const monthName = dayjs().month(month).format('M월');

        // 캘린더 그리드 생성 (최대 6주)
        const days = [];
        // 이전 달 빈 칸
        for (let i = 0; i < startDay; i++) {
            days.push(<Box key={`empty-${i}`} sx={{ width: '100%', pt: '100%' }} />);
        }

        // 이번 달 날짜
        for (let d = 1; d <= daysInMonth; d++) {
            const dateStr = `${currentYear}-${(month + 1).toString().padStart(2, '0')}-${d.toString().padStart(2, '0')}`;
            const isRecommended = recommendedDates.includes(dateStr);
            const isWeekend = dayjs(dateStr).day() === 0 || dayjs(dateStr).day() === 6;

            days.push(
                <Box
                    key={dateStr}
                    sx={{
                        position: 'relative',
                        width: '100%',
                        pt: '100%',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        borderRadius: '4px',
                        bgcolor: isRecommended ? '#667EEA' : 'transparent',
                        transition: 'all 0.2s',
                    }}
                >
                    <Typography
                        sx={{
                            position: 'absolute',
                            top: '50%',
                            left: '50%',
                            transform: 'translate(-50%, -50%)',
                            fontSize: '9px',
                            fontWeight: isRecommended ? 700 : 400,
                            color: isRecommended
                                ? 'white'
                                : isWeekend
                                    ? (isDarkTheme ? '#ef4444' : '#dc2626')
                                    : (isDarkTheme ? '#9CA3AF' : '#4B5563'),
                        }}
                    >
                        {d}
                    </Typography>
                </Box>
            );
        }

        return (
            <Paper
                elevation={0}
                sx={{
                    p: 1.5,
                    bgcolor: isDarkTheme ? 'rgba(255,255,255,0.03)' : '#F9FBFF',
                    borderRadius: '12px',
                    border: `1px solid ${isDarkTheme ? '#3A3A3A' : '#E9ECEF'}`,
                    height: '100%',
                }}
            >
                <Typography
                    variant="subtitle2"
                    sx={{
                        mb: 1,
                        fontWeight: 700,
                        color: isDarkTheme ? 'white' : 'black',
                        textAlign: 'center',
                        fontSize: '12px',
                    }}
                >
                    {monthName}
                </Typography>
                <Box
                    sx={{
                        display: 'grid',
                        gridTemplateColumns: 'repeat(7, 1fr)',
                        gap: '2px',
                    }}
                >
                    {/* 요일 헤더 */}
                    {['일', '월', '화', '수', '목', '금', '토'].map((d, i) => (
                        <Typography
                            key={i}
                            sx={{
                                fontSize: '8px',
                                textAlign: 'center',
                                color: i === 0 || i === 6 ? '#ef4444' : (isDarkTheme ? '#4B5563' : '#9CA3AF'),
                                pb: 0.5,
                            }}
                        >
                            {d}
                        </Typography>
                    ))}
                    {/* 날짜 데이터 */}
                    {days}
                </Box>
            </Paper>
        );
    };

    return (
        <Box sx={{ width: '100%' }}>
            <Grid container spacing={2}>
                {[...Array(12)].map((_, i) => (
                    <Grid xs={6} sm={4} md={3} key={i}>
                        {renderMonth(i)}
                    </Grid>
                ))}
            </Grid>
        </Box>
    );
};

export default VacationCalendarGrid;
