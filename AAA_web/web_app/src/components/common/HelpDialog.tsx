import {
  Dialog,
  DialogTitle,
  DialogContent,
  IconButton,
  Typography,
  Box,
  Divider,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Chip,
  TextField,
  InputAdornment,
} from '@mui/material';
import {
  Close as CloseIcon,
  ExpandMore as ExpandMoreIcon,
  Search as SearchIcon,
  Keyboard as KeyboardIcon,
  Help as HelpIcon,
  Info as InfoIcon,
} from '@mui/icons-material';
import { useState } from 'react';
import type { ReactNode } from 'react';
import { useThemeStore } from '../../store/themeStore';

interface HelpDialogProps {
  open: boolean;
  onClose: () => void;
}

interface HelpSection {
  title: string;
  icon: ReactNode;
  items: HelpItem[];
}

interface HelpItem {
  title: string;
  description: string;
  shortcut?: string;
  keywords?: string[]; // 검색용 키워드
}

export default function HelpDialog({ open, onClose }: HelpDialogProps) {
  const { colorScheme } = useThemeStore();
  const [searchQuery, setSearchQuery] = useState('');
  const [expandedSection, setExpandedSection] = useState<string | false>('keyboard');

  // 도움말 섹션
  const helpSections: HelpSection[] = [
    {
      title: '키보드 단축키',
      icon: <KeyboardIcon />,
      items: [
        {
          title: '메시지 전송',
          description: '입력한 메시지를 AI에게 전송합니다.',
          shortcut: 'Enter',
          keywords: ['전송', '보내기', 'send', 'enter'],
        },
        {
          title: '줄바꿈',
          description: '메시지 입력 중 새 줄을 추가합니다.',
          shortcut: 'Shift + Enter',
          keywords: ['줄바꿈', '개행', 'newline', 'shift'],
        },
        {
          title: '클립보드 이미지 붙여넣기',
          description: '클립보드의 이미지를 첨부파일로 추가합니다.',
          shortcut: 'Ctrl + V',
          keywords: ['붙여넣기', '이미지', 'paste', 'ctrl', 'clipboard'],
        },
        {
          title: '검색',
          description: '대화 내용을 검색합니다.',
          shortcut: 'Ctrl + K',
          keywords: ['검색', 'search', 'find', 'ctrl'],
        },
        {
          title: '새 채팅방',
          description: '새로운 채팅방을 생성합니다.',
          shortcut: 'Ctrl + N',
          keywords: ['새', '채팅', 'new', 'chat', 'ctrl'],
        },
        {
          title: '설정',
          description: '설정 페이지를 엽니다.',
          shortcut: 'Ctrl + ,',
          keywords: ['설정', 'settings', 'config', 'ctrl'],
        },
      ],
    },
    {
      title: '기본 기능',
      icon: <HelpIcon />,
      items: [
        {
          title: 'AI 모델 선택',
          description: '채팅 입력창 상단의 드롭다운에서 AI 모델을 선택할 수 있습니다. Gemini, GPT, Claude 등을 지원합니다.',
          keywords: ['모델', 'ai', 'gemini', 'gpt', 'claude', 'model'],
        },
        {
          title: '파일 첨부',
          description: '이미지, PDF 등의 파일을 드래그 앤 드롭하거나 📎 버튼을 클릭하여 첨부할 수 있습니다.',
          keywords: ['파일', '첨부', 'file', 'attach', 'upload', '이미지', 'pdf'],
        },
        {
          title: '채팅방 관리',
          description: '사이드바에서 채팅방을 생성, 선택, 이름 변경, 삭제할 수 있습니다. 채팅방을 우클릭하면 컨텍스트 메뉴가 나타납니다.',
          keywords: ['채팅방', '대화', 'chat', 'archive', '생성', '삭제', 'create', 'delete'],
        },
        {
          title: '검색',
          description: '사이드바 상단의 검색 아이콘을 클릭하거나 Ctrl+K를 눌러 대화 내용을 검색할 수 있습니다.',
          keywords: ['검색', 'search', 'find', '찾기'],
        },
        {
          title: '웹 검색 모드',
          description: 'AI 응답에 실시간 웹 검색 결과를 포함하려면 입력창의 웹 검색 토글을 활성화하세요.',
          keywords: ['웹', '검색', 'web', 'search', 'internet'],
        },
      ],
    },
    {
      title: '업무 기능',
      icon: <InfoIcon />,
      items: [
        {
          title: '전자결재',
          description: '사이드바의 "전자결재" 메뉴에서 결재 문서를 확인하고 처리할 수 있습니다.',
          keywords: ['결재', '전자결재', 'approval', 'document', '문서'],
        },
        {
          title: '휴가관리',
          description: '휴가 신청, 승인 현황 조회, 휴가 내역 확인 기능을 제공합니다. 사이드바의 "휴가 관리" 메뉴를 클릭하세요.',
          keywords: ['휴가', 'leave', 'vacation', '신청', '연차'],
        },
        {
          title: '받은선물함',
          description: '우측 상단의 선물함 아이콘(보라색)을 클릭하여 받은 쿠폰과 선물을 확인할 수 있습니다.',
          keywords: ['선물', '선물함', 'gift', '쿠폰', 'coupon'],
        },
        {
          title: '공모전',
          description: '사내 공모전 참여 및 투표 기능을 제공합니다.',
          keywords: ['공모전', 'contest', '투표', 'vote'],
        },
      ],
    },
    {
      title: 'AI 채팅방 종류',
      icon: <InfoIcon />,
      items: [
        {
          title: '사내업무',
          description: '일반적인 업무 관련 질문과 대화를 위한 기본 채팅방입니다.',
          keywords: ['사내업무', '업무', 'work', '기본'],
        },
        {
          title: '코딩어시스턴트',
          description: '프로그래밍, 코드 작성, 디버깅, 코드 리뷰 등 개발 관련 질문에 특화된 AI 어시스턴트입니다.',
          keywords: ['코딩', '프로그래밍', 'coding', 'programming', 'code', '개발', '디버깅'],
        },
        {
          title: 'SAP어시스턴트',
          description: 'SAP 시스템 관련 질문에 모듈별로 최적화된 답변을 제공하는 전문 AI입니다.',
          keywords: ['sap', '모듈', 'module', '어시스턴트', 'erp'],
        },
        {
          title: 'AI Chatbot',
          description: '다양한 주제에 대해 자유롭게 대화할 수 있는 범용 AI 챗봇입니다.',
          keywords: ['chatbot', '챗봇', 'ai', '대화'],
        },
      ],
    },
    {
      title: '테마 및 설정',
      icon: <InfoIcon />,
      items: [
        {
          title: '다크 모드',
          description: '설정 페이지에서 Light / Dark / System 테마를 선택할 수 있습니다.',
          keywords: ['테마', '다크', 'dark', 'theme', 'light', 'system'],
        },
        {
          title: '알림 설정',
          description: '생일, 선물, 결재 등의 알림을 설정 페이지에서 관리할 수 있습니다.',
          keywords: ['알림', 'notification', 'alert', '설정'],
        },
        {
          title: '계정 정보',
          description: '설정 페이지에서 계정 정보를 확인하고 비밀번호를 변경할 수 있습니다.',
          keywords: ['계정', 'account', '정보', '비밀번호', 'password'],
        },
      ],
    },
  ];

  // 검색 필터링
  const filteredSections = helpSections.map((section) => ({
    ...section,
    items: section.items.filter((item) => {
      if (!searchQuery) return true;

      const query = searchQuery.toLowerCase();
      const matchTitle = item.title.toLowerCase().includes(query);
      const matchDescription = item.description.toLowerCase().includes(query);
      const matchKeywords = item.keywords?.some((keyword) =>
        keyword.toLowerCase().includes(query)
      );
      const matchShortcut = item.shortcut?.toLowerCase().includes(query);

      return matchTitle || matchDescription || matchKeywords || matchShortcut;
    }),
  })).filter((section) => section.items.length > 0);

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="md"
      fullWidth
      PaperProps={{
        sx: {
          borderRadius: 2,
          maxHeight: '80vh',
        },
      }}
    >
      {/* 헤더 */}
      <DialogTitle
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          bgcolor: colorScheme.primaryColor,
          color: 'white',
          py: 2,
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <HelpIcon />
          <Typography variant="h6" sx={{ fontWeight: 600 }}>
            도움말
          </Typography>
        </Box>

        <IconButton
          onClick={onClose}
          sx={{
            color: 'white',
            '&:hover': {
              bgcolor: 'rgba(255,255,255,0.1)',
            },
          }}
        >
          <CloseIcon />
        </IconButton>
      </DialogTitle>

      <DialogContent sx={{ p: 0 }}>
        {/* 검색바 */}
        <Box sx={{ p: 2, pb: 1 }}>
          <TextField
            fullWidth
            placeholder="도움말 검색..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon sx={{ color: 'text.secondary' }} />
                </InputAdornment>
              ),
            }}
            sx={{
              '& .MuiOutlinedInput-root': {
                borderRadius: 2,
              },
            }}
          />
        </Box>

        <Divider />

        {/* 도움말 섹션 */}
        <Box sx={{ p: 2 }}>
          {filteredSections.length === 0 ? (
            <Box
              sx={{
                textAlign: 'center',
                py: 4,
                color: 'text.secondary',
              }}
            >
              <Typography>검색 결과가 없습니다.</Typography>
            </Box>
          ) : (
            filteredSections.map((section, index) => (
              <Accordion
                key={index}
                expanded={expandedSection === section.title}
                onChange={() =>
                  setExpandedSection(
                    expandedSection === section.title ? false : section.title
                  )
                }
                sx={{
                  mb: 1,
                  '&:before': {
                    display: 'none',
                  },
                  boxShadow: 1,
                  borderRadius: 2,
                  overflow: 'hidden',
                }}
              >
                <AccordionSummary
                  expandIcon={<ExpandMoreIcon />}
                  sx={{
                    bgcolor: 'action.hover',
                    '&:hover': {
                      bgcolor: 'action.selected',
                    },
                  }}
                >
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    {section.icon}
                    <Typography sx={{ fontWeight: 600 }}>
                      {section.title}
                    </Typography>
                    <Chip
                      label={section.items.length}
                      size="small"
                      sx={{ height: 20, minWidth: 20 }}
                    />
                  </Box>
                </AccordionSummary>

                <AccordionDetails sx={{ p: 2 }}>
                  <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                    {section.items.map((item, itemIndex) => (
                      <Box key={itemIndex}>
                        <Box
                          sx={{
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            mb: 0.5,
                          }}
                        >
                          <Typography
                            variant="body2"
                            sx={{ fontWeight: 600, color: colorScheme.primaryColor }}
                          >
                            {item.title}
                          </Typography>

                          {item.shortcut && (
                            <Chip
                              label={item.shortcut}
                              size="small"
                              sx={{
                                bgcolor: 'action.hover',
                                fontFamily: 'monospace',
                                fontSize: '0.75rem',
                              }}
                            />
                          )}
                        </Box>

                        <Typography
                          variant="body2"
                          sx={{ color: 'text.secondary', fontSize: '0.85rem' }}
                        >
                          {item.description}
                        </Typography>

                        {itemIndex < section.items.length - 1 && (
                          <Divider sx={{ mt: 2 }} />
                        )}
                      </Box>
                    ))}
                  </Box>
                </AccordionDetails>
              </Accordion>
            ))
          )}
        </Box>
      </DialogContent>
    </Dialog>
  );
}
