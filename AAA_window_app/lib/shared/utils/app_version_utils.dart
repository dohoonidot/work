import 'package:package_info_plus/package_info_plus.dart';

class AppVersionUtils {
  static PackageInfo? _packageInfo;

  // 앱 버전 정보 초기화
  static Future<void> initialize() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  // 앱 버전 정보 가져오기
  static Future<PackageInfo> getPackageInfo() async {
    if (_packageInfo == null) {
      await initialize();
    }
    return _packageInfo!;
  }

  // 앱 버전 문자열 가져오기 (예: "1.2.0")
  static Future<String> getVersionString() async {
    final packageInfo = await getPackageInfo();
    print('🔍 DEBUG - packageInfo.version: ${packageInfo.version}');
    print('🔍 DEBUG - packageInfo.buildNumber: ${packageInfo.buildNumber}');
    print('🔍 DEBUG - 반환할 버전: ${packageInfo.version}');
    return packageInfo.version; // 빌드 번호 없이 버전만 반환
  }

  // 앱 이름 가져오기
  static Future<String> getAppName() async {
    final packageInfo = await getPackageInfo();
    return packageInfo.appName;
  }

  // 앱 패키지명 가져오기
  static Future<String> getPackageName() async {
    final packageInfo = await getPackageInfo();
    return packageInfo.packageName;
  }

  // 상세 버전 정보 (디버깅용)
  static Future<Map<String, String>> getDetailedVersionInfo() async {
    final packageInfo = await getPackageInfo();
    return {
      'appName': packageInfo.appName,
      'packageName': packageInfo.packageName,
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'versionString': '${packageInfo.version}+${packageInfo.buildNumber}',
    };
  }
}
