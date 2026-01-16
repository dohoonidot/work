/// AI 휴가 추천 캘린더 그리드 위젯
///
/// 추천 날짜를 월별 캘린더 형태로 시각화

import 'package:flutter/material.dart';

/// 추천 날짜 캘린더 그리드
class VacationCalendarGrid extends StatelessWidget {
  final List<String> recommendedDates;
  final bool isDarkTheme;

  const VacationCalendarGrid({
    super.key,
    required this.recommendedDates,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendedDates.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('추천 날짜가 없습니다.'),
        ),
      );
    }

    // 추천 날짜를 월별로 그룹화
    final datesByMonth = _groupByMonth(recommendedDates);

    return Column(
      children: datesByMonth.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildMonthCalendar(entry.key, entry.value),
        );
      }).toList(),
    );
  }

  /// 월별 캘린더 생성
  Widget _buildMonthCalendar(String monthKey, List<DateTime> highlightDates) {
    // monthKey: "2026-02"
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;

    // 시작 요일 (0=일요일, 1=월요일, ..., 6=토요일)
    final startWeekday = firstDay.weekday % 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkTheme
              ? const Color(0xFF505050)
              : const Color(0xFFE9ECEF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 월 헤더
          Text(
            '${year}년 ${month}월',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
            ),
          ),
          const SizedBox(height: 16),

          // 요일 헤더
          _buildWeekdayHeader(),
          const SizedBox(height: 8),

          // 날짜 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) {
                // 빈 공간
                return const SizedBox();
              }

              final day = index - startWeekday + 1;
              final currentDate = DateTime(year, month, day);

              // 추천 날짜인지 확인
              final isHighlighted = highlightDates.any((d) =>
                  d.year == currentDate.year &&
                  d.month == currentDate.month &&
                  d.day == currentDate.day);

              // 주말인지 확인
              final isWeekend = currentDate.weekday == DateTime.saturday ||
                  currentDate.weekday == DateTime.sunday;

              return _buildDateCell(day, isHighlighted, isWeekend);
            },
          ),
        ],
      ),
    );
  }

  /// 요일 헤더 빌드
  Widget _buildWeekdayHeader() {
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];

    return Row(
      children: weekdays.asMap().entries.map((entry) {
        final index = entry.key;
        final day = entry.value;
        final isWeekend = index == 0 || index == 6; // 일요일 또는 토요일

        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isWeekend
                    ? Colors.red[400]
                    : (isDarkTheme ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 날짜 셀 빌드
  Widget _buildDateCell(int day, bool isHighlighted, bool isWeekend) {
    Color bgColor = Colors.transparent;
    Color textColor;
    FontWeight fontWeight = FontWeight.normal;

    if (isHighlighted) {
      // 추천 날짜: 파란색 배경, 흰색 텍스트
      bgColor = const Color(0xFF4A90E2);
      textColor = Colors.white;
      fontWeight = FontWeight.bold;
    } else if (isWeekend) {
      // 주말: 빨간색 텍스트
      textColor = Colors.red[300]!;
    } else {
      // 평일: 기본 텍스트 색상
      textColor = isDarkTheme ? Colors.grey[300]! : Colors.grey[800]!;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isHighlighted
            ? null
            : Border.all(
                color: isDarkTheme
                    ? Colors.grey[700]!.withOpacity(0.3)
                    : Colors.grey[300]!.withOpacity(0.5),
                width: 1,
              ),
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  /// 추천 날짜를 월별로 그룹화
  ///
  /// Returns: Map<"YYYY-MM", List<DateTime>>
  Map<String, List<DateTime>> _groupByMonth(List<String> dates) {
    final Map<String, List<DateTime>> result = {};

    for (final dateStr in dates) {
      try {
        final date = DateTime.parse(dateStr);
        final monthKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        result.putIfAbsent(monthKey, () => []).add(date);
      } catch (e) {
        print('날짜 파싱 오류: $dateStr - $e');
      }
    }

    // 월별로 정렬 (오름차순)
    final sortedEntries = result.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Map.fromEntries(sortedEntries);
  }
}

/// 연속 휴가 기간 테이블
class ConsecutivePeriodsTable extends StatelessWidget {
  final List<dynamic> periods; // VacationPeriod 타입 (순환 참조 방지를 위해 dynamic 사용)
  final bool isDarkTheme;

  const ConsecutivePeriodsTable({
    super.key,
    required this.periods,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('연속 휴가 기간이 없습니다.'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkTheme
              ? const Color(0xFF505050)
              : const Color(0xFFE9ECEF),
        ),
      ),
      child: Column(
        children: [
          // 테이블 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkTheme
                  ? const Color(0xFF2D2D2D)
                  : const Color(0xFFE9ECEF),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    '기간',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkTheme ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Text(
                      '일수',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkTheme ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '설명',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkTheme ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 테이블 바디
          ...periods.asMap().entries.map((entry) {
            final index = entry.key;
            final period = entry.value;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: index < periods.length - 1
                      ? BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE9ECEF),
                        )
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${_formatDate(period.startDate)} ~ ${_formatDate(period.endDate)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkTheme ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${period.days}일',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      period.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
