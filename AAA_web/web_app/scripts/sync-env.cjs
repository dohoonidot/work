/**
 * 환경 동기화 스크립트
 *
 * env.config.ts의 IS_PRODUCTION 값을 읽어서 .env 파일을 자동 생성합니다.
 * npm run build 실행 시 prebuild로 자동 실행됩니다.
 */

const fs = require('fs');
const path = require('path');

// 파일 경로
const ENV_CONFIG_PATH = path.join(__dirname, '../src/config/env.config.ts');
const ENV_FILE_PATH = path.join(__dirname, '../.env');

console.log('\n🔧 [sync-env] 환경 설정 동기화 시작...\n');

try {
  // 1. env.config.ts 파일 읽기
  const envConfigContent = fs.readFileSync(ENV_CONFIG_PATH, 'utf8');

  // 2. IS_PRODUCTION 값 추출 (정규식)
  const match = envConfigContent.match(/export\s+const\s+IS_PRODUCTION\s*=\s*(true|false)/);

  if (!match) {
    throw new Error('env.config.ts에서 IS_PRODUCTION 값을 찾을 수 없습니다.');
  }

  const isProduction = match[1] === 'true';

  console.log(`📋 IS_PRODUCTION = ${isProduction}`);
  console.log(`📋 환경: ${isProduction ? '프로덕션 (배포용)' : '개발 (Dev)'}`);

  // 3. API URL 결정
  const apiUrl = isProduction
    ? 'https://ai2great.com:8080'  // 프로덕션
    : 'https://ai2great.com:8060'; // 개발

  console.log(`📋 API URL: ${apiUrl}`);

  // 4. .env 파일 생성
  const envContent = `# API 서버 URL (자동 생성됨 - env.config.ts의 IS_PRODUCTION=${isProduction})
# 개발 환경: https://ai2great.com:8060
# 프로덕션 환경: https://ai2great.com:8080
VITE_API_URL=${apiUrl}

# 앱 정보
VITE_APP_NAME=ASPN AI Agent
VITE_APP_VERSION=1.3.0

# 서버 설정 (프로덕션 배포용)
PORT=443
HOST=0.0.0.0

# SSL 인증서 경로 (서버에 배포 후 사용)
CERT_PATH=/home/aspn2/AAA_WEB/fullchain.pem
KEY_PATH=/home/aspn2/AAA_WEB/privkey.key
`;

  fs.writeFileSync(ENV_FILE_PATH, envContent, 'utf8');

  console.log(`\n✅ .env 파일이 성공적으로 생성되었습니다.`);
  console.log(`   경로: ${ENV_FILE_PATH}`);
  console.log(`\n🚀 빌드를 계속 진행합니다...\n`);

} catch (error) {
  console.error('\n❌ 환경 설정 동기화 실패:', error.message);
  process.exit(1);
}
