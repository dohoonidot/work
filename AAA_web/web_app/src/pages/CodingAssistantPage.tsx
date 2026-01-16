import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  FormControl,
  Select,
  MenuItem,
  InputLabel,
  Chip,
} from '@mui/material';
import {
  Code as CodeIcon,
} from '@mui/icons-material';
import MobileMainLayout from '../components/layout/MobileMainLayout';
import ChatArea from '../components/chat/ChatArea';
import chatService from '../services/chatService';
import authService from '../services/authService';
import { useChatStore } from '../store/chatStore';
import type { Archive } from '../services/chatService';

export default function CodingAssistantPage() {
  const [currentArchive, setCurrentArchive] = useState<Archive | null>(null);
  const [archives, setArchives] = useState<Archive[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [aiModel, setAiModel] = useState('gemini-flash-2.5');
  const { setCurrentArchive: setGlobalCurrentArchive } = useChatStore();

  // 코딩 어시스턴트 아카이브 로드 및 생성
  useEffect(() => {
    loadArchives();
  }, []);

  const loadArchives = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const user = authService.getCurrentUser();
      if (!user) {
        setError('사용자 정보를 찾을 수 없습니다.');
        return;
      }

      console.log('코딩 어시스턴트 아카이브 로드 시작:', user.userId);
      
      // 기존 아카이브 목록 조회
      const archiveList = await chatService.getArchiveList(user.userId);
      console.log('로드된 아카이브 목록:', archiveList);
      
      // 코딩 관련 아카이브 찾기
      let codingArchive = archiveList.find(archive => 
        archive.archive_name.toLowerCase().includes('코딩') || 
        archive.archive_name.toLowerCase().includes('coding') ||
        archive.archive_name.toLowerCase().includes('코딩 어시스턴트')
      );
      
      // 코딩 아카이브가 없으면 생성
      if (!codingArchive) {
        console.log('코딩 어시스턴트 아카이브가 없어서 생성합니다.');
        codingArchive = await chatService.createArchive(
          user.userId,
          '코딩 어시스턴트',
          'coding'
        );
        console.log('생성된 코딩 어시스턴트 아카이브:', codingArchive);
      }
      
      setArchives(archiveList);
      setCurrentArchive(codingArchive);
      // 전역 상태에도 반영하여 사이드바에서 선택 상태 표시
      setGlobalCurrentArchive(codingArchive);
      
    } catch (err: any) {
      console.error('코딩 어시스턴트 아카이브 로드 실패:', err);
      setError(err.message || '코딩 어시스턴트 아카이브를 불러오는데 실패했습니다.');
    } finally {
      setLoading(false);
    }
  };

  const handleSendMessage = async (message: string) => {
    if (!currentArchive) return;
    
    try {
      await chatService.sendMessage(
        currentArchive.archive_name,
        message,
        aiModel,
        'CODING',
        ''
      );
    } catch (err: any) {
      console.error('메시지 전송 실패:', err);
      setError(err.message || '메시지 전송에 실패했습니다.');
    }
  };

  return (
    <MobileMainLayout>
      <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        {/* 코딩 어시스턴트 설정 영역 - AI 모델 선택 */}
        <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider', bgcolor: 'background.paper' }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            {/* AI 모델 선택 - 왼쪽에 위치 */}
            <FormControl size="small" sx={{ minWidth: 180 }}>
              <InputLabel>AI 모델</InputLabel>
              <Select
                value={aiModel}
                label="AI 모델"
                onChange={(e) => setAiModel(e.target.value)}
                sx={{ borderRadius: 2 }}
              >
                <MenuItem value="gemini-flash-2.5">
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Chip label="⚡" size="small" sx={{ bgcolor: '#4285F4', color: 'white', fontSize: '0.7rem' }} />
                    <Typography variant="body2" sx={{ fontSize: '0.8rem' }}>Gemini Flash 2.5</Typography>
                  </Box>
                </MenuItem>
                <MenuItem value="gpt-5">
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Chip label="🚀" size="small" sx={{ bgcolor: '#10A37F', color: 'white', fontSize: '0.7rem' }} />
                    <Typography variant="body2" sx={{ fontSize: '0.8rem' }}>GPT-5</Typography>
                  </Box>
                </MenuItem>
                <MenuItem value="claude-sonnet-4">
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Chip label="🧠" size="small" sx={{ bgcolor: '#FF6B35', color: 'white', fontSize: '0.7rem' }} />
                    <Typography variant="body2" sx={{ fontSize: '0.8rem' }}>Claude Sonnet 4</Typography>
                  </Box>
                </MenuItem>
              </Select>
            </FormControl>

            {/* 오른쪽 빈공간 */}
            <Box sx={{ flex: 1 }} />
          </Box>
        </Box>

        {/* 채팅 영역 - 더 큰 공간 */}
        <Box sx={{ flex: 1, overflow: 'hidden' }}>
          <ChatArea
            currentArchive={currentArchive}
            onSendMessage={handleSendMessage}
            showAiModelSelection={false}
            aiModel={aiModel}
            onAiModelChange={setAiModel}
            loading={loading}
            error={error}
          />
        </Box>
      </Box>
    </MobileMainLayout>
  );
}
