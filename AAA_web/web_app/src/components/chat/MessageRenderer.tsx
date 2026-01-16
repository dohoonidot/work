import { Box, Typography, CircularProgress, IconButton, Tooltip } from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import ContentCopyIcon from '@mui/icons-material/ContentCopy';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus, vs } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { useThemeStore } from '../../store/themeStore';

interface MessageParts {
  thoughtPart: string;
  responsePart: string;
  hasThoughtCompleted: boolean;
}

interface MessageRendererProps {
  message: string;
  isStreaming?: boolean;
  archiveName?: string;
}

/**
 * Flutter의 parseThinkingResponse 로직과 동일하게 메시지를 파싱
 */
function parseMessage(message: string, archiveName: string): MessageParts {
  // AI Chatbot, 코딩어시스턴트, SAP어시스턴트는 CoT 사용 안함
  const shouldDisableCOT =
    archiveName === 'AI Chatbot' ||
    archiveName === '코딩어시스턴트' ||
    archiveName === 'SAP어시스턴트';

  if (shouldDisableCOT) {
    return {
      thoughtPart: '',
      responsePart: message,
      hasThoughtCompleted: true,
    };
  }

  // </think> 태그 찾기
  const thinkEndIndex = message.indexOf('</think>');

  if (thinkEndIndex !== -1) {
    // </think> 태그가 있으면 생각 과정과 응답 분리
    const thoughtPart = message.substring(0, thinkEndIndex + 8); // </think> 포함
    const responsePart =
      thinkEndIndex + 8 < message.length
        ? message.substring(thinkEndIndex + 8).trim()
        : '';

    return {
      thoughtPart,
      responsePart,
      hasThoughtCompleted: true,
    };
  } else if (message.includes('<think>')) {
    // <think>는 있지만 </think>가 아직 없음 (스트리밍 중)
    return {
      thoughtPart: message,
      responsePart: '',
      hasThoughtCompleted: false,
    };
  }

  // CoT 태그가 없으면 전체를 응답으로 처리
  return {
    thoughtPart: '',
    responsePart: message,
    hasThoughtCompleted: true,
  };
}

/**
 * Flutter의 buildThoughtWidget과 동일한 스타일의 생각 과정 위젯
 */
function ThoughtWidget({
  thoughtText,
  isStreaming,
  hasThoughtCompleted,
}: {
  thoughtText: string;
  isStreaming: boolean;
  hasThoughtCompleted: boolean;
}) {
  // 헤더 텍스트 결정 (Flutter 로직과 동일)
  const headerText = isStreaming
    ? hasThoughtCompleted
      ? '답변 중...'
      : '생각 중...'
    : '답변 종료';

  // <think> 태그 제거하여 표시
  const cleanedText = thoughtText
    .replace(/<think>/g, '')
    .replace(/<\/think>/g, '')
    .trim();

  return (
    <Box
      sx={{
        width: '100%',
        mb: 1,
        borderRadius: 2,
        border: '1px solid',
        borderColor: 'divider',
        bgcolor: 'grey.50',
        boxShadow: 1,
      }}
    >
      {/* 헤더 */}
      <Box
        sx={{
          p: 1.5,
          borderBottom: '1px solid',
          borderColor: 'divider',
          display: 'flex',
          alignItems: 'center',
          gap: 1,
        }}
      >
        {isStreaming ? (
          <CircularProgress size={16} sx={{ color: '#03a9f4' }} />
        ) : (
          <CheckCircleIcon sx={{ fontSize: 16, color: '#03a9f4' }} />
        )}
        <Typography
          variant="caption"
          sx={{ fontWeight: 'bold', fontSize: '0.875rem' }}
        >
          {headerText}
        </Typography>
      </Box>

      {/* 내용 */}
      <Box
        sx={{
          p: 1.5,
          maxHeight: 100,
          minHeight: 50,
          overflow: 'auto',
          // ✅ 텍스트 선택 활성화 (!important 추가)
          userSelect: 'text !important',
          cursor: 'text !important',
          WebkitUserSelect: 'text !important',
          MozUserSelect: 'text !important',
          '&::-webkit-scrollbar': {
            width: '6px',
          },
          '&::-webkit-scrollbar-thumb': {
            bgcolor: 'grey.400',
            borderRadius: '3px',
          },
        }}
      >
        <Typography
          variant="body2"
          sx={{
            fontSize: '0.8125rem',
            fontStyle: 'italic',
            color: 'text.secondary',
            whiteSpace: 'pre-wrap',
            // ✅ 텍스트 선택 활성화 (!important 추가)
            userSelect: 'text !important',
            WebkitUserSelect: 'text !important',
            MozUserSelect: 'text !important',
          }}
        >
          {cleanedText}
        </Typography>
      </Box>
    </Box>
  );
}

/**
 * 구분선 컴포넌트 (Flutter의 _buildDivider와 동일)
 */
function ResponseDivider() {
  return (
    <Box sx={{ display: 'flex', alignItems: 'center', my: 1 }}>
      <Box sx={{ flex: 1, height: '1px', bgcolor: 'divider' }} />
      <Typography
        variant="caption"
        sx={{
          px: 1.5,
          color: 'text.secondary',
          fontSize: '0.75rem',
        }}
      >
        최종 응답
      </Typography>
      <Box sx={{ flex: 1, height: '1px', bgcolor: 'divider' }} />
    </Box>
  );
}

/**
 * 코드 블록 컴포넌트 (코드 하이라이팅 포함)
 */
function CodeBlock({ 
  language, 
  children 
}: { 
  language?: string; 
  children: string;
}) {
  const { colorScheme } = useThemeStore();
  const isDark = colorScheme.name === 'Dark';
  const codeStyle = isDark ? vscDarkPlus : vs;

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(children);
      // 복사 성공 피드백 (추후 스낵바로 개선 가능)
    } catch (err) {
      console.error('복사 실패:', err);
    }
  };

  return (
    <Box
      sx={{
        position: 'relative',
        my: 1,
        borderRadius: 1,
        overflow: 'hidden',
        border: `1px solid ${colorScheme.textFieldBorderColor}`,
        bgcolor: colorScheme.codeBlockBackgroundColor,
      }}
    >
      {/* 코드 블록 헤더 (언어명 + 복사 버튼) */}
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          px: 1.5,
          py: 0.5,
          bgcolor: isDark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.02)',
          borderBottom: `1px solid ${colorScheme.textFieldBorderColor}`,
        }}
      >
        <Typography
          variant="caption"
          sx={{
            fontSize: '0.75rem',
            color: colorScheme.hintTextColor,
            fontWeight: 500,
          }}
        >
          {language || 'code'}
        </Typography>
        <Tooltip title="코드 복사">
          <IconButton
            size="small"
            onClick={handleCopy}
            sx={{
              color: colorScheme.copyButtonColor,
              '&:hover': {
                bgcolor: isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)',
              },
            }}
          >
            <ContentCopyIcon sx={{ fontSize: '0.875rem' }} />
          </IconButton>
        </Tooltip>
      </Box>

      {/* 코드 하이라이팅 */}
      <SyntaxHighlighter
        language={language || 'text'}
        style={codeStyle}
        customStyle={{
          margin: 0,
          padding: '1rem',
          fontSize: '0.875rem',
          lineHeight: 1.5,
          backgroundColor: 'transparent',
          // ✅ 코드 블록 텍스트 선택 활성화 (!important 추가)
          userSelect: 'text !important',
          WebkitUserSelect: 'text !important',
          MozUserSelect: 'text !important',
          msUserSelect: 'text !important',
        }}
        PreTag="div"
      >
        {String(children).replace(/\n$/, '')}
      </SyntaxHighlighter>
    </Box>
  );
}

/**
 * 응답 부분 렌더링 (Markdown)
 */
function ResponseContent({ text }: { text: string }) {
  const { colorScheme } = useThemeStore();
  const isDark = colorScheme.name === 'Dark';

  return (
    <ReactMarkdown
      remarkPlugins={[remarkGfm]}
      components={{
        code({ node, inline, className, children, ...props }: any) {
          const match = /language-(\w+)/.exec(className || '');
          const language = match ? match[1] : '';
          const codeString = String(children).replace(/\n$/, '');

          return !inline && language ? (
            <CodeBlock language={language}>{codeString}</CodeBlock>
          ) : (
            <code
              style={{
                backgroundColor: colorScheme.codeBlockBackgroundColor,
                color: colorScheme.codeTextColor,
                padding: '2px 6px',
                borderRadius: '4px',
                fontSize: '0.9em',
                fontFamily: 'monospace',
              }}
              {...props}
            >
              {children}
            </code>
          );
        },
        a({ node, children, ...props }: any) {
          return (
            <a
              {...props}
              style={{ 
                color: colorScheme.linkTextColor, 
                textDecoration: 'underline' 
              }}
              target="_blank"
              rel="noopener noreferrer"
            >
              {children}
            </a>
          );
        },
        p({ children }: any) {
          return (
            <Typography
              variant="body1"
              sx={{
                color: colorScheme.markdownTextColor,
                mb: 1,
                lineHeight: 1.7,
              }}
            >
              {children}
            </Typography>
          );
        },
        h1({ children }: any) {
          return (
            <Typography
              variant="h4"
              sx={{
                color: colorScheme.markdownTextColor,
                fontWeight: 700,
                mt: 2,
                mb: 1,
              }}
            >
              {children}
            </Typography>
          );
        },
        h2({ children }: any) {
          return (
            <Typography
              variant="h5"
              sx={{
                color: colorScheme.markdownTextColor,
                fontWeight: 600,
                mt: 2,
                mb: 1,
              }}
            >
              {children}
            </Typography>
          );
        },
        h3({ children }: any) {
          return (
            <Typography
              variant="h6"
              sx={{
                color: colorScheme.markdownTextColor,
                fontWeight: 600,
                mt: 1.5,
                mb: 0.5,
              }}
            >
              {children}
            </Typography>
          );
        },
        ul({ children }: any) {
          return (
            <Box
              component="ul"
              sx={{
                color: colorScheme.markdownTextColor,
                pl: 3,
                mb: 1,
              }}
            >
              {children}
            </Box>
          );
        },
        ol({ children }: any) {
          return (
            <Box
              component="ol"
              sx={{
                color: colorScheme.markdownTextColor,
                pl: 3,
                mb: 1,
              }}
            >
              {children}
            </Box>
          );
        },
        li({ children }: any) {
          return (
            <Box
              component="li"
              sx={{
                color: colorScheme.markdownTextColor,
                mb: 0.5,
              }}
            >
              {children}
            </Box>
          );
        },
        table({ children }: any) {
          return (
            <Box
              component="table"
              sx={{
                width: '100%',
                borderCollapse: 'collapse',
                my: 2,
                border: `1px solid ${colorScheme.textFieldBorderColor}`,
              }}
            >
              {children}
            </Box>
          );
        },
        th({ children }: any) {
          return (
            <Box
              component="th"
              sx={{
                border: `1px solid ${colorScheme.textFieldBorderColor}`,
                p: 1,
                bgcolor: isDark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.02)',
                color: colorScheme.tableTextColor,
                fontWeight: 600,
                textAlign: 'left',
              }}
            >
              {children}
            </Box>
          );
        },
        td({ children }: any) {
          return (
            <Box
              component="td"
              sx={{
                border: `1px solid ${colorScheme.textFieldBorderColor}`,
                p: 1,
                color: colorScheme.tableTextColor,
              }}
            >
              {children}
            </Box>
          );
        },
        blockquote({ children }: any) {
          return (
            <Box
              component="blockquote"
              sx={{
                borderLeft: `4px solid ${colorScheme.primaryColor}`,
                pl: 2,
                ml: 0,
                my: 1,
                fontStyle: 'italic',
                color: colorScheme.hintTextColor,
              }}
            >
              {children}
            </Box>
          );
        },
      }}
    >
      {text}
    </ReactMarkdown>
  );
}

/**
 * 메인 메시지 렌더러
 * Flutter의 CoT 처리 로직을 React로 구현
 */
export default function MessageRenderer({
  message,
  isStreaming = false,
  archiveName = '사내업무',
}: MessageRendererProps) {
  const { thoughtPart, responsePart, hasThoughtCompleted } = parseMessage(
    message,
    archiveName
  );

  return (
    <Box
      sx={{
        // ✅ 텍스트 드래그 & 복사 활성화 (!important 추가)
        userSelect: 'text !important',
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
      {/* 생각 과정 표시 */}
      {thoughtPart && (
        <>
          <ThoughtWidget
            thoughtText={thoughtPart}
            isStreaming={isStreaming}
            hasThoughtCompleted={hasThoughtCompleted}
          />

          {/* 생각이 완료되고 응답이 있으면 구분선 */}
          {hasThoughtCompleted && responsePart && <ResponseDivider />}
        </>
      )}

      {/* 최종 응답 표시 */}
      {responsePart && <ResponseContent text={responsePart} />}
    </Box>
  );
}
