/// auto_updater 설정
///
/// GitHub Releases 기반 자동 업데이트 설정
library;

class UpdateConfig {
  /// Appcast URL (GitHub Releases)
  ///
  /// Sparkle appcast.xml 파일 URL
  static const String appcastURL =
      'https://github.com/dohooniaspn/ASPN_AI_AGENT/releases/latest/download/appcast.xml';

  /// 앱 시작 후 업데이트 확인 지연 시간
  static const Duration startupCheckDelay = Duration(seconds: 3);

  /// 디버그 모드
  static const bool debugMode = true;

  /// 로그 출력
  static void log(String message) {
    if (debugMode) {
      print('🔄 [AUTO_UPDATE] $message');
    }
  }

  /// 에러 로그
  static void logError(String message, [Object? error]) {
    if (debugMode) {
      print('❌ [AUTO_UPDATE] ERROR: $message');
      if (error != null) print('   $error');
    }
  }

  /// 성공 로그
  static void logSuccess(String message) {
    if (debugMode) {
      print('✅ [AUTO_UPDATE] $message');
    }
  }
}

/// 업데이트 확인 결과
enum UpdateCheckResult {
  available, // 업데이트 사용 가능
  noUpdate, // 최신 버전 사용 중
  networkError, // 네트워크 오류
  parseError, // 서버 응답 파싱 오류
  unknownError, // 알 수 없는 오류
}
