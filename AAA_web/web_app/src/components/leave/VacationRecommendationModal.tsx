import React, { useState, useEffect, useRef } from 'react';
import {
    Dialog,
    Box,
    Typography,
    IconButton,
    LinearProgress,
    Divider,
    Button,
    useTheme,
    Fade,
} from '@mui/material';
import CloseIcon from '@mui/icons-material/Close';
import AutoAwesomeIcon from '@mui/icons-material/AutoAwesome';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import InsertChartOutlinedIcon from '@mui/icons-material/InsertChartOutlined';
import DateRangeIcon from '@mui/icons-material/DateRange';
import BeachAccessIcon from '@mui/icons-material/BeachAccess';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';

import { fetchVacationRecommendation } from '../../services/vacationRecommendationService';
import type { VacationRecommendationResponse } from '../../types/leave';
import MonthlyDistributionChart from './charts/MonthlyDistributionChart';
import WeekdayDistributionChart from './charts/WeekdayDistributionChart';
import HolidayAdjacentUsageChart from './charts/HolidayAdjacentUsageChart';
import VacationCalendarGrid from './VacationCalendarGrid';

interface VacationRecommendationModalProps {
    open: boolean;
    onClose: () => void;
    userId: string;
    year: number;
}

const VacationRecommendationModal: React.FC<VacationRecommendationModalProps> = ({
    open,
    onClose,
    userId,
    year,
}) => {
    const theme = useTheme();
    const isDark = theme.palette.mode === 'dark';
    const scrollRef = useRef<HTMLDivElement>(null);

    const [state, setState] = useState<VacationRecommendationResponse>({
        reasoningContents: '',
        finalResponseContents: '',
        recommendedDates: [],
        monthlyDistribution: {},
        consecutivePeriods: [],
        isComplete: false,
        streamingProgress: 0,
    });

    const [error, setError] = useState<string | null>(null);

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

    useEffect(() => {
        if (open && userId) {
            startRecommendation();
        }
    }, [open, userId, year]);

    useEffect(() => {
        if (scrollRef.current && !state.isComplete) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
        }
    }, [state.reasoningContents, state.markdownBuffer]);

    const startRecommendation = async () => {
        setError(null);
        setState({
            reasoningContents: '',
            finalResponseContents: '',
            recommendedDates: [],
            monthlyDistribution: {},
            consecutivePeriods: [],
            isComplete: false,
            streamingProgress: 0,
        });

        try {
            const generator = fetchVacationRecommendation(userId, year);
            for await (const update of generator) {
                setState(update);
            }
        } catch (err: any) {
            setError(err.message || '추천 데이터를 가져오는 중 에러가 발생했습니다.');
        }
    };

    const SectionTitle = ({ icon: Icon, title, color }: any) => (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 2, mt: 4 }}>
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
            <Typography variant="h6" sx={{ fontWeight: 700, fontSize: '1.1rem' }}>
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

    return (
        <Dialog
            open={open}
            onClose={state.isComplete || error ? onClose : undefined}
            maxWidth="md"
            fullWidth
            PaperProps={{
                sx: {
                    borderRadius: '24px',
                    bgcolor: isDark ? '#1F1F1F' : 'white',
                    backgroundImage: isDark ? 'linear-gradient(rgba(255, 255, 255, 0.02), rgba(255, 255, 255, 0.02))' : 'none',
                    maxHeight: '90vh',
                    boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
                },
            }}
        >
            <Box sx={{ p: 4, pb: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                    <Box
                        sx={{
                            width: 48,
                            height: 48,
                            borderRadius: '14px',
                            background: 'linear-gradient(135deg, #667EEA 0%, #764BA2 100%)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            color: 'white',
                            boxShadow: '0 4px 12px rgba(102, 126, 234, 0.3)',
                        }}
                    >
                        <AutoAwesomeIcon />
                    </Box>
                    <Box>
                        <Typography variant="h5" sx={{ fontWeight: 800, background: 'linear-gradient(135deg, #667EEA 0%, #764BA2 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
                            내 휴가계획 AI 추천
                        </Typography>
                        <Typography variant="body2" sx={{ color: isDark ? '#9CA3AF' : '#6B7280', fontWeight: 500 }}>
                            {year}년 AI 연차 사용 계획 제안
                        </Typography>
                    </Box>
                </Box>
                <IconButton onClick={onClose} sx={{ color: isDark ? '#9CA3AF' : '#6B7280' }}>
                    <CloseIcon />
                </IconButton>
            </Box>

            <Divider sx={{ mx: 4, opacity: isDark ? 0.1 : 0.5 }} />

            {!state.isComplete && !error && (
                <Box sx={{ px: 4, mt: 3, mb: 1 }}>
                    <LinearProgress
                        variant="determinate"
                        value={state.streamingProgress * 100}
                        sx={{
                            height: 8,
                            borderRadius: 4,
                            bgcolor: isDark ? '#333' : '#F3F4F6',
                            '& .MuiLinearProgress-bar': {
                                background: 'linear-gradient(90deg, #667EEA 0%, #764BA2 100%)',
                                borderRadius: 4,
                            },
                        }}
                    />
                </Box>
            )}

            <Box
                ref={scrollRef}
                sx={{
                    p: 4,
                    pt: 2,
                    overflowY: 'auto',
                    display: 'flex',
                    flexDirection: 'column',
                    gap: 1,
                }}
            >
                {error ? (
                    <Box sx={{ textAlign: 'center', py: 8 }}>
                        <Typography color="error" variant="h6" gutterBottom>
                            추천 로드 실패
                        </Typography>
                        <Typography sx={{ color: isDark ? '#9CA3AF' : '#6B7280', mb: 3 }}>
                            {error}
                        </Typography>
                        <Button variant="outlined" onClick={startRecommendation}>
                            다시 시도
                        </Button>
                    </Box>
                ) : (
                    <Box>
                        {state.reasoningContents && (
                            <Fade in timeout={800}>
                                <Box>
                                    <SectionTitle icon={TrendingUpIcon} title="📊 분석 과정" color="#3B82F6" />
                                    <Typography
                                        variant="body2"
                                        sx={{
                                            whiteSpace: 'pre-wrap',
                                            color: isDark ? '#D1D5DB' : '#374151',
                                            lineHeight: 1.8,
                                            fontFamily: 'monospace',
                                            bgcolor: isDark ? '#2D2D2D' : '#F8F9FA',
                                            p: 3,
                                            borderRadius: '16px',
                                            border: `1px solid ${isDark ? '#444' : '#E5E7EB'}`,
                                        }}
                                    >
                                        {state.reasoningContents}
                                    </Typography>
                                </Box>
                            </Fade>
                        )}

                        {state.leavesData && (
                            <Fade in timeout={1200}>
                                <Box>
                                    <SectionTitle icon={InsertChartOutlinedIcon} title="📈 과거 휴가 사용 내역" color="#667EEA" />
                                    <GradientCard>
                                        <MonthlyDistributionChart monthlyData={state.leavesData.monthlyUsage} isDarkTheme={isDark} />
                                    </GradientCard>
                                </Box>
                            </Fade>
                        )}

                        {state.markdownBuffer && !state.isComplete && (
                            <Fade in timeout={500}>
                                <Box>
                                    <SectionTitle icon={AutoAwesomeIcon} title="💡 AI 분석 결과" color="#764BA2" />
                                    <Box sx={{ px: 1 }}>
                                        <ReactMarkdown
                                            remarkPlugins={[remarkGfm]}
                                            components={markdownComponents}
                                        >
                                            {normalizeLineBreaks(sanitizeMarkdown(state.markdownBuffer))}
                                        </ReactMarkdown>
                                    </Box>
                                </Box>
                            </Fade>
                        )}

                        {state.isComplete && (
                            <Fade in timeout={1000}>
                                <Box>
                                    {state.weekdayCountsData && (
                                        <Box>
                                            <SectionTitle icon={InsertChartOutlinedIcon} title="📅 요일별 연차 사용량" color="#10B981" />
                                            <GradientCard>
                                                <WeekdayDistributionChart weekdayData={state.weekdayCountsData.counts} isDarkTheme={isDark} />
                                            </GradientCard>
                                        </Box>
                                    )}

                                    {state.holidayAdjacentUsageRate !== undefined && (
                                        <Box>
                                            <SectionTitle icon={InsertChartOutlinedIcon} title="🎯 공휴일 인접 사용률" color="#F59E0B" />
                                            <GradientCard padding={2}>
                                                <HolidayAdjacentUsageChart usageRate={state.holidayAdjacentUsageRate} isDarkTheme={isDark} />
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
                                            {normalizeLineBreaks(sanitizeMarkdown(state.finalResponseContents))}
                                        </ReactMarkdown>
                                    </Box>

                                    {Object.keys(state.monthlyDistribution).length > 0 && (
                                        <Box>
                                            <SectionTitle icon={InsertChartOutlinedIcon} title="📈 월별 연차 사용 분포" color="#6366F1" />
                                            <GradientCard>
                                                <MonthlyDistributionChart monthlyData={state.monthlyDistribution} isDarkTheme={isDark} />
                                            </GradientCard>
                                        </Box>
                                    )}

                                    {state.recommendedDates.length > 0 && (
                                        <Box>
                                            <SectionTitle icon={DateRangeIcon} title="🗓️ 추천 휴가 날짜 캘린더" color="#7C3AED" />
                                            <GradientCard>
                                                <VacationCalendarGrid recommendedDates={state.recommendedDates} isDarkTheme={isDark} />
                                            </GradientCard>
                                        </Box>
                                    )}

                                    {state.consecutivePeriods.length > 0 && (
                                        <Box sx={{ mb: 4 }}>
                                            <SectionTitle icon={BeachAccessIcon} title="🏖️ 주요 연속 휴가 기간" color="#EC4899" />
                                            {state.consecutivePeriods.map((period, index) => (
                                                <Box
                                                    key={index}
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
                                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1 }}>
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
                            </Fade>
                        )}
                    </Box>
                )}
            </Box>

            <Box sx={{ p: 4, pt: 2, textAlign: 'center' }}>
                <Button
                    variant="contained"
                    onClick={onClose}
                    sx={{
                        py: 1.5,
                        px: 6,
                        borderRadius: '14px',
                        background: 'linear-gradient(135deg, #667EEA 0%, #764BA2 100%)',
                        boxShadow: '0 4px 12px rgba(102, 126, 234, 0.3)',
                        color: 'white',
                        fontWeight: 700,
                        '&:hover': {
                            background: 'linear-gradient(135deg, #5A72E0 0%, #6E4496 100%)',
                            boxShadow: '0 6px 16px rgba(102, 126, 234, 0.4)',
                        },
                    }}
                >
                    {state.isComplete ? '확인 및 닫기' : '분석 중...'}
                </Button>
            </Box>
        </Dialog>
    );
};

export default VacationRecommendationModal;
