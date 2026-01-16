import { useEffect, useMemo, useState } from 'react';
import {
  Box,
  Typography,
  IconButton,
  Button,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Divider,
  CircularProgress,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  useMediaQuery,
  Slide,
  Snackbar,
  Alert,
} from '@mui/material';
import { useTheme } from '@mui/material/styles';
import {
  Close as CloseIcon,
  HowToReg as HowToRegIcon,
  FormatListNumbered as FormatListNumberedIcon,
  Save as SaveIcon,
  AttachFile as AttachFileIcon,
  OpenInFull as OpenInFullIcon,
  Description as DescriptionIcon,
  PersonAddOutlined as PersonAddOutlinedIcon,
  CloudDone as CloudDoneIcon,
  FolderOpen as FolderOpenIcon,
  Add as AddIcon,
  PictureAsPdf as PictureAsPdfIcon,
  TableChart as TableChartIcon,
  TextSnippet as TextSnippetIcon,
  InsertDriveFile as InsertDriveFileIcon,
  Image as ImageIcon,
} from '@mui/icons-material';
import authService from '../../services/authService';
import leaveService from '../../services/leaveService';
import departmentService from '../../services/departmentService';
import { useThemeStore } from '../../store/themeStore';
import { useElectronicApprovalStore } from '../../store/electronicApprovalStore';
import ApproverSelectionModal from '../leave/ApproverSelectionModal';
import ReferenceSelectionModal from '../leave/ReferenceSelectionModal';
import type { EApprovalAttachment, EApprovalDraftData, EApprovalCcPerson } from '../../types/eapproval';
import { LIMIT_APPROVAL_TYPE } from '../../config/env.config';

const APPROVAL_TYPES_ALL = [
  '매출/매입계약 기안서',
  '기본양식',
  '구매신청서',
  '교육신청서',
  '경조사비 지급신청서',
  '휴가 부여 상신',
];

const APPROVAL_TYPES_PROD = ['휴가 부여 상신'];

const LEAVE_TYPES = [
  '예비군/민방위 연차',
  '배우자 출산휴가',
  '경조사휴가',
  '산전후휴가',
  '결혼휴가',
  '병가',
];

const CONTRACT_WEB_URL = 'http://210.107.96.193:3001/contract';
const PURCHASE_WEB_URL = 'http://210.107.96.193:3001/purchase';
const DEFAULT_WEB_URL = 'http://210.107.96.193:3001/default';
const PRIMARY_COLOR = '#4A6CF7';
const SUCCESS_COLOR = '#10B981';
const INFO_COLOR = '#20C997';
const MUTED_COLOR = '#8B95A1';
const LIGHT_BORDER = '#E9ECEF';
const DARK_BORDER = '#4A5568';
const LIGHT_SURFACE = '#F8F9FA';
const DARK_SURFACE = '#2D3748';
const DARK_PANEL = '#1A1D1F';
const LIGHT_TEXT = '#1A1D1F';
const MUTED_TEXT = '#6C757D';

const getApprovalTypeLabel = (value?: string) => {
  if (!value) return '';
  if (value === 'hr_leave_grant') return '휴가 부여 상신';
  if (value === '매출/매입 계약 기안서') return '매출/매입계약 기안서';
  return value;
};

const getApprovalTypeValue = (label?: string) => {
  if (!label) return '';
  if (label === '휴가 부여 상신') return 'hr_leave_grant';
  if (label === '매출/매입계약 기안서') return '매출/매입 계약 기안서';
  return label;
};

export default function ElectronicApprovalDraftPanel() {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const { colorScheme } = useThemeStore();
  const isDark = colorScheme.name === 'Dark';
  const user = authService.getCurrentUser();
  const {
    isOpen,
    isLoading,
    pendingData,
    closePanel,
    setLoading,
    clearPendingData,
  } = useElectronicApprovalStore();

  const [approvalType, setApprovalType] = useState('');
  const [draftingDepartment, setDraftingDepartment] = useState('');
  const [isCustomDepartment, setIsCustomDepartment] = useState(false);
  const [departments, setDepartments] = useState<string[]>([]);
  const [retentionPeriod, setRetentionPeriod] = useState('영구');
  const [draftingDate, setDraftingDate] = useState(new Date().toISOString().slice(0, 10));
  const [documentTitle, setDocumentTitle] = useState('');
  const [content, setContent] = useState('');
  const [leaveType, setLeaveType] = useState('');
  const [grantDays, setGrantDays] = useState('');
  const [reason, setReason] = useState('');
  const [approvers, setApprovers] = useState<Array<{
    approverId: string;
    approverName: string;
    approvalSeq: number;
    department?: string;
    jobPosition?: string;
  }>>([]);
  const [ccList, setCcList] = useState<EApprovalCcPerson[]>([]);
  const [attachments, setAttachments] = useState<File[]>([]);
  const [chatAttachments, setChatAttachments] = useState<EApprovalAttachment[]>([]);
  const [isApproverModalOpen, setIsApproverModalOpen] = useState(false);
  const [isReferenceModalOpen, setIsReferenceModalOpen] = useState(false);
  const [isSequentialApproval, setIsSequentialApproval] = useState(false);
  const [webviewOpen, setWebviewOpen] = useState(false);
  const [htmlContent, setHtmlContent] = useState('');
  const [snackbarOpen, setSnackbarOpen] = useState(false);
  const [snackbarMessage, setSnackbarMessage] = useState('');
  const [snackbarSeverity, setSnackbarSeverity] = useState<'success' | 'error'>('success');

  const approvalOptions = LIMIT_APPROVAL_TYPE ? APPROVAL_TYPES_PROD : APPROVAL_TYPES_ALL;

  const webviewUrl = useMemo(() => {
    if (approvalType === '매출/매입계약 기안서') return CONTRACT_WEB_URL;
    if (approvalType === '구매신청서') return PURCHASE_WEB_URL;
    return DEFAULT_WEB_URL;
  }, [approvalType]);

  useEffect(() => {
    if (!isOpen) {
      clearPendingData();
      return;
    }

    const init = async (data?: EApprovalDraftData | null) => {
      setLoading(true);
      try {
        const deptList = await departmentService.getDepartmentList();
        setDepartments(deptList || []);

        const initialApprovalType = getApprovalTypeLabel(data?.approval_type) || approvalOptions[0];
        const resolvedApprovalType = LIMIT_APPROVAL_TYPE && initialApprovalType !== '휴가 부여 상신'
          ? '휴가 부여 상신'
          : initialApprovalType;
        setApprovalType(resolvedApprovalType);
        setDraftingDepartment(data?.department || '');
        setDocumentTitle(data?.title || '');
        setContent(data?.content || '');
        setHtmlContent(data?.html_content || '');
        setLeaveType(data?.leave_type || '');
        setGrantDays(data?.grant_days ? String(data.grant_days) : '');
        setReason(data?.reason || '');
        setChatAttachments(data?.attachments_list || []);

        if (data?.approval_line && data.approval_line.length > 0) {
          setApprovers(
            data.approval_line.map((item, index) => ({
              approverId: item.approver_id || item.approverId || '',
              approverName: item.approver_name || item.approverName || '',
              approvalSeq: item.approval_seq || item.approvalSeq || index + 1,
              department: item.department,
              jobPosition: item.job_position || item.jobPosition,
            }))
          );
        } else if (user?.userId) {
          const saved = await leaveService.loadEApprovalLine(user.userId, 'hr_leave_grant');
          setApprovers(saved.approvalLine || []);
          setCcList(saved.ccList || []);
        }

        if (data?.cc_list && data.cc_list.length > 0) {
          setCcList(data.cc_list);
        }
      } finally {
        setLoading(false);
      }
    };

    init(pendingData);
  }, [isOpen, pendingData, user?.userId, approvalOptions, clearPendingData, setLoading]);

  const handleAttachmentSelect = (files: FileList | null) => {
    if (!files) return;
    setAttachments((prev) => [...prev, ...Array.from(files)]);
  };

  const handleRemoveAttachment = (index: number) => {
    setAttachments((prev) => prev.filter((_, i) => i !== index));
  };

  const handleRemoveChatAttachment = (index: number) => {
    setChatAttachments((prev) => prev.filter((_, i) => i !== index));
  };

  const handleReset = () => {
    setApprovalType(approvalOptions[0] || '');
    setDraftingDepartment('');
    setIsCustomDepartment(false);
    setRetentionPeriod('영구');
    setDraftingDate(new Date().toISOString().slice(0, 10));
    setDocumentTitle('');
    setContent('');
    setLeaveType('');
    setGrantDays('');
    setReason('');
    setApprovers([]);
    setCcList([]);
    setAttachments([]);
    setChatAttachments([]);
    setIsSequentialApproval(false);
    setHtmlContent('');
  };

  const formatSize = (size?: number) => {
    if (!size && size !== 0) return '';
    if (size < 1024) return `${size} B`;
    if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
    return `${(size / (1024 * 1024)).toFixed(1)} MB`;
  };

  const getFileIcon = (fileName: string) => {
    const ext = fileName.split('.').pop()?.toLowerCase();
    if (!ext) return InsertDriveFileIcon;
    if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'].includes(ext)) return ImageIcon;
    if (ext === 'pdf') return PictureAsPdfIcon;
    if (['xls', 'xlsx'].includes(ext)) return TableChartIcon;
    if (['txt'].includes(ext)) return TextSnippetIcon;
    return InsertDriveFileIcon;
  };

  const panelBorderColor = isDark ? DARK_BORDER : LIGHT_BORDER;
  const panelSurface = isDark ? DARK_SURFACE : LIGHT_SURFACE;
  const panelText = isDark ? 'white' : LIGHT_TEXT;
  const subtitleText = isDark ? '#9CA3AF' : '#6B7280';
  const fieldSx = {
    '& .MuiInputLabel-root': {
      color: isDark ? '#A0AEC0' : MUTED_TEXT,
      fontSize: 12,
    },
    '& .MuiOutlinedInput-root': {
      borderRadius: '8px',
      backgroundColor: isDark ? DARK_SURFACE : 'white',
      '& fieldset': {
        borderColor: isDark ? DARK_BORDER : LIGHT_BORDER,
      },
      '&:hover fieldset': {
        borderColor: isDark ? DARK_BORDER : LIGHT_BORDER,
      },
      '&.Mui-focused fieldset': {
        borderColor: PRIMARY_COLOR,
      },
    },
    '& .MuiOutlinedInput-input': {
      padding: '12px',
    },
  };

  if (!isOpen) return null;

  const handleApproverConfirm = (_ids: string[], selectedApprovers: any[]) => {
    const next = selectedApprovers.map((approver, index) => ({
      approverId: approver.approverId,
      approverName: approver.approverName,
      approvalSeq: index + 1,
      department: approver.department,
      jobPosition: approver.jobPosition,
    }));
    setApprovers(next);
    setIsApproverModalOpen(false);
  };

  const handleSaveApprovalLine = async () => {
    if (!user?.userId || approvers.length === 0) return;
    try {
      await leaveService.saveEApprovalLine({
        userId: user.userId,
        approvalType: 'hr_leave_grant',
        approvalLine: approvers.map((item) => ({
          approverId: item.approverId,
          approverName: item.approverName,
          approvalSeq: item.approvalSeq,
          department: item.department,
          jobPosition: item.jobPosition,
        })),
        ccList: ccList.map((item: any) => ({ user_id: item.user_id || item.userId, name: item.name })),
      });
      setSnackbarSeverity('success');
      setSnackbarMessage('결재라인이 저장되었습니다.');
      setSnackbarOpen(true);
    } catch (error: any) {
      setSnackbarSeverity('error');
      setSnackbarMessage(error?.message || '결재라인 저장에 실패했습니다.');
      setSnackbarOpen(true);
    }
  };

  const handleSubmit = async () => {
    if (!draftingDepartment.trim() || !approvalType) {
      alert('기안부서와 결재 종류를 입력해주세요.');
      return;
    }
    if (!documentTitle.trim()) {
      alert('제목을 입력해주세요.');
      return;
    }
    if (approvers.length === 0) {
      alert('승인자를 선택해주세요.');
      return;
    }

    const confirmed = window.confirm('전자결재를 상신하시겠습니까?');
    if (!confirmed) return;

    setLoading(true);
    try {
      if (approvalType === '휴가 부여 상신') {
        if (!leaveType) {
          alert('휴가 종류를 선택해주세요.');
          return;
        }
        const grant = Number(grantDays || 0);
        if (!grant) {
          alert('휴가 부여 일수를 입력해주세요.');
          return;
        }

        await leaveService.submitLeaveGrantRequestMultipart({
          userId: user?.userId || '',
          department: draftingDepartment,
          approvalDate: new Date().toISOString().split('.')[0] + 'Z',
          approvalType: getApprovalTypeValue(approvalType),
          approvalLine: approvers.map((item) => ({
            approverId: item.approverId,
            approverName: item.approverName,
            approvalSeq: item.approvalSeq,
            department: item.department,
            jobPosition: item.jobPosition,
          })),
          title: documentTitle,
          leaveType,
          grantDays: grant,
          reason: reason || '',
          attachmentsList: chatAttachments,
          ccList: ccList.map((item: any) => ({ user_id: item.user_id || item.userId, name: item.name })),
          files: attachments,
        });
      } else {
        await new Promise((resolve) => setTimeout(resolve, 1500));
      }

      closePanel();
    } finally {
      setLoading(false);
    }
  };

  // 공통 패널 내용 스타일
  const panelContentSx = {
    bgcolor: isDark ? DARK_PANEL : 'white',
    boxShadow: isDark ? '0 8px 32px rgba(0, 0, 0, 0.4)' : '0 4px 20px rgba(0, 0, 0, 0.15)',
    display: 'flex',
    flexDirection: 'column',
  };

  // 패널 내용 렌더링 함수
  const renderPanelContent = () => (
    <>
      <Box
            sx={{
              px: 3,
              py: 2.5,
              borderBottom: `1px solid ${isDark ? '#2D3748' : LIGHT_BORDER}`,
              display: 'flex',
              alignItems: 'center',
              gap: 1.5,
            }}
          >
            <DescriptionIcon sx={{ color: panelText, fontSize: 24 }} />
            <Typography sx={{ flexGrow: 1, fontSize: 18, fontWeight: 700, color: panelText }}>
              전자결재 상신
            </Typography>
            <IconButton onClick={closePanel} sx={{ color: panelText }}>
              <CloseIcon />
            </IconButton>
          </Box>

          <Box sx={{ flex: 1, overflow: 'auto', p: 3 }}>
            {isLoading && (
              <Box
                sx={{
                  mb: 2,
                  p: 2.5,
                  borderRadius: '12px',
                  border: `1px solid ${PRIMARY_COLOR}4D`,
                  bgcolor: `${PRIMARY_COLOR}1A`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 1.5,
                }}
              >
                <CircularProgress size={20} sx={{ color: PRIMARY_COLOR }} />
                <Typography sx={{ color: PRIMARY_COLOR, fontWeight: 600, fontSize: 14 }}>
                  휴가 부여 상신 데이터를 불러오는 중입니다...
                </Typography>
              </Box>
            )}

            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
              <DescriptionIcon sx={{ fontSize: 16, color: PRIMARY_COLOR }} />
              <Typography sx={{ fontSize: 14, fontWeight: 600, color: panelText }}>
                공통 필수영역
              </Typography>
            </Box>

            <Box sx={{ display: 'grid', gridTemplateColumns: isMobile ? '1fr' : 'repeat(4, 1fr)', gap: 1 }}>
              {isCustomDepartment ? (
                <TextField
                  label="기안부서 *"
                  value={draftingDepartment}
                  onChange={(e) => setDraftingDepartment(e.target.value)}
                  placeholder="부서명을 입력하세요"
                  InputProps={{
                    endAdornment: (
                      <IconButton
                        onClick={() => {
                          setIsCustomDepartment(false);
                          setDraftingDepartment('');
                        }}
                        size="small"
                      >
                        <CloseIcon fontSize="small" />
                      </IconButton>
                    ),
                  }}
                  sx={fieldSx}
                />
              ) : (
                <FormControl fullWidth sx={fieldSx}>
                  <InputLabel>기안부서 *</InputLabel>
                  <Select
                    label="기안부서 *"
                    value={draftingDepartment || ''}
                    onChange={(e) => {
                      if (e.target.value === '__CUSTOM__') {
                        setIsCustomDepartment(true);
                        setDraftingDepartment('');
                        return;
                      }
                      setDraftingDepartment(String(e.target.value));
                    }}
                  >
                    {departments.map((dept) => (
                      <MenuItem key={dept} value={dept}>{dept}</MenuItem>
                    ))}
                    <MenuItem value="__CUSTOM__">직접입력</MenuItem>
                  </Select>
                </FormControl>
              )}

              <TextField
                label="기안자 *"
                value={user?.userId || ''}
                InputProps={{ readOnly: true }}
                sx={{
                  ...fieldSx,
                  '& .MuiOutlinedInput-input': {
                    padding: '12px',
                    color: MUTED_TEXT,
                  },
                }}
              />

              <TextField
                label="기안일 *"
                type="date"
                value={draftingDate}
                onChange={(e) => setDraftingDate(e.target.value)}
                InputLabelProps={{ shrink: true }}
                sx={fieldSx}
              />

              <FormControl fullWidth sx={fieldSx}>
                <InputLabel>보존년한 *</InputLabel>
                <Select
                  label="보존년한 *"
                  value={retentionPeriod}
                  onChange={(e) => setRetentionPeriod(String(e.target.value))}
                >
                  {['영구', '5년', '10년', '15년', '20년'].map((item) => (
                    <MenuItem key={item} value={item}>{item}</MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Box>

            <Box sx={{ mt: 2, mb: 3 }}>
              <FormControl fullWidth sx={fieldSx}>
                <InputLabel>결재 종류 *</InputLabel>
                <Select
                  label="결재 종류 *"
                  value={approvalType}
                  onChange={(e) => {
                    const next = String(e.target.value);
                    setApprovalType(next);
                    setDocumentTitle(next);
                  }}
                >
                  {approvalOptions.map((item) => (
                    <MenuItem key={item} value={item}>{item}</MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Box>

            <Box sx={{ display: 'grid', gridTemplateColumns: isMobile ? '1fr' : '1fr 1fr', gap: 2, mb: 3 }}>
              <Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1.5 }}>
                  <HowToRegIcon sx={{ fontSize: 16, color: PRIMARY_COLOR }} />
                  <Typography sx={{ fontSize: 14, fontWeight: 600, color: panelText }}>
                    승인자
                  </Typography>
                </Box>
                <Box sx={{ display: 'flex', gap: 1, mb: 1.5 }}>
                  <Button
                    fullWidth
                    variant="contained"
                    startIcon={<HowToRegIcon sx={{ fontSize: 16 }} />}
                    onClick={() => {
                      setIsSequentialApproval(false);
                      setIsApproverModalOpen(true);
                    }}
                    sx={{ bgcolor: PRIMARY_COLOR, borderRadius: '10px', py: 1.3, fontWeight: 600 }}
                  >
                    승인자 선택
                  </Button>
                  <Button
                    fullWidth
                    variant="contained"
                    startIcon={<FormatListNumberedIcon sx={{ fontSize: 16 }} />}
                    onClick={() => {
                      setIsSequentialApproval(true);
                      setIsApproverModalOpen(true);
                    }}
                    sx={{ bgcolor: SUCCESS_COLOR, borderRadius: '10px', py: 1.3, fontWeight: 600 }}
                  >
                    순차결재
                  </Button>
                  <Button
                    fullWidth
                    variant="contained"
                    startIcon={<SaveIcon sx={{ fontSize: 16 }} />}
                    onClick={handleSaveApprovalLine}
                    sx={{ bgcolor: '#6B7280', borderRadius: '10px', py: 1.3, fontWeight: 600, fontSize: 12 }}
                  >
                    결재라인 저장
                  </Button>
                </Box>
                <Box
                  sx={{
                    minHeight: 80,
                    p: 2,
                    borderRadius: '12px',
                    bgcolor: panelSurface,
                    border: `1px solid ${panelBorderColor}`,
                  }}
                >
                  {approvers.length === 0 ? (
                    <Box sx={{ textAlign: 'center', color: subtitleText }}>
                      <HowToRegIcon sx={{ fontSize: 20, color: PRIMARY_COLOR }} />
                      <Typography sx={{ fontSize: 12, fontWeight: 500, mt: 0.5 }}>
                        승인자 선택
                      </Typography>
                    </Box>
                  ) : (
                    <Box>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 1 }}>
                        <HowToRegIcon sx={{ fontSize: 16, color: PRIMARY_COLOR }} />
                        <Typography sx={{ fontSize: 11, fontWeight: 600, color: panelText }}>
                          선택된 승인자 ({approvers.length}명)
                        </Typography>
                      </Box>
                      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.75 }}>
                        {approvers.map((item, idx) => (
                          <Box
                            key={`${item.approverId}-${idx}`}
                            sx={{
                              px: 1,
                              py: 0.5,
                              borderRadius: '12px',
                              bgcolor: `${PRIMARY_COLOR}1A`,
                              color: PRIMARY_COLOR,
                              fontSize: 10,
                              fontWeight: 500,
                            }}
                          >
                            {isSequentialApproval ? `${idx + 1}. ` : ''}{item.approverName}
                          </Box>
                        ))}
                      </Box>
                    </Box>
                  )}
                </Box>
              </Box>

              <Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1.5 }}>
                  <PersonAddOutlinedIcon sx={{ fontSize: 16, color: INFO_COLOR }} />
                  <Typography sx={{ fontSize: 14, fontWeight: 600, color: panelText }}>
                    참조자
                  </Typography>
                </Box>
                <Button
                  fullWidth
                  variant="contained"
                  startIcon={<PersonAddOutlinedIcon sx={{ fontSize: 16 }} />}
                  onClick={() => setIsReferenceModalOpen(true)}
                  sx={{ bgcolor: INFO_COLOR, borderRadius: '10px', py: 1.3, fontWeight: 600, mb: 1.5 }}
                >
                  참조자 선택
                </Button>
                <Box
                  sx={{
                    minHeight: 80,
                    p: 2,
                    borderRadius: '12px',
                    bgcolor: panelSurface,
                    border: `1px solid ${panelBorderColor}`,
                  }}
                >
                  {ccList.length === 0 ? (
                    <Box sx={{ textAlign: 'center', color: subtitleText }}>
                      <PersonAddOutlinedIcon sx={{ fontSize: 20, color: INFO_COLOR }} />
                      <Typography sx={{ fontSize: 12, fontWeight: 500, mt: 0.5 }}>
                        참조자 선택
                      </Typography>
                    </Box>
                  ) : (
                    <Box>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 1 }}>
                        <PersonAddOutlinedIcon sx={{ fontSize: 16, color: INFO_COLOR }} />
                        <Typography sx={{ fontSize: 11, fontWeight: 600, color: panelText }}>
                          선택된 참조자 ({ccList.length}명)
                        </Typography>
                      </Box>
                      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.75 }}>
                        {ccList.map((item, idx) => (
                          <Box
                            key={`${item.name}-${idx}`}
                            sx={{
                              px: 1,
                              py: 0.5,
                              borderRadius: '12px',
                              bgcolor: `${INFO_COLOR}1A`,
                              color: INFO_COLOR,
                              fontSize: 10,
                              fontWeight: 500,
                            }}
                          >
                            {item.name}
                          </Box>
                        ))}
                      </Box>
                    </Box>
                  )}
                </Box>
              </Box>
            </Box>

            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
              <DescriptionIcon sx={{ fontSize: 16, color: PRIMARY_COLOR }} />
              <Typography sx={{ fontSize: 14, fontWeight: 600, color: panelText }}>
                결재 상세
              </Typography>
            </Box>

            <Box sx={{ mb: 3 }}>
              {approvalType === '휴가 부여 상신' && (
                <Box
                  sx={{
                    p: 2,
                    borderRadius: '8px',
                    bgcolor: panelSurface,
                  }}
                >
                  <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                    <FormControl fullWidth sx={fieldSx}>
                      <InputLabel>휴가 종류 *</InputLabel>
                      <Select label="휴가 종류 *" value={leaveType} onChange={(e) => setLeaveType(String(e.target.value))}>
                        {LEAVE_TYPES.map((item) => (
                          <MenuItem key={item} value={item}>{item}</MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                    <TextField
                      label="제목 *"
                      value={documentTitle}
                      onChange={(e) => setDocumentTitle(e.target.value)}
                      sx={fieldSx}
                    />
                    <TextField
                      label="휴가 부여 일수 *"
                      value={grantDays}
                      onChange={(e) => setGrantDays(e.target.value)}
                      type="number"
                      sx={fieldSx}
                    />
                    <TextField
                      label="사유"
                      value={reason}
                      onChange={(e) => setReason(e.target.value)}
                      multiline
                      minRows={4}
                      sx={fieldSx}
                    />
                  </Box>
                </Box>
              )}

              {approvalType === '기본양식' && (
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                  <TextField
                    label="제목 *"
                    value={documentTitle}
                    onChange={(e) => setDocumentTitle(e.target.value)}
                    sx={fieldSx}
                  />
                  {htmlContent ? (
                    <Box
                      sx={{
                        border: `1px solid ${panelBorderColor}`,
                        borderRadius: '8px',
                        p: 2,
                        bgcolor: panelSurface,
                        maxHeight: 240,
                        overflow: 'auto',
                        color: panelText,
                        fontSize: 14,
                      }}
                      dangerouslySetInnerHTML={{ __html: htmlContent }}
                    />
                  ) : (
                    <TextField
                      label="내용 *"
                      value={content}
                      onChange={(e) => setContent(e.target.value)}
                      multiline
                      minRows={5}
                      sx={fieldSx}
                    />
                  )}
                </Box>
              )}

              {(approvalType === '매출/매입계약 기안서' || approvalType === '구매신청서') && (
                <Box sx={{ border: `1px solid ${panelBorderColor}`, borderRadius: '8px', overflow: 'hidden' }}>
                  <Box sx={{ display: 'flex', justifyContent: 'flex-end', p: 1, bgcolor: panelSurface }}>
                    <Button size="small" startIcon={<OpenInFullIcon />} onClick={() => setWebviewOpen(true)}>
                      전체 화면
                    </Button>
                  </Box>
                  <Box sx={{ height: 320 }}>
                    <iframe title="approval-webview" src={webviewUrl} width="100%" height="100%" style={{ border: 0 }} />
                  </Box>
                </Box>
              )}

              {(approvalType === '교육신청서' || approvalType === '경조사비 지급신청서') && (
                <Box sx={{ p: 2, borderRadius: '8px', bgcolor: panelSurface, color: panelText }}>
                  <Typography variant="body2">추후 구현 예정입니다.</Typography>
                </Box>
              )}
            </Box>

            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
              <AttachFileIcon sx={{ fontSize: 16, color: PRIMARY_COLOR }} />
              <Typography sx={{ fontSize: 14, fontWeight: 600, color: panelText }}>
                첨부파일
              </Typography>
            </Box>

            <Box
              sx={{
                p: 2,
                borderRadius: '12px',
                bgcolor: panelSurface,
                border: `1px solid ${panelBorderColor}`,
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                <AttachFileIcon sx={{ fontSize: 16, color: panelText }} />
                <Typography sx={{ fontSize: 14, fontWeight: 600, color: panelText }}>
                  {attachments.length + chatAttachments.length === 0
                    ? '첨부파일'
                    : `첨부파일 ${attachments.length + chatAttachments.length}개`}
                </Typography>
                <Box sx={{ flex: 1 }} />
                {(attachments.length > 0 || chatAttachments.length > 0) && (
                  <Button size="small" onClick={() => { setAttachments([]); setChatAttachments([]); }} sx={{ color: PRIMARY_COLOR }}>
                    모두 삭제
                  </Button>
                )}
                <Button
                  size="small"
                  variant="contained"
                  startIcon={<AddIcon sx={{ fontSize: 16 }} />}
                  component="label"
                  sx={{ bgcolor: PRIMARY_COLOR, fontSize: 12, py: 0.5, px: 1.5 }}
                >
                  파일 추가
                  <input hidden type="file" multiple onChange={(e) => handleAttachmentSelect(e.target.files)} />
                </Button>
              </Box>

              {chatAttachments.length > 0 && (
                <Box sx={{ mb: 2 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 1 }}>
                    <CloudDoneIcon sx={{ fontSize: 14, color: SUCCESS_COLOR }} />
                    <Typography sx={{ fontSize: 11, color: SUCCESS_COLOR }}>
                      채팅에서 첨부됨 ({chatAttachments.length}개)
                    </Typography>
                  </Box>
                  <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                    {chatAttachments.map((item, idx) => {
                      const Icon = getFileIcon(item.file_name);
                      return (
                        <Box
                          key={`${item.file_name}-${idx}`}
                          sx={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 1,
                            p: 1,
                            borderRadius: '8px',
                            bgcolor: isDark ? '#1A202C' : 'white',
                            border: `1px solid ${panelBorderColor}`,
                          }}
                        >
                          <Icon sx={{ fontSize: 20, color: PRIMARY_COLOR }} />
                          <Box>
                            <Typography sx={{ fontSize: 12, fontWeight: 600, color: panelText }}>
                              {item.file_name.length > 15 ? `${item.file_name.slice(0, 12)}...` : item.file_name}
                            </Typography>
                            <Typography sx={{ fontSize: 10, color: subtitleText }}>
                              {formatSize(item.size)}
                            </Typography>
                          </Box>
                          <IconButton size="small" onClick={() => handleRemoveChatAttachment(idx)}>
                            <CloseIcon sx={{ fontSize: 12, color: subtitleText }} />
                          </IconButton>
                        </Box>
                      );
                    })}
                  </Box>
                </Box>
              )}

              {attachments.length > 0 && (
                <Box>
                  {chatAttachments.length > 0 && (
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 1 }}>
                      <FolderOpenIcon sx={{ fontSize: 14, color: PRIMARY_COLOR }} />
                      <Typography sx={{ fontSize: 11, color: PRIMARY_COLOR }}>
                        직접 첨부 ({attachments.length}개)
                      </Typography>
                    </Box>
                  )}
                  <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                    {attachments.map((file, idx) => {
                      const Icon = getFileIcon(file.name);
                      return (
                        <Box
                          key={`${file.name}-${idx}`}
                          sx={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 1,
                            p: 1,
                            borderRadius: '8px',
                            bgcolor: isDark ? '#1A202C' : 'white',
                            border: `1px solid ${panelBorderColor}`,
                            boxShadow: isDark ? 'none' : '0 1px 2px rgba(0,0,0,0.05)',
                          }}
                        >
                          <Icon sx={{ fontSize: 20, color: PRIMARY_COLOR }} />
                          <Box>
                            <Typography sx={{ fontSize: 12, fontWeight: 600, color: panelText }}>
                              {file.name.length > 15 ? `${file.name.slice(0, 12)}...` : file.name}
                            </Typography>
                            <Typography sx={{ fontSize: 10, color: subtitleText }}>
                              {formatSize(file.size)}
                            </Typography>
                          </Box>
                          <IconButton size="small" onClick={() => handleRemoveAttachment(idx)}>
                            <CloseIcon sx={{ fontSize: 12, color: subtitleText }} />
                          </IconButton>
                        </Box>
                      );
                    })}
                  </Box>
                </Box>
              )}

              {attachments.length === 0 && chatAttachments.length === 0 && (
                <Typography sx={{ fontSize: 12, color: subtitleText, textAlign: 'center', mt: 2 }}>
                  파일을 추가하려면 위의 "파일 추가" 버튼을 클릭하세요
                </Typography>
              )}
            </Box>
          </Box>

          <Divider />
          <Box sx={{ p: 3, borderTop: `1px solid ${isDark ? '#2D3748' : LIGHT_BORDER}` }}>
            <Button
              fullWidth
              variant="outlined"
              startIcon={<SaveIcon />}
              onClick={handleSaveApprovalLine}
              sx={{
                color: PRIMARY_COLOR,
                borderColor: PRIMARY_COLOR,
                borderRadius: '8px',
                py: 1.2,
                fontWeight: 600,
                mb: 1.5,
              }}
            >
              결재라인 저장
            </Button>
            <Box sx={{ display: 'flex', gap: 1.5 }}>
              <Button
                fullWidth
                onClick={handleReset}
                sx={{ color: MUTED_COLOR, fontWeight: 600 }}
              >
                초기화
              </Button>
              <Button
                fullWidth
                variant="contained"
                onClick={handleSubmit}
                disabled={isLoading}
                sx={{ bgcolor: PRIMARY_COLOR, fontWeight: 600, py: 1.2 }}
              >
                {isLoading ? <CircularProgress size={20} sx={{ color: 'white' }} /> : '상신'}
              </Button>
            </Box>
          </Box>
    </>
  );

  // 공통 모달들
  const renderModals = () => (
    <>
      <Dialog open={webviewOpen} onClose={() => setWebviewOpen(false)} fullScreen={isMobile} maxWidth="xl" fullWidth>
        <DialogTitle>결재 상세</DialogTitle>
        <DialogContent sx={{ p: 0, height: isMobile ? '100%' : '80vh' }}>
          <iframe title="approval-webview-full" src={webviewUrl} width="100%" height="100%" style={{ border: 0 }} />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setWebviewOpen(false)}>닫기</Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snackbarOpen}
        autoHideDuration={3000}
        onClose={() => setSnackbarOpen(false)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          onClose={() => setSnackbarOpen(false)}
          severity={snackbarSeverity}
          sx={{ width: '100%' }}
        >
          {snackbarMessage}
        </Alert>
      </Snackbar>

      <ApproverSelectionModal
        open={isApproverModalOpen}
        onClose={() => setIsApproverModalOpen(false)}
        onConfirm={handleApproverConfirm}
        initialSelectedApproverIds={approvers.map((item) => item.approverId)}
        sequentialApproval={isSequentialApproval}
      />

      <ReferenceSelectionModal
        open={isReferenceModalOpen}
        onClose={() => setIsReferenceModalOpen(false)}
        onConfirm={(refs: any[]) => setCcList(refs.map((ref) => ({
          name: ref.name,
          department: ref.department,
          user_id: ref.userId || ref.user_id,
        })))}
        currentReferences={ccList as any}
      />
    </>
  );

  // 모바일: 오른쪽 슬라이드 패널
  if (isMobile) {
    return (
      <>
        <Box
          sx={{
            position: 'fixed',
            inset: 0,
            bgcolor: 'rgba(0, 0, 0, 0.15)',
            zIndex: 1200,
          }}
          onClick={closePanel}
        />
        <Slide direction="left" in={isOpen} mountOnEnter unmountOnExit>
          <Box
            sx={{
              ...panelContentSx,
              position: 'fixed',
              top: 0,
              right: 0,
              height: '100vh',
              width: '100%',
              zIndex: 1300,
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {renderPanelContent()}
          </Box>
        </Slide>
        {renderModals()}
      </>
    );
  }

  // 데스크톱: 중앙 팝업 모달
  return (
    <>
      <Box
        sx={{
          position: 'fixed',
          inset: 0,
          bgcolor: 'rgba(0, 0, 0, 0.5)',
          zIndex: 1200,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
        onClick={closePanel}
      >
        <Box
          sx={{
            ...panelContentSx,
            width: '60vw',
            minWidth: 500,
            maxWidth: 1000,
            maxHeight: '90vh',
            borderRadius: '12px',
            overflow: 'hidden',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          {renderPanelContent()}
        </Box>
      </Box>
      {renderModals()}
    </>
  );
}
