import React, { useMemo } from 'react';
import {
    BarChart,
    Bar,
    XAxis,
    YAxis,
    CartesianGrid,
    Tooltip,
    ResponsiveContainer,
    Cell,
} from 'recharts';
import { Box, Typography } from '@mui/material';

interface WeekdayDistributionChartProps {
    weekdayData: Record<string, number>;
    isDarkTheme: boolean;
}

const WeekdayDistributionChart: React.FC<WeekdayDistributionChartProps> = ({
    weekdayData,
    isDarkTheme,
}) => {
    const data = useMemo(() => {
        const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
        // API 데이터 매핑 (Thursday -> 목)
        const mapping: Record<string, string> = {
            'Monday': '월',
            'Tuesday': '화',
            'Wednesday': '수',
            'Thursday': '목',
            'Friday': '금',
            'Saturday': '토',
            'Sunday': '일',
        };
        const shortMapping: Record<string, string> = {
            mon: '월',
            tue: '화',
            wed: '수',
            thu: '목',
            fri: '금',
            sat: '토',
            sun: '일',
        };

        return weekdays.map(day => {
            // 영어 키 또는 한글 키 모두 지원
            const englishDay = Object.keys(mapping).find(key => mapping[key] === day);
            const shortKey = Object.keys(shortMapping).find(key => shortMapping[key] === day);
            const value =
                (englishDay && weekdayData[englishDay]) ||
                (shortKey && weekdayData[shortKey]) ||
                weekdayData[day] ||
                0;

            return {
                name: day,
                count: value,
            };
        });
    }, [weekdayData]);

    const CustomTooltip = ({ active, payload, label }: any) => {
        if (active && payload && payload.length) {
            return (
                <Box
                    sx={{
                        bgcolor: isDarkTheme ? '#2D2D2D' : 'white',
                        p: 1.5,
                        border: `1px solid ${isDarkTheme ? '#444' : '#E5E7EB'}`,
                        borderRadius: '8px',
                        boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)',
                    }}
                >
                    <Typography variant="body2" fontWeight={600} color={isDarkTheme ? 'white' : 'black'}>
                        {`${label}요일`}
                    </Typography>
                    <Typography variant="body2" color="#764BA2" fontWeight={700}>
                        {`${payload[0].value}회`}
                    </Typography>
                </Box>
            );
        }
        return null;
    };

    return (
        <Box sx={{ width: '100%', height: 250, mt: 2 }}>
            <ResponsiveContainer width="100%" height="100%">
                <BarChart
                    data={data}
                    margin={{ top: 10, right: 10, left: -20, bottom: 0 }}
                >
                    <CartesianGrid
                        strokeDasharray="3 3"
                        vertical={false}
                        stroke={isDarkTheme ? '#444' : '#E5E7EB'}
                    />
                    <XAxis
                        dataKey="name"
                        axisLine={false}
                        tickLine={false}
                        tick={{ fill: isDarkTheme ? '#9CA3AF' : '#6B7280', fontSize: 12 }}
                        dy={10}
                    />
                    <YAxis
                        axisLine={false}
                        tickLine={false}
                        tick={{ fill: isDarkTheme ? '#9CA3AF' : '#6B7280', fontSize: 12 }}
                        allowDecimals={false}
                    />
                    <Tooltip content={<CustomTooltip />} cursor={{ fill: isDarkTheme ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.02)' }} />
                    <Bar
                        dataKey="count"
                        radius={[4, 4, 0, 0]}
                        animationDuration={1500}
                        animationEasing="ease-out"
                    >
                        {data.map((entry, index) => (
                            <Cell
                                key={`cell-${index}`}
                                fill={entry.count > 0 ? '#764BA2' : isDarkTheme ? '#3A3A3A' : '#F3F4F6'}
                            />
                        ))}
                    </Bar>
                </BarChart>
            </ResponsiveContainer>
        </Box>
    );
};

export default WeekdayDistributionChart;
