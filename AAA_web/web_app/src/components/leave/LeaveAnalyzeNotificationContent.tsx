import React, { useMemo } from 'react';
import { Box, Typography } from '@mui/material';
import AutoAwesomeIcon from '@mui/icons-material/AutoAwesome';
import InsertChartOutlinedIcon from '@mui/icons-material/InsertChartOutlined';
import DateRangeIcon from '@mui/icons-material/DateRange';
import BeachAccessIcon from '@mui/icons-material/BeachAccess';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';

import MonthlyDistributionChart from './charts/MonthlyDistributionChart';
import WeekdayDistributionChart from './charts/WeekdayDistributionChart';
import HolidayAdjacentUsageChart from './charts/HolidayAdjacentUsageChart';
import VacationCalendarGrid from './VacationCalendarGrid';
import { parseLeaveAnalyzeMessage } from '../../utils/leaveAnalyzeParser';

interface LeaveAnalyzeNotificationContentProps {
  message: string;
  isDark: boolean;
}

const LeaveAnalyzeNotificationContent: React.FC<LeaveAnalyzeNotificationContentProps> = ({
  message,
  isDark,
}) => {
  const parsed = useMemo(() => parseLeaveAnalyzeMessage(message), [message]);

  const sanitizeMarkdown = (content: string) => {
    if (!content) return '';
    let sanitized = content;

    sanitized = sanitized.replace(/\\n/g, '\n');
    sanitized = sanitized.replace(/~~/g, '~');

    sanitized = sanitized.replace(/```json[\s\S]*?```/g, '');
    sanitized = sanitized.replace(/\b(short|long)\s*\{[^{}]*"weekday_counts"[^}]*\}[^}]*\}/gi, '');
    sanitized = sanitized.replace(/\{[^{}]*"weekday_counts"[^}]*\}[^}]*\}?/g, '');
    sanitized = sanitized.replace(/\{[^{}]*"holiday_adjacent[^}]*\}[^}]*\}?/g, '');
    sanitized = sanitized.replace(/\{[^{}]*"total_leave_days"[^}]*\}[^}]*\}?/g, '');
    sanitized = sanitized.replace(/\{[^{}]*"leaves"[^}]*\}[^}]*\}?/g, '');

    const filtered = sanitized
      .split('\n')
      .filter((line) => {
        const lowered = line.toLowerCase();
        return !(
          lowered.includes('weekday_counts') ||
          lowered.includes('holiday_adjacent') ||
          lowered.includes('total_leave_days') ||
          lowered.includes('"leaves"') ||
          lowered.includes('"mon"') ||
          lowered.includes('"tue"') ||
          lowered.includes('"wed"') ||
          lowered.includes('"thu"') ||
          lowered.includes('"fri"') ||
          lowered.includes('"sat"') ||
          lowered.includes('"sun"')
        );
      })
      .join('\n');

    return filtered.replace(/\n{3,}/g, '\n\n').trim();
  };

  const normalizeLineBreaks = (content: string) => {
    if (!content) return '';
    const parts = content.split('```');
    return parts
      .map((part, index) => {
        if (index % 2 === 1) return part;
        return part.replace(/\n/g, '  \n');
      })
      .join('```');
  };

  const markdownComponents = {
    p: ({ children }: any) => (
      <Typography variant="body2" sx={{ mb: 1.5, lineHeight: 1.7, color: isDark ? '#D1D5DB' : '#4B5563' }}>
        {children}
      </Typography>
    ),
    del: ({ children }: any) => <span>{children}</span>,
    table: ({ children }: any) => (
      <Box
        sx={{
          overflowX: 'auto',
          mb: 2,
          borderRadius: '12px',
          border: `1px solid ${isDark ? '#374151' : '#E5E7EB'}`,
        }}
      >
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>{children}</table>
      </Box>
    ),
    thead: ({ children }: any) => (
      <thead style={{ backgroundColor: isDark ? '#111827' : '#F9FAFB' }}>{children}</thead>
    ),
    tbody: ({ children }: any) => <tbody>{children}</tbody>,
    tr: ({ children }: any) => (
      <tr style={{ borderBottom: `1px solid ${isDark ? '#1F2937' : '#E5E7EB'}` }}>{children}</tr>
    ),
    th: ({ children }: any) => (
      <th
        style={{
          textAlign: 'left',
          padding: '10px 12px',
          fontSize: '0.85rem',
          fontWeight: 700,
          color: isDark ? '#E5E7EB' : '#374151',
        }}
      >
        {children}
      </th>
    ),
    td: ({ children }: any) => (
      <td
        style={{
          padding: '10px 12px',
          fontSize: '0.85rem',
          color: isDark ? '#D1D5DB' : '#4B5563',
        }}
      >
        {children}
      </td>
    ),
  };

  const SectionTitle = ({ icon: Icon, title, color }: any) => (
    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2, mt: 3 }}>
      <Box
        sx={{
          width: 36,
          height: 36,
          borderRadius: '10px',
          bgcolor: `${color}15`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: color,
        }}
      >
        <Icon sx={{ fontSize: 20 }} />
      </Box>
      <Typography variant="h6" sx={{ fontWeight: 700, fontSize: '1.05rem' }}>
        {title}
      </Typography>
    </Box>
  );

  const GradientCard = ({ children, padding = 3 }: any) => (
    <Box
      sx={{
        bgcolor: isDark ? 'rgba(255, 255, 255, 0.03)' : '#F9FBFF',
        borderRadius: '16px',
        border: `1px solid ${isDark ? '#3A3A3A' : '#E9ECEF'}`,
        p: padding,
        mb: 3,
      }}
    >
      {children}
    </Box>
  );

  const markdown = normalizeLineBreaks(sanitizeMarkdown(message));

  return (
    <Box>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2 }}>
        <AutoAwesomeIcon sx={{ color: 'primary.main' }} />
        <Typography variant="h6" sx={{ fontWeight: 700 }}>
          AI 휴가 추천 분석 결과
        </Typography>
      </Box>

      {parsed.leavesData && (
        <Box>
          <SectionTitle icon={InsertChartOutlinedIcon} title="📈 과거 휴가 사용 내역" color="#667EEA" />
          <GradientCard>
            <MonthlyDistributionChart monthlyData={parsed.leavesData.monthlyUsage} isDarkTheme={isDark} />
          </GradientCard>
        </Box>
      )}

      {parsed.weekdayCountsData && (
        <Box>
          <SectionTitle icon={InsertChartOutlinedIcon} title="📅 요일별 연차 사용량" color="#10B981" />
          <GradientCard>
            <WeekdayDistributionChart weekdayData={parsed.weekdayCountsData.counts} isDarkTheme={isDark} />
          </GradientCard>
        </Box>
      )}

      {parsed.holidayAdjacentUsageRate !== undefined && (
        <Box>
          <SectionTitle icon={InsertChartOutlinedIcon} title="🎯 공휴일 인접 사용률" color="#F59E0B" />
          <GradientCard padding={2}>
            <HolidayAdjacentUsageChart usageRate={parsed.holidayAdjacentUsageRate} isDarkTheme={isDark} />
          </GradientCard>
        </Box>
      )}

      <SectionTitle icon={AutoAwesomeIcon} title="✨ AI 추천 계획 상세" color="#667EEA" />
      <Box
        sx={{
          p: 3,
          bgcolor: isDark ? 'rgba(102, 126, 234, 0.05)' : '#F5F7FF',
          borderRadius: '16px',
          border: `1px solid ${isDark ? 'rgba(102, 126, 234, 0.2)' : '#E0E7FF'}`,
          '& .markdown-body': {
            color: isDark ? '#D1D5DB' : '#374151',
            fontSize: '0.9rem',
            lineHeight: 1.7,
          },
        }}
      >
        <ReactMarkdown remarkPlugins={[remarkGfm]} components={markdownComponents}>
          {markdown}
        </ReactMarkdown>
      </Box>

      {Object.keys(parsed.monthlyDistribution).length > 0 && (
        <Box>
          <SectionTitle icon={InsertChartOutlinedIcon} title="📈 월별 연차 사용 분포" color="#6366F1" />
          <GradientCard>
            <MonthlyDistributionChart monthlyData={parsed.monthlyDistribution} isDarkTheme={isDark} />
          </GradientCard>
        </Box>
      )}

      {parsed.recommendedDates.length > 0 && (
        <Box>
          <SectionTitle icon={DateRangeIcon} title="🗓️ 추천 휴가 날짜 캘린더" color="#7C3AED" />
          <GradientCard>
            <VacationCalendarGrid recommendedDates={parsed.recommendedDates} isDarkTheme={isDark} />
          </GradientCard>
        </Box>
      )}

      {parsed.consecutivePeriods.length > 0 && (
        <Box sx={{ mb: 4 }}>
          <SectionTitle icon={BeachAccessIcon} title="🏖️ 주요 연속 휴가 기간" color="#EC4899" />
          {parsed.consecutivePeriods.map((period, index) => (
            <Box
              key={`${period.startDate}-${period.endDate}-${index}`}
              sx={{
                p: 2.5,
                mb: 2,
                bgcolor: isDark ? 'rgba(236, 72, 153, 0.05)' : '#FFF1F2',
                borderRadius: '16px',
                border: `1px solid ${isDark ? 'rgba(236, 72, 153, 0.2)' : '#FFE4E6'}`,
                display: 'flex',
                gap: 2,
                alignItems: 'flex-start',
              }}
            >
              <Box sx={{ color: '#EC4899', mt: 0.5 }}>
                <DateRangeIcon />
              </Box>
              <Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1, flexWrap: 'wrap' }}>
                  <Typography variant="subtitle2" sx={{ fontWeight: 800 }}>
                    {`${period.startDate} ~ ${period.endDate}`}
                  </Typography>
                  <Box sx={{ px: 1, py: 0.2, bgcolor: '#EC4899', color: 'white', borderRadius: '6px', fontSize: '0.7rem', fontWeight: 700 }}>
                    {`${period.days}일`}
                  </Box>
                </Box>
                <Typography variant="body2" sx={{ color: isDark ? '#9CA3AF' : '#6B7280', fontSize: '0.85rem' }}>
                  {period.description}
                </Typography>
              </Box>
            </Box>
          ))}
        </Box>
      )}
    </Box>
  );
};

export default LeaveAnalyzeNotificationContent;
