/// auto_updater Provider
///
/// 간단한 Provider만 제공
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'update_service.dart';
import 'update_config.dart';

/// UpdateService 싱글톤 Provider
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

/// 현재 앱 버전 Provider
final currentVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version;
});

/// 앱 이름 Provider
final appNameProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.appName;
});

/// 업데이트 확인 중 여부 Provider
final isCheckingUpdateProvider = StateProvider<bool>((ref) => false);

/// 업데이트 사용 가능 여부 Provider
final hasUpdateAvailableProvider = StateProvider<bool>((ref) => false);

/// 마지막 업데이트 확인 시간 Provider
final lastCheckTimeProvider = StateProvider<DateTime?>((ref) => null);

/// 업데이트 오류 메시지 Provider
final updateErrorMessageProvider = StateProvider<String?>((ref) => null);

/// 업데이트 Notifier Provider
final updateNotifierProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier(ref.read(updateServiceProvider));
});

/// 업데이트 상태 클래스
class UpdateState {
  final bool isChecking;
  final bool hasUpdate;
  final DateTime? lastCheckTime;
  final String? errorMessage;

  UpdateState({
    this.isChecking = false,
    this.hasUpdate = false,
    this.lastCheckTime,
    this.errorMessage,
  });

  UpdateState copyWith({
    bool? isChecking,
    bool? hasUpdate,
    DateTime? lastCheckTime,
    String? errorMessage,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 업데이트 Notifier 클래스
class UpdateNotifier extends StateNotifier<UpdateState> {
  final UpdateService _updateService;

  UpdateNotifier(this._updateService) : super(UpdateState());

  Future<UpdateCheckResult> checkForUpdatesManually() async {
    state = state.copyWith(isChecking: true, errorMessage: null);

    try {
      await _updateService.checkForUpdatesManually();
      state = state.copyWith(
        isChecking: false,
        lastCheckTime: DateTime.now(),
      );
      return UpdateCheckResult.available; // auto_updater가 자동으로 다이얼로그 표시
    } catch (e) {
      state = state.copyWith(
        isChecking: false,
        errorMessage: e.toString(),
      );
      return UpdateCheckResult.unknownError;
    }
  }
}
