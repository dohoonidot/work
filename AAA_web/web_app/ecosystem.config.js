/**
 * PM2 프로세스 관리 설정
 * ASPN AI Agent Web Server
 *
 * 사용법:
 *   sudo pm2 start ecosystem.config.js
 *   sudo pm2 restart aspn-web
 *   sudo pm2 stop aspn-web
 *   sudo pm2 logs aspn-web
 *   sudo pm2 monit
 */

export default {
  apps: [{
    name: 'aspn-web',
    script: './server.js',

    // 인스턴스 설정
    instances: 1,  // 단일 인스턴스 (443 포트는 하나만)
    exec_mode: 'fork',  // cluster 모드는 사용하지 않음

    // 환경 변수
    env: {
      NODE_ENV: 'production',
      PORT: 443,
      HOST: '0.0.0.0',
      CERT_PATH: '/home/aspn2/AAA_WEB/fullchain.pem',
      KEY_PATH: '/home/aspn2/AAA_WEB/privkey.key'
    },

    // 개발 환경 (선택사항)
    env_development: {
      NODE_ENV: 'development',
      PORT: 8443,
      HOST: '0.0.0.0',
      CERT_PATH: '/home/aspn2/AAA_WEB/fullchain.pem',
      KEY_PATH: '/home/aspn2/AAA_WEB/privkey.key'
    },

    // 로그 설정
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    error_file: '/home/aspn2/AAA_WEB/logs/error.log',
    out_file: '/home/aspn2/AAA_WEB/logs/out.log',
    merge_logs: true,
    log_type: 'json',  // JSON 형식 로그

    // 자동 재시작 설정
    watch: false,  // 파일 변경 감지 비활성화 (프로덕션)
    ignore_watch: ['node_modules', 'logs', 'dist'],
    max_memory_restart: '500M',  // 메모리 500MB 초과 시 재시작

    // 재시작 설정
    autorestart: true,  // 자동 재시작 활성화
    max_restarts: 10,   // 최대 재시작 횟수
    min_uptime: '10s',  // 최소 실행 시간 (10초 미만이면 비정상)
    restart_delay: 4000,  // 재시작 지연 (4초)

    // 에러 설정
    exp_backoff_restart_delay: 100,  // 지수 백오프 지연

    // 크론 재시작 (선택사항 - 매일 새벽 3시 재시작)
    // cron_restart: '0 3 * * *',

    // 시간대 설정
    time: true
  }]
};
