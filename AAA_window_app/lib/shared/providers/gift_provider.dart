import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';

// 1. 선물 상태를 정의하는 클래스
class GiftState {
  final List<Map<String, dynamic>> gifts;
  final bool hasNewGift;
  final bool isLoading;
  final String? errorMessage;

  GiftState({
    this.gifts = const [],
    this.hasNewGift = false,
    this.isLoading = false,
    this.errorMessage,
  });

  GiftState copyWith({
    List<Map<String, dynamic>>? gifts,
    bool? hasNewGift,
    bool? isLoading,
    String? errorMessage,
  }) {
    return GiftState(
      gifts: gifts ?? this.gifts,
      hasNewGift: hasNewGift ?? this.hasNewGift,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// 2. 상태를 관리하고 비즈니스 로직을 처리하는 Notifier
class GiftNotifier extends StateNotifier<GiftState> {
  final String userId;

  GiftNotifier(this.userId) : super(GiftState()) {
    if (userId.isNotEmpty) {
      fetchGifts();
    }
  }

  // 서버에서 선물 목록을 가져오는 메소드
  Future<void> fetchGifts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await ApiService.checkGifts(userId);
      if (response['gifts'] != null) {
        final List<Map<String, dynamic>> gifts = List<Map<String, dynamic>>.from(response['gifts']);
        state = state.copyWith(gifts: gifts, isLoading: false);
      } else {
        state = state.copyWith(gifts: [], isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // 새로운 선물이 도착했음을 알리는 메소드
  void newGiftArrived() {
    state = state.copyWith(hasNewGift: true);
    fetchGifts(); // 새로운 선물이 왔으니 목록을 갱신
  }

  // 사용자가 선물함을 확인했음을 알리는 메소드
  void giftsChecked() {
    state = state.copyWith(hasNewGift: false);
  }
}

// 3. Provider 정의
final giftProvider = StateNotifierProvider<GiftNotifier, GiftState>((ref) {
  // 실제 앱에서는 로그인된 사용자 ID를 받아와야 합니다.
  // 여기서는 임시로 빈 값을 넣고, 실제 사용할 때는 동적으로 주입해야 합니다.
  // 예: final userId = ref.watch(userProvider).userId;
  return GiftNotifier(''); // 사용자 ID가 설정되기 전 초기 상태
});

// 사용자 ID에 따라 동적으로 Provider를 생성하기 위한 Family Provider
final giftProviderFamily = StateNotifierProvider.family<GiftNotifier, GiftState, String>((ref, userId) {
  return GiftNotifier(userId);
});