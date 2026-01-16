import { useState, useEffect, useRef } from 'react';
import {
  Box,
  Drawer,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Typography,
  Chip,
  Divider,
  IconButton,
  Tooltip,
  useMediaQuery,
  useTheme,
  AppBar,
  Toolbar,
  Menu,
  MenuItem,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Button,
  Snackbar,
  Alert,
  DialogContentText,
  Avatar,
} from '@mui/material';
import {
  Lock as LockIcon,
  Code as CodeIcon,
  Business as BusinessIcon,
  AutoAwesome as AutoAwesomeIcon,
  Chat as ChatIcon,
  Add as AddIcon,
  Search as SearchIcon,
  Description as DescriptionIcon,
  BeachAccess as BeachAccessIcon,
  // EmojiEvents as EmojiEventsIcon,
  Menu as MenuIcon,
  MoreVert as MoreVertIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  DeleteSweep as DeleteSweepIcon,
  Refresh as RefreshIcon,
  Settings as SettingsIcon,
  Help as HelpIcon,
  Logout as LogoutIcon,
} from '@mui/icons-material';
import { useNavigate, useLocation } from 'react-router-dom';
import { useChatStore, ARCHIVE_NAMES, getArchiveIcon, getArchiveColor, getArchiveTag, getArchiveDescription, isDefaultArchive } from '../store/chatStore';
import { useThemeStore } from '../store/themeStore';
import authService from '../services/authService';
import chatService from '../services/chatService';
import ChatArea from '../components/chat/ChatArea';
import SearchDialog from '../components/chat/SearchDialog';
import { NotificationBell } from '../components/common/NotificationBell';
import { GiftButton } from '../components/common/GiftBox';
import HelpDialog from '../components/common/HelpDialog';
import LeaveRequestDraftPanel from '../components/leave/LeaveRequestDraftPanel';
import ElectronicApprovalDraftPanel from '../components/approval/ElectronicApprovalDraftPanel';
import { MobileOnly, DesktopOnly } from '../components/common/Responsive';
import type { Archive } from '../types';
import { useElectronicApprovalStore } from '../store/electronicApprovalStore';

const SIDEBAR_WIDTH = 280; // 230 + 20px

export default function ChatPage() {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md')); // < 900px = 모바일
  const { colorScheme } = useThemeStore();
  const isDark = colorScheme.name === 'Dark';
  const { openPanel: openElectronicApproval } = useElectronicApprovalStore();
  const navigate = useNavigate();
  const location = useLocation();

  const {
    archives,
    currentArchive,
    setArchives,
    setCurrentArchive,
    setMessages,
  } = useChatStore();

  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [searchDialogOpen, setSearchDialogOpen] = useState(false);
  const [helpDialogOpen, setHelpDialogOpen] = useState(false);
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [selectedArchive, setSelectedArchive] = useState<Archive | null>(null);
  const [renameDialogOpen, setRenameDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [resetDialogOpen, setResetDialogOpen] = useState(false);
  const [bulkDeleteDialogOpen, setBulkDeleteDialogOpen] = useState(false);
  const deleteDialogOpenTimeRef = useRef<number>(0);
  const [newName, setNewName] = useState('');
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' | 'info' }>({
    open: false,
    message: '',
    severity: 'success',
  });

  const [isInitialized, setIsInitialized] = useState(false);

  // 초기 로드: 아카이브 목록 가져오기 (한 번만 실행)
  useEffect(() => {
    let isMounted = true;

    const initialize = async () => {
      if (isInitialized) return; // 이미 초기화되었으면 중복 실행 방지

      await loadArchives();

      if (isMounted) {
        setIsInitialized(true);
      }
    };

    initialize();

    return () => {
      isMounted = false; // cleanup: 언마운트 시 플래그 설정
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // 빈 배열: 컴포넌트 마운트 시 한 번만 실행

  // 현재 아카이브 상태 디버깅
  useEffect(() => {
    console.log('ChatPage: currentArchive 변경됨:', currentArchive?.archive_name);
  }, [currentArchive]);

  useEffect(() => {
    console.log('💎 deleteDialogOpen 상태 변경됨:', deleteDialogOpen);
    if (deleteDialogOpen) {
      console.log('💎 다이얼로그가 열렸습니다!');
      console.log('💎 selectedArchive:', selectedArchive);
    }
  }, [deleteDialogOpen]);

  // 아카이브 목록 로드
  const loadArchives = async () => {
    const currentUser = authService.getCurrentUser();
    if (!currentUser) {
      console.warn('사용자 정보가 없습니다.');
      return [];
    }

    try {
      console.log('아카이브 로드 시작:', currentUser.userId);
      const archiveList = await chatService.getArchiveList(currentUser.userId);
      console.log('로드된 아카이브 목록:', archiveList);

      // 중복 제거 (archive_id 기준)
      const uniqueArchives = archiveList.filter((archive, index, self) =>
        index === self.findIndex((a) => a.archive_id === archive.archive_id)
      );

      // ✅ 기본 아카이브와 일반 아카이브 분리
      const defaultArchives: Archive[] = [];
      const customArchives: Archive[] = [];

      uniqueArchives.forEach((archive) => {
        const name = archive.archive_name;
        const type = archive.archive_type || '';

        // 기본 아카이브 판별
        if (
          name === ARCHIVE_NAMES.WORK ||
          name === ARCHIVE_NAMES.CODE ||
          name === ARCHIVE_NAMES.SAP ||
          name === ARCHIVE_NAMES.CHATBOT ||
          type === 'code' ||
          type === 'sap'
        ) {
          defaultArchives.push(archive);
        } else {
          customArchives.push(archive);
        }
      });

      console.log('📊 기본 아카이브 수:', defaultArchives.length);
      console.log('📊 일반 아카이브 수:', customArchives.length);

      // ✅ 기본 아카이브는 각 타입별로 가장 최신 것만 선택
      const latestDefaultArchives: Archive[] = [];

      // 사내업무 (archive_type === '' && archive_name === '사내업무')
      const workArchives = defaultArchives
        .filter((a) => a.archive_name === ARCHIVE_NAMES.WORK && (a.archive_type === '' || !a.archive_type))
        .sort((a, b) => new Date(b.archive_time).getTime() - new Date(a.archive_time).getTime());
      if (workArchives.length > 0) {
        latestDefaultArchives.push(workArchives[0]);
        console.log('✅ 사내업무 최신:', workArchives[0].archive_id, workArchives[0].archive_time);
      }

      // 코딩어시스턴트 (archive_type === 'code' || archive_name === '코딩어시스턴트')
      const codeArchives = defaultArchives
        .filter((a) => a.archive_name === ARCHIVE_NAMES.CODE || a.archive_type === 'code')
        .sort((a, b) => new Date(b.archive_time).getTime() - new Date(a.archive_time).getTime());
      if (codeArchives.length > 0) {
        latestDefaultArchives.push(codeArchives[0]);
        console.log('✅ 코딩어시스턴트 최신:', codeArchives[0].archive_id, codeArchives[0].archive_time);
      }

      // SAP어시스턴트 (archive_type === 'sap' || archive_name === 'SAP어시스턴트')
      const sapArchives = defaultArchives
        .filter((a) => a.archive_name === ARCHIVE_NAMES.SAP || a.archive_type === 'sap')
        .sort((a, b) => new Date(b.archive_time).getTime() - new Date(a.archive_time).getTime());
      if (sapArchives.length > 0) {
        latestDefaultArchives.push(sapArchives[0]);
        console.log('✅ SAP어시스턴트 최신:', sapArchives[0].archive_id, sapArchives[0].archive_time);
      }

      // AI Chatbot (archive_name === 'AI Chatbot')
      const chatbotArchives = defaultArchives
        .filter((a) => a.archive_name === ARCHIVE_NAMES.CHATBOT)
        .sort((a, b) => new Date(b.archive_time).getTime() - new Date(a.archive_time).getTime());
      if (chatbotArchives.length > 0) {
        latestDefaultArchives.push(chatbotArchives[0]);
        console.log('✅ AI Chatbot 최신:', chatbotArchives[0].archive_id, chatbotArchives[0].archive_time);
      }

      // ✅ 기본 아카이브(최신 것만) + 일반 아카이브(모두) 합치기
      const filteredArchives = [...latestDefaultArchives, ...customArchives];
      console.log('📋 필터링 후 총 아카이브 수:', filteredArchives.length);

      // 아카이브 정렬 (Flutter와 동일한 로직)
      const sorted = [...filteredArchives].sort((a, b) => {
        const orderA = getArchiveOrder(a);
        const orderB = getArchiveOrder(b);

        if (orderA !== orderB) {
          return orderA - orderB;
        }

        // 같은 순서면 시간순 정렬 (최신순)
        return new Date(b.archive_time).getTime() - new Date(a.archive_time).getTime();
      });

      setArchives(sorted);

      // 기본 아카이브가 없으면 생성
      if (sorted.length === 0) {
        console.log('아카이브가 없어서 기본 아카이브를 생성합니다.');
        await createDefaultArchive();
      } else {
        // 현재 아카이브가 없을 때만 기본 아카이브 선택
        if (!currentArchive) {
          // 사내업무 아카이브를 찾아서 선택
          const workArchive = sorted.find(
            (a) => a.archive_name === ARCHIVE_NAMES.WORK
          );

          if (workArchive) {
            selectArchive(workArchive);
          } else {
            // 없으면 첫 번째 아카이브 선택
            selectArchive(sorted[0]);
          }
        }
      }

      return sorted;
    } catch (error: any) {
      console.error('Failed to load archives:', error);
      console.error('에러 상세:', error.response?.data);

      // 500 에러 시 기본 아카이브 생성 시도
      if (error.response?.status === 500) {
        console.log('서버 에러로 인해 기본 아카이브를 생성합니다.');
        try {
          await createDefaultArchive();
        } catch (createError) {
          console.error('기본 아카이브 생성도 실패:', createError);
        }
      }

      return [];
    }
  };

  // 아카이브 순서 계산
  const getArchiveOrder = (archive: any): number => {
    const name = archive.archive_name;
    const type = archive.archive_type;

    if (name === ARCHIVE_NAMES.WORK || (type === '' && name.includes('사내업무'))) {
      return 1;
    } else if (name === ARCHIVE_NAMES.CODE || type === 'code') {
      return 2;
    } else if (name === ARCHIVE_NAMES.SAP || type === 'sap') {
      return 3;
    } else if (name === ARCHIVE_NAMES.CHATBOT) {
      return 4;
    }
    return 5;
  };

  // 기본 아카이브 생성 (사내업무)
  const createDefaultArchive = async () => {
    const currentUser = authService.getCurrentUser();
    if (!currentUser) {
      console.warn('사용자 정보가 없어서 기본 아카이브를 생성할 수 없습니다.');
      return;
    }

    try {
      console.log('기본 아카이브 생성 시작:', currentUser.userId);
      const response = await chatService.createArchive(currentUser.userId, '');
      const newArchive = response.archive;
      console.log('생성된 아카이브:', newArchive);

      // 아카이브 이름을 "사내업무"로 설정
      if (newArchive.archive_name !== ARCHIVE_NAMES.WORK) {
        console.log('아카이브 이름을 사내업무로 변경합니다.');
        await chatService.updateArchive(currentUser.userId, newArchive.archive_id, ARCHIVE_NAMES.WORK);
        newArchive.archive_name = ARCHIVE_NAMES.WORK;
      }

      setArchives([newArchive]);
      selectArchive(newArchive);
      console.log('기본 아카이브 생성 및 선택 완료');
    } catch (error: any) {
      console.error('Failed to create default archive:', error);
      console.error('에러 상세:', error.response?.data);
    }
  };

  // 아카이브 선택 (Flutter의 selectTopic과 동일)
  const selectArchive = async (archive: any) => {
    console.log('selectArchive 시작:', archive.archive_name, archive.archive_id);

    // 1. 현재 아카이브 상태 업데이트
    setCurrentArchive(archive);

    // 2. 아카이브의 메시지 가져오기
    try {
      const messages = await chatService.getArchiveDetail(archive.archive_id);
      console.log('로드된 메시지 수:', messages.length);
      setMessages(messages);
    } catch (error) {
      console.error('Failed to load messages:', error);
      setMessages([]);
    }
  };


  // 아이콘 가져오기 - Flutter 스타일 (18px)
  const getIcon = (archive: Archive) => {
    const iconName = getArchiveIcon(archive);
    const color = getArchiveColor(archive, false);

    const iconProps = { sx: { color, fontSize: 18, opacity: 0.7 } }; // Flutter: 18px with opacity

    switch (iconName) {
      case 'code':
        return <CodeIcon {...iconProps} />;
      case 'business':
        return <BusinessIcon {...iconProps} />;
      case 'auto_awesome':
        return <AutoAwesomeIcon {...iconProps} />;
      case 'lock':
        return <LockIcon {...iconProps} />;
      default:
        return <ChatIcon {...iconProps} />;
    }
  };

  // 메뉴 열기
  const handleMenuOpen = (event: React.MouseEvent<HTMLElement>, archive: Archive) => {
    event.stopPropagation();
    setAnchorEl(event.currentTarget);
    setSelectedArchive(archive);
  };

  // 메뉴 닫기
  const handleMenuClose = () => {
    setAnchorEl(null);
    // selectedArchive는 다이얼로그에서 사용할 수 있도록 유지
    // 각 다이얼로그의 onClose에서 개별적으로 null 처리
  };

  // 이름 변경 다이얼로그 열기
  const handleRenameClick = () => {
    console.log('handleRenameClick 호출됨, selectedArchive:', selectedArchive);
    if (selectedArchive) {
      const archiveToRename = selectedArchive; // 아카이브 참조 저장
      const currentName = selectedArchive.archive_name;

      // 먼저 메뉴 닫기
      setAnchorEl(null);

      // 다이얼로그는 메뉴가 완전히 닫힌 후에 열기
      // MenuItem에서 이미 blur() 처리했으므로 여기서는 제거
      setTimeout(() => {
        setSelectedArchive(archiveToRename); // 다시 설정
        setNewName(currentName);
        setRenameDialogOpen(true);
        console.log('이름 변경 다이얼로그 열림');
      }, 350); // 350ms로 증가하여 Menu 애니메이션 완료 보장
    } else {
      console.warn('selectedArchive가 없습니다.');
      setAnchorEl(null);
    }
  };

  // 이름 변경 실행
  const handleRenameSubmit = async () => {
    console.log('handleRenameSubmit 호출됨, selectedArchive:', selectedArchive, 'newName:', newName);
    if (selectedArchive && newName.trim()) {
      const restrictedNames = [
        ARCHIVE_NAMES.WORK,
        ARCHIVE_NAMES.CHATBOT,
        ARCHIVE_NAMES.CODE,
        ARCHIVE_NAMES.SAP,
      ];

      if (restrictedNames.some(name => name === newName.trim())) {
        console.log('제한된 이름 사용 시도:', newName.trim());
        setSnackbar({
          open: true,
          message: `"${newName}"는 기본 아카이브 이름으로 사용할 수 없습니다.`,
          severity: 'error',
        });
        return;
      }

      try {
        const user = authService.getCurrentUser();
        console.log('현재 사용자:', user);
        if (user) {
          console.log('아카이브 이름 변경 시작:', {
            userId: user.userId,
            archiveId: selectedArchive.archive_id,
            newName: newName.trim(),
          });
          await chatService.updateArchive(user.userId, selectedArchive.archive_id, newName.trim());
          console.log('아카이브 이름 변경 API 호출 완료, 목록 새로고침');
          await loadArchives();
          setSnackbar({
            open: true,
            message: '아카이브 이름이 변경되었습니다.',
            severity: 'success',
          });
        }
      } catch (error: any) {
        console.error('아카이브 이름 변경 실패:', error);
        setSnackbar({
          open: true,
          message: error?.response?.data?.message || error?.message || '아카이브 이름 변경에 실패했습니다.',
          severity: 'error',
        });
        return;
      }

      setRenameDialogOpen(false);
      setSelectedArchive(null);
    } else {
      console.warn('selectedArchive 또는 newName이 없습니다:', { selectedArchive, newName });
    }
  };

  // 삭제/초기화 버튼 클릭
  const handleDeleteClick = () => {
    console.log('🟣 handleDeleteClick 호출됨');
    console.log('🟣 selectedArchive:', selectedArchive);

    if (selectedArchive) {
      const isDefault = isDefaultArchive(selectedArchive);
      console.log('🟣 isDefault:', isDefault);

      // 메뉴 닫기
      setAnchorEl(null);

      // 메뉴 닫힘 애니메이션 완료 대기 후 다이얼로그 열기
      requestAnimationFrame(() => {
        setTimeout(() => {
          if (isDefault) {
            console.log('🟣 초기화 다이얼로그 열기');
            setResetDialogOpen(true);
          } else {
            console.log('🟣 삭제 다이얼로그 열기');
            deleteDialogOpenTimeRef.current = Date.now();
            setDeleteDialogOpen(true);
          }
        }, 150);
      });
    } else {
      console.log('🟣 selectedArchive 없음');
      setAnchorEl(null);
    }
  };

  // 아카이브 삭제 실행
  const handleDeleteConfirm = async () => {
    console.log('📍 handleDeleteConfirm 함수 진입');

    if (!selectedArchive) {
      console.log('❌ selectedArchive 없음 - 함수 종료');
      return;
    }

    console.log('📍 selectedArchive:', {
      id: selectedArchive.id,
      archive_id: selectedArchive.archive_id,
      archive_name: selectedArchive.archive_name
    });

    try {
      // 삭제할 아카이브 ID 저장
      const deletedArchiveId = selectedArchive.archive_id;
      const wasCurrentArchive = currentArchive?.archive_id === deletedArchiveId;

      console.log('🗑️ API 호출 시작 - archive_id:', deletedArchiveId);

      // API 호출
      await chatService.deleteArchive(deletedArchiveId);

      console.log('✅ API 호출 성공!');

      // 목록 새로고침
      console.log('🔄 아카이브 목록 새로고침 중...');
      const freshArchives = await loadArchives();
      console.log('✅ 목록 새로고침 완료, 아카이브 수:', freshArchives.length);

      // 삭제한 아카이브가 현재 선택된 아카이브였다면, 다른 아카이브 선택
      if (wasCurrentArchive && freshArchives.length > 0) {
        console.log('🔄 다른 아카이브 선택 중...');

        // 기본 아카이브(사내업무) 찾기
        const workArchive = freshArchives.find(a =>
          a.archive_name === '사내업무' && a.archive_type === ''
        );

        if (workArchive) {
          console.log('✅ 사내업무 아카이브 선택');
          selectArchive(workArchive);
        } else if (freshArchives.length > 0) {
          console.log('✅ 첫 번째 아카이브 선택');
          selectArchive(freshArchives[0]);
        }
      }

      // 성공 메시지
      setSnackbar({
        open: true,
        message: '아카이브가 삭제되었습니다.',
        severity: 'success',
      });
      console.log('✅ 삭제 완료!');

    } catch (error: any) {
      console.error('❌ 아카이브 삭제 실패:', error);
      console.error('❌ 에러 상세:', {
        message: error?.message,
        status: error?.response?.status,
        data: error?.response?.data
      });

      // 에러 메시지
      setSnackbar({
        open: true,
        message: error?.response?.data?.message || error?.message || '아카이브 삭제에 실패했습니다.',
        severity: 'error',
      });
    } finally {
      console.log('🔒 다이얼로그 닫기');
      // 다이얼로그 닫기
      setDeleteDialogOpen(false);
      setSelectedArchive(null);
    }
  };

  // 아카이브 초기화 실행
  const handleResetConfirm = async () => {
    console.log('🔄 handleResetConfirm 호출됨');
    console.log('🔄 selectedArchive:', selectedArchive);

    if (!selectedArchive) {
      console.error('❌ selectedArchive 없음');
      return;
    }

    try {
      const user = authService.getCurrentUser();
      if (!user) {
        console.error('❌ 사용자 정보 없음');
        setSnackbar({
          open: true,
          message: '사용자 정보를 찾을 수 없습니다.',
          severity: 'error',
        });
        return;
      }

      const archiveType = selectedArchive.archive_type || '';
      const archiveName = selectedArchive.archive_name;

      console.log('🔄 초기화 시작:', {
        userId: user.userId,
        archiveId: selectedArchive.archive_id,
        archiveType,
        archiveName,
      });

      // resetArchive는 새 아카이브 ID를 반환
      console.log('🗑️ Step 1: 기존 아카이브 삭제 API 호출...');
      const newArchiveId = await chatService.resetArchive(
        user.userId,
        selectedArchive.archive_id,
        archiveType,
        archiveName
      );

      console.log('✅ 초기화 완료! 새 아카이브 ID:', newArchiveId);
      console.log('🔄 Step 2: 아카이브 목록 새로고침...');
      const freshArchives = await loadArchives();
      console.log('✅ 목록 새로고침 완료, 아카이브 수:', freshArchives.length);

      // Flutter 로직: 새로 생성된 아카이브를 선택
      console.log('🔄 Step 3: 새 아카이브 선택...');
      const newArchive = freshArchives.find(a => a.archive_id === newArchiveId);
      if (newArchive) {
        console.log('✅ 새 아카이브 선택:', newArchive.archive_name);
        selectArchive(newArchive);
      } else {
        console.warn('⚠️ 새 아카이브를 찾을 수 없음:', newArchiveId);
        // 같은 이름의 아카이브를 찾아서 선택
        const sameNameArchive = freshArchives.find(a => a.archive_name === archiveName);
        if (sameNameArchive) {
          console.log('✅ 같은 이름의 아카이브 선택:', sameNameArchive.archive_name);
          selectArchive(sameNameArchive);
        }
      }

      setSnackbar({
        open: true,
        message: '대화 내용이 초기화되었습니다.',
        severity: 'success',
      });
      console.log('✅✅✅ 초기화 전체 완료!');

    } catch (error: any) {
      console.error('❌❌❌ 초기화 실패:', error);
      console.error('❌ 에러 상세:', {
        message: error?.message,
        status: error?.response?.status,
        data: error?.response?.data
      });

      setSnackbar({
        open: true,
        message: error?.response?.data?.message || error?.message || '아카이브 초기화에 실패했습니다.',
        severity: 'error',
      });
    } finally {
      console.log('🔒 초기화 다이얼로그 닫기');
      setResetDialogOpen(false);
      setSelectedArchive(null);
    }
  };

  // 커스텀 아카이브 일괄 삭제
  const handleBulkDelete = async () => {
    console.log('🗑️🗑️🗑️ 커스텀 아카이브 일괄 삭제 시작');

    try {
      // 기본 아카이브가 아닌 커스텀 아카이브만 필터링
      const customArchives = archives.filter(archive => !isDefaultArchive(archive));

      console.log(`📊 삭제 대상: ${customArchives.length}개의 커스텀 아카이브`);

      if (customArchives.length === 0) {
        setSnackbar({
          open: true,
          message: '삭제할 커스텀 아카이브가 없습니다.',
          severity: 'info',
        });
        return;
      }

      // 각 커스텀 아카이브 삭제
      let successCount = 0;
      let failCount = 0;

      for (const archive of customArchives) {
        try {
          console.log(`🗑️ 삭제 중: ${archive.archive_name} (${archive.archive_id})`);
          await chatService.deleteArchive(archive.archive_id);
          successCount++;
          console.log(`✅ 삭제 완료: ${archive.archive_name}`);
        } catch (error) {
          console.error(`❌ 삭제 실패: ${archive.archive_name}`, error);
          failCount++;
        }
      }

      console.log(`✅ 삭제 완료: ${successCount}개 성공, ${failCount}개 실패`);

      // 목록 새로고침
      const freshArchives = await loadArchives();

      // 현재 아카이브가 삭제되었다면 기본 아카이브 선택
      const currentStillExists = freshArchives.some(a => a.archive_id === currentArchive?.archive_id);
      if (!currentStillExists && freshArchives.length > 0) {
        const workArchive = freshArchives.find(a => a.archive_name === ARCHIVE_NAMES.WORK);
        if (workArchive) {
          selectArchive(workArchive);
        } else if (freshArchives.length > 0) {
          selectArchive(freshArchives[0]);
        }
      }

      setSnackbar({
        open: true,
        message: `${successCount}개의 아카이브가 삭제되었습니다.${failCount > 0 ? ` (${failCount}개 실패)` : ''}`,
        severity: successCount > 0 ? 'success' : 'error',
      });
      console.log('✅✅✅ 일괄 삭제 완료!');

    } catch (error: any) {
      console.error('❌❌❌ 일괄 삭제 실패:', error);
      setSnackbar({
        open: true,
        message: '아카이브 일괄 삭제에 실패했습니다.',
        severity: 'error',
      });
    } finally {
      setBulkDeleteDialogOpen(false);
    }
  };

  // 현재 사용자 정보
  const currentUser = authService.getCurrentUser();

  // 사이드바 콘텐츠 (Desktop/Mobile 공통) - MobileMainLayout 스타일로 통일
  const sidebarContent = (
    <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* 사용자 정보 헤더 - MobileMainLayout 스타일 */}
      <Box
        sx={{
          p: 2,
          background: `linear-gradient(180deg, ${colorScheme.sidebarGradientStart}, ${colorScheme.sidebarGradientEnd})`,
          color: colorScheme.sidebarTextColor,
          borderBottom: `1px solid ${colorScheme.textFieldBorderColor}`,
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1.5 }}>
          <Avatar sx={{
            bgcolor: isDark ? 'rgba(79, 195, 247, 0.2)' : '#e3f2fd',
            color: colorScheme.primaryColor,
            width: 40,
            height: 40
          }}>
            <ChatIcon sx={{ fontSize: 20 }} />
          </Avatar>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography
              variant="subtitle1"
              sx={{
                fontWeight: 'bold',
                fontSize: '1rem',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                maxWidth: '100%'
              }}
            >
              {currentUser?.userId || '사용자'}
            </Typography>
            <Typography variant="body2" sx={{ opacity: 0.7, fontSize: '0.8rem' }}>
              ASPN AI Agent
            </Typography>
          </Box>
        </Box>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, justifyContent: 'space-between' }}>
          <Chip
            label="모바일 웹 버전"
            size="small"
            sx={{
              bgcolor: isDark ? 'rgba(79, 195, 247, 0.2)' : '#e3f2fd',
              color: colorScheme.primaryColor,
              fontSize: '0.75rem',
              height: 22
            }}
          />
          {/* 검색 버튼 */}
          <Tooltip title="대화 내용 검색" placement="right">
            <IconButton
              onClick={() => {
                setSearchDialogOpen(true);
                if (isMobile) setMobileMenuOpen(false);
              }}
              size="small"
              sx={{
                color: colorScheme.primaryColor,
                opacity: 0.7,
                '&:hover': {
                  opacity: 1,
                  bgcolor: 'transparent',
                },
              }}
            >
              <SearchIcon sx={{ fontSize: 20 }} />
            </IconButton>
          </Tooltip>
          {/* 새 채팅방 버튼 */}
          <Tooltip title="새 채팅방 만들기" placement="right">
            <IconButton
              onClick={async () => {
                try {
                  const currentUser = authService.getCurrentUser();
                  if (currentUser) {
                    console.log('➕ 새 아카이브 생성 시작');

                    // 기존 아카이브 중 "새 대화 N" 형식의 최대 번호 찾기
                    const newChatNumbers = archives
                      .map(a => {
                        const match = a.archive_name.match(/^새 대화 (\d+)$/);
                        return match ? parseInt(match[1], 10) : 0;
                      })
                      .filter(n => n > 0);

                    const nextNumber = newChatNumbers.length > 0 ? Math.max(...newChatNumbers) + 1 : 1;
                    const newArchiveName = `새 대화 ${nextNumber}`;

                    console.log('📝 새 아카이브 이름:', newArchiveName);

                    const response = await chatService.createArchive(currentUser.userId, '', '');
                    console.log('✅ 새 아카이브 생성 완료:', response.archive.archive_id);

                    // 이름 변경
                    await chatService.updateArchive(currentUser.userId, response.archive.archive_id, newArchiveName);
                    console.log('✅ 이름 변경 완료:', newArchiveName);

                    const freshArchives = await loadArchives();
                    const newArchive = freshArchives.find(a => a.archive_id === response.archive.archive_id);

                    if (newArchive) {
                      console.log('✅ 새 아카이브 선택:', newArchive.archive_name);
                      selectArchive(newArchive);
                    } else {
                      console.warn('⚠️ 생성된 아카이브를 찾을 수 없음');
                    }

                    if (isMobile) setMobileMenuOpen(false);
                  }
                } catch (error) {
                  console.error('새 채팅방 생성 실패:', error);
                  alert('새 채팅방 생성에 실패했습니다.');
                }
              }}
              size="small"
              sx={{
                color: colorScheme.primaryColor,
                opacity: 0.7,
                '&:hover': {
                  opacity: 1,
                  bgcolor: 'transparent',
                },
              }}
            >
              <AddIcon sx={{ fontSize: 19 }} />
            </IconButton>
          </Tooltip>
          {/* 일괄 삭제 버튼 */}
          <Tooltip title="커스텀 아카이브 일괄 삭제" placement="right">
            <IconButton
              onClick={() => {
                setBulkDeleteDialogOpen(true);
                if (isMobile) setMobileMenuOpen(false);
              }}
              size="small"
              sx={{
                color: isDark ? '#ff6b6b' : '#d32f2f',
                opacity: 0.7,
                '&:hover': {
                  opacity: 1,
                  bgcolor: 'transparent',
                },
              }}
            >
              <DeleteSweepIcon sx={{ fontSize: 20 }} />
            </IconButton>
          </Tooltip>
        </Box>
      </Box>

      <Divider sx={{ borderColor: colorScheme.textFieldBorderColor }} />

      {/* 채팅방 목록 */}
      <Box sx={{ flex: 1, overflow: 'auto', px: 1, minHeight: 0 }}>
        <List sx={{ py: 0.5 }}>
          {archives.map((archive) => {
            const isSelected = currentArchive?.archive_id === archive.archive_id;
            const color = getArchiveColor(archive, isDark);
            const tag = getArchiveTag(archive);
            const description = getArchiveDescription(archive);

            return (
              <Box key={archive.archive_id}>
                <ListItemButton
                  selected={isSelected}
                  onClick={() => {
                    selectArchive(archive);
                    if (isMobile) setMobileMenuOpen(false);
                  }}
                  component="div"
                  sx={{
                    borderRadius: 2,
                    mb: 0.5,
                    color: colorScheme.sidebarTextColor,
                    pr: 6,
                    '&.Mui-selected': {
                      bgcolor: isDark ? 'rgba(79, 195, 247, 0.15)' : '#e3f2fd',
                      color: colorScheme.primaryColor,
                      '&:hover': {
                        bgcolor: isDark ? 'rgba(79, 195, 247, 0.25)' : '#bbdefb',
                      },
                      '& .MuiListItemIcon-root': {
                        color: colorScheme.primaryColor,
                      },
                    },
                    '&:hover': {
                      bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#f5f5f5',
                      '& .menu-icon-button': {
                        opacity: 1,
                        visibility: 'visible',
                      },
                    },
                    '& .menu-icon-button': {
                      opacity: 0,
                      visibility: 'hidden',
                      transition: 'opacity 0.2s ease, visibility 0.2s ease',
                    },
                    '&.Mui-selected .menu-icon-button': {
                      opacity: 1,
                      visibility: 'visible',
                    },
                  }}
                >
                  <ListItemIcon sx={{ minWidth: 40 }}>
                    {getIcon(archive)}
                  </ListItemIcon>

                  <ListItemText
                    primary={
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                        <Typography
                          variant="body2"
                          sx={{
                            fontWeight: isSelected ? 600 : 400,
                            fontSize: '0.875rem',
                            flex: 1,
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                          }}
                        >
                          {archive.archive_name}
                        </Typography>
                        {tag && (
                          <Chip
                            label={tag}
                            size="small"
                            sx={{
                              height: 18,
                              fontSize: '0.625rem',
                              fontWeight: 'bold',
                              bgcolor: `${color}33`,
                              color: color,
                              borderRadius: '4px',
                              '& .MuiChip-label': {
                                px: 0.75,
                                py: 0.25,
                              },
                            }}
                          />
                        )}
                      </Box>
                    }
                  />

                  <IconButton
                    className="menu-icon-button"
                    size="small"
                    onClick={(e) => {
                      e.stopPropagation();
                      handleMenuOpen(e, archive);
                    }}
                    sx={{
                      position: 'absolute',
                      right: 8,
                      top: '50%',
                      transform: 'translateY(-50%)',
                      color: colorScheme.hintTextColor,
                    }}
                    id={`archive-menu-button-${archive.archive_id}`}
                    aria-label="아카이브 메뉴"
                  >
                    <MoreVertIcon fontSize="small" />
                  </IconButton>
                </ListItemButton>

                {/* 설명 표시 */}
                {description && (
                  <Box sx={{ px: 2, pb: 0.5 }}>
                    <Typography
                      variant="caption"
                      sx={{
                        color: colorScheme.hintTextColor,
                        fontSize: '0.7rem',
                        lineHeight: 1.3,
                        display: 'block',
                      }}
                    >
                      {description}
                    </Typography>
                  </Box>
                )}
              </Box>
            );
          })}
        </List>
      </Box>

      {/* 하단 고정 영역 (업무 메뉴 + 하단 메뉴) */}
      <Box sx={{ flexShrink: 0 }}>
        <Divider sx={{ mx: 2, borderColor: colorScheme.textFieldBorderColor }} />

        {/* 업무 메뉴 섹션 - MobileMainLayout 스타일 */}
        <Box sx={{ px: 2, py: 1 }}>
          <Typography variant="caption" sx={{ color: colorScheme.hintTextColor, fontWeight: 600 }}>
            업무
          </Typography>
        </Box>
        <List sx={{ px: 1 }}>
          {/* 전자결재 메뉴 (임시 숨김) */}
          {/* <ListItemButton
            onClick={() => {
              navigate('/approval');
              if (isMobile) setMobileMenuOpen(false);
            }}
            selected={location.pathname === '/approval'}
            sx={{
              borderRadius: 2,
              mb: 0.5,
              color: colorScheme.sidebarTextColor,
              '&.Mui-selected': {
                backgroundColor: isDark ? 'rgba(79, 195, 247, 0.15)' : '#e3f2fd',
                color: colorScheme.primaryColor,
                '&:hover': {
                  backgroundColor: isDark ? 'rgba(79, 195, 247, 0.25)' : '#bbdefb',
                },
                '& .MuiListItemIcon-root': {
                  color: colorScheme.primaryColor,
                },
              },
              '&:hover': {
                backgroundColor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#f5f5f5',
              },
            }}
          >
            <ListItemIcon sx={{ color: location.pathname === '/approval' ? colorScheme.primaryColor : colorScheme.hintTextColor }}>
              <DescriptionIcon />
            </ListItemIcon>
            <ListItemText
              primary="전자결재"
              primaryTypographyProps={{
                fontSize: '0.9rem',
                fontWeight: location.pathname === '/approval' ? 600 : 400,
              }}
            />
          </ListItemButton> */}

          {/* 휴가관리 */}
          <ListItemButton
            onClick={() => {
              navigate('/leave');
              if (isMobile) setMobileMenuOpen(false);
            }}
            selected={location.pathname === '/leave'}
            sx={{
              borderRadius: 2,
              mb: 0.5,
              color: colorScheme.sidebarTextColor,
              '&.Mui-selected': {
                backgroundColor: isDark ? 'rgba(79, 195, 247, 0.15)' : '#e3f2fd',
                color: colorScheme.primaryColor,
                '&:hover': {
                  backgroundColor: isDark ? 'rgba(79, 195, 247, 0.25)' : '#bbdefb',
                },
                '& .MuiListItemIcon-root': {
                  color: colorScheme.primaryColor,
                },
              },
              '&:hover': {
                backgroundColor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#f5f5f5',
              },
            }}
          >
            <ListItemIcon sx={{ color: location.pathname === '/leave' ? colorScheme.primaryColor : colorScheme.hintTextColor }}>
              <BeachAccessIcon />
            </ListItemIcon>
            <ListItemText
              primary="휴가 관리"
              primaryTypographyProps={{
                fontSize: '0.9rem',
                fontWeight: location.pathname === '/leave' ? 600 : 400,
              }}
            />
          </ListItemButton>

        </List>

        <Divider sx={{ mx: 2, borderColor: colorScheme.textFieldBorderColor }} />

        {/* 하단 메뉴 - MobileMainLayout 스타일 */}
        <List sx={{ px: 1 }}>
          <ListItemButton
            onClick={() => {
              navigate('/settings');
              if (isMobile) setMobileMenuOpen(false);
            }}
            selected={location.pathname === '/settings'}
            sx={{
              borderRadius: 2,
              mb: 0.5,
              color: colorScheme.sidebarTextColor,
              '&.Mui-selected': {
                backgroundColor: isDark ? 'rgba(79, 195, 247, 0.15)' : '#e3f2fd',
                color: colorScheme.primaryColor,
                '&:hover': {
                  backgroundColor: isDark ? 'rgba(79, 195, 247, 0.25)' : '#bbdefb',
                },
                '& .MuiListItemIcon-root': {
                  color: colorScheme.primaryColor,
                },
              },
              '&:hover': {
                backgroundColor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#f5f5f5',
              },
            }}
          >
            <ListItemIcon sx={{ color: location.pathname === '/settings' ? colorScheme.primaryColor : colorScheme.hintTextColor }}>
              <SettingsIcon />
            </ListItemIcon>
            <ListItemText
              primary="설정"
              primaryTypographyProps={{
                fontSize: '0.9rem',
                fontWeight: location.pathname === '/settings' ? 600 : 400,
              }}
            />
          </ListItemButton>

          <ListItemButton
            onClick={() => {
              setHelpDialogOpen(true);
              if (isMobile) setMobileMenuOpen(false);
            }}
            selected={helpDialogOpen}
            sx={{
              borderRadius: 2,
              mb: 0.5,
              color: colorScheme.sidebarTextColor,
              '&.Mui-selected': {
                backgroundColor: isDark ? 'rgba(79, 195, 247, 0.15)' : '#e3f2fd',
                color: colorScheme.primaryColor,
                '&:hover': {
                  backgroundColor: isDark ? 'rgba(79, 195, 247, 0.25)' : '#bbdefb',
                },
                '& .MuiListItemIcon-root': {
                  color: colorScheme.primaryColor,
                },
              },
              '&:hover': {
                backgroundColor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#f5f5f5',
              },
            }}
          >
            <ListItemIcon sx={{ color: helpDialogOpen ? colorScheme.primaryColor : colorScheme.hintTextColor }}>
              <HelpIcon />
            </ListItemIcon>
            <ListItemText
              primary="도움말"
              primaryTypographyProps={{
                fontSize: '0.9rem',
                fontWeight: helpDialogOpen ? 600 : 400,
              }}
            />
          </ListItemButton>

          <ListItemButton
            onClick={() => {
              authService.logout();
              if (isMobile) setMobileMenuOpen(false);
            }}
            sx={{
              borderRadius: 2,
              color: isDark ? '#ff6b6b' : '#d32f2f',
              '&:hover': {
                backgroundColor: isDark ? 'rgba(255, 107, 107, 0.1)' : '#ffebee',
                color: isDark ? '#ff8787' : '#b71c1c',
              },
            }}
          >
            <ListItemIcon sx={{ color: 'inherit' }}>
              <LogoutIcon />
            </ListItemIcon>
            <ListItemText
              primary="로그아웃"
              primaryTypographyProps={{ fontSize: '0.9rem' }}
            />
          </ListItemButton>

          {/* 사내AI 공모전 메뉴 (임시 숨김) */}
          {/* <ListItemButton
            onClick={() => {
              navigate('/contest');
              if (isMobile) setMobileMenuOpen(false);
            }}
            selected={location.pathname === '/contest'}
            sx={{
              borderRadius: 2,
              mb: 0.5,
              color: colorScheme.sidebarTextColor,
              '&.Mui-selected': {
                backgroundColor: isDark ? 'rgba(79, 195, 247, 0.15)' : '#e3f2fd',
                color: colorScheme.primaryColor,
                '&:hover': {
                  backgroundColor: isDark ? 'rgba(79, 195, 247, 0.25)' : '#bbdefb',
                },
                '& .MuiListItemIcon-root': {
                  color: colorScheme.primaryColor,
                },
              },
              '&:hover': {
                backgroundColor: isDark ? 'rgba(255, 255, 255, 0.05)' : '#f5f5f5',
              },
            }}
          >
            <ListItemIcon sx={{ color: location.pathname === '/contest' ? colorScheme.primaryColor : colorScheme.hintTextColor }}>
              <EmojiEventsIcon />
            </ListItemIcon>
            <ListItemText
              primary="사내AI 공모전"
              primaryTypographyProps={{
                fontSize: '0.9rem',
                fontWeight: location.pathname === '/contest' ? 600 : 400,
              }}
            />
          </ListItemButton> */}
        </List>
      </Box>
    </Box>
  );

  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: { xs: 'column', md: 'row' },
        height: '100vh',
        overflow: 'hidden',
        width: '100%',
      }}
    >
      {/* 모바일 상단 헤더 (모바일에서만 표시) */}
      <MobileOnly>
        <AppBar
          position="static"
          sx={{
            background: `linear-gradient(90deg, ${colorScheme.appBarGradientStart}, ${colorScheme.appBarGradientEnd})`,
            flexShrink: 0,
            zIndex: (theme) => theme.zIndex.drawer + 1,
            // Safe Area handling for top
            pt: 'var(--sat)',
          }}
        >
          <Toolbar variant="dense" sx={{ minHeight: { xs: 48 } }}>
            <IconButton
              edge="start"
              color="inherit"
              onClick={() => setMobileMenuOpen(true)}
              sx={{ mr: 2, color: colorScheme.appBarTextColor }}
            >
              <MenuIcon />
            </IconButton>
            <Typography variant="h6" component="div" sx={{ flexGrow: 1, fontSize: '1rem', color: colorScheme.appBarTextColor }}>
              {currentArchive?.archive_name || 'ASPN AI Agent'}
            </Typography>
            <GiftButton />
            <IconButton
              color="inherit"
              onClick={() => openElectronicApproval()}
              sx={{ color: colorScheme.appBarTextColor }}
            >
              <DescriptionIcon />
            </IconButton>
            {currentUser && <NotificationBell userId={currentUser!.userId} />}
          </Toolbar>
        </AppBar>
      </MobileOnly>

      {/* 데스크톱 상단 버튼들 (우측 상단 고정) */}
      <DesktopOnly>
        <Box
          sx={{
            position: 'fixed',
            top: 12,
            right: 16,
            zIndex: (theme) => theme.zIndex.drawer + 2,
            display: 'flex',
            gap: 1,
          }}
        >
          <GiftButton />
          <IconButton
            color="inherit"
            onClick={() => openElectronicApproval()}
            sx={{ color: colorScheme.textColor }}
          >
            <DescriptionIcon />
          </IconButton>
          {currentUser && <NotificationBell userId={currentUser.userId} />}
        </Box>
      </DesktopOnly>

      {/* 메인 콘텐츠 영역 (사이드바 + 채팅 영역) */}
      <Box
        sx={{
          display: 'flex',
          flex: 1,
          overflow: 'hidden',
          width: '100%',
          height: {
            xs: 'calc(100vh - 48px - var(--sat))', // 모바일: AppBar 및 Safe Area 제외
            md: '100vh', // 데스크톱: 전체 높이
          },
        }}
      >
        {/* 사이드바 - Desktop: permanent, Mobile: temporary - Flutter 스타일 */}
        <MobileOnly>
          <Drawer
            variant="temporary"
            open={mobileMenuOpen}
            onClose={() => setMobileMenuOpen(false)}
            ModalProps={{
              keepMounted: true, // 모바일에서 성능 향상
              disableAutoFocus: true,
            }}
            sx={{
              '& .MuiDrawer-paper': {
                width: SIDEBAR_WIDTH,
                boxSizing: 'border-box',
                bgcolor: colorScheme.sidebarBackgroundColor,
                borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                // Safe area padding for the drawer content if needed
                pl: 'var(--sal)',
              },
            }}
          >
            {sidebarContent}
          </Drawer>
        </MobileOnly>

        <DesktopOnly>
          <Drawer
            variant="permanent"
            open={true}
            sx={{
              width: SIDEBAR_WIDTH,
              flexShrink: 0,
              '& .MuiDrawer-paper': {
                width: SIDEBAR_WIDTH,
                boxSizing: 'border-box',
                bgcolor: colorScheme.sidebarBackgroundColor,
                borderRight: `1px solid ${colorScheme.textFieldBorderColor}`,
                position: 'relative',
                height: '100vh',
              },
            }}
          >
            {sidebarContent}
          </Drawer>
        </DesktopOnly>

        {/* 메인 채팅 영역 */}
        <Box
          component="main"
          sx={{
            flexGrow: 1,
            width: {
              xs: '100%', // 모바일: 전체 너비
              md: `calc(100% - ${SIDEBAR_WIDTH}px)`, // 데스크톱: 사이드바 제외
            },
            height: '100%',
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <ChatArea />
        </Box>
      </Box>

      {/* 검색 다이얼로그 */}
      <SearchDialog
        open={searchDialogOpen}
        onClose={() => setSearchDialogOpen(false)}
        archives={archives}
        onSelectArchive={(archive) => {
          selectArchive(archive);
          setSearchDialogOpen(false);
        }}
        onSelectMessage={(archiveId, chatId) => {
          console.log('메시지 선택:', archiveId, chatId);
        }}
      />

      {/* 컨텍스트 메뉴 */}
      {/* 도움말 다이얼로그 */}
      <HelpDialog
        open={helpDialogOpen}
        onClose={() => setHelpDialogOpen(false)}
      />

      <Menu
        anchorEl={anchorEl}
        open={Boolean(anchorEl)}
        onClose={handleMenuClose}
        MenuListProps={{
          'aria-labelledby': 'archive-menu-button',
          disableListWrap: true,
          autoFocus: false,
          autoFocusItem: false,
        }}
        slotProps={{
          paper: {
            sx: {
              zIndex: (theme) => theme.zIndex.modal + 1, // Modal 위에 표시
            },
          },
        }}
        disablePortal={false} // Portal 사용
        disableAutoFocus={true} // 자동 포커스 비활성화로 aria-hidden 문제 방지
        disableEnforceFocus={true} // 포커스 강제 비활성화
        disableRestoreFocus={true} // 메뉴 닫을 때 포커스 복원 비활성화
        disableScrollLock={true} // 스크롤 잠금 비활성화
      >
        {selectedArchive && !isDefaultArchive(selectedArchive) && (
          <MenuItem
            onClick={(e) => {
              e.stopPropagation();
              handleRenameClick();
            }}
          >
            <ListItemIcon>
              <EditIcon fontSize="small" />
            </ListItemIcon>
            <ListItemText>이름 변경</ListItemText>
          </MenuItem>
        )}
        <MenuItem
          onClick={(e) => {
            e.stopPropagation();
            handleDeleteClick();
          }}
        >
          <ListItemIcon>
            {selectedArchive && isDefaultArchive(selectedArchive) ? (
              <RefreshIcon fontSize="small" />
            ) : (
              <DeleteIcon fontSize="small" color="error" />
            )}
          </ListItemIcon>
          <ListItemText>
            {selectedArchive && isDefaultArchive(selectedArchive) ? '초기화' : '삭제'}
          </ListItemText>
        </MenuItem>
      </Menu>

      {/* 이름 변경 다이얼로그 */}
      <Dialog
        open={renameDialogOpen}
        onClose={() => setRenameDialogOpen(false)}
        disableEnforceFocus
      >
        <DialogTitle>아카이브 이름 변경</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            label="새 이름"
            fullWidth
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            onKeyPress={(e) => {
              if (e.key === 'Enter') {
                handleRenameSubmit();
              }
            }}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => {
            console.log('이름 변경 다이얼로그 취소 버튼 클릭');
            setRenameDialogOpen(false);
          }}>취소</Button>
          <Button onClick={() => {
            console.log('이름 변경 버튼 클릭됨!');
            handleRenameSubmit();
          }} variant="contained">
            변경
          </Button>
        </DialogActions>
      </Dialog>

      {/* 삭제 확인 다이얼로그 */}
      <Dialog
        open={deleteDialogOpen}
        onClose={() => {
          console.log('🔵 다이얼로그 onClose');
          setDeleteDialogOpen(false);
          setSelectedArchive(null);
        }}
        PaperProps={{
          onMouseMove: () => {
            console.log('🟠 다이얼로그 내부에서 마우스 움직임 감지됨');
          },
          sx: {
            zIndex: 9999,
          }
        }}
        slotProps={{
          backdrop: {
            sx: {
              zIndex: (theme) => theme.zIndex.drawer + 1,
            },
          },
        }}
      >
        <DialogTitle
          onMouseEnter={() => console.log('🔷 DialogTitle 마우스 진입')}
        >
          아카이브 삭제
        </DialogTitle>
        <DialogContent
          onMouseEnter={() => console.log('🔷 DialogContent 마우스 진입')}
        >
          <DialogContentText>
            "{selectedArchive?.archive_name}" 아카이브를 삭제하시겠습니까?
            <br />
            이 작업은 되돌릴 수 없습니다.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => {
            setDeleteDialogOpen(false);
            setSelectedArchive(null);
          }}>취소</Button>
          <Button
            onMouseEnter={() => {
              console.log('🟢 삭제 버튼 위에 마우스 올림');
              console.log('🟢 버튼 disabled 상태:', !selectedArchive);
            }}
            onMouseDown={(e) => {
              console.log('🟡 삭제 버튼 mouseDown');
              e.stopPropagation();
            }}
            onClick={async (e) => {
              console.log('🔴 삭제 버튼 onClick 발생!');
              e.stopPropagation();
              e.preventDefault();

              if (!selectedArchive) {
                console.log('❌ selectedArchive 없음');
                return;
              }

              console.log('✅ selectedArchive 있음:', selectedArchive.archive_id);
              console.log('🚀 handleDeleteConfirm 호출 시작...');

              try {
                await handleDeleteConfirm();
                console.log('✅ handleDeleteConfirm 완료');
              } catch (error) {
                console.error('❌ 삭제 중 에러:', error);
              }
            }}
            variant="contained"
            color="error"
            disabled={!selectedArchive}
          >
            삭제
          </Button>
        </DialogActions>
      </Dialog>

      {/* 초기화 확인 다이얼로그 */}
      <Dialog
        open={resetDialogOpen}
        onClose={() => {
          console.log('🔵 초기화 다이얼로그 onClose');
          setResetDialogOpen(false);
          setSelectedArchive(null);
        }}
        PaperProps={{
          onMouseMove: () => {
            console.log('🟠 초기화 다이얼로그 내부에서 마우스 움직임');
          },
          sx: {
            zIndex: 9999,
          }
        }}
        slotProps={{
          backdrop: {
            sx: {
              zIndex: (theme) => theme.zIndex.drawer + 1,
            },
          },
        }}
      >
        <DialogTitle
          onMouseEnter={() => console.log('🔷 초기화 DialogTitle 마우스 진입')}
        >
          기본 아카이브 초기화
        </DialogTitle>
        <DialogContent
          onMouseEnter={() => console.log('🔷 초기화 DialogContent 마우스 진입')}
        >
          <DialogContentText>
            "{selectedArchive?.archive_name}"의 대화 내용을 초기화하시겠습니까?
            <br />
            <br />
            초기화하면 기존 대화 내용이 모두 삭제되고 새로운 동일 유형의 아카이브가 생성됩니다.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button
            onMouseEnter={() => console.log('🟢 취소 버튼 마우스 진입')}
            onMouseDown={(e) => {
              console.log('🟡 취소 버튼 mouseDown');
              e.stopPropagation();
            }}
            onClick={(e) => {
              console.log('🔴 취소 버튼 클릭됨!');
              e.stopPropagation();
              setResetDialogOpen(false);
              setSelectedArchive(null);
            }}
          >
            취소
          </Button>
          <Button
            onMouseEnter={() => {
              console.log('🟢 초기화 버튼 마우스 진입');
            }}
            onMouseDown={(e) => {
              console.log('🟡 초기화 버튼 mouseDown');
              e.stopPropagation();
            }}
            onClick={async (e) => {
              console.log('🔴🔴🔴 초기화 버튼 onClick 발생!');
              e.stopPropagation();
              e.preventDefault();

              try {
                await handleResetConfirm();
              } catch (error) {
                console.error('❌ 초기화 중 에러:', error);
              }
            }}
            variant="contained"
            color="primary"
          >
            초기화
          </Button>
        </DialogActions>
      </Dialog>

      {/* 일괄 삭제 확인 다이얼로그 */}
      <Dialog
        open={bulkDeleteDialogOpen}
        onClose={() => {
          setBulkDeleteDialogOpen(false);
        }}
        PaperProps={{
          sx: {
            zIndex: 9999,
          }
        }}
        slotProps={{
          backdrop: {
            sx: {
              zIndex: (theme) => theme.zIndex.drawer + 1,
            },
          },
        }}
      >
        <DialogTitle>커스텀 아카이브 일괄 삭제</DialogTitle>
        <DialogContent>
          <DialogContentText>
            기본 아카이브를 제외한 모든 커스텀 아카이브를 삭제하시겠습니까?
            <br />
            <br />
            <strong>삭제 대상: {archives.filter(a => !isDefaultArchive(a)).length}개</strong>
            <br />
            이 작업은 되돌릴 수 없습니다.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button
            onClick={() => {
              setBulkDeleteDialogOpen(false);
            }}
          >
            취소
          </Button>
          <Button
            onClick={async (e) => {
              e.stopPropagation();
              e.preventDefault();
              await handleBulkDelete();
            }}
            variant="contained"
            color="error"
          >
            전체 삭제
          </Button>
        </DialogActions>
      </Dialog>

      {/* 알림 스낵바 */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={3000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          onClose={() => setSnackbar({ ...snackbar, open: false })}
          severity={snackbar.severity}
          sx={{ width: '100%' }}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>

      {/* 휴가 신청 초안 패널 */}
      <LeaveRequestDraftPanel />
      <ElectronicApprovalDraftPanel />
    </Box>
  );
}
