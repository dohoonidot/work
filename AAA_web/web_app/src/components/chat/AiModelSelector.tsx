import { useState } from 'react';
import {
  Box,
  Popover,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Typography,
  IconButton,
} from '@mui/material';
import {
  Check as CheckIcon,
  KeyboardArrowDown as KeyboardArrowDownIcon,
} from '@mui/icons-material';
import { useThemeStore } from '../../store/themeStore';
import { useChatStore } from '../../store/chatStore';

// AI 모델 정의 (Flutter와 동일)
const AI_MODELS = [
  {
    id: 'gemini-pro-3',
    name: 'Gemini Pro 3',
    icon: '🚀', // 업그레이드된 버전으로 로켓 아이콘
    description: 'Google의 최신 고성능 AI',
  },
  {
    id: 'gpt-5.2',
    name: 'GPT-5.2',
    icon: '🤖', // 더 현대적인 로봇 아이콘
    description: 'OpenAI의 강화된 언어 모델',
  },
  {
    id: 'claude-sonnet-4.5',
    name: 'Claude Sonnet 4.5',
    icon: '🧠', // 유지
    description: 'Anthropic의 안전한 AI',
  },
];

interface AiModelSelectorProps {
  size?: 'small' | 'medium';
}

export default function AiModelSelector({ size = 'small' }: AiModelSelectorProps) {
  const { colorScheme } = useThemeStore();
  const { selectedModel, setSelectedModel } = useChatStore();
  const [anchorEl, setAnchorEl] = useState<HTMLElement | null>(null);
  const isDark = colorScheme.name === 'Dark';

  const currentModel = AI_MODELS.find((m) => m.id === selectedModel) || AI_MODELS[0];

  const handleClick = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorEl(event.currentTarget);
  };

  const handleClose = () => {
    setAnchorEl(null);
  };

  const handleSelect = (modelId: string) => {
    setSelectedModel(modelId);
    handleClose();
  };

  const open = Boolean(anchorEl);

  return (
    <>
      <Box
        component="button"
        onClick={handleClick}
        sx={{
          display: 'flex',
          alignItems: 'center',
          gap: 0.5,
          padding: size === 'small' ? '4px 8px' : '6px 12px',
          border: 'none',
          background: 'transparent',
          cursor: 'pointer',
          borderRadius: 1,
          '&:hover': {
            bgcolor: isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)',
          },
        }}
      >
        <Typography
          sx={{
            fontSize: size === 'small' ? '0.75rem' : '0.875rem',
            color: isDark ? '#B19CD9' : '#6B46C1',
            fontWeight: 600,
          }}
        >
          {currentModel.icon}
        </Typography>
        <Typography
          sx={{
            fontSize: size === 'small' ? '0.6875rem' : '0.75rem',
            color: isDark ? '#B19CD9' : '#6B46C1',
            fontWeight: 600,
          }}
        >
          {currentModel.name}
        </Typography>
        <KeyboardArrowDownIcon
          sx={{
            fontSize: size === 'small' ? '0.75rem' : '0.875rem',
            color: isDark ? '#8B5CF6' : '#6B46C1',
          }}
        />
      </Box>

      <Popover
        open={open}
        anchorEl={anchorEl}
        onClose={handleClose}
        anchorOrigin={{
          vertical: 'bottom',
          horizontal: 'left',
        }}
        transformOrigin={{
          vertical: 'top',
          horizontal: 'left',
        }}
        PaperProps={{
          sx: {
            mt: 0.5,
            minWidth: 250,
            bgcolor: isDark ? '#2D2D30' : '#FFFFFF',
            borderRadius: 1,
            boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
          },
        }}
      >
        <List sx={{ py: 0.5 }}>
          {AI_MODELS.map((model) => {
            const isSelected = selectedModel === model.id;
            return (
              <ListItem key={model.id} disablePadding>
                <ListItemButton
                  onClick={() => handleSelect(model.id)}
                  sx={{
                    py: 1.5,
                    px: 2,
                    minHeight: 60,
                    '&:hover': {
                      bgcolor: isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)',
                    },
                  }}
                >
                  <ListItemIcon sx={{ minWidth: 32 }}>
                    <Typography sx={{ fontSize: '1rem' }}>{model.icon}</Typography>
                  </ListItemIcon>
                  <ListItemText
                    primary={
                      <Typography
                        sx={{
                          fontSize: '0.6875rem',
                          fontWeight: 600,
                          color: isDark ? '#B19CD9' : '#000000',
                        }}
                      >
                        {model.name}
                      </Typography>
                    }
                    secondary={
                      <Typography
                        sx={{
                          fontSize: '0.625rem',
                          color: isDark ? '#888888' : '#666666',
                          mt: 0.25,
                        }}
                      >
                        {model.description}
                      </Typography>
                    }
                  />
                  {isSelected && (
                    <CheckIcon
                      sx={{
                        fontSize: '0.75rem',
                        color: isDark ? '#8B5CF6' : '#6B46C1',
                      }}
                    />
                  )}
                </ListItemButton>
              </ListItem>
            );
          })}
        </List>
      </Popover>
    </>
  );
}

