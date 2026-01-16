// import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'

createRoot(document.getElementById('root')!).render(
  // StrictMode는 개발 중 중복 렌더링을 유발할 수 있어 비활성화
  // 프로덕션 빌드에서는 자동으로 제거됨
  // <StrictMode>
    <App />
  // </StrictMode>,
)
