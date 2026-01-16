/// AI 휴가 추천 모달
///
/// 휴가 추천 결과를 표시하는 팝업

import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/features/leave/models/vacation_recommendation_model.dart';
import 'package:ASPN_AI_AGENT/features/leave/providers/vacation_recommendation_provider.dart';
import 'package:ASPN_AI_AGENT/features/leave/widgets/vacation_recommendation_charts.dart';
import 'package:ASPN_AI_AGENT/features/leave/widgets/vacation_recommendation_calendar_view.dart';
import 'package:ASPN_AI_AGENT/features/leave/widgets/vacation_ui_constants.dart';
import 'package:ASPN_AI_AGENT/features/leave/widgets/vacation_ui_components.dart';
import 'package:ASPN_AI_AGENT/shared/utils/message_renderer/gpt_markdown_renderer.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';

/// 마크다운 표 파싱 및 표시를 위한 유틸리티 클래스
class MarkdownTableParser {
  /// 마크다운 표를 파싱하여 List<List<String>>으로 변환
  static List<List<String>>? parseTable(String markdown) {
    // 다양한 줄바꿈 문자 처리
    final normalizedMarkdown =
        markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final lines = normalizedMarkdown.split('\n');

    if (lines.isEmpty) return null;

    final List<List<String>> tableData = [];

    // 첫 번째 행이 표 제목인지 확인 (**|로 시작하고 |로 끝남)
    int headerStartIndex = 0;
    if (lines.length > 0 &&
        lines[0].startsWith('**') &&
        lines[0].contains('|') &&
        !lines[0].contains('---')) {
      // 표 제목 행은 건너뜀
      headerStartIndex = 1;
    }

    // 표 헤더 찾기
    int tableHeaderIndex = -1;
    for (int i = headerStartIndex; i < lines.length; i++) {
      if (lines[i].contains('|') &&
          !lines[i].contains('---') &&
          lines[i].split('|').length > 1) {
        tableHeaderIndex = i;
        break;
      }
    }

    if (tableHeaderIndex == -1) return null;

    // 헤더 파싱
    final headerLine = lines[tableHeaderIndex];
    final headerCells = _parseTableRow(headerLine);
    tableData.add(headerCells);

    // 구분선 찾기
    int dataStartIndex = tableHeaderIndex + 1;
    if (dataStartIndex < lines.length) {
      final separatorLine = lines[dataStartIndex];
      if (separatorLine.contains('|') &&
          (separatorLine.contains('---') ||
              separatorLine.contains(':--') ||
              separatorLine.contains('--:'))) {
        dataStartIndex++;
      }
    }

    // 데이터 행들 파싱
    for (int i = dataStartIndex; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('|') && !line.startsWith('**')) {
        final cells = _parseTableRow(line);
        if (cells.isNotEmpty) {
          tableData.add(cells);
        }
      } else if (!line.contains('|')) {
        break;
      }
    }

    return tableData.isNotEmpty ? tableData : null;
  }

  static List<String> _parseTableRow(String row) {
    // | 구분자로 분리하고 앞뒤 공백 제거
    final cells = row
        .split('|')
        .map((cell) => cell.trim())
        .where((cell) => cell.isNotEmpty)
        .toList();
    return cells;
  }

  /// 표가 포함된 마크다운인지 확인
  static bool containsTable(String markdown) {
    // 다양한 줄바꿈 문자 처리
    final normalizedMarkdown =
        markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final lines = normalizedMarkdown.split('\n');

    // 최소 3줄 이상이어야 표로 인정 (헤더, 구분선, 최소 하나의 데이터 행)
    if (lines.length < 3) return false;

    // |가 포함된 줄들 찾기 (표 관련 줄들)
    final tableLines = lines
        .where((line) => line.trim().isNotEmpty && line.contains('|'))
        .toList();

    if (tableLines.length < 3) return false;

    // 표 헤더 찾기 (첫 번째 |가 포함된 줄)
    String? headerLine;
    int headerIndex = -1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('|') &&
          !line.contains('---') &&
          line.split('|').length > 1) {
        headerLine = line;
        headerIndex = i;
        break;
      }
    }

    if (headerLine == null || headerIndex == -1) return false;

    // 구분선 확인 (헤더 다음 줄이 ---를 포함하는지)
    if (headerIndex + 1 >= lines.length) return false;

    final separatorLine = lines[headerIndex + 1].trim();
    if (!(separatorLine.contains('---') ||
        separatorLine.contains(':--') ||
        separatorLine.contains('--:'))) {
      return false;
    }

    // 최소 하나의 데이터 행이 있는지 확인
    int dataRowCount = 0;
    for (int i = headerIndex + 2; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('|') && !line.startsWith('**')) {
        dataRowCount++;
      } else if (line.isNotEmpty && !line.contains('|')) {
        break; // 표가 끝남
      }
    }

    return dataRowCount > 0;
  }
}

/// 마크다운 표 위젯
class MarkdownTableWidget extends StatelessWidget {
  final List<List<String>> tableData;
  final bool isDarkTheme;

  const MarkdownTableWidget({
    super.key,
    required this.tableData,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (tableData.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 화면 너비에 맞게 컬럼 너비 계산
        final tableWidth = constraints.maxWidth;
        final columnCount = tableData.isNotEmpty ? tableData[0].length : 2;

        // 각 컬럼의 너비를 균등하게 분배 (패딩과 보더 고려)
        final availableWidth = tableWidth - (columnCount - 1) * 0.5; // 보더 너비
        final columnWidth = availableWidth / columnCount;

        // 컬럼 너비 맵 생성
        Map<int, TableColumnWidth> columnWidths = {};
        for (int i = 0; i < columnCount; i++) {
          columnWidths[i] = FixedColumnWidth(columnWidth);
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF3A3A3A) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF505050)
                  : const Color(0xFFE9ECEF),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Table(
            columnWidths: columnWidths,
            border: TableBorder(
              horizontalInside: BorderSide(
                color: isDarkTheme
                    ? const Color(0xFF505050)
                    : const Color(0xFFE9ECEF),
                width: 0.5,
              ),
              verticalInside: BorderSide(
                color: isDarkTheme
                    ? const Color(0xFF505050)
                    : const Color(0xFFE9ECEF),
                width: 0.5,
              ),
            ),
            children: tableData.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final row = entry.value;
              final isHeader = rowIndex == 0;

              return TableRow(
                decoration: isHeader
                    ? BoxDecoration(
                        color: isDarkTheme
                            ? const Color(0xFF4A4A4A)
                            : const Color(0xFFF8F9FA),
                      )
                    : null,
                children: row.map((cell) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      cell,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isHeader ? FontWeight.bold : FontWeight.normal,
                        color: isDarkTheme ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// AI 휴가 추천 모달
class VacationRecommendationPopup extends ConsumerStatefulWidget {
  final int year;

  const VacationRecommendationPopup({
    super.key,
    required this.year,
  });

  @override
  ConsumerState<VacationRecommendationPopup> createState() =>
      _VacationRecommendationPopupState();
}

class _VacationRecommendationPopupState
    extends ConsumerState<VacationRecommendationPopup> {
  double _animatedProgress = 0.0;
  Timer? _progressTimer;
  double _targetProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _startProgressAnimation();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgressAnimation() {
    _progressTimer?.cancel();
    _animatedProgress = 0.0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_animatedProgress < _targetProgress) {
          _animatedProgress += 0.01; // 1%씩 증가
          if (_animatedProgress > _targetProgress) {
            _animatedProgress = _targetProgress;
          }
        } else if (_animatedProgress > _targetProgress) {
          _animatedProgress = _targetProgress;
        }
      });

      // 목표 진행률에 도달하면 타이머 중지 (일시적으로)
      if (_animatedProgress >= 1.0 ||
          (_animatedProgress >= _targetProgress && _targetProgress > 0)) {
        // 완료되지 않았으면 계속 유지
      }
    });
  }

  void _updateTargetProgress(double newProgress) {
    _targetProgress = newProgress;
    if (_animatedProgress > _targetProgress) {
      _animatedProgress = _targetProgress;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(vacationRecommendationProvider);

    // 실제 진행률 업데이트
    if (state.hasValue && !state.value!.isComplete) {
      _updateTargetProgress(state.value!.streamingProgress);
    } else if (state.isLoading) {
      _updateTargetProgress(0.3); // 로딩 중 기본 진행률
    } else if (state.hasValue && state.value!.isComplete) {
      _updateTargetProgress(1.0); // 완료
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VacationUIRadius.xLarge),
      ),
      child: Container(
        width: 750,
        height: 800,
        padding: EdgeInsets.all(VacationUISpacing.paddingXXL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkTheme
                ? VacationUIColors.darkBackgroundGradient
                : VacationUIColors.lightBackgroundGradient,
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(VacationUIRadius.xLarge),
          boxShadow: VacationUIShadows.modalShadow(isDarkTheme),
        ),
        child: Column(
          children: [
            // 헤더
            _buildHeader(context, isDarkTheme),
            const SizedBox(height: 20),
            Divider(
              height: 1,
              color: isDarkTheme
                  ? const Color(0xFF505050)
                  : const Color(0xFFE9ECEF),
            ),

            // 상단 고정 진행률 바 (스크롤되지 않음) - 애니메이션 효과 적용
            if ((state.hasValue && !state.value!.isComplete) ||
                state.isLoading) ...[
              Container(
                margin: const EdgeInsets.only(top: 20, bottom: 12),
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // 배경
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDarkTheme
                                ? [
                                    const Color(0xFF3A3A3A),
                                    const Color(0xFF2D2D2D)
                                  ]
                                : [
                                    const Color(0xFFE8E8E8),
                                    const Color(0xFFF0F0F0)
                                  ],
                          ),
                        ),
                      ),
                      // 진행률 바
                      FractionallySizedBox(
                        widthFactor: _animatedProgress,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: VacationUIColors.accentGradient,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 스크롤 가능한 내용 영역
            Expanded(
              child: state.when(
                data: (data) => _buildScrollableContent(data, isDarkTheme),
                loading: () => _buildLoadingState(isDarkTheme),
                error: (error, stackTrace) => _buildErrorState(
                  error.toString(),
                  isDarkTheme,
                  () {
                    // 재시도 로직은 외부에서 처리
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),

            // 하단 버튼
            const SizedBox(height: 20),
            _buildCloseButton(context, isDarkTheme),
          ],
        ),
      ),
    );
  }

  /// 헤더 빌드
  Widget _buildHeader(BuildContext context, bool isDarkTheme) {
    return Row(
      children: [
        const GradientIconContainer(
          icon: Icons.auto_awesome,
          size: 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: VacationUIColors.primaryGradient,
                ).createShader(bounds),
                child: const Text(
                  '내 휴가계획 AI 추천',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.year}년 연차 사용 계획',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '닫기',
        ),
      ],
    );
  }

  /// 스크롤 가능한 내용 빌드 (진행률 바 제외)
  Widget _buildScrollableContent(
      VacationRecommendationResponse data, bool isDarkTheme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 분석 과정 (📊 이전 텍스트) - JSON 제외한 텍스트만 표시
          if (data.reasoningContents.isNotEmpty &&
              !data.isAfterAnalysisMarker) ...[
            FadeInSection(
              delay: 0,
              child: _buildSectionTitle('📊 분석 과정', isDarkTheme),
            ),
            const SizedBox(height: 14),
            FadeInSection(
              delay: 100,
              child: _buildReasoningText(
                  data.reasoningContents, data.isComplete, isDarkTheme),
            ),
            const SizedBox(height: 28),
          ],

          // 2. 과거 휴가 사용 내역 차트 (leaves JSON) - 그래프로만 표시
          if (data.leavesData != null &&
              data.leavesData!.monthlyUsage.isNotEmpty) ...[
            FadeInSection(
              delay: 200,
              child: _buildSectionTitle('📈 과거 휴가 사용 내역', isDarkTheme),
            ),
            const SizedBox(height: 14),
            FadeInSection(
              delay: 300,
              child: GradientCard(
                isDarkTheme: isDarkTheme,
                child: MonthlyDistributionChart(
                  monthlyData: data.leavesData!.monthlyUsage,
                  isDarkTheme: isDarkTheme,
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // 4. 📊 이후 마크다운 스트리밍 (reasoning 중간부터)
          if (data.isAfterAnalysisMarker &&
              data.markdownBuffer.isNotEmpty &&
              !data.isComplete) ...[
            FadeInSection(
              delay: 400,
              child: _buildSectionTitle('💡 AI 분석 결과', isDarkTheme),
            ),
            const SizedBox(height: 14),
            FadeInSection(
              delay: 500,
              child: _buildMarkdownContent(data.markdownBuffer, isDarkTheme),
            ),
            const SizedBox(height: 28),
          ],

          // 5. finalResponseContents에서 파싱된 요일별 분포 (JSON에서)
          // reasoning에서 온 weekdayCountsData와 구분하기 위해 isComplete일 때만 표시
          if (data.isComplete &&
              data.weekdayCountsData != null &&
              data.weekdayCountsData!.counts.isNotEmpty) ...[
            FadeInSection(
              delay: 600,
              child: _buildSectionTitle('📊 요일별 연차 사용량', isDarkTheme),
            ),
            const SizedBox(height: 14),
            FadeInSection(
              delay: 700,
              child: GradientCard(
                isDarkTheme: isDarkTheme,
                child: WeekdayDistributionChart(
                  weekdayData: data.weekdayCountsData!.counts,
                  isDarkTheme: isDarkTheme,
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // 6. 공휴일 인접 사용률 원형 그래프
          if (data.isComplete && data.holidayAdjacentUsageRate != null) ...[
            FadeInSection(
              delay: 800,
              child: Padding(
                padding: const EdgeInsets.only(left: 20), // 살짝 오른쪽으로 이동
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('🎯 공휴일 인접 사용률', isDarkTheme),
                    const SizedBox(height: 20), // 텍스트와 그래프 사이 간격 증가
                    GradientCard(
                      isDarkTheme: isDarkTheme,
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        height: 180,
                        child: HolidayAdjacentUsageRateChart(
                          usageRate: data.holidayAdjacentUsageRate!,
                          isDarkTheme: isDarkTheme,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // 7. 최종 응답 마크다운 (event: final) - 마크다운 렌더링 개선
          if (data.isComplete && data.finalResponseContents.isNotEmpty) ...[
            // "주요 연속 휴가 기간" 기준으로 분리
            ..._buildSplitMarkdownContent(
                data.finalResponseContents, isDarkTheme),
          ],

          // 분석 완료 후 기존 섹션들
          if (data.isComplete) ...[
            // 월별 분포 차트 (파싱된 데이터)
            if (data.monthlyDistribution.isNotEmpty) ...[
              FadeInSection(
                delay: 1200,
                child: _buildSectionTitle('📈 월별 연차 사용 분포', isDarkTheme),
              ),
              const SizedBox(height: 14),
              FadeInSection(
                delay: 1300,
                child: GradientCard(
                  isDarkTheme: isDarkTheme,
                  child: MonthlyDistributionChart(
                    monthlyData: data.monthlyDistribution,
                    isDarkTheme: isDarkTheme,
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // 추천 날짜 캘린더 그리드
            if (data.recommendedDates.isNotEmpty) ...[
              FadeInSection(
                delay: 1400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('📅 추천 휴가 날짜', isDarkTheme),
                    const SizedBox(height: 10),
                    Text(
                      '추천된 날짜는 파란색으로 표시됩니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FadeInSection(
                delay: 1500,
                child: GradientCard(
                  isDarkTheme: isDarkTheme,
                  padding: const EdgeInsets.all(16),
                  child: VacationCalendarGrid(
                    recommendedDates: data.recommendedDates,
                    isDarkTheme: isDarkTheme,
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // 연속 휴가 기간 - 각 기간을 별도의 카드로 표시
            if (data.consecutivePeriods.isNotEmpty) ...[
              FadeInSection(
                delay: 1600,
                child: _buildSectionTitle('🏖️ 주요 연속 휴가 기간', isDarkTheme),
              ),
              const SizedBox(height: 14),
              ...data.consecutivePeriods.asMap().entries.map((entry) {
                final index = entry.key;
                final period = entry.value;
                return FadeInSection(
                  delay: 1700 + (index * 100),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDarkTheme
                            ? VacationUIColors.darkCardGradient
                            : VacationUIColors.lightCardGradient,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF667EEA).withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667EEA).withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const GradientIconContainer(
                              icon: Icons.calendar_today,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${period.startDate} ~ ${period.endDate}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDarkTheme ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF667EEA).withOpacity(0.2),
                                    const Color(0xFF764BA2).withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      const Color(0xFF667EEA).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${period.days}일',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF667EEA),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          period.description,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: isDarkTheme
                                ? Colors.grey[300]
                                : Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 28),
            ],
          ],
        ],
      ),
    );
  }

  /// 섹션 제목 빌드
  Widget _buildSectionTitle(String title, bool isDarkTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // 그라데이션 액센트 바
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: VacationUIColors.primaryGradient,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// 분석 과정 텍스트 빌드
  Widget _buildReasoningText(String text, bool isComplete, bool isDarkTheme) {
    // JSON 데이터 제거 (leaves, weekday_counts 관련 텍스트 제거)
    String cleanedText = text;

    // weekday_counts나 leaves가 포함된 라인 전체 제거
    final lines = cleanedText.split('\n');
    final filteredLines = <String>[];

    for (final line in lines) {
      // weekday_counts나 leaves가 포함된 라인은 제외
      if (!line.contains('weekday_counts') &&
          !line.contains('"leaves"') &&
          !line.contains('holiday_adjacent') &&
          !line.contains('total_leave_days')) {
        filteredLines.add(line);
      }
    }

    cleanedText = filteredLines.join('\n');

    // JSON 형식의 텍스트 제거 (더 강력한 패턴 매칭)
    // 1. {로 시작하는 JSON 제거
    cleanedText = cleanedText.replaceAll(
        RegExp(r'\{[^{}]*"leaves"[^{}]*\}', dotAll: true), '');
    cleanedText = cleanedText.replaceAll(
        RegExp(r'\{[^{}]*"weekday_counts"[^{}]*\}', dotAll: true), '');

    // 2. 앞에 텍스트가 있는 경우 (예: short{"weekday_counts":...})
    cleanedText = cleanedText.replaceAll(
        RegExp(r'[^{]*\{[^{}]*"leaves"[^{}]*\}[^}]*', dotAll: true), '');
    cleanedText = cleanedText.replaceAll(
        RegExp(r'[^{]*\{[^{}]*"weekday_counts"[^{}]*\}[^}]*', dotAll: true),
        '');

    // 3. 중첩된 JSON도 처리 (더 복잡한 패턴)
    cleanedText = cleanedText.replaceAll(
        RegExp(r'\{[^{}]*\{[^{}]*"leaves"[^{}]*\}[^{}]*\}', dotAll: true), '');
    cleanedText = cleanedText.replaceAll(
        RegExp(r'\{[^{}]*\{[^{}]*"weekday_counts"[^{}]*\}[^{}]*\}',
            dotAll: true),
        '');

    // 빈 줄 정리
    cleanedText = cleanedText.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    cleanedText = cleanedText.trim();

    if (cleanedText.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(VacationUIRadius.large),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkTheme
                  ? [
                      const Color(0xFF3A3A3A).withOpacity(0.7),
                      const Color(0xFF2D2D2D).withOpacity(0.5),
                    ]
                  : [
                      Colors.white.withOpacity(0.7),
                      const Color(0xFFF8F9FA).withOpacity(0.5),
                    ],
            ),
            borderRadius: BorderRadius.circular(VacationUIRadius.large),
            border: Border.all(
              color: isDarkTheme
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkTheme
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isComplete)
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 14, top: 2),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                  ),
                ),
              Expanded(
                child: Text(
                  cleanedText,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.8,
                    fontWeight: FontWeight.w400,
                    color: isDarkTheme ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "주요 연속 휴가 기간"을 기준으로 마크다운을 분리하여 표시
  List<Widget> _buildSplitMarkdownContent(String markdown, bool isDarkTheme) {
    final List<Widget> widgets = [];

    // "주요 연속 휴가 기간" 기준으로 분리
    final splitKeyword = '**주요 연속 휴가 기간:**';
    final splitIndex = markdown.indexOf(splitKeyword);

    if (splitIndex != -1) {
      // 분리되는 경우
      final beforePart = markdown.substring(0, splitIndex).trim();
      final afterPart = markdown.substring(splitIndex).trim();

      // 앞부분: 추천 계획
      if (beforePart.isNotEmpty) {
        widgets.add(_buildSectionTitle('📋 추천 계획', isDarkTheme));
        widgets.add(const SizedBox(height: 14));
        widgets.add(_buildMarkdownContent(beforePart, isDarkTheme));
        widgets.add(const SizedBox(height: 28));
      }

      // 뒷부분: 주요 연속 휴가 기간
      if (afterPart.isNotEmpty) {
        widgets.add(_buildSectionTitle('🗓️ 주요 연속 휴가 기간', isDarkTheme));
        widgets.add(const SizedBox(height: 14));
        // "**주요 연속 휴가 기간:**" 헤더 제거하고 내용만 표시
        final contentOnly = afterPart.replaceFirst(splitKeyword, '').trim();
        widgets.add(_buildMarkdownContent(contentOnly, isDarkTheme));
        widgets.add(const SizedBox(height: 28));
      }
    } else {
      // 분리되지 않는 경우 기존 방식대로
      widgets.add(_buildSectionTitle('📋 추천 계획', isDarkTheme));
      widgets.add(const SizedBox(height: 14));
      widgets.add(_buildMarkdownContent(markdown, isDarkTheme));
      widgets.add(const SizedBox(height: 28));
    }

    return widgets;
  }

  /// 마크다운 렌더링 위젯 - GptMarkdownRenderer 사용
  Widget _buildMarkdownContent(String markdown, bool isDarkTheme) {
    // 서버에서 보낸 값 그대로 표시 (취소선 변환 제거)
    String processedMarkdown = markdown;

    // \n을 실제 줄바꿈으로 강제 변환
    processedMarkdown = processedMarkdown
        .replaceAll('\\n', '\n')
        .replaceAll(RegExp(r'\r\n'), '\n')
        .replaceAll(RegExp(r'\r'), '\n');

    // JSON 데이터 제거
    processedMarkdown = _removeJsonDataFromMarkdown(processedMarkdown);

    // 테마 색상 설정
    final themeColors = isDarkTheme
        ? AppColorSchemes.codingDarkScheme
        : AppColorSchemes.lightScheme;

    return GradientCard(
      isDarkTheme: isDarkTheme,
      child: GptMarkdownRenderer.renderBasicMarkdown(
        processedMarkdown,
        themeColors: themeColors,
        role: 1,
        style: TextStyle(
          fontSize: 14,
          height: 1.8,
          color: isDarkTheme ? Colors.grey[300] : Colors.grey[800],
        ),
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;

  /// 마크다운에서 JSON 데이터 제거
  String _removeJsonDataFromMarkdown(String markdown) {
    String processedMarkdown = markdown;

    // 1. "연속 휴가 선호: short{...}" 같은 패턴 제거
    processedMarkdown = processedMarkdown.replaceAll(
        RegExp(r'연속\s*휴가\s*선호\s*:\s*[^{]*\{[^{}]*"weekday_counts"[^}]*\}[^}]*',
            dotAll: true),
        '');
    processedMarkdown = processedMarkdown.replaceAll(
        RegExp(
            r'연속\s*휴가\s*선호\s*:\s*[^{]*\{[^{}]*"holiday_adjacent"[^}]*\}[^}]*',
            dotAll: true),
        '');

    // 2. short{...}, long{...} 같은 패턴 제거
    processedMarkdown = processedMarkdown.replaceAll(
        RegExp(r'\b(short|long)\s*\{[^{}]*"weekday_counts"[^}]*\}[^}]*',
            dotAll: true),
        '');
    processedMarkdown = processedMarkdown.replaceAll(
        RegExp(r'\b(short|long)\s*\{[^{}]*"holiday_adjacent"[^}]*\}[^}]*',
            dotAll: true),
        '');

    // 3. 추천 날짜에서 "}" 괄호 제거 (아이콘 바로 뒤에 오는 경우)
    processedMarkdown = processedMarkdown.replaceAll(RegExp(r'📅\s*\}'), '📅');

    // 4. weekday_counts, holiday_adjacent_usage_rate 등이 포함된 JSON 제거 (더 강력한 패턴)
    processedMarkdown = processedMarkdown.replaceAll(
        RegExp(r'[^{]*\{[^{}]*"weekday_counts"[^}]*\}[^}]*', dotAll: true), '');
    processedMarkdown = processedMarkdown.replaceAll(
        RegExp(r'[^{]*\{[^{}]*"holiday_adjacent"[^}]*\}[^}]*', dotAll: true),
        '');
    processedMarkdown = processedMarkdown.replaceAll(
        RegExp(r'[^{]*\{[^{}]*"total_leave_days"[^}]*\}[^}]*', dotAll: true),
        '');

    // 5. JSON이 포함된 라인 전체 제거
    final lines = processedMarkdown.split('\n');
    final filteredLines = <String>[];

    for (final line in lines) {
      if (!line.contains('weekday_counts') &&
          !line.contains('holiday_adjacent') &&
          !line.contains('total_leave_days') &&
          !line.contains('"mon"') &&
          !line.contains('"tue"') &&
          !line.contains('"wed"') &&
          !line.contains('"thu"') &&
          !line.contains('"fri"') &&
          !line.contains('"sat"') &&
          !line.contains('"sun"')) {
        filteredLines.add(line);
      }
    }

    processedMarkdown = filteredLines.join('\n');

    // 빈 줄 정리
    processedMarkdown =
        processedMarkdown.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    return processedMarkdown.trim();
  }

  /// 로딩 상태 빌드
  Widget _buildLoadingState(bool isDarkTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
          ),
          const SizedBox(height: 24),
          Text(
            'AI가 휴가 계획을 분석하고 있습니다...',
            style: TextStyle(
              fontSize: 14,
              color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 상태 빌드
  Widget _buildErrorState(
      String error, bool isDarkTheme, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            '오류가 발생했습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 닫기 버튼 빌드
  Widget _buildCloseButton(BuildContext context, bool isDarkTheme) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkTheme
              ? [const Color(0xFF4A4A4A), const Color(0xFF3A3A3A)]
              : [const Color(0xFFF5F5F5), const Color(0xFFEEEEEE)],
        ),
        borderRadius: BorderRadius.circular(VacationUIRadius.medium),
        border: Border.all(
          color: isDarkTheme
              ? const Color(0xFF505050).withOpacity(0.5)
              : const Color(0xFFE0E0E0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkTheme ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(VacationUIRadius.medium),
          splashColor: const Color(0xFF667EEA).withOpacity(0.1),
          highlightColor: const Color(0xFF667EEA).withOpacity(0.05),
          child: Center(
            child: Text(
              '닫기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
