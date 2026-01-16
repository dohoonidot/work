import React from 'react';
import {
    PieChart,
    Pie,
    Cell,
    ResponsiveContainer,
    Tooltip,
} from 'recharts';
import { Box, Typography } from '@mui/material';

interface HolidayAdjacentUsageChartProps {
    usageRate: number; // 0.0 ~ 1.0
    isDarkTheme: boolean;
}

const HolidayAdjacentUsageChart: React.FC<HolidayAdjacentUsageChartProps> = ({
    usageRate,
    isDarkTheme,
}) => {
    const percentage = Math.round(usageRate * 100);

    const data = [
        { name: '공휴일 인접 사용', value: percentage },
        { name: '기타 사용', value: 100 - percentage },
    ];

    const COLORS = ['#667EEA', isDarkTheme ? '#3A3A3A' : '#F3F4F6'];

    return (
        <Box
            sx={{
                width: '100%',
                height: 180,
                minHeight: 180,
                minWidth: 0,
                position: 'relative',
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
            }}
        >
            <ResponsiveContainer width="100%" height={180}>
                <PieChart>
                    <Pie
                        data={data}
                        cx="50%"
                        cy="50%"
                        innerRadius={60}
                        outerRadius={80}
                        paddingAngle={5}
                        dataKey="value"
                        animationDuration={1500}
                        startAngle={90}
                        endAngle={-270}
                    >
                        {data.map((_, index) => (
                            <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} stroke="none" />
                        ))}
                    </Pie>
                    <Tooltip
                        contentStyle={{
                            backgroundColor: isDarkTheme ? '#2D2D2D' : 'white',
                            border: `1px solid ${isDarkTheme ? '#444' : '#E5E7EB'}`,
                            borderRadius: '8px',
                            color: isDarkTheme ? 'white' : 'black'
                        }}
                    />
                </PieChart>
            </ResponsiveContainer>

            {/* 중앙 텍스트 */}
            <Box
                sx={{
                    position: 'absolute',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                }}
            >
                <Typography
                    variant="h4"
                    sx={{
                        fontWeight: 800,
                        color: '#667EEA',
                        lineHeight: 1,
                    }}
                >
                    {`${percentage}%`}
                </Typography>
                <Typography
                    variant="caption"
                    sx={{
                        color: isDarkTheme ? '#9CA3AF' : '#6B7280',
                        fontWeight: 500,
                        mt: 0.5,
                    }}
                >
                    인접 사용률
                </Typography>
            </Box>
        </Box>
    );
};

export default HolidayAdjacentUsageChart;
