import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    IconButton,
    Card,
    CardContent,
    Grid,
    Chip,
    Divider,
    Button,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    CircularProgress,
    Fade,
} from '@mui/material';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import RefreshIcon from '@mui/icons-material/Refresh';
import AssignmentIcon from '@mui/icons-material/Assignment';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import PendingIcon from '@mui/icons-material/Pending';
import CancelIcon from '@mui/icons-material/Cancel';
import AttachFileIcon from '@mui/icons-material/AttachFile';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';

import leaveService from '../services/leaveService';
import authService from '../services/authService';
import type { LeaveGrantRequestItem } from '../types/leave';
import { useThemeStore } from '../store/themeStore';

const LeaveGrantHistoryPage: React.FC = () => {
    const navigate = useNavigate();
    const { colorScheme } = useThemeStore();
    const isDark = colorScheme.name === 'Dark';

    const [loading, setLoading] = useState(true);
    const [history, setHistory] = useState<LeaveGrantRequestItem[]>([]);
    const [selectedItem, setSelectedItem] = useState<LeaveGrantRequestItem | null>(null);
    const [stats, setStats] = useState({
        total: 0,
        pending: 0,
        managerGranted: 0,
        approved: 0,
    });

    const fetchHistory = useCallback(async () => {
        setLoading(true);
        try {
            const user = authService.getCurrentUser();
            if (!user) return;

            const response = await leaveService.getGrantRequestList(user.userId);
            const data = response.leaveGrants || [];
            setHistory(data);

            setStats({
                total: data.length,
                pending: data.filter((item: any) => item.status === 'REQUESTED').length,
                managerGranted: data.filter((item: any) => item.isManager === 1).length,
                approved: data.filter((item: any) => item.status === 'APPROVED').length,
            });
        } catch (error) {
            console.error('Failed to fetch history:', error);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchHistory();
    }, [fetchHistory]);

    const getStatusInfo = (status: string) => {
        switch (status) {
            case 'APPROVED':
                return { label: '승인됨', color: '#4CAF50', icon: <CheckCircleIcon sx={{ fontSize: 16 }} /> };
            case 'REQUESTED':
                return { label: '대기중', color: '#2196F3', icon: <PendingIcon sx={{ fontSize: 16 }} /> };
            case 'REJECTED':
                return { label: '반려됨', color: '#F44336', icon: <CancelIcon sx={{ fontSize: 16 }} /> };
            default:
                return { label: status, color: '#9E9E9E', icon: null };
        }
    };

    const StatCard = ({ title, count, color, icon: Icon }: any) => (
        <Card
            elevation={0}
            sx={{
                bgcolor: isDark ? 'rgba(255, 255, 255, 0.03)' : 'white',
                border: `1px solid ${isDark ? '#3A3A3A' : '#E9ECEF'}`,
                borderRadius: '16px',
                transition: 'transform 0.2s',
                '&:hover': { transform: 'translateY(-4px)' },
            }}
        >
            <CardContent sx={{ p: '20px !important' }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
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
                        <Icon />
                    </Box>
                    <Typography variant="h5" sx={{ fontWeight: 800, color: colorScheme.textColor }}>
                        {count}
                    </Typography>
                </Box>
                <Typography variant="body2" sx={{ color: isDark ? '#9CA3AF' : '#6B7280', fontWeight: 600 }}>
                    {title}
                </Typography>
            </CardContent>
        </Card>
    );

    return (
        <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', bgcolor: colorScheme.backgroundColor, height: '100vh', overflow: 'hidden' }}>
            <Box
                sx={{
                    height: 64,
                    display: 'flex',
                    alignItems: 'center',
                    px: 2,
                    bgcolor: colorScheme.surfaceColor,
                    borderBottom: `1px solid ${colorScheme.textFieldBorderColor}`,
                    zIndex: 10,
                }}
            >
                <IconButton onClick={() => navigate(-1)} sx={{ mr: 1, color: colorScheme.textColor }}>
                    <ArrowBackIcon />
                </IconButton>
                <Typography variant="h6" sx={{ fontWeight: 700, flex: 1, color: colorScheme.textColor }}>
                    휴가 부여 내역
                </Typography>
                <IconButton onClick={fetchHistory} sx={{ color: colorScheme.textColor }}>
                    <RefreshIcon />
                </IconButton>
            </Box>

            <Box sx={{ flex: 1, overflowY: 'auto', p: 3 }}>
                <Box sx={{ maxWidth: 1200, mx: 'auto' }}>
                    <Grid container spacing={2} sx={{ mb: 4 }}>
                        <Grid xs={6} sm={3}>
                            <StatCard title="전체 내역" count={stats.total} color="#667EEA" icon={AssignmentIcon} />
                        </Grid>
                        <Grid xs={6} sm={3}>
                            <StatCard title="승인 대기" count={stats.pending} color="#2196F3" icon={PendingIcon} />
                        </Grid>
                        <Grid xs={6} sm={3}>
                            <StatCard title="관리자 부여" count={stats.managerGranted} color="#7C3AED" icon={CheckCircleIcon} />
                        </Grid>
                        <Grid xs={6} sm={3}>
                            <StatCard title="최종 승인" count={stats.approved} color="#4CAF50" icon={CheckCircleIcon} />
                        </Grid>
                    </Grid>

                    <Typography variant="subtitle1" sx={{ fontWeight: 700, mb: 2, color: colorScheme.textColor, display: 'flex', alignItems: 'center', gap: 1 }}>
                        부여 기록 목록
                        <Chip label={`${history.length}건`} size="small" sx={{ height: 20, fontSize: '11px', bgcolor: `${colorScheme.primaryColor}20`, color: colorScheme.primaryColor, fontWeight: 700 }} />
                    </Typography>

                    {loading ? (
                        <Box sx={{ display: 'flex', justifyContent: 'center', py: 10 }}>
                            <CircularProgress size={40} sx={{ color: colorScheme.primaryColor }} />
                        </Box>
                    ) : history.length === 0 ? (
                        <Box sx={{ textAlign: 'center', py: 10, bgcolor: isDark ? 'rgba(255, 255, 255, 0.02)' : '#F9FAFB', borderRadius: '24px', border: `2px dashed ${isDark ? '#333' : '#E5E7EB'}` }}>
                            <AssignmentIcon sx={{ fontSize: 64, color: isDark ? '#333' : '#E5E7EB', mb: 2 }} />
                            <Typography sx={{ color: isDark ? '#666' : '#9CA3AF', fontWeight: 500 }}>
                                휴가 부여 내역이 없습니다.
                            </Typography>
                        </Box>
                    ) : (
                        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                            {history.map((item, index) => {
                                const status = getStatusInfo(item.status);
                                return (
                                    <Fade in timeout={300 + index * 50} key={item.id}>
                                        <Card
                                            onClick={() => setSelectedItem(item)}
                                            sx={{
                                                borderRadius: '16px',
                                                cursor: 'pointer',
                                                bgcolor: isDark ? 'rgba(255, 255, 255, 0.03)' : 'white',
                                                border: `1px solid ${isDark ? '#3A3A3A' : '#E9ECEF'}`,
                                                transition: 'all 0.2s',
                                                '&:hover': {
                                                    borderColor: colorScheme.primaryColor,
                                                    boxShadow: `0 8px 16px ${colorScheme.primaryColor}15`,
                                                },
                                            }}
                                        >
                                            <CardContent sx={{ p: 2.5 }}>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 1.5 }}>
                                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                        <Box
                                                            sx={{
                                                                px: 1.2,
                                                                py: 0.4,
                                                                borderRadius: '8px',
                                                                bgcolor: `${status.color}15`,
                                                                color: status.color,
                                                                display: 'flex',
                                                                alignItems: 'center',
                                                                gap: 0.5,
                                                            }}
                                                        >
                                                            {status.icon}
                                                            <Typography variant="caption" sx={{ fontWeight: 800 }}>
                                                                {status.label}
                                                            </Typography>
                                                        </Box>
                                                        {item.isManager === 1 && (
                                                            <Chip
                                                                label="관리자 부여"
                                                                size="small"
                                                                sx={{ height: 22, fontSize: '10px', bgcolor: '#7C3AED15', color: '#7C3AED', fontWeight: 700, borderRadius: '6px' }}
                                                            />
                                                        )}
                                                    </Box>
                                                    <Typography variant="caption" sx={{ color: isDark ? '#666' : '#9CA3AF' }}>
                                                        {dayjs(item.procDate || item.approvalDate).format('YYYY.MM.DD')}
                                                    </Typography>
                                                </Box>

                                                <Typography variant="subtitle1" sx={{ fontWeight: 700, mb: 0.5, color: colorScheme.textColor }}>
                                                    {item.title}
                                                </Typography>

                                                <Typography
                                                    variant="body2"
                                                    sx={{
                                                        color: isDark ? '#9CA3AF' : '#6B7280',
                                                        mb: 2,
                                                        display: '-webkit-box',
                                                        WebkitLineClamp: 1,
                                                        WebkitBoxOrient: 'vertical',
                                                        overflow: 'hidden',
                                                    }}
                                                >
                                                    {item.reason}
                                                </Typography>

                                                <Divider sx={{ mb: 2, opacity: 0.5 }} />

                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                        <Typography variant="body2" sx={{ fontWeight: 700, color: colorScheme.primaryColor }}>
                                                            {item.leaveType}
                                                        </Typography>
                                                        <Typography sx={{ fontSize: '14px', fontWeight: 800, color: colorScheme.textColor }}>
                                                            {item.grantDays}일
                                                        </Typography>
                                                    </Box>

                                                    {item.attachmentsList && item.attachmentsList.length > 0 && (
                                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, color: isDark ? '#666' : '#9CA3AF' }}>
                                                            <AttachFileIcon sx={{ fontSize: 16 }} />
                                                            <Typography variant="caption" sx={{ fontWeight: 600 }}>
                                                                {item.attachmentsList.length}
                                                            </Typography>
                                                        </Box>
                                                    )}
                                                </Box>
                                            </CardContent>
                                        </Card>
                                    </Fade>
                                );
                            })}
                        </Box>
                    )}
                </Box>
            </Box>

            <Dialog
                open={!!selectedItem}
                onClose={() => setSelectedItem(null)}
                maxWidth="sm"
                fullWidth
                PaperProps={{
                    sx: { borderRadius: '24px', bgcolor: colorScheme.surfaceColor, backgroundImage: 'none' }
                }}
            >
                {selectedItem && (
                    <>
                        <DialogTitle sx={{ p: 3, pb: 1, fontWeight: 800, color: colorScheme.textColor }}>
                            부여 정보 상세
                        </DialogTitle>
                        <DialogContent sx={{ p: 3, pt: 1 }}>
                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, mt: 2 }}>
                                <Box>
                                    <Typography variant="caption" display="block" sx={{ color: isDark ? '#666' : '#9CA3AF', mb: 0.5, fontWeight: 700 }}>
                                        상태
                                    </Typography>
                                    <Box sx={{ display: 'flex', gap: 1 }}>
                                        <Chip
                                            label={getStatusInfo(selectedItem.status).label}
                                            size="small"
                                            sx={{
                                                bgcolor: `${getStatusInfo(selectedItem.status).color}15`,
                                                color: getStatusInfo(selectedItem.status).color,
                                                fontWeight: 700,
                                                borderRadius: '8px'
                                            }}
                                        />
                                        {selectedItem.isManager === 1 && (
                                            <Chip label="관리자 부여" size="small" sx={{ bgcolor: '#7C3AED15', color: '#7C3AED', fontWeight: 700, borderRadius: '8px' }} />
                                        )}
                                    </Box>
                                </Box>

                                <Box>
                                    <Typography variant="caption" display="block" sx={{ color: isDark ? '#666' : '#9CA3AF', mb: 0.5, fontWeight: 700 }}>
                                        제목
                                    </Typography>
                                    <Typography variant="body1" sx={{ fontWeight: 700, color: colorScheme.textColor }}>
                                        {selectedItem.title}
                                    </Typography>
                                </Box>

                                <Box sx={{ display: 'flex', gap: 4 }}>
                                    <Box sx={{ flex: 1 }}>
                                        <Typography variant="caption" display="block" sx={{ color: isDark ? '#666' : '#9CA3AF', mb: 0.5, fontWeight: 700 }}>
                                            휴가 종류
                                        </Typography>
                                        <Typography variant="body1" sx={{ fontWeight: 700, color: colorScheme.textColor }}>
                                            {selectedItem.leaveType}
                                        </Typography>
                                    </Box>
                                    <Box sx={{ flex: 1 }}>
                                        <Typography variant="caption" display="block" sx={{ color: isDark ? '#666' : '#9CA3AF', mb: 0.5, fontWeight: 700 }}>
                                            부여 일수
                                        </Typography>
                                        <Typography variant="body1" sx={{ fontWeight: 800, color: colorScheme.textColor }}>
                                            {selectedItem.grantDays}일
                                        </Typography>
                                    </Box>
                                </Box>

                                <Box>
                                    <Typography variant="caption" display="block" sx={{ color: isDark ? '#666' : '#9CA3AF', mb: 0.5, fontWeight: 700 }}>
                                        상세 사유
                                    </Typography>
                                    <Box sx={{ p: 2, bgcolor: isDark ? 'rgba(255, 255, 255, 0.02)' : '#F8F9FA', borderRadius: '12px', border: `1px solid ${isDark ? '#333' : '#E9ECEF'}` }}>
                                        <Typography variant="body2" sx={{ color: colorScheme.textColor, whiteSpace: 'pre-wrap', lineHeight: 1.6 }}>
                                            {selectedItem.reason}
                                        </Typography>
                                    </Box>
                                </Box>

                                {selectedItem.comment && (
                                    <Box>
                                        <Typography variant="caption" display="block" sx={{ color: isDark ? '#666' : '#9CA3AF', mb: 0.5, fontWeight: 700 }}>
                                            결재 코멘트
                                        </Typography>
                                        <Box sx={{ p: 2, bgcolor: isDark ? 'rgba(76, 175, 80, 0.05)' : '#F6FEF8', borderRadius: '12px', border: `1px solid ${isDark ? 'rgba(76, 175, 80, 0.2)' : '#E8F5E9'}` }}>
                                            <Typography variant="body2" sx={{ color: colorScheme.textColor, fontStyle: 'italic' }}>
                                                "{selectedItem.comment}"
                                            </Typography>
                                        </Box>
                                    </Box>
                                )}

                                {selectedItem.attachmentsList && selectedItem.attachmentsList.length > 0 && (
                                    <Box>
                                        <Typography variant="caption" display="block" sx={{ color: isDark ? '#666' : '#9CA3AF', mb: 1, fontWeight: 700 }}>
                                            첨부파일 ({selectedItem.attachmentsList.length})
                                        </Typography>
                                        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                                            {selectedItem.attachmentsList.map((file, i) => (
                                                <Box
                                                    key={i}
                                                    sx={{
                                                        p: 1.5,
                                                        borderRadius: '12px',
                                                        border: `1px solid ${isDark ? '#333' : '#E9ECEF'}`,
                                                        display: 'flex',
                                                        alignItems: 'center',
                                                        gap: 1.5,
                                                        cursor: 'pointer',
                                                        '&:hover': { bgcolor: isDark ? 'rgba(255, 255, 255, 0.02)' : '#F8F9FA' }
                                                    }}
                                                >
                                                    <AttachFileIcon sx={{ color: isDark ? '#666' : '#9CA3AF', fontSize: 20 }} />
                                                    <Typography variant="body2" sx={{ flex: 1, color: colorScheme.textColor, fontWeight: 600 }}>
                                                        {file.name || `첨부파일_${i + 1}`}
                                                    </Typography>
                                                </Box>
                                            ))}
                                        </Box>
                                    </Box>
                                )}
                            </Box>
                        </DialogContent>
                        <DialogActions sx={{ p: 3, pt: 1 }}>
                            <Button
                                fullWidth
                                variant="contained"
                                onClick={() => setSelectedItem(null)}
                                sx={{
                                    py: 1.5,
                                    borderRadius: '14px',
                                    bgcolor: colorScheme.primaryColor,
                                    fontWeight: 700,
                                    boxShadow: `0 4px 12px ${colorScheme.primaryColor}30`,
                                    '&:hover': { bgcolor: colorScheme.primaryColor, opacity: 0.9 }
                                }}
                            >
                                닫기
                            </Button>
                        </DialogActions>
                    </>
                )}
            </Dialog>
        </Box>
    );
};

export default LeaveGrantHistoryPage;
