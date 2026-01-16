/// AI 휴가 추천 서비스
///
/// API 호출 및 Mock 데이터 제공

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:ASPN_AI_AGENT/features/leave/models/vacation_recommendation_model.dart';
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';

class VacationRecommendationService {
  /// Mock 데이터 사용 여부 (개발용 토글)
  static const bool _useMockData = false;

  /// AI 휴가 추천 요청
  ///
  /// [userId] 사용자 ID
  /// [year] 연도
  /// Returns: 스트리밍 응답
  static Stream<VacationRecommendationResponse> fetchRecommendation(
    String userId,
    int year,
  ) async* {
    if (_useMockData) {
      yield* _getMockDataStream(year);
    } else {
      yield* _fetchFromAPI(userId, year);
    }
  }

  /// Mock 데이터 스트리밍 시뮬레이션
  static Stream<VacationRecommendationResponse> _getMockDataStream(int year) async* {
    // Stage 1: 데이터 수집 시작 (1초 대기)
    await Future.delayed(const Duration(seconds: 1));
    yield VacationRecommendationResponse(
      reasoningContents: '📥 사용자 과거 휴가 사용 내역 로드 중...',
      finalResponseContents: '',
      recommendedDates: [],
      monthlyDistribution: {},
      consecutivePeriods: [],
      isComplete: false,
      streamingProgress: 0.15,
    );

    // Stage 2: 팀 데이터 로드 (1.5초 대기)
    await Future.delayed(const Duration(milliseconds: 1500));
    yield VacationRecommendationResponse(
      reasoningContents: '''📥 사용자 과거 휴가 사용 내역 로드 완료 (${year - 1}년:17건)

👥 팀 휴가 데이터 로드 중...''',
      finalResponseContents: '',
      recommendedDates: [],
      monthlyDistribution: {},
      consecutivePeriods: [],
      isComplete: false,
      streamingProgress: 0.30,
    );

    // Stage 3: 공휴일 데이터 로드 (1.5초 대기)
    await Future.delayed(const Duration(milliseconds: 1500));
    yield VacationRecommendationResponse(
      reasoningContents: '''📥 사용자 과거 휴가 사용 내역 로드 완료 (${year - 1}년:17건)

👥 팀 휴가 데이터 로드 완료 (0건)

🗓️ 공휴일 데이터 로드 중...''',
      finalResponseContents: '',
      recommendedDates: [],
      monthlyDistribution: {},
      consecutivePeriods: [],
      isComplete: false,
      streamingProgress: 0.45,
    );

    // Stage 4: 잔여 연차 조회 (1초 대기)
    await Future.delayed(const Duration(seconds: 1));
    yield VacationRecommendationResponse(
      reasoningContents: '''📥 사용자 과거 휴가 사용 내역 로드 완료 (${year - 1}년:17건)

👥 팀 휴가 데이터 로드 완료 (0건)

🗓️ 공휴일 데이터 로드 완료 (${year - 1}년:121일, ${year}년:118일)

🧾 잔여 연차 조회 중...''',
      finalResponseContents: '',
      recommendedDates: [],
      monthlyDistribution: {},
      consecutivePeriods: [],
      isComplete: false,
      streamingProgress: 0.60,
    );

    // Stage 5: 사용자 경향 분석 (2초 대기)
    await Future.delayed(const Duration(seconds: 2));
    yield VacationRecommendationResponse(
      reasoningContents: '''📥 사용자 과거 휴가 사용 내역 로드 완료 (${year - 1}년:17건)

👥 팀 휴가 데이터 로드 완료 (0건)

🗓️ 공휴일 데이터 로드 완료 (${year - 1}년:121일, ${year}년:118일)

🧾 잔여 연차 조회 완료 (15.0일)

📊 사용자 경향 분석 중...''',
      finalResponseContents: '',
      recommendedDates: [],
      monthlyDistribution: {},
      consecutivePeriods: [],
      isComplete: false,
      streamingProgress: 0.75,
    );

    // Stage 6: 최종 계획 수립 (2초 대기)
    await Future.delayed(const Duration(seconds: 2));
    yield VacationRecommendationResponse(
      reasoningContents: '''📥 사용자 과거 휴가 사용 내역 로드 완료 (${year - 1}년:17건)

👥 팀 휴가 데이터 로드 완료 (0건)

🗓️ 공휴일 데이터 로드 완료 (${year - 1}년:121일, ${year}년:118일)

🧾 잔여 연차 조회 완료 (15.0일)

📊 사용자 경향 분석 완료 (과거 17건 기반)
사용자는 1회 사용 시 1일 이하의 짧은 휴가를 선호하며(평균 1일), 월요일(5회)과 금요일/목요일(각 4회)을 주로 사용하여 주말을 확장하는 패턴을 보입니다. 특히 설날(1월 31일), 5월 연휴(5월 2일), 선거일(6월 2일), 한글날(10월 10일) 등 주요 공휴일과 주말 사이의 징검다리 날짜를 정확히 공략하여 휴식 효율을 극대화하는 경향이 뚜렷합니다.

주요 특징:
- 징검다리 연휴 선호: 예
- 평균 휴가 길이: 1.0일
- 가장 많이 사용하는 요일: 월요일
- 공휴일 인접 사용률: 24%
- 연속 휴가 선호: short

✍️ ${year}년 연차 사용 계획 수립 중...''',
      finalResponseContents: '',
      recommendedDates: [],
      monthlyDistribution: {},
      consecutivePeriods: [],
      isComplete: false,
      streamingProgress: 0.90,
    );

    // Stage 7: 완료 (1초 대기)
    await Future.delayed(const Duration(seconds: 1));

    final finalContents = '''✍️ ${year}년 연차 사용 계획 수립 완료

**총 사용 연차:** 15일 / 15일

**월별 분포:**
  • ${year}-02: 2일
  • ${year}-03: 1일
  • ${year}-05: 2일
  • ${year}-06: 2일
  • ${year}-08: 1일
  • ${year}-09: 2일
  • ${year}-10: 2일
  • ${year}-11: 1일
  • ${year}-12: 2일

**추천 날짜 (15일):**
${year}-02-19, ${year}-02-20, ${year}-03-03, ${year}-05-04, ${year}-05-26, ${year}-06-04, ${year}-06-05, ${year}-08-14, ${year}-09-23, ${year}-09-28, ${year}-10-02, ${year}-10-08, ${year}-11-06, ${year}-12-24, ${year}-12-31

**전략 및 이유:**
사용자의 '짧은 연속 휴가' 및 '징검다리 연휴' 선호도를 반영하여, 1일 단위로 연차를 사용해 휴일 효율을 극대화하는 전략을 수립했습니다. 1. 설날(2월), 선거일(6월) 등 주중 공휴일 전후에 연차를 배치하여 주말을 포함한 긴 휴식 기간을 확보했습니다. 2. 5월 어린이날과 부처님오신날 대체공휴일에 각각 하루씩 붙여 4일 휴가를 만들었습니다. 3. 추석(9월) 연휴의 앞뒤(수, 월)를 사용하여 명절 피로를 최소화했습니다. 4. 휴일이 없는 11월과 12월 말에는 금요일과 목요일을 활용해 리프레시 기간을 마련했습니다. 모든 날짜는 제공된 휴일 목록을 엄격히 피하여 평일에만 배치되었습니다.

**주요 연속 휴가 기간:**
  • ${year}-02-14 ~ ${year}-02-22: 9일
  • ${year}-02-28 ~ ${year}-03-03: 4일
  • ${year}-05-02 ~ ${year}-05-05: 4일
  • ${year}-05-23 ~ ${year}-05-26: 4일
  • ${year}-06-03 ~ ${year}-06-07: 5일
''';

    final recommendedDatesList = [
      '$year-02-19',
      '$year-02-20',
      '$year-03-03',
      '$year-05-04',
      '$year-05-26',
      '$year-06-04',
      '$year-06-05',
      '$year-08-14',
      '$year-09-23',
      '$year-09-28',
      '$year-10-02',
      '$year-10-08',
      '$year-11-06',
      '$year-12-24',
      '$year-12-31',
    ];

    yield VacationRecommendationResponse(
      reasoningContents: '''📥 사용자 과거 휴가 사용 내역 로드 완료 (${year - 1}년:17건)

👥 팀 휴가 데이터 로드 완료 (0건)

🗓️ 공휴일 데이터 로드 완료 (${year - 1}년:121일, ${year}년:118일)

🧾 잔여 연차 조회 완료 (15.0일)

📊 사용자 경향 분석 완료 (과거 17건 기반)
사용자는 1회 사용 시 1일 이하의 짧은 휴가를 선호하며(평균 1일), 월요일(5회)과 금요일/목요일(각 4회)을 주로 사용하여 주말을 확장하는 패턴을 보입니다.''',
      finalResponseContents: finalContents,
      recommendedDates: recommendedDatesList,
      monthlyDistribution: VacationContentParser.parseMonthlyDistribution(finalContents),
      consecutivePeriods: VacationContentParser.parseConsecutivePeriods(finalContents),
      isComplete: true,
      streamingProgress: 1.0,
      totalDays: 15.0,
      usedDays: 15.0,
    );
  }

  /// 실제 API 호출 (SSE 스트리밍)
  static Stream<VacationRecommendationResponse> _fetchFromAPI(
    String userId,
    int year,
  ) async* {
    final url = Uri.parse('${AppConfig.baseUrl}/leave/user/annualPlans');
    final client = http.Client();

    try {
      print('🚀 [VacationService] API 요청 시작: $url');
      print('🚀 [VacationService] user_id: $userId');

      // POST request
      var request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'user_id': userId});

      final response = await client.send(request);

      print('📡 [VacationService] 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('API 요청 실패: ${response.statusCode}');
      }

      // SSE 파싱 시작
      String currentEventType = '';
      String reasoningBuffer = '';
      String markdownBuffer = '';
      bool isAfterMarker = false;

      LeavesData? leavesData;
      WeekdayCountsData? weekdayCountsData;

      int lineCount = 0;
      final random = Random();

      await for (String line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        lineCount++;

        // event: 파싱
        if (line.startsWith('event: ')) {
          currentEventType = line.substring(7).trim();
          // final 이벤트는 로그 찍지 않음
          if (currentEventType != 'final') {
            print('📡 [VacationService] SSE 이벤트 타입: "$currentEventType"');
          }
          continue;
        }

        // data: 파싱
        if (line.startsWith('data: ')) {
          final data = line.substring(6);

          // 실제 데이터 값 로그 출력
          print('📦 [VacationService] SSE 데이터 수신 ($currentEventType): "$data"');

          if (data.isEmpty) continue;

          if (currentEventType == 'reasoning') {
            // 📊 마커 체크
            if (data.contains('📊')) {
              print('🎯 [VacationService] 📊 마커 감지 - 스트리밍 모드 전환');
              isAfterMarker = true;
            }

            if (!isAfterMarker) {
              // 📊 이전: JSON 파싱 시도
              bool isJsonData = false;
              String? jsonString;
              
              // 1. {로 시작하는 경우
              if (data.trim().startsWith('{')) {
                jsonString = data.trim();
              } 
              // 2. {가 포함된 경우 (예: short{"weekday_counts":...})
              else if (data.contains('{') && data.contains('}')) {
                // JSON 부분 추출 (첫 번째 { 부터 마지막 } 까지)
                final startIndex = data.indexOf('{');
                final endIndex = data.lastIndexOf('}');
                if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
                  jsonString = data.substring(startIndex, endIndex + 1);
                }
              }
              
              // JSON 파싱 시도
              if (jsonString != null) {
                try {
                  final json = jsonDecode(jsonString);
                  print('📊 [VacationService] JSON 데이터 파싱 시도');

                  if (json.containsKey('leaves')) {
                    leavesData = LeavesData.fromJson(json);
                    print('✅ [VacationService] leaves 데이터 파싱 완료: ${leavesData.monthlyUsage}');
                    isJsonData = true; // JSON 데이터는 텍스트로 표시하지 않음
                  } else if (json.containsKey('weekday_counts')) {
                    weekdayCountsData = WeekdayCountsData.fromJson(json);
                    print('✅ [VacationService] weekday_counts 데이터 파싱 완료: ${weekdayCountsData.counts}');
                    isJsonData = true; // JSON 데이터는 텍스트로 표시하지 않음
                  }
                  // weekday_counts나 leaves가 포함된 JSON이면 전체 라인 제거
                  if (isJsonData && data.contains('weekday_counts') || data.contains('"leaves"')) {
                    // 이미 isJsonData = true로 설정됨
                  }
                } catch (e) {
                  // JSON 파싱 실패 시에도 weekday_counts나 leaves가 포함되어 있으면 제거
                  if (data.contains('weekday_counts') || data.contains('"leaves"')) {
                    print('⚠️ [VacationService] JSON 파싱 실패했지만 weekday_counts/leaves 포함되어 제거: $e');
                    isJsonData = true; // 텍스트로 표시하지 않음
                  } else {
                    print('⚠️ [VacationService] JSON 파싱 실패 (일반 텍스트로 처리): $e');
                  }
                }
              } else {
                // JSON 형식이 아니지만 weekday_counts나 leaves 키워드가 포함된 경우도 제거
                if (data.contains('weekday_counts') || data.contains('"leaves"')) {
                  print('⚠️ [VacationService] JSON 형식이 아니지만 weekday_counts/leaves 포함되어 제거');
                  isJsonData = true; // 텍스트로 표시하지 않음
                }
              }

              // JSON 데이터가 아닌 경우에만 reasoningBuffer에 추가
              if (!isJsonData) {
                reasoningBuffer += data + '\n';
                
                // 천천히 표시하기 위한 딜레이 (300-800ms)
                final delay = 300 + random.nextInt(500);
                await Future.delayed(Duration(milliseconds: delay));
              } else {
                // JSON 데이터는 즉시 업데이트 (딜레이 없음)
                await Future.delayed(Duration(milliseconds: 100));
              }

              yield VacationRecommendationResponse(
                reasoningContents: reasoningBuffer,
                finalResponseContents: '',
                leavesData: leavesData,
                weekdayCountsData: weekdayCountsData,
                isAfterAnalysisMarker: false,
                markdownBuffer: '',
                recommendedDates: [],
                monthlyDistribution: {},
                consecutivePeriods: [],
                isComplete: false,
                streamingProgress: 0.5,
              );
            } else {
              // 📊 이후: 즉시 마크다운 렌더링
              markdownBuffer += data;

              yield VacationRecommendationResponse(
                reasoningContents: reasoningBuffer,
                finalResponseContents: '',
                leavesData: leavesData,
                weekdayCountsData: weekdayCountsData,
                isAfterAnalysisMarker: true,
                markdownBuffer: markdownBuffer,
                recommendedDates: [],
                monthlyDistribution: {},
                consecutivePeriods: [],
                isComplete: false,
                streamingProgress: 0.7,
              );
            }
          } else if (currentEventType == 'final') {
            // final 이벤트: 마크다운 누적
            markdownBuffer += data;

            yield VacationRecommendationResponse(
              reasoningContents: reasoningBuffer,
              finalResponseContents: markdownBuffer,
              leavesData: leavesData,
              weekdayCountsData: weekdayCountsData,
              isAfterAnalysisMarker: true,
              markdownBuffer: markdownBuffer,
              recommendedDates: [],
              monthlyDistribution: {},
              consecutivePeriods: [],
              isComplete: false,
              streamingProgress: 0.9,
            );
          }
        }
      }

      // 스트림 완료 후 최종 데이터 파싱
      print('🏁 [VacationService] SSE 스트림 완료 (총 $lineCount 라인)');

      final monthlyDist =
          VacationContentParser.parseMonthlyDistribution(markdownBuffer);
      final periods =
          VacationContentParser.parseConsecutivePeriods(markdownBuffer);

      // finalResponseContents에서 JSON 데이터 파싱
      WeekdayCountsData? finalWeekdayCountsData = weekdayCountsData;
      double? holidayAdjacentUsageRate;
      double? holidayAdjacentDays;
      double? totalLeaveDays;
      
      final jsonData = VacationContentParser.parseJsonFromFinalResponse(markdownBuffer);
      if (jsonData != null) {
        print('📊 [VacationService] finalResponseContents에서 JSON 파싱 성공');
        
        // weekday_counts 파싱
        if (jsonData.containsKey('weekday_counts')) {
          finalWeekdayCountsData = WeekdayCountsData.fromJson(jsonData);
          print('✅ [VacationService] finalResponseContents weekday_counts 파싱: ${finalWeekdayCountsData.counts}');
        }
        
        // holiday_adjacent_usage_rate 파싱
        if (jsonData.containsKey('holiday_adjacent_usage_rate')) {
          holidayAdjacentUsageRate = (jsonData['holiday_adjacent_usage_rate'] as num).toDouble();
          print('✅ [VacationService] 공휴일 인접 사용률: ${(holidayAdjacentUsageRate * 100).toStringAsFixed(2)}%');
        }
        
        // holiday_adjacent_days 파싱
        if (jsonData.containsKey('holiday_adjacent_days')) {
          holidayAdjacentDays = (jsonData['holiday_adjacent_days'] as num).toDouble();
          print('✅ [VacationService] 공휴일 인접 사용일: $holidayAdjacentDays일');
        }
        
        // total_leave_days 파싱
        if (jsonData.containsKey('total_leave_days')) {
          totalLeaveDays = (jsonData['total_leave_days'] as num).toDouble();
          print('✅ [VacationService] 전체 사용일: $totalLeaveDays일');
        }
      }

      print('📊 [VacationService] 최종 파싱 완료:');
      print('  - 월별 분포: $monthlyDist');
      print('  - 연속 휴가: ${periods.length}개');

      yield VacationRecommendationResponse(
        reasoningContents: reasoningBuffer,
        finalResponseContents: markdownBuffer,
        leavesData: leavesData,
        weekdayCountsData: finalWeekdayCountsData,
        holidayAdjacentUsageRate: holidayAdjacentUsageRate,
        holidayAdjacentDays: holidayAdjacentDays,
        totalLeaveDays: totalLeaveDays,
        isAfterAnalysisMarker: true,
        markdownBuffer: markdownBuffer,
        recommendedDates: [],
        monthlyDistribution: monthlyDist,
        consecutivePeriods: periods,
        isComplete: true,
        streamingProgress: 1.0,
      );
    } on SocketException catch (e) {
      print('❌ [VacationService] 네트워크 오류: $e');
      throw Exception('네트워크 연결을 확인해주세요.');
    } on TimeoutException catch (e) {
      print('❌ [VacationService] 타임아웃 오류: $e');
      throw Exception('요청 시간이 초과되었습니다.');
    } on FormatException catch (e) {
      print('❌ [VacationService] 데이터 파싱 오류: $e');
      throw Exception('데이터 파싱 오류: $e');
    } catch (e) {
      print('❌ [VacationService] 알 수 없는 오류: $e');
      throw Exception('휴가 추천 요청 중 오류가 발생했습니다: $e');
    } finally {
      client.close();
      print('🔚 [VacationService] HTTP 클라이언트 종료');
    }
  }
}
