/// AI 휴가 추천 프로바이더
///
/// Riverpod를 사용한 상태 관리

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/features/leave/models/vacation_recommendation_model.dart';
import 'package:ASPN_AI_AGENT/features/leave/services/vacation_recommendation_service.dart';

/// AI 휴가 추천 상태 프로바이더
final vacationRecommendationProvider = StateNotifierProvider<
    VacationRecommendationNotifier,
    AsyncValue<VacationRecommendationResponse>>(
  (ref) => VacationRecommendationNotifier(),
);

/// AI 휴가 추천 상태 관리 클래스
class VacationRecommendationNotifier
    extends StateNotifier<AsyncValue<VacationRecommendationResponse>> {

  StreamSubscription<VacationRecommendationResponse>? _subscription;

  VacationRecommendationNotifier()
      : super(const AsyncValue.loading());

  /// AI 휴가 추천 요청
  ///
  /// [userId] 사용자 ID
  /// [year] 연도
  void fetchRecommendation(String userId, int year) {
    // 기존 구독 취소
    _subscription?.cancel();

    // 로딩 상태로 설정
    state = const AsyncValue.loading();

    // 스트림 구독 시작
    _subscription = VacationRecommendationService.fetchRecommendation(
      userId,
      year,
    ).listen(
      (data) {
        // 데이터 수신 시 상태 업데이트
        state = AsyncValue.data(data);
      },
      onError: (error, stackTrace) {
        // 에러 발생 시 상태 업데이트
        state = AsyncValue.error(error, stackTrace);
      },
      onDone: () {
        // 스트림 완료 - 최종 데이터 전체 로그 출력
        if (state.hasValue) {
          final finalData = state.value!;
          print('🎉 [VacationRecommendation] API 호출 완료 - 최종 데이터 전체 출력:');
          print('=' * 80);
          print('📊 분석 과정 (reasoningContents):');
          print(finalData.reasoningContents);
          print('');
          print('📋 최종 응답 (finalResponseContents):');
          print(finalData.finalResponseContents);
          print('');
          print('📅 추천 날짜: ${finalData.recommendedDates.join(", ")}');
          print('📈 월별 분포: ${finalData.monthlyDistribution}');
          print('🏖️ 연속 휴가 기간: ${finalData.consecutivePeriods.length}개');
          print('✅ 완료 상태: ${finalData.isComplete}');
          print('📊 진행률: ${(finalData.streamingProgress * 100).toStringAsFixed(1)}%');
          print('=' * 80);
        }
        print('AI 휴가 추천 스트림 완료');
      },
    );
  }

  /// 상태 초기화
  void reset() {
    _subscription?.cancel();
    state = const AsyncValue.loading();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
