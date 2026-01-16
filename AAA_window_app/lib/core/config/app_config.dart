class AppConfig {
  static const bool isOfficialRelease = false; // true : 정식빌드 , false : 개발용 빌드

  static String get baseUrl {
    return isOfficialRelease
        ? 'https://ai2great.com:8080'
        : 'https://ai2great.com:8060';
  }
}
