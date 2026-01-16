import { useState, useEffect } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  TextField,
  IconButton,
  Box,
  Typography,
  CircularProgress,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  Chip,
  Tabs,
  Tab,
  Divider,
} from '@mui/material';
import {
  Search as SearchIcon,
  Clear as ClearIcon,
  Chat as ChatIcon,
} from '@mui/icons-material';
import chatService from '../../services/chatService';
import authService from '../../services/authService';
import type { Archive } from '../../types';
import { useThemeStore } from '../../store/themeStore';

interface SearchResult {
  chat_id: number;
  archive_id: string;
  archive_name: string;
  message: string;
  role: number;
  timestamp: string;
  archive_time?: string;
}

interface SearchDialogProps {
  open: boolean;
  onClose: () => void;
  archives: Archive[];
  onSelectArchive: (archive: Archive) => void;
  onSelectMessage: (archiveId: string, chatId: number) => void;
}

export default function SearchDialog({
  open,
  onClose,
  archives,
  onSelectArchive,
  onSelectMessage,
}: SearchDialogProps) {
  const { colorScheme } = useThemeStore();
  const [searchKeyword, setSearchKeyword] = useState('');
  const [searchResults, setSearchResults] = useState<SearchResult[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [selectedTab, setSelectedTab] = useState(0);

  // 검색 실행 (메모리 기반)
  const performSearch = async (keyword: string) => {
    if (!keyword.trim()) {
      setSearchResults([]);
      return;
    }

    setIsSearching(true);
    try {
      const user = authService.getCurrentUser();
      if (!user) return;

      // Flutter의 searchArchiveContent 로직을 사용 (메모리 기반 검색)
      const results = await chatService.searchArchiveContent(
        keyword,
        archives,
        user.userId
      );
      setSearchResults(results);
    } catch (error) {
      console.error('검색 실패:', error);
      setSearchResults([]);
    } finally {
      setIsSearching(false);
    }
  };

  // 검색어 변경 시 검색 실행 (디바운스)
  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchKeyword.trim()) {
        performSearch(searchKeyword);
      } else {
        setSearchResults([]);
      }
    }, 500);

    return () => clearTimeout(timer);
  }, [searchKeyword]);

  // 다이얼로그 닫을 때 초기화
  const handleClose = () => {
    setSearchKeyword('');
    setSearchResults([]);
    setSelectedTab(0);
    onClose();
  };

  // 아카이브별로 결과 그룹화
  const groupedResults: Record<string, SearchResult[]> = {};
  searchResults.forEach((result) => {
    const archiveName = result.archive_name;
    if (!groupedResults[archiveName]) {
      groupedResults[archiveName] = [];
    }
    groupedResults[archiveName].push(result);
  });

  // 아카이브 이름 목록 (탭으로 사용)
  const archiveNames = Object.keys(groupedResults);

  // 기본 아카이브와 일반 아카이브 분리
  const defaultArchives: string[] = [];
  const customArchives: string[] = [];

  archiveNames.forEach((name) => {
    if (
      name === '사내업무' ||
      name === '코딩어시스턴트' ||
      name === '코딩 어시스턴트' ||
      name === 'SAP어시스턴트' ||
      name === 'SAP 어시스턴트' ||
      name === 'AI Chatbot'
    ) {
      defaultArchives.push(name);
    } else {
      customArchives.push(name);
    }
  });

  // 기본 아카이브는 고정 순서로 정렬
  defaultArchives.sort((a, b) => {
    const getOrder = (name: string) => {
      if (name === '사내업무') return 1;
      if (name === '코딩어시스턴트' || name === '코딩 어시스턴트') return 2;
      if (name === 'SAP어시스턴트' || name === 'SAP 어시스턴트') return 3;
      if (name === 'AI Chatbot') return 4;
      return 5;
    };
    return getOrder(a) - getOrder(b);
  });

  // 일반 아카이브는 시간순 정렬
  customArchives.sort((a, b) => {
    const aTime = groupedResults[a]?.[0]?.archive_time || '';
    const bTime = groupedResults[b]?.[0]?.archive_time || '';
    return bTime.localeCompare(aTime);
  });

  // 최종 아카이브 목록 (기본 아카이브 + 일반 아카이브)
  const sortedArchiveNames = [...defaultArchives, ...customArchives];

  // 현재 선택된 아카이브의 결과
  const currentArchiveName = sortedArchiveNames[selectedTab];
  const currentResults = currentArchiveName
    ? groupedResults[currentArchiveName] || []
    : [];

  // 메시지 선택 핸들러
  const handleMessageClick = (result: SearchResult) => {
    const archive = archives.find((a) => a.archive_id === result.archive_id);
    if (archive) {
      onSelectArchive(archive);
      // 메시지로 스크롤하는 기능은 ChatArea에서 구현 필요
      onSelectMessage(result.archive_id, result.chat_id);
    }
    handleClose();
  };

  // 검색 결과 하이라이팅
  const highlightText = (text: string, keyword: string) => {
    if (!keyword.trim()) return text;

    const parts = text.split(new RegExp(`(${keyword})`, 'gi'));
    return parts.map((part, index) =>
      part.toLowerCase() === keyword.toLowerCase() ? (
        <Box
          key={index}
          component="span"
          sx={{
            bgcolor: colorScheme.warningColor + '40',
            fontWeight: 600,
          }}
        >
          {part}
        </Box>
      ) : (
        part
      )
    );
  };

  return (
    <Dialog
      open={open}
      onClose={handleClose}
      maxWidth="md"
      fullWidth
      PaperProps={{
        sx: {
          bgcolor: colorScheme.backgroundColor,
          minHeight: '500px',
        },
      }}
    >
      <DialogTitle>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <SearchIcon sx={{ color: colorScheme.primaryColor }} />
          <Typography
            variant="h6"
            sx={{ flexGrow: 1, color: colorScheme.textColor }}
          >
            대화 내용 검색
          </Typography>
          {searchResults.length > 0 && !isSearching && (
            <Chip
              label={`${searchResults.length}개 결과`}
              size="small"
              sx={{
                bgcolor: colorScheme.primaryColor + '20',
                color: colorScheme.primaryColor,
                fontWeight: 600,
              }}
            />
          )}
        </Box>
      </DialogTitle>

      <DialogContent>
        {/* 검색 필드 */}
        <TextField
          fullWidth
          placeholder="검색어를 입력하세요"
          value={searchKeyword}
          onChange={(e) => setSearchKeyword(e.target.value)}
          autoFocus
          InputProps={{
            startAdornment: <SearchIcon sx={{ mr: 1, color: 'text.secondary' }} />,
            endAdornment: searchKeyword && (
              <IconButton
                size="small"
                onClick={() => setSearchKeyword('')}
                sx={{ mr: -1 }}
              >
                <ClearIcon fontSize="small" />
              </IconButton>
            ),
          }}
          sx={{
            mb: 2,
            '& .MuiOutlinedInput-root': {
              bgcolor: colorScheme.textFieldFillColor,
              borderRadius: 2,
            },
          }}
        />

        {/* 검색 중 표시 */}
        {isSearching && (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
            <CircularProgress size={40} />
            <Typography sx={{ ml: 2, color: colorScheme.textColor }}>
              검색 중...
            </Typography>
          </Box>
        )}

        {/* 검색 결과 없음 */}
        {!isSearching && searchKeyword.trim() && searchResults.length === 0 && (
          <Box sx={{ textAlign: 'center', py: 4 }}>
            <Typography sx={{ color: colorScheme.hintTextColor }}>
              검색 결과가 없습니다.
            </Typography>
          </Box>
        )}

        {/* 검색 결과 */}
        {!isSearching && searchResults.length > 0 && (
          <Box>
            {/* 아카이브 탭 */}
            {sortedArchiveNames.length > 1 && (
              <Tabs
                value={selectedTab}
                onChange={(_, newValue) => setSelectedTab(newValue)}
                variant="scrollable"
                scrollButtons="auto"
                sx={{
                  mb: 2,
                  borderBottom: `1px solid ${colorScheme.textFieldBorderColor}`,
                }}
              >
                {sortedArchiveNames.map((name, index) => (
                  <Tab
                    key={name}
                    label={
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <ChatIcon sx={{ fontSize: '1rem' }} />
                        <Typography variant="body2">{name}</Typography>
                        <Chip
                          label={groupedResults[name]?.length || 0}
                          size="small"
                          sx={{ height: 20, fontSize: '0.7rem' }}
                        />
                      </Box>
                    }
                  />
                ))}
              </Tabs>
            )}

            {/* 현재 선택된 아카이브의 결과 목록 */}
            {currentResults.length > 0 && (
              <List>
                {currentResults.map((result, index) => (
                  <Box key={`${result.chat_id}-${index}`}>
                    <ListItemButton
                      onClick={() => handleMessageClick(result)}
                      sx={{
                        borderRadius: 1,
                        mb: 0.5,
                        '&:hover': {
                          bgcolor: colorScheme.chatAiBubbleColor,
                        },
                      }}
                    >
                      <ListItemText
                        primary={
                          <Typography
                            variant="body2"
                            sx={{
                              color: colorScheme.textColor,
                              mb: 0.5,
                            }}
                          >
                            {highlightText(result.message, searchKeyword)}
                          </Typography>
                        }
                        secondary={
                          <Typography
                            variant="caption"
                            sx={{ color: colorScheme.hintTextColor }}
                          >
                            {new Date(result.timestamp).toLocaleString('ko-KR')}
                          </Typography>
                        }
                      />
                    </ListItemButton>
                    {index < currentResults.length - 1 && (
                      <Divider sx={{ my: 0.5 }} />
                    )}
                  </Box>
                ))}
              </List>
            )}
          </Box>
        )}
      </DialogContent>
    </Dialog>
  );
}

