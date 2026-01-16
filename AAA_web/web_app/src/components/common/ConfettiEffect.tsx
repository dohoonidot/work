import { useEffect, useState } from 'react';
import { Box } from '@mui/material';

interface ConfettiEffectProps {
  active: boolean;
  duration?: number; // 지속 시간 (ms)
  onComplete?: () => void;
}

/**
 * 생일, 선물 수령 등 축하 이벤트에 사용되는 Confetti 효과
 *
 * 사용 예:
 * ```tsx
 * const [showConfetti, setShowConfetti] = useState(false);
 *
 * <ConfettiEffect
 *   active={showConfetti}
 *   duration={5000}
 *   onComplete={() => setShowConfetti(false)}
 * />
 * ```
 *
 * 주의: react-confetti 패키지가 설치되어 있어야 합니다.
 * npm install react-confetti
 */
export default function ConfettiEffect({ active, duration = 5000, onComplete }: ConfettiEffectProps) {
  const [windowSize, setWindowSize] = useState({
    width: window.innerWidth,
    height: window.innerHeight,
  });

  useEffect(() => {
    const handleResize = () => {
      setWindowSize({
        width: window.innerWidth,
        height: window.innerHeight,
      });
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  useEffect(() => {
    if (active && duration > 0) {
      const timer = setTimeout(() => {
        if (onComplete) {
          onComplete();
        }
      }, duration);

      return () => clearTimeout(timer);
    }
  }, [active, duration, onComplete]);

  if (!active) {
    return null;
  }

  // react-confetti가 설치되어 있으면 사용
  try {
    // 동적 import를 시도
    const ReactConfetti = require('react-confetti').default;

    return (
      <Box
        sx={{
          position: 'fixed',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          zIndex: 9999,
          pointerEvents: 'none',
        }}
      >
        <ReactConfetti
          width={windowSize.width}
          height={windowSize.height}
          recycle={false}
          numberOfPieces={500}
          gravity={0.3}
        />
      </Box>
    );
  } catch (error) {
    // react-confetti가 없으면 CSS 애니메이션으로 대체
    return (
      <Box
        sx={{
          position: 'fixed',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          zIndex: 9999,
          pointerEvents: 'none',
          overflow: 'hidden',
        }}
      >
        {/* CSS 기반 간단한 Confetti 효과 */}
        {[...Array(50)].map((_, i) => (
          <Box
            key={i}
            sx={{
              position: 'absolute',
              top: '-10px',
              left: `${Math.random() * 100}%`,
              width: `${Math.random() * 10 + 5}px`,
              height: `${Math.random() * 10 + 5}px`,
              bgcolor: `hsl(${Math.random() * 360}, 100%, 50%)`,
              borderRadius: Math.random() > 0.5 ? '50%' : '0',
              animation: `fall ${Math.random() * 3 + 2}s linear infinite`,
              animationDelay: `${Math.random() * 2}s`,
              '@keyframes fall': {
                '0%': {
                  transform: 'translateY(0) rotate(0deg)',
                  opacity: 1,
                },
                '100%': {
                  transform: `translateY(${windowSize.height}px) rotate(${Math.random() * 720 - 360}deg)`,
                  opacity: 0,
                },
              },
            }}
          />
        ))}
      </Box>
    );
  }
}

/**
 * Confetti Hook
 *
 * 사용 예:
 * ```tsx
 * const { triggerConfetti, ConfettiComponent } = useConfetti();
 *
 * <button onClick={triggerConfetti}>축하!</button>
 * {ConfettiComponent}
 * ```
 */
export function useConfetti(duration = 5000) {
  const [active, setActive] = useState(false);

  const triggerConfetti = () => {
    setActive(true);
  };

  const ConfettiComponent = (
    <ConfettiEffect
      active={active}
      duration={duration}
      onComplete={() => setActive(false)}
    />
  );

  return {
    triggerConfetti,
    ConfettiComponent,
    isActive: active,
  };
}
