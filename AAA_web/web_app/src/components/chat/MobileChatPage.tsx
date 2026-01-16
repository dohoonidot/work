import {
  Box,
} from '@mui/material';
import ChatArea from './ChatArea';
import type { Archive } from '../../types';

interface MobileChatPageProps {
  archives: Archive[];
  currentArchive: Archive | null;
  onSelectArchive: (archive: Archive) => void;
  onCreateArchive: (archiveType: string) => void;
}

export default function MobileChatPage({
}: MobileChatPageProps) {

  return (
    <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* 채팅 영역 */}
      <Box sx={{ flex: 1, overflow: 'hidden' }}>
        <ChatArea />
      </Box>
    </Box>
  );
}
