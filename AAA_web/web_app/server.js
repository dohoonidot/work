/**
 * ASPN AI Agent Web Server
 * Express HTTPS 서버 - React 앱 프로덕션 배포
 *
 * 요구사항:
 * - HTTPS (포트 443)
 * - 호스트: 0.0.0.0 (모든 IP에서 접근 가능)
 * - CORS: 모든 origin 허용
 * - SPA 라우팅 지원
 * - 정적 파일 서빙 (dist/)
 */

import express from 'express';
import cors from 'cors';
import https from 'https';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs';

// ES 모듈에서 __dirname 구현
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();

// ============================================
// 1. 환경 설정
// ============================================
const PORT = process.env.PORT || 443;
const HOST = process.env.HOST || '0.0.0.0';
const CERT_PATH = process.env.CERT_PATH || '/home/aspn2/AAA_WEB/fullchain.pem';
const KEY_PATH = process.env.KEY_PATH || '/home/aspn2/AAA_WEB/privkey.key';

console.log('\n==============================================');
console.log('⚙️  Configuration');
console.log('==============================================');
console.log(`Port: ${PORT}`);
console.log(`Host: ${HOST}`);
console.log(`Cert: ${CERT_PATH}`);
console.log(`Key: ${KEY_PATH}`);
console.log(`Node ENV: ${process.env.NODE_ENV || 'production'}`);
console.log('==============================================\n');

// ============================================
// 2. 미들웨어 설정
// ============================================

// CORS 설정 - 모든 origin 허용
app.use(cors({
  origin: '*', // 모든 도메인 허용
  credentials: true, // 쿠키 전송 허용
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Cookie', 'X-Requested-With']
}));

// Preflight 요청 처리
app.options('*', cors());

// JSON 요청 본문 파싱
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 요청 로깅 미들웨어
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.url} - IP: ${req.ip}`);
  next();
});

// ============================================
// 3. 정적 파일 서빙
// ============================================

// dist 폴더의 정적 파일 서빙
const distPath = join(__dirname, 'dist');
console.log(`📁 Static files path: ${distPath}`);

// dist 폴더 존재 확인
if (!fs.existsSync(distPath)) {
  console.error(`❌ ERROR: dist folder not found at: ${distPath}`);
  console.error('   Please run "npm run build:prod" first');
  process.exit(1);
}

app.use(express.static(distPath, {
  maxAge: '1d', // 캐시 1일
  etag: true,
  lastModified: true,
  setHeaders: (res, path) => {
    // HTML 파일은 캐시하지 않음 (항상 최신 버전 제공)
    if (path.endsWith('.html')) {
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
      res.setHeader('Pragma', 'no-cache');
      res.setHeader('Expires', '0');
    }
    // 보안 헤더 추가
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
  }
}));

// ============================================
// 4. 헬스체크 엔드포인트
// ============================================
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'production',
    version: '1.0.0'
  });
});

// 서버 정보 엔드포인트 (개발용)
app.get('/api/server-info', (req, res) => {
  res.json({
    name: 'ASPN AI Agent Web Server',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'production',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// ============================================
// 5. SPA 라우팅 처리
// ============================================

// 모든 라우트를 index.html로 리다이렉트 (React Router 지원)
app.get('*', (req, res) => {
  const indexPath = join(distPath, 'index.html');

  // index.html 파일 존재 확인
  if (!fs.existsSync(indexPath)) {
    console.error(`❌ index.html not found at: ${indexPath}`);
    return res.status(500).send('Server configuration error: index.html not found');
  }

  res.sendFile(indexPath);
});

// ============================================
// 6. 에러 핸들링 미들웨어
// ============================================
app.use((err, req, res, next) => {
  console.error('❌ Server error:', err);

  // 에러 응답
  res.status(err.status || 500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
    timestamp: new Date().toISOString()
  });
});

// ============================================
// 7. HTTPS 서버 시작
// ============================================

// SSL 인증서 로드
let httpsOptions;
try {
  console.log('🔐 Loading SSL certificates...');
  httpsOptions = {
    cert: fs.readFileSync(CERT_PATH, 'utf8'),
    key: fs.readFileSync(KEY_PATH, 'utf8')
  };
  console.log('✅ SSL certificates loaded successfully');
} catch (error) {
  console.error('\n❌ Failed to load SSL certificates:');
  console.error(`   Error: ${error.message}`);
  console.error(`   Cert path: ${CERT_PATH}`);
  console.error(`   Key path: ${KEY_PATH}`);
  console.error('\nPlease check:');
  console.error('1. Certificate files exist');
  console.error('2. File paths are correct');
  console.error('3. You have read permissions');
  console.error('\n');
  process.exit(1);
}

// HTTPS 서버 생성 및 시작
const server = https.createServer(httpsOptions, app);

server.listen(PORT, HOST, () => {
  console.log('\n==============================================');
  console.log('🚀 ASPN AI Agent Web Server Started');
  console.log('==============================================');
  console.log(`📡 HTTPS Server: https://${HOST === '0.0.0.0' ? 'localhost' : HOST}:${PORT}`);
  console.log(`📁 Static files: ${distPath}`);
  console.log(`🔒 SSL Cert: ${CERT_PATH}`);
  console.log(`🔑 SSL Key: ${KEY_PATH}`);
  console.log(`🌐 CORS: Enabled (all origins)`);
  console.log(`⏰ Started at: ${new Date().toISOString()}`);
  console.log('==============================================');
  console.log('\n✨ Server is ready to accept connections!\n');
  console.log('Health check: https://localhost/health');
  console.log('Press Ctrl+C to stop the server\n');
});

// 에러 핸들링
server.on('error', (error) => {
  console.error('\n❌ Server error occurred:');

  if (error.code === 'EACCES') {
    console.error(`   Port ${PORT} requires elevated privileges`);
    console.error('   Solution: Run with sudo');
    console.error(`   Example: sudo node server.js`);
  } else if (error.code === 'EADDRINUSE') {
    console.error(`   Port ${PORT} is already in use`);
    console.error('   Solution: Stop the other process or use a different port');
    console.error(`   Check: sudo lsof -i :${PORT}`);
  } else {
    console.error(`   ${error.message}`);
  }

  console.error('\n');
  process.exit(1);
});

// Graceful shutdown
const gracefulShutdown = (signal) => {
  console.log(`\n⚠️  ${signal} received, closing server gracefully...`);

  server.close(() => {
    console.log('✅ HTTPS server closed');
    console.log('👋 Goodbye!\n');
    process.exit(0);
  });

  // 강제 종료 타임아웃 (10초)
  setTimeout(() => {
    console.error('❌ Could not close connections in time, forcefully shutting down');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// 처리되지 않은 Promise rejection 처리
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
});

// 처리되지 않은 예외 처리
process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  gracefulShutdown('UNCAUGHT_EXCEPTION');
});
