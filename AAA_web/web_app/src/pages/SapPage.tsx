import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Button,
  FormControl,
  Select,
  MenuItem,
  InputLabel,
  Chip,
  Stack,
} from '@mui/material';
import {
  Business as SapIcon,
} from '@mui/icons-material';
import MobileMainLayout from '../components/layout/MobileMainLayout';
import ChatArea from '../components/chat/ChatArea';
import chatService from '../services/chatService';
import authService from '../services/authService';
import { useChatStore } from '../store/chatStore';
import type { Archive } from '../services/chatService';

export default function SapPage() {
  const [currentArchive, setCurrentArchive] = useState<Archive | null>(null);
  const [archives, setArchives] = useState<Archive[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [aiModel, setAiModel] = useState('gemini-flash-2.5');
  const [selectedModule, setSelectedModule] = useState<string>('');
  const { setCurrentArchive: setGlobalCurrentArchive } = useChatStore();

  // SAP 아카이브 로드 및 생성
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

      console.log('SAP 아카이브 로드 시작:', user.userId);

      // 기존 아카이브 목록 조회
      const archiveList = await chatService.getArchiveList(user.userId);
      console.log('로드된 아카이브 목록:', archiveList);

      // SAP 관련 아카이브 찾기
      let sapArchive = archiveList.find(archive =>
        archive.archive_name.toLowerCase().includes('sap') ||
        archive.archive_name.toLowerCase().includes('sap 어시스턴트')
      );

      // SAP 아카이브가 없으면 생성
      if (!sapArchive) {
        console.log('SAP 아카이브가 없어서 생성합니다.');
        sapArchive = await chatService.createArchive(
          user.userId,
          'SAP 어시스턴트',
          'sap'
        );
        console.log('생성된 SAP 아카이브:', sapArchive);
      }

      setArchives(archiveList);
      setCurrentArchive(sapArchive);
      // 전역 상태에도 반영하여 사이드바에서 선택 상태 표시
      setGlobalCurrentArchive(sapArchive);

    } catch (err: any) {
      console.error('SAP 아카이브 로드 실패:', err);
      setError(err.message || 'SAP 아카이브를 불러오는데 실패했습니다.');
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
        'SAP',
        selectedModule || ''
      );
    } catch (err: any) {
      console.error('메시지 전송 실패:', err);
      setError(err.message || '메시지 전송에 실패했습니다.');
    }
  };

  return (
    <MobileMainLayout>
      <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        {/* SAP 설정 영역 - 모듈 선택과 AI 모델 선택 */}
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

            {/* SAP 모듈 선택 - 오른쪽에 위치 */}
            <Box sx={{ flex: 1 }} />
            <FormControl size="small" sx={{ minWidth: 180 }}>
              <InputLabel>SAP 모듈</InputLabel>
              <Select
                value={selectedModule}
                label="SAP 모듈"
                onChange={(e) => setSelectedModule(e.target.value)}
                sx={{ borderRadius: 2 }}
              >
                <MenuItem value="">
                  <em>모듈을 선택하세요</em>
                </MenuItem>
                {['BC', 'CO', 'FI', 'HR', 'IS', 'MM', 'PM', 'PP', 'PS', 'QM', 'SD', 'TR', 'WF', 'General'].map(code => (
                  <MenuItem key={code} value={code}>
                    {code}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
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

// 사용하지 않는 컴포넌트들 제거
