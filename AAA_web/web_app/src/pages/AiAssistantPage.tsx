import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useChatStore } from '../store/chatStore';
import chatService from '../services/chatService';
import authService from '../services/authService';
import { Box, CircularProgress, Typography } from '@mui/material';

/**
 * AI Chatbot 페이지
 * "AI Chatbot" 아카이브를 자동으로 선택하고 채팅 페이지로 리다이렉트
 */
export default function AiAssistantPage() {
  const navigate = useNavigate();
  const { archives, setCurrentArchive, loadArchives } = useChatStore();
  const [isCreating, setIsCreating] = useState(false);

  useEffect(() => {
    const handleAiAssistant = async () => {
      console.log('AI Chatbot 페이지 진입');
      console.log('현재 아카이브 목록:', archives);

      // "AI Chatbot" 아카이브 찾기 (Flutter와 동일)
      let aiChatbotArchive = archives.find(
        (archive) => archive.archive_name === 'AI Chatbot' && archive.archive_type === ''
      );

      console.log('AI Chatbot 아카이브:', aiChatbotArchive);

      if (!aiChatbotArchive) {
        // AI Chatbot 아카이브가 없으면 생성
        console.log('AI Chatbot 아카이브가 없습니다. 생성합니다...');
        setIsCreating(true);

        try {
          const user = authService.getCurrentUser();
          if (!user) {
            console.error('사용자 정보가 없습니다.');
            navigate('/login', { replace: true });
            return;
          }

          // AI Chatbot 아카이브 생성 (Flutter와 동일: archive_type = '')
          const response = await chatService.createArchive(user.userId, '');
          console.log('AI Chatbot 생성 응답:', response);

          // 생성된 아카이브 이름을 "AI Chatbot"으로 변경
          if (response.archive.archive_name !== 'AI Chatbot') {
            await chatService.updateArchive(response.archive.archive_id, 'AI Chatbot');
            response.archive.archive_name = 'AI Chatbot';
          }

          // 아카이브 목록 새로고침
          await loadArchives();

          // 다시 찾기 (Flutter와 동일한 조건)
          aiChatbotArchive = archives.find(
            (archive) => archive.archive_name === 'AI Chatbot' && archive.archive_type === ''
          );
        } catch (error) {
          console.error('AI Chatbot 아카이브 생성 실패:', error);
          // 실패해도 채팅 페이지로 이동
          navigate('/chat', { replace: true });
          return;
        } finally {
          setIsCreating(false);
        }
      }

      if (aiChatbotArchive) {
        console.log('AI Chatbot 아카이브로 전환:', aiChatbotArchive);
        
        // Flutter의 selectTopic과 동일한 로직
        // 1. 현재 아카이브 상태 업데이트
        setCurrentArchive(aiChatbotArchive);
        
        // 2. 상태 업데이트 확인
        console.log('setCurrentArchive 호출 완료');
        
        // 3. 상태 업데이트 완료 대기
        await new Promise(resolve => setTimeout(resolve, 200));
        
        // 4. 채팅 페이지로 리다이렉트
        navigate('/chat', { replace: true });
      } else {
        // AI Chatbot이 없으면 바로 이동
        navigate('/chat', { replace: true });
      }
    };

    handleAiAssistant();
  }, [archives, setCurrentArchive, navigate, loadArchives]);

  // 로딩 중 표시
  return (
    <Box
      sx={{
        height: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 2,
      }}
    >
      <CircularProgress />
      <Typography variant="body2" color="text.secondary">
        {isCreating
          ? 'AI Chatbot 아카이브를 생성하는 중...'
          : 'AI Chatbot으로 이동 중...'}
      </Typography>
    </Box>
  );
}
