/// auto_updater 서비스
///
/// GitHub Releases 기반 자동 업데이트 기능
library;

import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:auto_updater/auto_updater.dart';
import 'update_config.dart';

/// 자동 업데이트 서비스 (싱글톤)
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  bool _isInitialized = false;
  bool _isChecking = false;
  String? _cachedLatestVersion;
  String? _cachedLatestShortVersion;

  /// 초기화 여부
  bool get isInitialized => _isInitialized;

  /// 업데이트 확인 중 여부
  bool get isChecking => _isChecking;

  /// 서비스 초기화
  ///
  /// main() 함수에서 호출
  Future<bool> initialize() async {
    if (_isInitialized) {
      UpdateConfig.log('이미 초기화됨');
      return true;
    }

    try {
      UpdateConfig.log('초기화 시작...');

      // Windows에서만 작동
      if (!Platform.isWindows) {
        UpdateConfig.log('Windows가 아닙니다. 업데이트 기능 비활성화');
        return false;
      }

      // appcast URL 설정 (메인 스레드에서 실행하여 플랫폼 채널 스레드 문제를 방지)
      await Future.microtask(() async {
        await autoUpdater.setFeedURL(UpdateConfig.appcastURL);
        UpdateConfig.logSuccess('Appcast URL 설정: ${UpdateConfig.appcastURL}');
      });

      // Skip 버튼 제어는 appcast의 criticalUpdate 속성으로 처리

      _isInitialized = true;
      UpdateConfig.logSuccess('초기화 완료');
      return true;
    } catch (e) {
      UpdateConfig.logError('초기화 실패', e);
      return false;
    }
  }

  /// 로그인 후 자동 업데이트 확인
  ///
  /// ChatHomePageV5 진입 시 호출
  Future<void> checkForUpdatesAfterLogin() async {
    if (!_isInitialized) {
      UpdateConfig.log('초기화되지 않음. 초기화 시도...');
      await initialize();
    }

    if (!_isInitialized) {
      UpdateConfig.logError('초기화 실패로 업데이트 확인 중단');
      return;
    }

    if (_isChecking) {
      UpdateConfig.log('이미 업데이트 확인 중');
      return;
    }

    try {
      _isChecking = true;
      UpdateConfig.log('업데이트 확인 시작...');

      // 지연 후 확인
      await Future.delayed(UpdateConfig.startupCheckDelay);

      // 미리 최신버전 확인하여 동일하면 UI 표시 스킵
      final shouldSkip = await _isAlreadyLatest();
      if (shouldSkip) {
        UpdateConfig.log('최신 버전과 동일하여 업데이트 확인 UI 스킵');
        return;
      }

      // 업데이트 확인 (WinSparkle 기본 다이얼로그 표시)
      await autoUpdater.checkForUpdates();
      UpdateConfig.logSuccess('업데이트 확인 완료');
    } catch (e) {
      UpdateConfig.logError('업데이트 확인 실패', e);
    } finally {
      _isChecking = false;
    }
  }

  /// 수동 업데이트 확인
  ///
  /// 설정 페이지의 "업데이트 확인" 버튼에서 호출
  Future<void> checkForUpdatesManually() async {
    if (!_isInitialized) {
      UpdateConfig.log('초기화되지 않음. 초기화 시도...');
      await initialize();
    }

    if (!_isInitialized) {
      UpdateConfig.logError('초기화 실패로 업데이트 확인 중단');
      throw Exception('업데이트 서비스가 초기화되지 않았습니다.');
    }

    if (_isChecking) {
      UpdateConfig.log('이미 업데이트 확인 중');
      return;
    }

    try {
      _isChecking = true;
      UpdateConfig.log('수동 업데이트 확인 시작...');

      // 미리 최신버전 확인하여 동일하면 UI 표시 스킵
      final shouldSkip = await _isAlreadyLatest();
      if (shouldSkip) {
        UpdateConfig.log('최신 버전과 동일하여 업데이트 확인 UI 스킵');
        return;
      }

      // 업데이트 확인 (WinSparkle 기본 다이얼로그 표시)
      await autoUpdater.checkForUpdates();
      UpdateConfig.logSuccess('수동 업데이트 확인 완료');
    } catch (e) {
      UpdateConfig.logError('수동 업데이트 확인 실패', e);
      rethrow;
    } finally {
      _isChecking = false;
    }
  }

  Future<bool> _isAlreadyLatest() async {
    try {
      final current = await _getCurrentVersion();
      if (current.isEmpty) return false;
      final currentShort = current.split('+').first.trim();

      // appcast의 shortVersionString 우선 비교
      final latestShort = await _getLatestShortVersionFromAppcast();
      final basis = latestShort.isNotEmpty
          ? latestShort.trim()
          : (await _getLatestVersionFromAppcast()).trim();

      if (basis.isEmpty) return false; // 비교 불가 시 진행

      UpdateConfig.log(
          '버전 비교 - current(short): $currentShort, latest(basis): $basis');

      // 버전 비교: 현재 버전이 최신 버전보다 같거나 높으면 스킵
      final comparison = _compareVersions(currentShort, basis);
      if (comparison >= 0) {
        UpdateConfig.log('현재 버전이 최신 버전보다 같거나 높아 업데이트 확인 스킵');
        return true; // 같거나 높으면 스킵
      }

      return false; // 낮으면 업데이트 확인 진행
    } catch (_) {
      return false;
    }
  }

  /// 버전 비교 함수
  ///
  /// 반환값:
  /// - 양수: current > latest (현재 버전이 더 높음)
  /// - 0: current == latest (같음)
  /// - 음수: current < latest (현재 버전이 더 낮음)
  int _compareVersions(String current, String latest) {
    try {
      final currentParts =
          current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts =
          latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // 길이 맞추기 (짧은 쪽에 0 추가)
      final maxLength = currentParts.length > latestParts.length
          ? currentParts.length
          : latestParts.length;

      while (currentParts.length < maxLength) currentParts.add(0);
      while (latestParts.length < maxLength) latestParts.add(0);

      // 각 부분 비교
      for (int i = 0; i < maxLength; i++) {
        if (currentParts[i] > latestParts[i]) return 1;
        if (currentParts[i] < latestParts[i]) return -1;
      }

      return 0; // 같음
    } catch (_) {
      // 파싱 실패 시 문자열 비교로 폴백
      return current.compareTo(latest);
    }
  }

  Future<String> _getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  Future<String> _getLatestVersionFromAppcast() async {
    if (_cachedLatestVersion != null) return _cachedLatestVersion!;
    try {
      final uri = Uri.parse(UpdateConfig.appcastURL);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return '';
      final body = resp.body;
      // 매우 단순한 정규식으로 sparkle:version 추출
      final match = RegExp(r'sparkle:version\s*=\s*"([^"]+)"').firstMatch(body);
      if (match != null) {
        _cachedLatestVersion = match.group(1);
        return _cachedLatestVersion!;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<String> _getLatestShortVersionFromAppcast() async {
    if (_cachedLatestShortVersion != null) return _cachedLatestShortVersion!;
    try {
      final uri = Uri.parse(UpdateConfig.appcastURL);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return '';
      final body = resp.body;
      final match = RegExp(r'sparkle:shortVersionString\s*=\s*"([^"]+)"')
          .firstMatch(body);
      if (match != null) {
        _cachedLatestShortVersion = match.group(1);
        return _cachedLatestShortVersion!;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// 서비스 종료
  void dispose() {
    UpdateConfig.log('서비스 종료');
    _isInitialized = false;
    _isChecking = false;
  }
}
