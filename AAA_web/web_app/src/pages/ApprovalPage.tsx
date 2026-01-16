import React, { useState, useEffect } from 'react';
import {
  Box,
  Paper,
  Typography,
  Button,
  Grid,
  Card,
  CardContent,
  CardActions,
  Chip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  List,
  ListItem,
  ListItemText,
  ListItemSecondaryAction,
  IconButton,
  Fab,
  useMediaQuery,
  useTheme,
  Tabs,
  Tab,
  Alert,
  Stepper,
  Step,
  StepLabel,
  Divider,
} from '@mui/material';
import {
  ArrowBack as ArrowBackIcon,
  Add as AddIcon,
  Assignment as AssignmentIcon,
  CheckCircle as CheckIcon,
  Cancel as CancelIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Visibility as ViewIcon,
  Send as SendIcon,
  Pending as PendingIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDayjs } from '@mui/x-date-pickers/AdapterDayjs';
import dayjs, { Dayjs } from 'dayjs';
import 'dayjs/locale/ko';

// 전자결재 타입 정의
interface ApprovalRequest {
  id: string;
  title: string;
  type: string;
  content: string;
  amount?: number;
  status: 'draft' | 'pending' | 'approved' | 'rejected';
  createdAt: string;
  submittedAt?: string;
  approvedAt?: string;
  approver?: string;
  comments?: string;
}

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`approval-tabpanel-${index}`}
      aria-labelledby={`approval-tab-${index}`}
      {...other}
    >
      {value === index && <Box sx={{ p: 3 }}>{children}</Box>}
    </div>
  );
}

export default function ApprovalPage() {
  const navigate = useNavigate();
  const [tabValue, setTabValue] = useState(0);
  const [approvalRequests, setApprovalRequests] = useState<ApprovalRequest[]>([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingRequest, setEditingRequest] = useState<ApprovalRequest | null>(null);
  const [formData, setFormData] = useState({
    title: '',
    type: '',
    content: '',
    amount: '',
  });
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));

  const approvalTypes = [
    { value: 'purchase', label: '구매 요청' },
    { value: 'contract', label: '계약 승인' },
    { value: 'expense', label: '경비 지출' },
    { value: 'vacation', label: '휴가 신청' },
    { value: 'business', label: '출장 신청' },
    { value: 'other', label: '기타' },
  ];

  // 샘플 데이터
  useEffect(() => {
    setApprovalRequests([
      {
        id: '1',
        title: '사무용품 구매 요청',
        type: 'purchase',
        content: '사무용품 구매를 위한 결재 요청입니다.',
        amount: 500000,
        status: 'approved',
        createdAt: '2024-01-10',
        submittedAt: '2024-01-10',
        approvedAt: '2024-01-12',
        approver: '김부장',
        comments: '승인합니다.',
      },
      {
        id: '2',
        title: '출장 신청',
        type: 'business',
        content: '고객사 방문을 위한 출장 신청입니다.',
        status: 'pending',
        createdAt: '2024-01-15',
        submittedAt: '2024-01-15',
      },
      {
        id: '3',
        title: '경비 지출 요청',
        type: 'expense',
        content: '회식비 지출 요청입니다.',
        amount: 200000,
        status: 'draft',
        createdAt: '2024-01-18',
      },
    ]);
  }, []);

  const handleTabChange = (event: React.SyntheticEvent, newValue: number) => {
    setTabValue(newValue);
  };

  const handleOpenDialog = (request?: ApprovalRequest) => {
    if (request) {
      setEditingRequest(request);
      setFormData({
        title: request.title,
        type: request.type,
        content: request.content,
        amount: request.amount?.toString() || '',
      });
    } else {
      setEditingRequest(null);
      setFormData({
        title: '',
        type: '',
        content: '',
        amount: '',
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingRequest(null);
    setFormData({
      title: '',
      type: '',
      content: '',
      amount: '',
    });
  };

  const handleSubmit = () => {
    if (!formData.title || !formData.type || !formData.content) {
      return;
    }

    if (editingRequest) {
      // 수정
      setApprovalRequests(prev => 
        prev.map(req => 
          req.id === editingRequest.id 
            ? {
                ...req,
                title: formData.title,
                type: formData.type,
                content: formData.content,
                amount: formData.amount ? parseInt(formData.amount) : undefined,
              }
            : req
        )
      );
    } else {
      // 새로 추가
      const newRequest: ApprovalRequest = {
        id: Date.now().toString(),
        title: formData.title,
        type: formData.type,
        content: formData.content,
        amount: formData.amount ? parseInt(formData.amount) : undefined,
        status: 'draft',
        createdAt: dayjs().format('YYYY-MM-DD'),
      };
      setApprovalRequests(prev => [newRequest, ...prev]);
    }

    handleCloseDialog();
  };

  const handleDelete = (id: string) => {
    setApprovalRequests(prev => prev.filter(req => req.id !== id));
  };

  const handleSubmitApproval = (id: string) => {
    setApprovalRequests(prev => 
      prev.map(req => 
        req.id === id 
          ? { ...req, status: 'pending', submittedAt: dayjs().format('YYYY-MM-DD') }
          : req
      )
    );
  };

  const handleApprove = (id: string) => {
    setApprovalRequests(prev => 
      prev.map(req => 
        req.id === id 
          ? { 
              ...req, 
              status: 'approved', 
              approvedAt: dayjs().format('YYYY-MM-DD'),
              approver: '김부장',
              comments: '승인합니다.'
            }
          : req
      )
    );
  };

  const handleReject = (id: string) => {
    setApprovalRequests(prev => 
      prev.map(req => 
        req.id === id 
          ? { 
              ...req, 
              status: 'rejected', 
              approvedAt: dayjs().format('YYYY-MM-DD'),
              approver: '김부장',
              comments: '거부합니다.'
            }
          : req
      )
    );
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'approved': return 'success';
      case 'rejected': return 'error';
      case 'pending': return 'warning';
      default: return 'default';
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'approved': return '승인';
      case 'rejected': return '거부';
      case 'pending': return '대기';
      default: return '임시저장';
    }
  };

  const getTypeLabel = (type: string) => {
    return approvalTypes.find(t => t.value === type)?.label || type;
  };

  const draftRequests = approvalRequests.filter(req => req.status === 'draft');
  const pendingRequests = approvalRequests.filter(req => req.status === 'pending');
  const approvedRequests = approvalRequests.filter(req => req.status === 'approved');
  const rejectedRequests = approvalRequests.filter(req => req.status === 'rejected');

  return (
    <LocalizationProvider dateAdapter={AdapterDayjs} adapterLocale="ko">
      <Box sx={{ p: { xs: 2, md: 3 }, height: '100%', overflow: 'auto' }}>
        {/* 헤더 */}
        <Box sx={{ mb: 3 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
            <IconButton aria-label="뒤로가기" onClick={() => navigate(-1)} size="small">
              <ArrowBackIcon />
            </IconButton>
            <Typography variant="h4" sx={{ fontWeight: 'bold' }}>
              전자결재
            </Typography>
          </Box>
          <Typography variant="body1" color="text.secondary">
            결재 문서를 작성하고 관리하세요
          </Typography>
        </Box>

        {/* 통계 카드 */}
        <Grid container spacing={2} sx={{ mb: 3 }}>
          <Grid item xs={6} md={3}>
            <Card>
              <CardContent sx={{ textAlign: 'center' }}>
                <Typography variant="h4" color="primary.main" sx={{ fontWeight: 'bold' }}>
                  {approvalRequests.length}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  전체 문서
                </Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={6} md={3}>
            <Card>
              <CardContent sx={{ textAlign: 'center' }}>
                <Typography variant="h4" color="warning.main" sx={{ fontWeight: 'bold' }}>
                  {pendingRequests.length}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  대기 중
                </Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={6} md={3}>
            <Card>
              <CardContent sx={{ textAlign: 'center' }}>
                <Typography variant="h4" color="success.main" sx={{ fontWeight: 'bold' }}>
                  {approvedRequests.length}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  승인됨
                </Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={6} md={3}>
            <Card>
              <CardContent sx={{ textAlign: 'center' }}>
                <Typography variant="h4" color="error.main" sx={{ fontWeight: 'bold' }}>
                  {rejectedRequests.length}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  거부됨
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* 탭 */}
        <Paper sx={{ mb: 3 }}>
          <Tabs
            value={tabValue}
            onChange={handleTabChange}
            variant={isMobile ? 'scrollable' : 'standard'}
            scrollButtons="auto"
          >
            <Tab label="전체" />
            <Tab label="임시저장" />
            <Tab label="대기 중" />
            <Tab label="승인됨" />
            <Tab label="거부됨" />
          </Tabs>
        </Paper>

        {/* 탭 패널 */}
        <TabPanel value={tabValue} index={0}>
          <ApprovalRequestList 
            requests={approvalRequests} 
            onEdit={handleOpenDialog}
            onDelete={handleDelete}
            onSubmit={handleSubmitApproval}
            onApprove={handleApprove}
            onReject={handleReject}
            isMobile={isMobile}
          />
        </TabPanel>
        <TabPanel value={tabValue} index={1}>
          <ApprovalRequestList 
            requests={draftRequests} 
            onEdit={handleOpenDialog}
            onDelete={handleDelete}
            onSubmit={handleSubmitApproval}
            onApprove={handleApprove}
            onReject={handleReject}
            isMobile={isMobile}
          />
        </TabPanel>
        <TabPanel value={tabValue} index={2}>
          <ApprovalRequestList 
            requests={pendingRequests} 
            onEdit={handleOpenDialog}
            onDelete={handleDelete}
            onSubmit={handleSubmitApproval}
            onApprove={handleApprove}
            onReject={handleReject}
            isMobile={isMobile}
          />
        </TabPanel>
        <TabPanel value={tabValue} index={3}>
          <ApprovalRequestList 
            requests={approvedRequests} 
            onEdit={handleOpenDialog}
            onDelete={handleDelete}
            onSubmit={handleSubmitApproval}
            onApprove={handleApprove}
            onReject={handleReject}
            isMobile={isMobile}
          />
        </TabPanel>
        <TabPanel value={tabValue} index={4}>
          <ApprovalRequestList 
            requests={rejectedRequests} 
            onEdit={handleOpenDialog}
            onDelete={handleDelete}
            onSubmit={handleSubmitApproval}
            onApprove={handleApprove}
            onReject={handleReject}
            isMobile={isMobile}
          />
        </TabPanel>

        {/* 결재 문서 작성 다이얼로그 */}
        <Dialog 
          open={openDialog} 
          onClose={handleCloseDialog}
          maxWidth="md"
          fullWidth
          fullScreen={isMobile}
        >
          <DialogTitle>
            {editingRequest ? '결재 문서 수정' : '결재 문서 작성'}
          </DialogTitle>
          <DialogContent>
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
              <TextField
                label="제목"
                value={formData.title}
                onChange={(e) => setFormData(prev => ({ ...prev, title: e.target.value }))}
                fullWidth
                required
              />

              <FormControl fullWidth>
                <InputLabel>결재 유형</InputLabel>
                <Select
                  value={formData.type}
                  label="결재 유형"
                  onChange={(e) => setFormData(prev => ({ ...prev, type: e.target.value }))}
                >
                  {approvalTypes.map((type) => (
                    <MenuItem key={type.value} value={type.value}>
                      {type.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>

              <TextField
                label="금액 (원)"
                type="number"
                value={formData.amount}
                onChange={(e) => setFormData(prev => ({ ...prev, amount: e.target.value }))}
                fullWidth
                placeholder="금액이 있는 경우 입력하세요"
              />

              <TextField
                label="내용"
                multiline
                rows={6}
                value={formData.content}
                onChange={(e) => setFormData(prev => ({ ...prev, content: e.target.value }))}
                fullWidth
                required
                placeholder="결재 내용을 상세히 작성해주세요"
              />
            </Box>
          </DialogContent>
          <DialogActions sx={{ p: 2 }}>
            <Button onClick={handleCloseDialog}>취소</Button>
            <Button 
              onClick={handleSubmit} 
              variant="contained"
              disabled={!formData.title || !formData.type || !formData.content}
            >
              {editingRequest ? '수정' : '저장'}
            </Button>
          </DialogActions>
        </Dialog>

        {/* 플로팅 액션 버튼 */}
        <Fab
          color="primary"
          aria-label="add"
          sx={{
            position: 'fixed',
            bottom: 16,
            right: 16,
          }}
          onClick={() => handleOpenDialog()}
        >
          <AddIcon />
        </Fab>
      </Box>
    </LocalizationProvider>
  );
}

// 결재 문서 목록 컴포넌트
function ApprovalRequestList({ 
  requests, 
  onEdit, 
  onDelete, 
  onSubmit,
  onApprove,
  onReject,
  isMobile 
}: { 
  requests: ApprovalRequest[]; 
  onEdit: (request: ApprovalRequest) => void;
  onDelete: (id: string) => void;
  onSubmit: (id: string) => void;
  onApprove: (id: string) => void;
  onReject: (id: string) => void;
  isMobile: boolean;
}) {
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'approved': return 'success';
      case 'rejected': return 'error';
      case 'pending': return 'warning';
      default: return 'default';
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'approved': return '승인';
      case 'rejected': return '거부';
      case 'pending': return '대기';
      default: return '임시저장';
    }
  };

  const getTypeLabel = (type: string) => {
    const approvalTypes = [
      { value: 'purchase', label: '구매 요청' },
      { value: 'contract', label: '계약 승인' },
      { value: 'expense', label: '경비 지출' },
      { value: 'vacation', label: '휴가 신청' },
      { value: 'business', label: '출장 신청' },
      { value: 'other', label: '기타' },
    ];
    return approvalTypes.find(t => t.value === type)?.label || type;
  };

  if (requests.length === 0) {
    return (
      <Box sx={{ textAlign: 'center', py: 4 }}>
        <AssignmentIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
        <Typography variant="h6" color="text.secondary">
          결재 문서가 없습니다
        </Typography>
      </Box>
    );
  }

  return (
    <List>
      {requests.map((request) => (
        <ListItem
          key={request.id}
          sx={{
            bgcolor: 'background.paper',
            borderRadius: 2,
            mb: 1,
            boxShadow: 1,
            flexDirection: 'column',
            alignItems: 'stretch',
          }}
        >
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', width: '100%' }}>
            <ListItemText
              primary={
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Typography variant="h6" sx={{ fontWeight: 600 }}>
                    {request.title}
                  </Typography>
                  <Chip
                    label={getStatusLabel(request.status)}
                    color={getStatusColor(request.status) as any}
                    size="small"
                  />
                </Box>
              }
              secondary={
                <Box>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                    {getTypeLabel(request.type)}
                    {request.amount && ` • ${request.amount.toLocaleString()}원`}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                    {request.content.length > 100 ? `${request.content.substring(0, 100)}...` : request.content}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    작성일: {dayjs(request.createdAt).format('YYYY-MM-DD')}
                    {request.submittedAt && ` • 제출일: ${dayjs(request.submittedAt).format('YYYY-MM-DD')}`}
                    {request.approvedAt && ` • 처리일: ${dayjs(request.approvedAt).format('YYYY-MM-DD')}`}
                  </Typography>
                </Box>
              }
            />
            <ListItemSecondaryAction>
              <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                {request.status === 'draft' && (
                  <Button
                    size="small"
                    variant="contained"
                    startIcon={<SendIcon />}
                    onClick={() => onSubmit(request.id)}
                  >
                    제출
                  </Button>
                )}
                {request.status === 'pending' && (
                  <>
                    <Button
                      size="small"
                      variant="contained"
                      color="success"
                      startIcon={<CheckIcon />}
                      onClick={() => onApprove(request.id)}
                    >
                      승인
                    </Button>
                    <Button
                      size="small"
                      variant="contained"
                      color="error"
                      startIcon={<CancelIcon />}
                      onClick={() => onReject(request.id)}
                    >
                      거부
                    </Button>
                  </>
                )}
                <IconButton
                  edge="end"
                  onClick={() => onEdit(request)}
                  size="small"
                >
                  <EditIcon />
                </IconButton>
                <IconButton
                  edge="end"
                  onClick={() => onDelete(request.id)}
                  size="small"
                  color="error"
                >
                  <DeleteIcon />
                </IconButton>
              </Box>
            </ListItemSecondaryAction>
          </Box>
        </ListItem>
      ))}
    </List>
  );
}
