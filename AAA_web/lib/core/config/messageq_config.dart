/// MessageQ 시스템 설정 관리
class MessageQConfig {
  // RabbitMQ 설정
  static const String rabbitmqHost = '211.43.205.49';
  static const int rabbitmqPort = 5672;
  static const String rabbitmqUsername = 'dev';
  static const String rabbitmqPassword = 'aspn1234';

  // 연결 설정
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration reconnectDelay = Duration(seconds: 5);
  static const int maxReconnectAttempts = 5;
  static const Duration heartbeatInterval = Duration(seconds: 30);

  // 개발/운영 환경 구분
  static const bool isDevelopment = true;

  /// RabbitMQ 연결 URL 생성
  static String get rabbitmqUrl =>
      'amqp://$rabbitmqUsername:$rabbitmqPassword@$rabbitmqHost:$rabbitmqPort';

  /// 환경별 설정 로드
  static Map<String, dynamic> getEnvironmentConfig() {
    if (isDevelopment) {
      return {
        'rabbitmq': {
          'host': rabbitmqHost,
          'port': rabbitmqPort,
          'username': rabbitmqUsername,
          'password': rabbitmqPassword,
        },
        'connection': {
          'timeout': connectionTimeout.inSeconds,
          'reconnectDelay': reconnectDelay.inSeconds,
          'maxAttempts': maxReconnectAttempts,
          'heartbeatInterval': heartbeatInterval.inSeconds,
        },
      };
    } else {
      // 운영 환경 설정 (필요시 추가)
      return {
        'rabbitmq': {
          'host': rabbitmqHost,
          'port': rabbitmqPort,
          'username': rabbitmqUsername,
          'password': rabbitmqPassword,
        },
        'connection': {
          'timeout': connectionTimeout.inSeconds,
          'reconnectDelay': reconnectDelay.inSeconds,
          'maxAttempts': maxReconnectAttempts,
          'heartbeatInterval': heartbeatInterval.inSeconds,
        },
      };
    }
  }
}
