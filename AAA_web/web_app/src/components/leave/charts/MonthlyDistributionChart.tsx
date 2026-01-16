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
import { Box, useTheme, Typography } from '@mui/material';

interface MonthlyDistributionChartProps {
    monthlyData: Record<string, number>;
    isDarkTheme: boolean;
}

const MonthlyDistributionChart: React.FC<MonthlyDistributionChartProps> = ({
    monthlyData,
    isDarkTheme,
}) => {
    const theme = useTheme();

    const data = useMemo(() => {
        // 1월부터 12월까지 데이터 생성
        const result = [];
        for (let i = 1; i <= 12; i++) {
            const monthStr = i < 10 ? `0${i}` : `${i}`;
            // 연도는 데이터에서 추출하거나 현재 연도 사용
            const firstKey = Object.keys(monthlyData)[0];
            const year = firstKey ? firstKey.split('-')[0] : new Date().getFullYear().toString();
            const key = `${year}-${monthStr}`;

            result.push({
                name: `${i}월`,
                days: monthlyData[key] || 0,
                fullKey: key,
            });
        }
        return result;
    }, [monthlyData]);

    // 커스텀 툴팁
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
                        {label}
                    </Typography>
                    <Typography variant="body2" color="#667EEA" fontWeight={700}>
                        {`${payload[0].value}일`}
                    </Typography>
                </Box>
            );
        }
        return null;
    };

    return (
        <Box sx={{ width: '100%', height: 250, minHeight: 250, minWidth: 0, mt: 2 }}>
            <ResponsiveContainer width="100%" height={250}>
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
                        dataKey="days"
                        radius={[4, 4, 0, 0]}
                        animationDuration={1500}
                        animationEasing="ease-out"
                    >
                        {data.map((entry, index) => (
                            <Cell
                                key={`cell-${index}`}
                                fill={entry.days > 0 ? '#667EEA' : isDarkTheme ? '#3A3A3A' : '#F3F4F6'}
                            />
                        ))}
                    </Bar>
                </BarChart>
            </ResponsiveContainer>
        </Box>
    );
};

export default MonthlyDistributionChart;
