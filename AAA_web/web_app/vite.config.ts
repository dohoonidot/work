import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// API 서버 URL (개발: 8060, 프로덕션: 8080)
const API_TARGET = process.env.VITE_API_URL || 
  (process.env.NODE_ENV === 'development' 
    ? 'https://ai2great.com:8060' 
    : 'https://ai2great.com:8080');

console.log(`🔧 [Vite Config] API Target: ${API_TARGET}`);

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
    open: true, // 브라우저 자동 열기
    hmr: {
      port: 5173,
      clientPort: 5173,
      host: 'localhost',
    },
    // SPA 라우팅을 위한 설정
    middlewareMode: false,
    cors: true,
    proxy: {
      // SSE 알림 프록시 설정
      '/sse': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
        ws: true, // WebSocket 지원 (SSE도 포함)
        configure: (proxy, _options) => {
          proxy.on('proxyReq', (proxyReq, req, _res) => {
            // 쿠키 헤더를 명시적으로 전달
            if (req.headers.cookie) {
              proxyReq.setHeader('Cookie', req.headers.cookie);
              console.log('[SSE Proxy] 쿠키 전달:', req.headers.cookie);
            }
          });
          proxy.on('proxyRes', (proxyRes, _req, _res) => {
            // Set-Cookie 헤더 전달 (백엔드에서 쿠키 설정 시)
            if (proxyRes.headers['set-cookie']) {
              console.log('[SSE Proxy] Set-Cookie 수신:', proxyRes.headers['set-cookie']);
            }
          });
        },
      },
      // API 프록시 설정 - CORS 문제 해결
      '/api': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
        configure: (proxy, _options) => {
          proxy.on('proxyReq', (proxyReq, req, _res) => {
            // 쿠키 헤더를 명시적으로 전달
            if (req.headers.cookie) {
              proxyReq.setHeader('Cookie', req.headers.cookie);
            }
          });
          proxy.on('proxyRes', (proxyRes, _req, _res) => {
            // Set-Cookie 헤더 전달 (로그인 시 session_id 쿠키 수신)
            if (proxyRes.headers['set-cookie']) {
              console.log('[API Proxy] Set-Cookie 수신:', proxyRes.headers['set-cookie']);
            }
          });
        },
      },
      '/streamChat/timeout': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
        configure: (proxy, _options) => {
          proxy.on('proxyReq', (proxyReq, _req, _res) => {
            // CORS 헤더 추가
            proxyReq.setHeader('Access-Control-Allow-Origin', '*');
            proxyReq.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
            proxyReq.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
          });
          proxy.on('proxyRes', (proxyRes, _req, _res) => {
            // 응답에 CORS 헤더 추가
            proxyRes.headers['Access-Control-Allow-Origin'] = '*';
            proxyRes.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS';
            proxyRes.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization';
          });
        },
      },
      '/streamChat/withModel': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
        configure: (proxy, _options) => {
          proxy.on('proxyReq', (proxyReq, _req, _res) => {
            // CORS 헤더 추가
            proxyReq.setHeader('Access-Control-Allow-Origin', '*');
            proxyReq.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
            proxyReq.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
          });
          proxy.on('proxyRes', (proxyRes, _req, _res) => {
            // 응답에 CORS 헤더 추가
            proxyRes.headers['Access-Control-Allow-Origin'] = '*';
            proxyRes.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS';
            proxyRes.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization';
          });
        },
      },
      '/getArchiveList': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
      },
      '/getSingleArchive': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
      },
      '/createArchive': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
      },
      '/updateArchive': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
      },
      '/updatePassword': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
      },
      '/deleteArchive': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
      },
      '/checkPrivacy': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
      },
      '/updatePrivacy': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
      },
      '/checkGifts': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
      },
      '/queue/checkGifts': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path,
      },
        '/send_birthday_gift': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        // 휴가관리 API 프록시
        '/leave/user/management': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/user/management/myCalendar': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/user/management/yearlyLeave': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/user/management/totalCalendar': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/user/request': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/user/cancel': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/admin/management': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/admin/management/deptCalendar': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/admin/approval': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/admin/approval/cancel': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/api/leave/management-table': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/user/management/departmentHistory': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        // 추가 휴가관리 API 프록시 (Flutter와 동일)
        '/api/leave/balance': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/user/management/yearly': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/admin/status': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/leave/admin/grant': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        // 사내AI 공모전 API 프록시
        '/contest/management': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/contest/chat': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/contest/vote': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/contest/user/remainVotes': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/contest/userInfo': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/contest/user/management': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
        '/api/getFileUrl': {
          target: API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path,
        },
      },
  },
})
