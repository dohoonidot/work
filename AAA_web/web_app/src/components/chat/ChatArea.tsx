import { useEffect, useRef, useState } from 'react';
import {
  Box,
  Paper,
  TextField,
  IconButton,
  Typography,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  CircularProgress,
  Avatar,
  useMediaQuery,
  useTheme,
  Divider,
  Chip,
  Stack,
  Switch,
  FormControlLabel,
  Tooltip,
  Popover,
  List,
  ListItem,
  ListItemText,
} from '@mui/material';
import {
  Send as SendIcon,
  SmartToy as BotIcon,
  Person as PersonIcon,
  ArrowBack as ArrowBackIcon,
  AttachFile as AttachFileIcon,
  Close as CloseIcon,
  Web as WebIcon,
  Settings as SettingsIcon,
} from '@mui/icons-material';
import { useChatStore, isDefaultArchive } from '../../store/chatStore';
import { useThemeStore } from '../../store/themeStore';
import { useLeaveRequestDraftStore } from '../../store/leaveRequestDraftStore';
import { useElectronicApprovalStore } from '../../store/electronicApprovalStore';
import chatService from '../../services/chatService';
import authService from '../../services/authService';
import FileService, { type FileAttachment } from '../../services/fileService';
import type { ChatMessage } from '../../types';
import type { LeaveTriggerData } from '../../types/leaveRequest';
import MessageRenderer from './MessageRenderer';
import AiModelSelector from './AiModelSelector';

export default function ChatArea() {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const { colorScheme } = useThemeStore();
  const isDark = colorScheme.name === 'Dark';
  const { openPanel } = useLeaveRequestDraftStore();
  const { openPanel: openElectronicApproval } = useElectronicApprovalStore();

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const textFieldRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // 파일 첨부 상태
  const [attachedFiles, setAttachedFiles] = useState<FileAttachment[]>([]);

  // 이미지 파일 미리보기 URL 상태
  const [imagePreviews, setImagePreviews] = useState<Record<string, string>>({});

  // 모바일 설정 메뉴 상태
  const [settingsAnchorEl, setSettingsAnchorEl] = useState<HTMLElement | null>(null);
  const settingsMenuOpen = Boolean(settingsAnchorEl);

  const {
    currentArchive,
    archives,
    messages,
    inputMessage,
    selectedModel,
    isWebSearchEnabled,
    selectedSapModule,
    isStreaming,
    streamingMessage,
    setInputMessage,
    setSelectedModel,
    setWebSearchEnabled,
    setSelectedSapModule,
    setStreaming,
    setStreamingMessage,
    appendStreamingMessage,
    addMessage,
    setMessages,
    setCurrentArchive,
  } = useChatStore();

  const user = authService.getCurrentUser();

  // 아카이브 메시지 로드
  const loadArchiveMessages = async (archive: any) => {
    try {
      const messages = await chatService.getArchiveDetail(archive.archive_id);
      setMessages(messages);
    } catch (error) {
      console.error('ChatArea: 메시지 로드 실패:', error);
      setMessages([]);
    }
  };

  // 자동 스크롤
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, streamingMessage]);

  // 컴포넌트 마운트 시 텍스트 필드에 포커스
  useEffect(() => {
    const focusTextField = () => {
      try {
        if (inputRef.current) {
          inputRef.current.focus();
          // 커서를 텍스트 끝으로 이동 (값이 있는 경우에만)
          if (inputRef.current.value !== undefined && inputRef.current.value !== null) {
            const length = inputRef.current.value.length || 0;
            inputRef.current.setSelectionRange(length, length);
          }
        }
      } catch (error) {
        console.warn('초기 포커스 설정 중 에러 (무시 가능):', error);
      }
    };

    const timer = setTimeout(() => {
      focusTextField();
      // UI가 완전히 렌더링된 후 다시 포커스
      setTimeout(focusTextField, 100);
    }, 500);

    return () => clearTimeout(timer);
  }, [currentArchive]);

  // 현재 아카이브가 변경될 때마다 메시지 로드
  useEffect(() => {
    if (currentArchive) {
      loadArchiveMessages(currentArchive);
    }
  }, [currentArchive]); // eslint-disable-line react-hooks/exhaustive-deps

  // 컴포넌트 언마운트 시 미리보기 URL 정리
  useEffect(() => {
    return () => {
      // 모든 미리보기 URL 정리
      Object.values(imagePreviews).forEach(url => {
        URL.revokeObjectURL(url);
      });
    };
  }, []);

  // 메시지 전송
  const handleSend = async () => {
    if (!inputMessage.trim() || isStreaming || !currentArchive || !user) return;

    const userMessage: ChatMessage = {
      chat_id: Date.now(),
      archive_id: currentArchive.archive_id,
      message: inputMessage.trim(),
      role: 0, // 사용자
      timestamp: new Date().toISOString(),
    };

    // 사용자 메시지 추가
    addMessage(userMessage);
    const messageText = inputMessage.trim();
    setInputMessage('');

    // 스트리밍 시작
    setStreaming(true);
    setStreamingMessage('');

    try {
      let fullResponse: string;
      const handleLeaveTrigger = (triggerData: LeaveTriggerData) => {
        console.log('[ChatArea] 휴가 트리거 수신:', triggerData);

        const formatDate = (isoDate: string): string => {
          if (!isoDate) return '';
          return isoDate.split('T')[0];
        };

        openPanel({
          userId: triggerData.user_id,
          startDate: formatDate(triggerData.start_date),
          endDate: formatDate(triggerData.end_date),
          leaveType: triggerData.leave_type,
          reason: triggerData.reason || '',
          halfDaySlot: triggerData.half_day_slot || 'ALL',
          approvalLine: triggerData.approval_line?.map(approver => ({
            approverId: approver.approver_id,
            approverName: approver.approver_name,
            approvalSeq: approver.approval_seq,
          })) || [],
          ccList: triggerData.cc_list?.map(cc => ({
            name: cc.name,
            userId: cc.user_id,
            department: '',
          })) || [],
          leaveStatus: triggerData.leave_status?.map(status => ({
            leaveType: status.leave_type,
            totalDays: status.total_days,
            remainDays: status.remain_days,
          })) || [],
        });
      };

      const handleApprovalTrigger = (approvalData: any) => {
        if (!approvalData?.approval_type) return;
        console.log('[ChatArea] 전자결재 트리거 수신:', approvalData);
        openElectronicApproval(approvalData);
      };

      // 파일 첨부가 있는 경우
      if (attachedFiles.length > 0) {

        // SAP 모듈 값 가져오기 (소문자로 변환)
        const moduleValue = isSapArchive() && selectedSapModule ? selectedSapModule.toLowerCase() : '';
        
        // 모듈 선택 상태 로그 (파일 첨부)
        console.log('📎 파일 첨부 메시지 전송 - 모듈 상태:', {
          isSapArchive: isSapArchive(),
          selectedSapModule,
          moduleValue,
          archiveName: currentArchive.archive_name,
          archiveType: currentArchive.archive_type,
        });
        
        const stream = isModelSelectorArchive()
          ? await FileService.sendMessageWithModelAndFiles(
              currentArchive.archive_id,
              user.userId,
              messageText,
              attachedFiles,
              selectedModel,
              currentArchive.archive_type || '',
              moduleValue,
              isWebSearchEnabled
            )
          : await FileService.sendMessageWithFiles(
              currentArchive.archive_id,
              user.userId,
              messageText,
              attachedFiles,
              currentArchive.archive_type || '',
              moduleValue,
              isWebSearchEnabled
            );

        fullResponse = await chatService.processStream({
          stream,
          onChunk: (chunk: string) => {
            appendStreamingMessage(chunk);
          },
          onLeaveTrigger: handleLeaveTrigger,
          onApprovalTrigger: handleApprovalTrigger,
        });
        
        // 파일 목록 초기화 및 미리보기 URL 정리
        setAttachedFiles([]);
        Object.values(imagePreviews).forEach(url => URL.revokeObjectURL(url));
        setImagePreviews({});
      } else {
        // 일반 메시지 전송
        // SAP 모듈 값 가져오기 (chatService에서 소문자로 변환하므로 원본 값 전달)
        const moduleValue = isSapArchive() && selectedSapModule ? selectedSapModule : '';
        
        // 모듈 선택 상태 로그
        console.log('💬 메시지 전송 - 모듈 상태:', {
          isSapArchive: isSapArchive(),
          selectedSapModule,
          moduleValue,
          archiveName: currentArchive.archive_name,
          archiveType: currentArchive.archive_type,
        });
        
        fullResponse = await chatService.sendMessage({
          userId: user.userId,
          archiveId: currentArchive.archive_id,
          message: messageText,
          aiModel: selectedModel,
          archiveName: currentArchive.archive_name,
          isWebSearchEnabled: isWebSearchEnabled,
          module: moduleValue,
          onChunk: (chunk: string) => {
            appendStreamingMessage(chunk);
          },
          onLeaveTrigger: handleLeaveTrigger,
          onApprovalTrigger: handleApprovalTrigger,
        });
      }

      // 스트리밍 완료 후 AI 메시지 추가
      const aiMessage: ChatMessage = {
        chat_id: Date.now() + 1,
        archive_id: currentArchive.archive_id,
        message: fullResponse,
        role: 1, // AI
        timestamp: new Date().toISOString(),
      };

      addMessage(aiMessage);

      // 자동 타이틀 업데이트 (Flutter와 동일한 로직)
      // 첫 번째 사용자 메시지인 경우에만 실행
      const userMessagesCount = [...messages, userMessage].filter(m => m.role === 0).length;
      const isFirstUserMessage = userMessagesCount === 1;

      // 자동 타이틀 생성 기능 활성화
      const AUTO_TITLE_ENABLED = true;

      if (AUTO_TITLE_ENABLED && isFirstUserMessage && !isDefaultArchive(currentArchive)) {
        console.log('🎯 첫 메시지 감지: 자동 타이틀 업데이트 시작', {
          archiveId: currentArchive.archive_id,
          message: messageText
        });

        // 자동 타이틀 생성 API 호출 (비동기, 백그라운드 실행)
        // 에러 발생 시에도 채팅은 정상 동작
        chatService.getAutoTitleStream(
          user.userId,
          currentArchive.archive_id,
          messageText,
          (chunk) => {
            // 타이틀 조각 수신 (로그만 출력)
            console.log('🔄 타이틀 조각 수신:', chunk);
          },
          (fullTitle) => {
            // 타이틀 생성 완료
            console.log('✅ 자동 타이틀 생성 완료:', fullTitle);

            // 아카이브 목록에서 현재 아카이브의 제목 업데이트
            const updatedArchives = archives.map(archive =>
              archive.archive_id === currentArchive.archive_id
                ? { ...archive, archive_name: fullTitle }
                : archive
            );

            // 상태 업데이트
            useChatStore.setState({
              archives: updatedArchives,
              currentArchive: { ...currentArchive, archive_name: fullTitle }
            });
          },
          (error) => {
            console.warn('⚠️ 자동 타이틀 생성 실패 (무시됨):', error.message);
            // 에러 발생 시 조용히 무시 - 채팅 기능에는 영향 없음
          }
        ).catch(err => {
          console.warn('⚠️ 자동 타이틀 스트림 예외 (무시됨):', err.message);
          // 에러 발생 시 조용히 무시 - 채팅 기능에는 영향 없음
        });
      }
    } catch (error) {
      console.error('메시지 전송 실패:', error);
      // 에러 메시지 추가
      const errorMessage: ChatMessage = {
        chat_id: Date.now() + 1,
        archive_id: currentArchive.archive_id,
        message: '죄송합니다. 메시지 전송 중 오류가 발생했습니다.',
        role: 1,
        timestamp: new Date().toISOString(),
      };
      addMessage(errorMessage);
    } finally {
      setStreaming(false);
      setStreamingMessage('');

      // 메시지 전송 완료 후 텍스트 필드에 포커스 (여러 번 시도)
      const focusTextField = () => {
        try {
          if (inputRef.current) {
            inputRef.current.focus();
            // 커서를 텍스트 끝으로 이동 (값이 있는 경우에만)
            if (inputRef.current.value !== undefined && inputRef.current.value !== null) {
              const length = inputRef.current.value.length || 0;
              inputRef.current.setSelectionRange(length, length);
            }
          }
        } catch (error) {
          console.warn('포커스 설정 중 에러 (무시 가능):', error);
        }
      };

      // 즉시 포커스 시도
      focusTextField();

      // UI 업데이트 후 다시 포커스 시도
      setTimeout(focusTextField, 50);
      setTimeout(focusTextField, 150);
    }
  };

  // Enter 키로 전송
  const handleKeyPress = (event: React.KeyboardEvent) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      handleSend();

      // 엔터 키 입력 직후 포커스 재설정 (더 빠른 반응을 위해)
      setTimeout(() => {
        try {
          if (inputRef.current) {
            inputRef.current.focus();
          }
        } catch (error) {
          console.warn('엔터 키 포커스 설정 중 에러 (무시 가능):', error);
        }
      }, 10);
    }
  };

  // 파일 첨부 핸들러
  const handleFileAttach = () => {
    fileInputRef.current?.click();
  };

  // 파일 선택 핸들러
  const handleFileSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const files = event.target.files;
    if (!files || files.length === 0) return;

    const newFiles: FileAttachment[] = [];
    const newPreviews: Record<string, string> = {};

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const fileAttachment = FileService.createFileAttachment(file);
      newFiles.push(fileAttachment);

      // 이미지 파일인 경우 미리보기 URL 생성
      if (file.type.startsWith('image/')) {
        const previewUrl = URL.createObjectURL(file);
        newPreviews[fileAttachment.id] = previewUrl;
      }
    }

    // 파일 검증
    const validation = isModelSelectorArchive()
      ? FileService.validateModelFiles(newFiles)
      : FileService.validateInternalFiles(newFiles);

    if (!validation.valid) {
      alert(validation.error);
      // 생성된 미리보기 URL 정리
      Object.values(newPreviews).forEach(url => URL.revokeObjectURL(url));
      return;
    }

    setAttachedFiles(prev => [...prev, ...newFiles]);
    setImagePreviews(prev => ({ ...prev, ...newPreviews }));

    // 파일 입력 초기화
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  // 파일 제거 핸들러
  const handleFileRemove = (fileId: string) => {
    setAttachedFiles(prev => prev.filter(file => file.id !== fileId));

    // 이미지 미리보기 URL 정리
    if (imagePreviews[fileId]) {
      URL.revokeObjectURL(imagePreviews[fileId]);
      setImagePreviews(prev => {
        const newPreviews = { ...prev };
        delete newPreviews[fileId];
        return newPreviews;
      });
    }
  };

  // 아카이브 타입 확인 (AI 모델 선택 여부)
  const isModelSelectorArchive = () => {
    if (!currentArchive) return false;

    const archiveName = currentArchive.archive_name.toLowerCase();
    const archiveType = currentArchive.archive_type?.toLowerCase() || '';

    return (
      archiveName.includes('코딩') ||
      archiveName.includes('sap') ||
      archiveName.includes('ai chatbot') ||
      archiveType === 'code' ||
      archiveType === 'sap'
    );
  };

  // SAP 어시스턴트 여부 확인
  const isSapArchive = () => {
    if (!currentArchive) return false;
    const archiveName = currentArchive.archive_name;
    const archiveType = currentArchive.archive_type;
    return archiveType === 'sap' || archiveName === 'SAP어시스턴트' || archiveName === 'SAP 어시스턴트';
  };

  // SAP 모듈 목록 (Flutter와 동일)
  const SAP_MODULES = ['BC', 'CO', 'FI', 'HR', 'IS', 'MM', 'PM', 'PP', 'PS', 'QM', 'SD', 'TR', 'WF', 'General'];

  // 모바일 설정 메뉴 열기
  const handleSettingsMenuOpen = (event: React.MouseEvent<HTMLElement>) => {
    setSettingsAnchorEl(event.currentTarget);
  };

  // 모바일 설정 메뉴 닫기
  const handleSettingsMenuClose = () => {
    setSettingsAnchorEl(null);
  };

  // 웹검색 토글 핸들러
  const handleWebSearchToggle = () => {
    const newState = !isWebSearchEnabled;
    setWebSearchEnabled(newState);
    console.log(`🌐 웹검색 토글: ${newState ? 'ON' : 'OFF'}`);
  };

  // 뒤로가기 버튼 핸들러 - "사내업무" 아카이브로 이동
  const handleBackToDefault = () => {
    const defaultArchive = archives.find(
      (archive) => archive.archive_name === '사내업무'
    );

    if (defaultArchive) {
      setCurrentArchive(defaultArchive);
    } else {
      // "사내업무" 아카이브가 없으면 첫 번째 아카이브로 이동
      if (archives.length > 0) {
        setCurrentArchive(archives[0]);
      }
    }
  };

  // 특수 채팅방인지 확인 (코딩어시스턴트, SAP어시스턴트, AI Chatbot)
  const isSpecialChatRoom =
    currentArchive?.archive_name === '코딩어시스턴트' ||
    currentArchive?.archive_name === 'SAP어시스턴트' ||
    currentArchive?.archive_name === 'AI Chatbot';

  // 아카이브가 선택되지 않은 경우
  if (!currentArchive) {
    return (
      <Box
        sx={{
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          bgcolor: 'background.default',
        }}
      >
        <Typography variant="h6" color="text.secondary">
          채팅방을 선택해주세요
        </Typography>
      </Box>
    );
  }

  // AI Chatbot 아카이브 여부 확인 (Flutter와 동일한 로직)
  const isAIChatbot = currentArchive.archive_name === 'AI Chatbot';

  return (
    <Box
      sx={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        bgcolor: 'background.default',
      }}
    >
      {/* 헤더: 뒤로가기 버튼 + AI 모델 선택 (데스크톱에서만 표시) */}
      <Paper
        elevation={2}
        sx={{
          p: { xs: 1.5, md: 2 },
          borderRadius: 0,
          display: { xs: 'none', md: 'flex' }, // 모바일에서는 숨김 (AppBar가 있음)
          alignItems: 'center',
          gap: 2,
          bgcolor: 'background.paper',
          borderBottom: '1px solid',
          borderColor: 'divider',
          flexShrink: 0,
        }}
      >
        {/* 뒤로가기 버튼 (특수 채팅방에서만 표시) */}
        {isSpecialChatRoom && (
          <IconButton
            onClick={handleBackToDefault}
            size="small"
            sx={{
              color: 'text.secondary',
              '&:hover': {
                bgcolor: 'action.hover',
              },
            }}
          >
            <ArrowBackIcon />
          </IconButton>
        )}

        <Typography
          variant={isMobile ? 'subtitle1' : 'h6'}
          sx={{
            flexGrow: 1,
            fontWeight: 600,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {currentArchive.archive_name}
        </Typography>

      </Paper>

      {/* 메시지 영역 */}
      <Box
        sx={{
          flex: 1,
          overflow: 'auto',
          p: { xs: 2, md: 3 },
          bgcolor: colorScheme.backgroundColor,
          '&::-webkit-scrollbar': {
            width: '8px',
          },
          '&::-webkit-scrollbar-track': {
            bgcolor: isDark ? 'rgba(255, 255, 255, 0.05)' : 'grey.100',
            borderRadius: '4px',
          },
          '&::-webkit-scrollbar-thumb': {
            bgcolor: isDark ? 'rgba(255, 255, 255, 0.2)' : 'grey.400',
            borderRadius: '4px',
            '&:hover': {
              bgcolor: isDark ? 'rgba(255, 255, 255, 0.3)' : 'grey.500',
            },
          },
        }}
      >
        {messages.length === 0 && !isStreaming ? (
          <Box
            sx={{
              height: '100%',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              textAlign: 'center',
              color: 'text.secondary',
            }}
          >
            <BotIcon sx={{ fontSize: 80, mb: 2, opacity: 0.5 }} />
            <Typography variant="h6" gutterBottom>
              {currentArchive.archive_name}에 오신 것을 환영합니다
            </Typography>
            <Typography variant="body2">
              무엇을 도와드릴까요?
            </Typography>
          </Box>
        ) : (
          <>
            {messages.map((msg, index) => (
              <Box
                key={msg.chat_id || index}
                sx={{
                  display: 'flex',
                  mb: 3,
                  flexDirection: msg.role === 0 ? 'row-reverse' : 'row',
                }}
              >
                {/* 아바타 */}
                <Avatar
                  sx={{
                    bgcolor: msg.role === 0 ? 'primary.main' : 'secondary.main',
                    mx: 1,
                  }}
                >
                  {msg.role === 0 ? <PersonIcon /> : <BotIcon />}
                </Avatar>

                {/* 메시지 버블 */}
                <Paper
                  elevation={1}
                  sx={{
                    p: { xs: 1.5, md: 2 },
                    maxWidth: { xs: '85%', sm: '75%', md: '70%', lg: '60%' },
                    bgcolor: msg.role === 0
                      ? colorScheme.chatUserBubbleColor
                      : colorScheme.chatAiBubbleColor,
                    color: msg.role === 0
                      ? colorScheme.userMessageTextColor
                      : colorScheme.aiMessageTextColor,
                    borderRadius: 2,
                    wordBreak: 'break-word',
                    // ✅ 텍스트 드래그 & 복사 활성화 (!important 추가)
                    userSelect: 'text !important',
                    cursor: 'text !important',
                    WebkitUserSelect: 'text !important',
                    MozUserSelect: 'text !important',
                    msUserSelect: 'text !important',
                    // 모든 하위 요소에도 적용
                    '& *': {
                      userSelect: 'text !important',
                      WebkitUserSelect: 'text !important',
                      MozUserSelect: 'text !important',
                      msUserSelect: 'text !important',
                    },
                  }}
                >
                  {msg.role === 1 ? (
                    <MessageRenderer
                      message={msg.message}
                      isStreaming={false}
                      archiveName={currentArchive?.archive_name}
                    />
                  ) : (
                    <Typography
                      variant="body1"
                      sx={{
                        // ✅ 텍스트 선택 활성화 (!important 추가)
                        userSelect: 'text !important',
                        cursor: 'text !important',
                        whiteSpace: 'pre-wrap',
                      }}
                    >
                      {msg.message}
                    </Typography>
                  )}
                </Paper>
              </Box>
            ))}

            {/* 스트리밍 중인 메시지 */}
            {isStreaming && (
              <Box sx={{ display: 'flex', mb: 3 }}>
                <Avatar sx={{ bgcolor: 'secondary.main', mx: 1 }}>
                  <BotIcon />
                </Avatar>

                <Paper
                  elevation={1}
                  sx={{
                    p: { xs: 1.5, md: 2 },
                    maxWidth: { xs: '85%', sm: '75%', md: '70%', lg: '60%' },
                    bgcolor: colorScheme.chatAiBubbleColor,
                    color: colorScheme.aiMessageTextColor,
                    borderRadius: 2,
                    wordBreak: 'break-word',
                    // ✅ 텍스트 드래그 & 복사 활성화 (!important 추가)
                    userSelect: 'text !important',
                    cursor: 'text !important',
                    WebkitUserSelect: 'text !important',
                    MozUserSelect: 'text !important',
                    msUserSelect: 'text !important',
                    // 모든 하위 요소에도 적용
                    '& *': {
                      userSelect: 'text !important',
                      WebkitUserSelect: 'text !important',
                      MozUserSelect: 'text !important',
                      msUserSelect: 'text !important',
                    },
                  }}
                >
                  {streamingMessage ? (
                    <MessageRenderer
                      message={streamingMessage}
                      isStreaming={true}
                      archiveName={currentArchive?.archive_name}
                    />
                  ) : (
                    <CircularProgress size={20} />
                  )}
                </Paper>
              </Box>
            )}

            <div ref={messagesEndRef} />
          </>
        )}
      </Box>

      <Divider />

      {/* 파일 첨부 목록 (개선된 미리보기) */}
      {attachedFiles.length > 0 && (
        <Box
          sx={{
            p: 2,
            bgcolor: colorScheme.surfaceColor,
            borderBottom: `1px solid ${colorScheme.textFieldBorderColor}`,
            borderTop: `1px solid ${colorScheme.textFieldBorderColor}`,
          }}
        >
          <Typography 
            variant="caption" 
            color="text.secondary" 
            sx={{ 
              mb: 1.5, 
              display: 'block',
              fontWeight: 600,
              fontSize: '0.75rem',
            }}
          >
            첨부된 파일 ({attachedFiles.length}개)
          </Typography>
          <Stack direction="row" spacing={1} sx={{ flexWrap: 'wrap', gap: 1 }}>
            {attachedFiles.map((file) => {
              const isImage = file.type.startsWith('image/');
              const previewUrl = imagePreviews[file.id];

              return (
                <Box key={file.id} sx={{ position: 'relative', display: 'inline-block', mr: 1, mb: 1 }}>
                  {isImage && previewUrl ? (
                    <Box
                      sx={{
                        position: 'relative',
                        borderRadius: 2,
                        overflow: 'hidden',
                        border: '2px solid',
                        borderColor: 'primary.light',
                        boxShadow: 1,
                        transition: 'all 0.2s ease-in-out',
                        '&:hover': {
                          boxShadow: 3,
                          transform: 'scale(1.02)',
                        },
                      }}
                    >
                      <Box
                        component="img"
                        src={previewUrl}
                        alt={file.name}
                        sx={{
                          width: 80,
                          height: 80,
                          objectFit: 'cover',
                          display: 'block',
                          backgroundColor: 'grey.100',
                        }}
                      />
                      <IconButton
                        onClick={() => handleFileRemove(file.id)}
                        size="small"
                        sx={{
                          position: 'absolute',
                          top: 4,
                          right: 4,
                          bgcolor: 'rgba(255,255,255,0.9)',
                          color: 'grey.700',
                          boxShadow: 1,
                          '&:hover': {
                            bgcolor: 'white',
                            color: 'error.main',
                          },
                          width: 24,
                          height: 24,
                        }}
                      >
                        <CloseIcon sx={{ fontSize: '1rem' }} />
                      </IconButton>
                      <Box
                        sx={{
                          position: 'absolute',
                          bottom: 0,
                          left: 0,
                          right: 0,
                          bgcolor: 'rgba(0,0,0,0.7)',
                          p: 0.5,
                          backdropFilter: 'blur(4px)',
                        }}
                      >
                        <Typography
                          variant="caption"
                          sx={{
                            color: 'white',
                            fontSize: '0.7rem',
                            fontWeight: 500,
                            display: 'block',
                            textAlign: 'center',
                          }}
                        >
                          {FileService.formatFileSize(file.size)}
                        </Typography>
                      </Box>
                    </Box>
                  ) : (
                    <Chip
                      label={
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                          <AttachFileIcon sx={{ fontSize: '1rem' }} />
                          <Box>
                            <Typography variant="caption" sx={{ fontSize: '0.75rem', fontWeight: 500 }}>
                              {file.name}
                            </Typography>
                            <Typography variant="caption" sx={{ fontSize: '0.65rem', color: 'text.secondary' }}>
                              {FileService.formatFileSize(file.size)}
                            </Typography>
                          </Box>
                        </Box>
                      }
                      onDelete={() => handleFileRemove(file.id)}
                      deleteIcon={<CloseIcon />}
                      variant="outlined"
                      size="small"
                      sx={{
                        height: 'auto',
                        py: 1,
                        px: 1.5,
                        borderColor: 'primary.light',
                        '& .MuiChip-label': {
                          px: 0,
                        },
                        '&:hover': {
                          borderColor: 'primary.main',
                          bgcolor: 'primary.50',
                        },
                      }}
                    />
                  )}
                </Box>
              );
            })}
          </Stack>
        </Box>
      )}

      {/* 입력 영역 */}
      <Paper
        elevation={3}
        sx={{
          p: { xs: 1.5, md: 2 },
          borderRadius: 0,
          display: 'flex',
          gap: { xs: 0.5, md: 1 },
          alignItems: 'flex-end',
          borderTop: `1px solid ${colorScheme.textFieldBorderColor}`,
          bgcolor: colorScheme.chatInputBackgroundColor,
        }}
      >
        {/* 파일 첨부 버튼 */}
        <IconButton
          color="primary"
          onClick={handleFileAttach}
          disabled={isStreaming}
          size={isMobile ? 'small' : 'medium'}
          sx={{
            color: 'primary.main',
            '&:hover': {
              bgcolor: 'primary.light',
              color: 'primary.dark',
            },
          }}
        >
          <AttachFileIcon fontSize={isMobile ? 'small' : 'medium'} />
        </IconButton>

        {/* 숨겨진 파일 입력 */}
        <input
          ref={fileInputRef}
          type="file"
          multiple
          onChange={handleFileSelect}
          style={{ display: 'none' }}
          accept={isModelSelectorArchive() ? '.jpg,.jpeg,.png' : '*'}
        />

        <TextField
          ref={textFieldRef}
          fullWidth
          multiline
          maxRows={isMobile ? 3 : 4}
          minRows={1}
          placeholder="메시지를 입력하세요..."
          value={inputMessage}
          onChange={(e) => setInputMessage(e.target.value)}
          onKeyPress={handleKeyPress}
          disabled={isStreaming}
          variant="outlined"
          size={isMobile ? 'small' : 'medium'}
          autoFocus={true}
          inputRef={inputRef}
          InputProps={{
            startAdornment: isModelSelectorArchive() ? (
              <>
                {/* 모바일: 설정 메뉴 아이콘만 표시 */}
                {isMobile ? (
                  <IconButton
                    size="small"
                    onClick={handleSettingsMenuOpen}
                    disabled={isStreaming}
                    sx={{
                      mr: 0.5,
                      color: 'primary.main',
                      '&:hover': {
                        bgcolor: 'primary.light',
                        color: 'primary.dark',
                      },
                    }}
                  >
                    <SettingsIcon sx={{ fontSize: '1.2rem' }} />
                  </IconButton>
                ) : (
                  /* 데스크톱: 기존 레이아웃 유지 */
                  <Box 
                    sx={{ 
                      display: 'flex', 
                      alignItems: 'center',
                      flexDirection: 'row',
                      gap: 1, 
                      mr: 1,
                    }}
                  >
                    {/* SAP 모듈 선택 드롭다운과 AI 모델 선택기를 같은 x축에 배치 */}
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.75 }}>
                      {/* SAP 모듈 선택 드롭다운 (SAP 어시스턴트일 때만 표시) */}
                      {isSapArchive() && (
                        <FormControl 
                          size="small" 
                          sx={{ 
                            minWidth: 100,
                            '& .MuiOutlinedInput-root': {
                              height: 36,
                            },
                          }}
                        >
                          <Select
                            value={selectedSapModule}
                            onChange={(e) => setSelectedSapModule(e.target.value)}
                            displayEmpty
                            disabled={isStreaming}
                            sx={{
                              fontSize: '0.875rem',
                              height: 36,
                              '& .MuiSelect-select': {
                                py: 0.75,
                                px: 1.5,
                              },
                            }}
                          >
                            <MenuItem value="" sx={{ fontSize: '0.875rem' }}>
                              <em>모듈</em>
                            </MenuItem>
                            {SAP_MODULES.map((module) => (
                              <MenuItem key={module} value={module} sx={{ fontSize: '0.875rem' }}>
                                {module}
                              </MenuItem>
                            ))}
                          </Select>
                        </FormControl>
                      )}

                      {/* AI 모델 선택기 */}
                      <AiModelSelector size="small" />
                    </Box>

                    {/* 웹검색 아이콘과 토글 */}
                    <Tooltip title="웹검색 사용">
                      <Box
                        sx={{
                          display: 'flex',
                          flexDirection: 'row',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: 0.5,
                        }}
                      >
                        <WebIcon
                          sx={{
                            fontSize: '1.2rem',
                            color: isWebSearchEnabled ? '#6B46C1' : 'grey.500',
                          }}
                        />
                        <Switch
                          checked={isWebSearchEnabled}
                          onChange={handleWebSearchToggle}
                          size="small"
                          color="primary"
                          disabled={isStreaming}
                          sx={{
                            '& .MuiSwitch-switchBase': {
                              '&.Mui-checked': {
                                color: '#6B46C1',
                                '& + .MuiSwitch-track': {
                                  backgroundColor: '#6B46C1',
                                },
                              },
                            },
                          }}
                        />
                      </Box>
                    </Tooltip>
                  </Box>
                )}
              </>
            ) : undefined,
          }}
          sx={{
            '& .MuiOutlinedInput-root': {
              borderRadius: 3,
              minHeight: { xs: 48, md: 56 },
              '& .MuiInputBase-input': {
                py: { xs: 1.25, md: 1.5 },
              },
            },
          }}
        />

        <IconButton
          color="primary"
          onClick={handleSend}
          disabled={(!inputMessage.trim() && attachedFiles.length === 0) || isStreaming}
          size={isMobile ? 'medium' : 'large'}
          sx={{
            bgcolor: 'primary.main',
            color: 'white',
            minWidth: { xs: 40, md: 48 },
            minHeight: { xs: 40, md: 48 },
            '&:hover': {
              bgcolor: 'primary.dark',
            },
            '&.Mui-disabled': {
              bgcolor: 'grey.300',
              color: 'grey.500',
            },
          }}
        >
          {isStreaming ? (
            <CircularProgress size={isMobile ? 20 : 24} sx={{ color: 'white' }} />
          ) : (
            <SendIcon fontSize={isMobile ? 'small' : 'medium'} />
          )}
        </IconButton>
      </Paper>

      {/* 모바일 설정 메뉴 팝오버 */}
      {isMobile && isModelSelectorArchive() && (
        <Popover
          open={settingsMenuOpen}
          anchorEl={settingsAnchorEl}
          onClose={handleSettingsMenuClose}
          anchorOrigin={{
            vertical: 'top',
            horizontal: 'left',
          }}
          transformOrigin={{
            vertical: 'bottom',
            horizontal: 'left',
          }}
          PaperProps={{
            sx: {
              mt: -1,
              minWidth: 280,
              bgcolor: isDark ? '#2D2D30' : '#FFFFFF',
              borderRadius: 2,
              boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
            },
          }}
        >
          <Box sx={{ p: 2 }}>
            <Typography
              variant="subtitle2"
              sx={{
                mb: 2,
                fontWeight: 600,
                color: isDark ? '#B19CD9' : '#6B46C1',
                fontSize: '0.875rem',
              }}
            >
              설정
            </Typography>

            {/* SAP 모듈 선택 */}
            {isSapArchive() && (
              <Box sx={{ mb: 2 }}>
                <Typography
                  variant="caption"
                  sx={{
                    display: 'block',
                    mb: 1,
                    color: isDark ? '#888888' : '#666666',
                    fontSize: '0.75rem',
                    fontWeight: 500,
                  }}
                >
                  SAP 모듈
                </Typography>
                <FormControl fullWidth size="small">
                  <Select
                    value={selectedSapModule}
                    onChange={(e) => {
                      setSelectedSapModule(e.target.value);
                      handleSettingsMenuClose();
                    }}
                    displayEmpty
                    disabled={isStreaming}
                    sx={{
                      fontSize: '0.875rem',
                      bgcolor: isDark ? 'rgba(255,255,255,0.05)' : '#f5f5f5',
                    }}
                  >
                    <MenuItem value="">
                      <em>모듈 선택</em>
                    </MenuItem>
                    {SAP_MODULES.map((module) => (
                      <MenuItem key={module} value={module}>
                        {module}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Box>
            )}

            {/* AI 모델 선택 */}
            <Box sx={{ mb: 2 }}>
              <Typography
                variant="caption"
                sx={{
                  display: 'block',
                  mb: 1,
                  color: isDark ? '#888888' : '#666666',
                  fontSize: '0.75rem',
                  fontWeight: 500,
                }}
              >
                AI 모델
              </Typography>
              <Box
                sx={{
                  p: 1.5,
                  borderRadius: 1,
                  bgcolor: isDark ? 'rgba(255,255,255,0.05)' : '#f5f5f5',
                  border: `1px solid ${isDark ? 'rgba(255,255,255,0.1)' : '#e0e0e0'}`,
                }}
              >
                <AiModelSelector size="small" />
              </Box>
            </Box>

            {/* 웹검색 토글 */}
            <Box>
              <Typography
                variant="caption"
                sx={{
                  display: 'block',
                  mb: 1,
                  color: isDark ? '#888888' : '#666666',
                  fontSize: '0.75rem',
                  fontWeight: 500,
                }}
              >
                웹검색
              </Typography>
              <FormControlLabel
                control={
                  <Switch
                    checked={isWebSearchEnabled}
                    onChange={handleWebSearchToggle}
                    size="medium"
                    color="primary"
                    disabled={isStreaming}
                    sx={{
                      '& .MuiSwitch-switchBase': {
                        '&.Mui-checked': {
                          color: '#6B46C1',
                          '& + .MuiSwitch-track': {
                            backgroundColor: '#6B46C1',
                          },
                        },
                      },
                    }}
                  />
                }
                label={
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <WebIcon
                      sx={{
                        fontSize: '1rem',
                        color: isWebSearchEnabled ? '#6B46C1' : 'grey.500',
                      }}
                    />
                    <Typography
                      variant="body2"
                      sx={{
                        fontSize: '0.875rem',
                        color: isDark ? '#FFFFFF' : '#000000',
                      }}
                    >
                      {isWebSearchEnabled ? '활성화됨' : '비활성화됨'}
                    </Typography>
                  </Box>
                }
                sx={{ margin: 0 }}
              />
            </Box>
          </Box>
        </Popover>
      )}
    </Box>
  );
}
