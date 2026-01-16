/// AI 휴가 추천 차트 위젯
///
/// fl_chart를 사용한 데이터 시각화

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// 월별 분포 바 차트
class MonthlyDistributionChart extends StatelessWidget {
  final Map<int, double> monthlyData;
  final bool isDarkTheme;

  const MonthlyDistributionChart({
    super.key,
    required this.monthlyData,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (monthlyData.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: Text('월별 분포 데이터가 없습니다.'),
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxY(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final month = group.x.toInt();
                final days = rod.toY;
                return BarTooltipItem(
                  '$month월\n${days.toStringAsFixed(1)}일',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${value.toInt()}월',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkTheme ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}일',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkTheme ? Colors.grey[400] : Colors.grey[700],
                    ),
                  );
                },
                reservedSize: 35,
                interval: 1,
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDarkTheme
                    ? Colors.grey[700]!.withOpacity(0.3)
                    : Colors.grey[300]!.withOpacity(0.5),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(
                color: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
              ),
              bottom: BorderSide(
                color: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
          ),
          barGroups: _createBarGroups(),
        ),
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups() {
    return monthlyData.entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: const Color(0xFF4A90E2),
            width: 20,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxY(),
              color: isDarkTheme
                  ? Colors.grey[800]!.withOpacity(0.3)
                  : Colors.grey[200]!.withOpacity(0.5),
            ),
          ),
        ],
      );
    }).toList();
  }

  double _getMaxY() {
    if (monthlyData.isEmpty) return 5;
    final maxValue = monthlyData.values.reduce((a, b) => a > b ? a : b);
    return (maxValue + 1).ceilToDouble();
  }
}

/// 연차 사용 프로그레스 바
class VacationProgressBar extends StatelessWidget {
  final double usedDays;
  final double totalDays;
  final bool isDarkTheme;

  const VacationProgressBar({
    super.key,
    required this.usedDays,
    required this.totalDays,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = totalDays > 0 ? usedDays / totalDays : 0.0;
    final remainingDays = totalDays - usedDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '총 ${usedDays.toStringAsFixed(1)}일 사용',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkTheme ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            Text(
              '잔여 ${remainingDays.toStringAsFixed(1)}일',
              style: TextStyle(
                fontSize: 14,
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            backgroundColor: isDarkTheme
                ? Colors.grey[700]
                : Colors.grey[300],
            color: const Color(0xFF4A90E2),
            minHeight: 16,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(percentage * 100).toStringAsFixed(0)}% 사용',
            style: TextStyle(
              fontSize: 12,
              color: isDarkTheme ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}

/// 통계 카드 위젯
class VacationStatisticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDarkTheme;

  const VacationStatisticsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
            ),
          ),
        ],
      ),
    );
  }
}

/// 요일별 사용 분포 바 차트
class WeekdayDistributionChart extends StatelessWidget {
  final Map<String, double> weekdayData;
  final bool isDarkTheme;

  const WeekdayDistributionChart({
    super.key,
    required this.weekdayData,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (weekdayData.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: Text('요일별 분포 데이터가 없습니다.'),
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxY(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
                final dayName = dayNames[group.x.toInt()];
                final count = rod.toY;
                return BarTooltipItem(
                  '$dayName요일\n${count.toStringAsFixed(1)}일',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const dayNames = ['월', '화', '수', '목', '금', '토', '일'];
                  final idx = value.toInt();
                  if (idx < 0 || idx >= dayNames.length) return const SizedBox();

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      dayNames[idx],
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkTheme ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}일',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkTheme ? Colors.grey[400] : Colors.grey[700],
                    ),
                  );
                },
                reservedSize: 35,
                interval: 1,
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDarkTheme
                    ? Colors.grey[700]!.withOpacity(0.3)
                    : Colors.grey[300]!.withOpacity(0.5),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(
                color: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
              ),
              bottom: BorderSide(
                color: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
          ),
          barGroups: _createWeekdayBars(),
        ),
      ),
    );
  }

  List<BarChartGroupData> _createWeekdayBars() {
    // API에서 오는 키: mon, tue, wed, thu, fri, sat, sun
    final dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return dayOrder.asMap().entries.map((entry) {
      final idx = entry.key;
      final dayKey = entry.value;
      final value = weekdayData[dayKey] ?? 0.0;

      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: value,
            color: const Color(0xFF4A90E2),
            width: 20,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxY(),
              color: isDarkTheme
                  ? Colors.grey[800]!.withOpacity(0.3)
                  : Colors.grey[200]!.withOpacity(0.5),
            ),
          ),
        ],
      );
    }).toList();
  }

  double _getMaxY() {
    if (weekdayData.isEmpty) return 10;
    final maxValue = weekdayData.values.reduce((a, b) => a > b ? a : b);
    return (maxValue + 2).ceilToDouble();
  }
}

/// 공휴일 인접 사용률 원형 그래프
class HolidayAdjacentUsageRateChart extends StatelessWidget {
  final double usageRate; // 0.0 ~ 1.0
  final bool isDarkTheme;

  const HolidayAdjacentUsageRateChart({
    super.key,
    required this.usageRate,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (usageRate * 100).toStringAsFixed(2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 원형 그래프와 텍스트를 하나의 Row로 배치
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 원형 그래프 - 더 작게
            SizedBox(
              width: 100,
              height: 100,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: usageRate * 100,
                      title: '$percentage%',
                      color: const Color(0xFF4A90E2),
                      radius: 40,
                      titleStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: (1 - usageRate) * 100,
                      title: '',
                      color: isDarkTheme
                          ? Colors.grey[700]
                          : Colors.grey[300],
                      radius: 40,
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 25,
                  startDegreeOffset: -90, // 상단에서 시작
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 설명 텍스트 - 우측에 배치
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '공휴일 인접 사용률',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '전체 연차 중 공휴일과 인접한 날짜에 사용한 비율입니다',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
