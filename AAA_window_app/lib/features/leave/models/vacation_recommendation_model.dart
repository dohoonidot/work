/// AI 휴가 추천 모델
///
/// AI가 분석한 휴가 추천 데이터를 담는 모델들

import 'dart:convert';

/// SSE Event Type
enum VacationSSEEventType {
  reasoning,
  final_,
}

/// Leaves JSON 데이터 (월별 휴가 사용)
class LeavesData {
  final Map<int, double> monthlyUsage; // {1: 1.0, 2: 0.0, ...}

  LeavesData({required this.monthlyUsage});

  factory LeavesData.fromJson(Map<String, dynamic> json) {
    // {"leaves":{"2025":{"01":1.0,"02":0.0,...}}} 파싱
    final Map<int, double> result = {};
    if (json.containsKey('leaves')) {
      final leaves = json['leaves'] as Map<String, dynamic>;
      if (leaves.isNotEmpty) {
        final yearData = leaves.values.first as Map<String, dynamic>;
        yearData.forEach((month, days) {
          result[int.parse(month)] = (days as num).toDouble();
        });
      }
    }
    return LeavesData(monthlyUsage: result);
  }
}

/// Weekday Counts JSON 데이터
class WeekdayCountsData {
  final Map<String, double> counts; // {"mon": 4.0, "fri": 5.0, ...}

  WeekdayCountsData({required this.counts});

  factory WeekdayCountsData.fromJson(Map<String, dynamic> json) {
    final Map<String, double> result = {};
    if (json.containsKey('weekday_counts')) {
      final counts = json['weekday_counts'] as Map<String, dynamic>;
      counts.forEach((day, count) {
        result[day] = (count as num).toDouble();
      });
    }
    return WeekdayCountsData(counts: result);
  }
}

/// 연속 휴가 기간 정보
class VacationPeriod {
  final String startDate;
  final String endDate;
  final int days;
  final String description;

  VacationPeriod({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.description,
  });

  factory VacationPeriod.fromJson(Map<String, dynamic> json) {
    return VacationPeriod(
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String,
      days: json['days'] as int,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate,
      'endDate': endDate,
      'days': days,
      'description': description,
    };
  }
}

/// AI 휴가 추천 응답 데이터
class VacationRecommendationResponse {
  /// 분석 과정 텍스트 (스트리밍 지원)
  final String reasoningContents;

  /// 최종 응답 텍스트 (월별 분포, 추천 날짜, 전략, 휴가 기간 포함)
  final String finalResponseContents;

  /// 추천 날짜 목록 (ISO 8601 형식: "2026-02-19")
  final List<String> recommendedDates;

  /// 월별 분포 (파싱됨) - Key: 월(1-12), Value: 연차 일수
  final Map<int, double> monthlyDistribution;

  /// 주요 연속 휴가 기간
  final List<VacationPeriod> consecutivePeriods;

  /// 분석 완료 여부
  final bool isComplete;

  /// 스트리밍 진행률 (0.0 ~ 1.0)
  final double streamingProgress;

  /// 총 연차 일수
  final double? totalDays;

  /// 사용 예정 연차 일수
  final double? usedDays;

  /// 과거 휴가 사용 내역 (leaves JSON)
  final LeavesData? leavesData;

  /// 요일별 사용 횟수 (weekday_counts JSON)
  final WeekdayCountsData? weekdayCountsData;

  /// 공휴일 인접 사용률 (0.0 ~ 1.0)
  final double? holidayAdjacentUsageRate;

  /// 공휴일 인접 사용일 수
  final double? holidayAdjacentDays;

  /// 전체 사용일 수
  final double? totalLeaveDays;

  /// 현재 파싱 단계 (📊 이전/이후 구분)
  final bool isAfterAnalysisMarker; // 📊 마커 이후인지 여부

  /// 마크다운 스트리밍 버퍼 (📊 이후 누적)
  final String markdownBuffer;

  VacationRecommendationResponse({
    required this.reasoningContents,
    required this.finalResponseContents,
    required this.recommendedDates,
    required this.monthlyDistribution,
    required this.consecutivePeriods,
    required this.isComplete,
    required this.streamingProgress,
    this.totalDays,
    this.usedDays,
    this.leavesData,
    this.weekdayCountsData,
    this.holidayAdjacentUsageRate,
    this.holidayAdjacentDays,
    this.totalLeaveDays,
    this.isAfterAnalysisMarker = false,
    this.markdownBuffer = '',
  });

  /// 초기 상태 생성
  factory VacationRecommendationResponse.initial() {
    return VacationRecommendationResponse(
      reasoningContents: '',
      finalResponseContents: '',
      recommendedDates: [],
      monthlyDistribution: {},
      consecutivePeriods: [],
      isComplete: false,
      streamingProgress: 0.0,
      leavesData: null,
      weekdayCountsData: null,
      isAfterAnalysisMarker: false,
      markdownBuffer: '',
    );
  }

  /// 로딩 상태 생성
  factory VacationRecommendationResponse.loading() {
    return VacationRecommendationResponse(
      reasoningContents: '분석을 시작합니다...',
      finalResponseContents: '',
      recommendedDates: [],
      monthlyDistribution: {},
      consecutivePeriods: [],
      isComplete: false,
      streamingProgress: 0.0,
      leavesData: null,
      weekdayCountsData: null,
      isAfterAnalysisMarker: false,
      markdownBuffer: '',
    );
  }

  /// API 응답으로부터 생성
  factory VacationRecommendationResponse.fromJson(Map<String, dynamic> json) {
    final reasoningContents = json['reasoning_contents'] as String? ?? '';
    final finalResponseContents = json['final_response_contents'] as String? ?? '';
    final recommendedDates = (json['recommended_dates'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ?? [];

    // final_response_contents에서 구조화된 데이터 파싱
    final monthlyDistribution = VacationContentParser.parseMonthlyDistribution(finalResponseContents);
    final consecutivePeriods = VacationContentParser.parseConsecutivePeriods(finalResponseContents);

    return VacationRecommendationResponse(
      reasoningContents: reasoningContents,
      finalResponseContents: finalResponseContents,
      recommendedDates: recommendedDates,
      monthlyDistribution: monthlyDistribution,
      consecutivePeriods: consecutivePeriods,
      isComplete: json['isComplete'] as bool? ?? true,
      streamingProgress: json['streamingProgress'] as double? ?? 1.0,
      totalDays: json['totalDays'] as double?,
      usedDays: json['usedDays'] as double?,
    );
  }

  /// 복사본 생성 (일부 필드만 업데이트)
  VacationRecommendationResponse copyWith({
    String? reasoningContents,
    String? finalResponseContents,
    List<String>? recommendedDates,
    Map<int, double>? monthlyDistribution,
    List<VacationPeriod>? consecutivePeriods,
    bool? isComplete,
    double? streamingProgress,
    double? totalDays,
    double? usedDays,
    LeavesData? leavesData,
    WeekdayCountsData? weekdayCountsData,
    double? holidayAdjacentUsageRate,
    double? holidayAdjacentDays,
    double? totalLeaveDays,
    bool? isAfterAnalysisMarker,
    String? markdownBuffer,
  }) {
    return VacationRecommendationResponse(
      reasoningContents: reasoningContents ?? this.reasoningContents,
      finalResponseContents: finalResponseContents ?? this.finalResponseContents,
      recommendedDates: recommendedDates ?? this.recommendedDates,
      monthlyDistribution: monthlyDistribution ?? this.monthlyDistribution,
      consecutivePeriods: consecutivePeriods ?? this.consecutivePeriods,
      isComplete: isComplete ?? this.isComplete,
      streamingProgress: streamingProgress ?? this.streamingProgress,
      totalDays: totalDays ?? this.totalDays,
      usedDays: usedDays ?? this.usedDays,
      leavesData: leavesData ?? this.leavesData,
      weekdayCountsData: weekdayCountsData ?? this.weekdayCountsData,
      holidayAdjacentUsageRate: holidayAdjacentUsageRate ?? this.holidayAdjacentUsageRate,
      holidayAdjacentDays: holidayAdjacentDays ?? this.holidayAdjacentDays,
      totalLeaveDays: totalLeaveDays ?? this.totalLeaveDays,
      isAfterAnalysisMarker: isAfterAnalysisMarker ?? this.isAfterAnalysisMarker,
      markdownBuffer: markdownBuffer ?? this.markdownBuffer,
    );
  }
}

/// 휴가 추천 응답 텍스트 파싱 유틸리티
class VacationContentParser {
  /// 월별 분포 파싱
  ///
  /// 예시: "2월: 2일, 3월: 1일, 7월: 3일" → {2: 2.0, 3: 1.0, 7: 3.0}
  static Map<int, double> parseMonthlyDistribution(String content) {
    final Map<int, double> result = {};

    // 정규식: "N월: M일" 패턴 매칭
    final regex = RegExp(r'(\d+)월:\s*(\d+(?:\.\d+)?)일');
    final matches = regex.allMatches(content);

    for (final match in matches) {
      final month = int.parse(match.group(1)!);
      final days = double.parse(match.group(2)!);
      result[month] = days;
    }

    return result;
  }

  /// 연속 휴가 기간 파싱
  ///
  /// 예시: "2026-02-19 ~ 2026-02-20 (2일): 설 연휴 연계" → VacationPeriod 객체
  static List<VacationPeriod> parseConsecutivePeriods(String content) {
    final List<VacationPeriod> result = [];

    // 정규식: "YYYY-MM-DD ~ YYYY-MM-DD (N일): 설명" 패턴 매칭
    final regex = RegExp(
      r'(\d{4}-\d{2}-\d{2})\s*~\s*(\d{4}-\d{2}-\d{2})\s*\((\d+)일\):\s*([^\n]+)'
    );
    final matches = regex.allMatches(content);

    for (final match in matches) {
      result.add(VacationPeriod(
        startDate: match.group(1)!,
        endDate: match.group(2)!,
        days: int.parse(match.group(3)!),
        description: match.group(4)!.trim(),
      ));
    }

    // 대체 패턴: "- YYYY-MM-DD ~ YYYY-MM-DD (N일): 설명" 형식도 지원
    final altRegex = RegExp(
      r'-\s*(\d{4}-\d{2}-\d{2})\s*~\s*(\d{4}-\d{2}-\d{2})\s*\((\d+)일\):\s*([^\n]+)'
    );
    final altMatches = altRegex.allMatches(content);

    for (final match in altMatches) {
      // 중복 체크
      final startDate = match.group(1)!;
      final endDate = match.group(2)!;
      final alreadyExists = result.any((p) =>
        p.startDate == startDate && p.endDate == endDate
      );

      if (!alreadyExists) {
        result.add(VacationPeriod(
          startDate: startDate,
          endDate: endDate,
          days: int.parse(match.group(3)!),
          description: match.group(4)!.trim(),
        ));
      }
    }

    return result;
  }

  /// 총 사용 연차 파싱
  ///
  /// 예시: "총 사용 연차: 15일 / 15일" → 15.0
  static double? parseTotalUsedDays(String content) {
    final regex = RegExp(r'총\s*사용\s*연차:\s*(\d+(?:\.\d+)?)일');
    final match = regex.firstMatch(content);
    return match != null ? double.parse(match.group(1)!) : null;
  }

  /// finalResponseContents에서 JSON 데이터 파싱
  /// 
  /// 예시: short{"weekday_counts":{...},"holiday_adjacent_usage_rate":0.5294,...}
  static Map<String, dynamic>? parseJsonFromFinalResponse(String content) {
    try {
      // JSON 부분 추출 (첫 번째 { 부터 마지막 } 까지)
      final startIndex = content.indexOf('{');
      final endIndex = content.lastIndexOf('}');
      
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        final jsonString = content.substring(startIndex, endIndex + 1);
        // 주석 제거 (# 주석 처리)
        final cleanedJson = jsonString.replaceAll(RegExp(r'#.*'), '').trim();
        return jsonDecode(cleanedJson) as Map<String, dynamic>;
      }
    } catch (e) {
      print('⚠️ [VacationContentParser] JSON 파싱 실패: $e');
    }
    return null;
  }
}
