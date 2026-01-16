# ASPN AI AGENT (AAA) 프로젝트 분석 보고서

## 📋 프로젝트 개요

**프로젝트명**: ASPN AI AGENT (AAA)  
**버전**: 1.2.0  
**프레임워크**: Flutter (Dart)  
**플랫폼**: Windows, Linux, macOS, Android, iOS, Web  
**설명**: AI 기반 데스크톱 애플리케이션으로, AMQP 메시징, 채팅, 선물함, 전자결재 등의 기능을 제공

## 🏗️ 프로젝트 구조

### 전체 디렉토리 구조
```
lib/
├── core/           # 핵심 기능 (데이터베이스, 설정, 모델, 믹스인)
├── features/       # 주요 기능별 모듈 (인증, 채팅, 선물, 휴가, SAP)
├── shared/         # 공통 기능 (프로바이더, 서비스, 위젯, 유틸리티)
├── ui/             # 사용자 인터페이스 (화면, 테마)
└── main.dart       # 애플리케이션 진입점
```

### 플랫폼별 지원
- **Windows**: 메인 타겟 플랫폼 (윈도우 매니저, 시스템 트레이 지원)
- **Linux**: 지원
- **macOS**: 지원
- **Android**: 지원
- **iOS**: 지원
- **Web**: 지원

## 🔧 주요 의존성 패키지

### 핵심 패키지
- **flutter_riverpod**: 상태 관리
- **sqflite_common_ffi**: SQLite 데이터베이스
- **dart_amqp**: AMQP 메시징
- **window_manager**: 윈도우 관리
- **system_tray**: 시스템 트레이
- **launch_at_startup**: 자동 실행

### UI/UX 패키지
- **fluent_ui**: Windows 스타일 UI
- **gpt_markdown**: AI 특화 마크다운 렌더러
- **confetti**: 축하 효과
- **multi_split_view**: 분할 뷰

### 유틸리티 패키지
- **crypto**: 암호화
- **uuid**: 고유 식별자
- **path_provider**: 경로 관리
- **shared_preferences**: 로컬 저장소

## 🚀 메인 애플리케이션 (main.dart)

### 주요 기능
1. **윈도우 크기 관리**: `changeWindowSize()` 함수로 동적 윈도우 크기 조정
2. **플랫폼별 초기화**: Windows/Linux/macOS별 설정
3. **자동 실행 설정**: Windows에서 시작 프로그램 등록
4. **데이터베이스 초기화**: SQLite FFI 초기화 및 DB 디렉토리 생성
5. **AMQP 서비스 초기화**: 메시징 서비스 설정

### 윈도우 옵션
```dart
// 메인 화면용
final mainWindowOptions = WindowOptions(
  size: const Size(1280, 720),
  minimumSize: const Size(600, 300),
  titleBarStyle: TitleBarStyle.normal,
  center: true,
);

// 로그인 화면용
WindowOptions loginWindowOptions = WindowOptions(
  size: const Size(400, 600),
  minimumSize: const Size(400, 600),
  titleBarStyle: TitleBarStyle.hidden,
  backgroundColor: Colors.transparent,
);
```

## 🗄️ 데이터베이스 시스템 (DatabaseHelper)

### 주요 특징
- **싱글톤 패턴**: `DatabaseHelper._instance`
- **플랫폼별 초기화**: Windows/Linux에서 SQLite FFI 사용
- **디버그 로깅**: `aspn_agent_debug.log` 파일에 상세 로그 기록
- **자동 업그레이드**: 버전 8로 강제 업그레이드 지원

### 데이터베이스 경로
- **1차**: Documents 폴더 (`getApplicationDocumentsDirectory()`)
- **2차**: 실행 파일 디렉토리 (`Platform.resolvedExecutable`)

### 로깅 시스템
```dart
Future<void> _debugLog(String message) async {
  String timestamp = DateTime.now().toIso8601String();
  String logMessage = '[$timestamp] $message\n';
  await _debugLogFile!.writeAsString(logMessage, mode: FileMode.append);
}
```

## 📡 AMQP 메시징 서비스 (AmqpService)

### 주요 기능
1. **연결 관리**: 클라이언트, 채널, 컨슈머 관리
2. **상태 관리**: 연결, 재연결, 헬스체크
3. **메시지 처리**: 선물, 알림, 채팅 메시지
4. **로깅 시스템**: 개발/운영/테스트 환경별 로그 레벨

### 로그 레벨
- **PRODUCTION**: ERROR, WARN만 출력
- **DEVELOPMENT**: 모든 로그 출력
- **TEST**: INFO, WARN, ERROR 출력

### 연결 상태 관리
```dart
bool _isConnected = false;
bool _isConnecting = false;
bool _isDisconnecting = false;
bool _isReconnecting = false;
int _reconnectAttempts = 0;
int _consecutiveFailures = 0;
```

### 외부 모듈 참조
- `NotificationNotifier`: 알림 처리
- `ChatNotifier`: 채팅 처리
- `AlertTickerNotifier`: 알림 티커 처리

## 🔄 상태 관리 (Riverpod)

### 주요 프로바이더
```dart
// 사용자 관리
final userIdProvider = StateProvider<String?>((ref) => null);
final usernameProvider = StateProvider<String>((ref) => '');
final passwordProvider = StateProvider<String>((ref) => '');
final rememberMeProvider = StateProvider<bool>((ref) => false);

// 채팅 관리
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) => {
  final userId = ref.watch(userIdProvider);
  return ChatNotifier(userId ?? '', ...);
});

// 테마 관리
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) => ThemeNotifier());

// AI 모델 선택
final selectedAiModelProvider = StateProvider<String>((ref) => 'gemini-flash-2.5');
```

## 🎨 사용자 인터페이스

### 주요 화면
1. **LoginPage**: 로그인 화면 (400x600 윈도우)
2. **ChatHomePage**: 메인 채팅 화면 (1280x720 윈도우)
3. **SapMainPage**: SAP 모듈 화면
4. **CodingAssistantPage**: 코딩 어시스턴트
5. **SignflowScreen**: 전자결재 화면
6. **SettingsPage**: 설정 화면

### 테마 시스템
- **AppTheme**: 동적 테마 변경 지원
- **ColorSchemes**: 다크/라이트 모드
- **SpoqaHanSansNeo 폰트**: 한글 최적화 폰트

### 윈도우 컨트롤
- **WindowControls**: 사용자 정의 윈도우 컨트롤
- **시스템 트레이**: 백그라운드 실행 지원

## 🔐 인증 시스템

### 로그인 기능
- **자동 로그인**: `AutoLoginService`로 자격 증명 저장
- **도메인 고정**: `@aspnc.com` 도메인 자동 추가
- **진행률 표시**: `LoginProgressIndicator`로 로그인 상태 표시

### 개인정보 동의
- **PrivacyAgreementPopup**: 개인정보 수집 동의
- **AMQP 연결 전 필수**: 개인정보 동의 후 메시징 서비스 활성화

## 💬 채팅 시스템

### 채팅 기능
- **AI 모델 선택**: Gemini, Claude 등 다양한 AI 모델
- **마크다운 렌더링**: `gpt_markdown` 패키지로 AI 응답 렌더링
- **첨부파일 지원**: 파일 업로드 및 다운로드
- **대화 기록**: 로컬 데이터베이스에 채팅 기록 저장

### 채팅 상태 관리
```dart
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final bool isDeleteMode;
  final Set<String> selectedForDelete;
}
```

## 🎁 선물함 시스템

### 주요 기능
1. **선물 도착 알림**: AMQP를 통한 실시간 알림
2. **생일 축하**: 생일자 자동 감지 및 축하 메시지
3. **선물 확인**: 사용자 확인 후 선물함에 추가
4. **개수 관리**: 실시간 선물 개수 업데이트

### 선물 관련 서비스
- **GiftService**: 선물 관련 API 호출
- **GiftArrivalPopup**: 선물 도착 알림 팝업
- **BirthdayPopup**: 생일 축하 팝업

## 📋 전자결재 시스템

### SignflowScreen
- **폼 빌더**: `flutter_form_builder` 사용
- **PDF 생성**: `pdf` 패키지로 문서 생성
- **인쇄 지원**: `printing` 패키지로 문서 인쇄
- **분할 뷰**: `multi_split_view`로 화면 분할

## 🛠️ 개발 도구 및 유틸리티

### 공통 유틸리티
- **CommonUiUtils**: UI 관련 공통 함수
- **AppVersionUtils**: 앱 버전 정보 관리
- **AmqpLogger**: AMQP 로깅 시스템

### 믹스인
- **TextEditingControllerMixin**: 텍스트 편집 컨트롤러 확장

## 🔧 설정 및 환경

### 앱 설정
- **AppConfig**: 애플리케이션 설정 관리
- **MessageQConfig**: AMQP 메시지 큐 설정
- **analysis_options.yaml**: Dart 코드 분석 규칙

### 플랫폼별 설정
- **Windows**: 윈도우 매니저, 시스템 트레이, 자동 실행
- **Android**: Gradle 빌드 설정
- **iOS**: Xcode 프로젝트 설정
- **Linux**: CMake 빌드 설정
- **macOS**: Xcode 프로젝트 설정

## 📱 에셋 및 리소스

### 폰트
- **SpoqaHanSansNeo**: Thin, Light, Medium, Regular, Bold 가중치

### 아이콘
- **ASPN_AAA_logo**: 메인 로고 (PNG, ICO)
- **AI 모델 아이콘**: 다양한 AI 서비스 아이콘

### 이미지
- **결제 수단**: 네이버페이, 스타벅스, 배민 등
- **편의점**: CU, GS25, 이마트, 신세계 등

## 🚀 빌드 및 배포

### Flutter 설정
- **SDK 버전**: ^3.5.4
- **Flutter Lints**: ^5.0.0
- **Flutter Launcher Icons**: 윈도우 아이콘 자동 생성

### 플랫폼별 빌드
- **Windows**: CMake 기반 네이티브 빌드
- **Android**: Gradle 빌드 시스템
- **iOS**: Xcode 빌드 시스템
- **Linux**: CMake 빌드 시스템
- **macOS**: Xcode 빌드 시스템

## 🔍 주요 코드 패턴

### 1. 싱글톤 패턴
```dart
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
}
```

### 2. Provider 패턴 (Riverpod)
```dart
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final userId = ref.watch(userIdProvider);
  return ChatNotifier(userId ?? '', ...);
});
```

### 3. 비동기 초기화
```dart
WidgetsBinding.instance.addPostFrameCallback((_) async {
  // UI 렌더링 후 실행되는 초기화 코드
});
```

### 4. 플랫폼별 분기
```dart
if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
  // 데스크톱 플랫폼 전용 코드
}
```

## 📊 성능 최적화

### 1. 지연 초기화
- AMQP 서비스: 로그인 후에만 연결
- 데이터베이스: 필요할 때만 초기화

### 2. 리소스 관리
- 연결 풀링: AMQP 연결 재사용
- 메모리 관리: 적절한 리소스 해제

### 3. 백그라운드 처리
- 백그라운드 초기화 서비스
- 시스템 트레이 지원

## 🔒 보안 및 개인정보

### 1. 개인정보 보호
- 개인정보 수집 동의 필수
- 로컬 데이터베이스 암호화
- 자동 로그인 정보 보안

### 2. API 보안
- HTTPS 통신
- 사용자 인증 토큰 관리
- 세션 관리

## 🧪 테스트 및 디버깅

### 1. 로깅 시스템
- 파일 기반 로깅
- 플랫폼별 로그 레벨 조정
- 에러 추적 및 디버깅

### 2. 개발 도구
- Flutter Inspector
- Dart DevTools
- 플랫폼별 디버거

## 📈 향후 개발 계획

### 1. 기능 확장
- 추가 AI 모델 지원
- 고급 채팅 기능
- 확장된 전자결재 시스템

### 2. 성능 개선
- 메모리 사용량 최적화
- 응답 속도 향상
- 대용량 데이터 처리

### 3. 플랫폼 확장
- 추가 데스크톱 플랫폼 지원
- 모바일 앱 기능 강화
- 웹 버전 개선

---

**생성일**: 2024년  
**프로젝트 버전**: 1.2.0  
**분석 범위**: 전체 프로젝트 구조 및 주요 코드  
**용도**: ChatGPT 메모리 저장 및 프로젝트 이해
