import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';
import 'package:ASPN_AI_AGENT/shared/services/contest_api_service.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';

class AnnualLeaveNoticeScreen extends ConsumerStatefulWidget {
  const AnnualLeaveNoticeScreen({super.key});

  @override
  ConsumerState<AnnualLeaveNoticeScreen> createState() =>
      _AnnualLeaveNoticeScreenState();
}

class _AnnualLeaveNoticeScreenState
    extends ConsumerState<AnnualLeaveNoticeScreen> {
  bool _isLoading = true;
  String? _error;

  // 사용자 정보
  String _name = '';
  String _position = '';
  String _department = '';
  String _joinDate = '';

  // 휴가 현황
  List<LeaveStatus> _leaveStatusList = [];
  String _usagePeriod = '';
  double _totalDays = 0.0;
  double _usedDays = 0.0;
  double _remainDays = 0.0;
  String _currentDate = '';

  // 사용일수 포맷팅 (일과 시간으로 변환)
  String _formatUsedDays(double days) {
    final wholeDays = days.floor();
    final decimalPart = days - wholeDays;
    final hours = (decimalPart * 8).round(); // 0.5일 = 4시간

    if (hours == 0) {
      return '${wholeDays}일';
    } else {
      return '${wholeDays}일 ${hours}H';
    }
  }

  // 잔여일수 포맷팅
  String _formatRemainDays(double days) {
    final wholeDays = days.floor();
    final decimalPart = days - wholeDays;
    final hours = (decimalPart * 8).round(); // 0.5일 = 4시간

    if (hours == 0) {
      return '${wholeDays}일';
    } else {
      return '${wholeDays}일 ${hours}H';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        throw Exception('사용자 ID가 없습니다.');
      }

      // 사용자 정보 로드
      final userInfo = await ContestApiService.getUserInfo(userId: userId);
      _name = userInfo['name'] ?? '';
      _position = userInfo['job_position'] ?? '위원';
      _department = userInfo['department'] ?? '';

      // 휴가 현황 로드
      final leaveData = await LeaveApiService.getLeaveManagement(userId);
      _leaveStatusList = leaveData.leaveStatus;

      // 연차휴가 데이터 찾기
      final annualLeave = _leaveStatusList.firstWhere(
        (status) => status.leaveType == '연차',
        orElse: () => LeaveStatus(
          leaveType: '연차',
          totalDays: 0.0,
          remainDays: 0.0,
        ),
      );

      _totalDays = annualLeave.totalDays;
      _remainDays = annualLeave.remainDays;
      _usedDays = _totalDays - _remainDays;

      // 연차휴가 사용기간 계산
      // 일반적으로 연차는 입사일 기준 1년 단위이지만,
      // API에서 입사일 정보를 가져올 수 없으므로 현재 연도 기준으로 계산
      final now = DateTime.now();
      // 연차 기간은 보통 전년도 8월 1일 ~ 올해 7월 31일 또는
      // 올해 1월 1일 ~ 올해 12월 31일 형식
      // 여기서는 올해 1월 1일 ~ 올해 12월 31일로 설정
      final startDate = DateTime(now.year, 1, 1);
      final endDate = DateTime(now.year, 12, 31);
      _usagePeriod =
          '${DateFormat('yyyy.MM.dd').format(startDate)} ~ ${DateFormat('yyyy.MM.dd').format(endDate)}';

      // 현재 날짜 (이미지 형식: 2025-05-22 현재)
      _currentDate = DateFormat('yyyy-MM-dd').format(now);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 연차휴가 사용촉진 통지서 데이터 로드 실패: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            isDarkTheme ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
        foregroundColor: isDarkTheme ? Colors.white : const Color(0xFF374151),
        elevation: 0,
        title: const Text(
          '연차휴가 사용촉진 통지서',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    '데이터 로딩 중...',
                    style: TextStyle(
                      color: isDarkTheme ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
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
                          fontWeight: FontWeight.w600,
                          color: isDarkTheme ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color:
                              isDarkTheme ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 제목
                          Center(
                            child: Text(
                              '연차휴가 사용촉진 통지서',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // 인적 사항
                          _buildSectionTitle('인적 사항'),
                          const SizedBox(height: 16),
                          _buildPersonalInfoTable(),
                          const SizedBox(height: 32),

                          // 휴가사용계획서
                          _buildSectionTitle('휴가사용계획서'),
                          const SizedBox(height: 16),
                          _buildUsagePlanSection(),
                          const SizedBox(height: 32),

                          // 기타
                          _buildSectionTitle('기타'),
                          const SizedBox(height: 16),
                          _buildOtherSection(),
                          const SizedBox(height: 32),

                          // 주의사항
                          _buildNoticeSection(),
                          const SizedBox(height: 40),

                          // 발행 정보
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildPersonalInfoTable() {
    return Table(
      border: TableBorder.all(
        color: Colors.grey[300]!,
        width: 1,
      ),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(2),
      },
      children: [
        // 헤더 행
        TableRow(
          decoration: BoxDecoration(
            color: Colors.grey[100],
          ),
          children: [
            _buildTableCell('직위', isHeader: true),
            _buildTableCell('성명', isHeader: true),
            _buildTableCell('소속', isHeader: true),
            _buildTableCell('입사일', isHeader: true),
          ],
        ),
        // 데이터 행
        TableRow(
          children: [
            _buildTableCell(_position.isEmpty ? '위원' : _position),
            _buildTableCell(_name.isEmpty ? '-' : _name),
            _buildTableCell(_department.isEmpty ? '-' : _department),
            _buildTableCell(_joinDate.isEmpty ? '-' : _joinDate),
          ],
        ),
        // 빈 행
        const TableRow(
          children: [
            SizedBox(height: 16),
            SizedBox(height: 16),
            SizedBox(height: 16),
            SizedBox(height: 16),
          ],
        ),
        // 휴가 정보 헤더
        TableRow(
          decoration: BoxDecoration(
            color: Colors.grey[100],
          ),
          children: [
            _buildTableCell('연차휴가사용기간', isHeader: true),
            _buildTableCell('', isHeader: true), // 빈 셀 (colSpan 대체)
            _buildTableCell('발생연차일수', isHeader: true),
            _buildTableCell('사용연차일수', isHeader: true),
          ],
        ),
        // 휴가 정보 데이터
        TableRow(
          children: [
            _buildTableCell(_usagePeriod),
            _buildTableCell(''), // 빈 셀 (colSpan 대체)
            _buildTableCell('${_totalDays.toStringAsFixed(0)}일'),
            _buildTableCell(_formatUsedDays(_usedDays)),
          ],
        ),
        // 잔여일수 행
        TableRow(
          decoration: BoxDecoration(
            color: Colors.blue[50],
          ),
          children: [
            _buildTableCell('잔여연차휴가일수', isHeader: true),
            _buildTableCell('', isHeader: true), // 빈 셀
            _buildTableCell('', isHeader: true), // 빈 셀
            _buildTableCell(
              _formatRemainDays(_remainDays),
              textStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
                fontSize: 16,
              ),
            ),
          ],
        ),
        // 현재 날짜 표시
        TableRow(
          children: [
            _buildTableCell(
              '$_currentDate 현재',
              textStyle: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            _buildTableCell(''), // 빈 셀
            _buildTableCell(''), // 빈 셀
            _buildTableCell(''), // 빈 셀
          ],
        ),
      ],
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    TextStyle? textStyle,
  }) {
    return TableCell(
      child: Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: textStyle ??
              TextStyle(
                fontSize: 14,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? Colors.black87 : Colors.black,
              ),
        ),
      ),
    );
  }

  Widget _buildUsagePlanSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '5월 26일까지 별첨1. 서식을 이용하여 본인의 연차휴가사용계획서를 경영관리팀에 제출하여 주시기 바랍니다.',
        style: TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildOtherSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '별첨 1. 미사용연차휴가 사용계획서',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '서명: ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              Text(
                '$_name (인)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[200]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. 연차유급 휴가 사용시기 지정시 노동 관련법령을 준수하고, 사업운영에 지장을 초래하지 않도록 협조해주시기 바랍니다.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '2. 기한 내에 "미사용 연차유급휴가 사용시기 지정 통보서" 가 제출되지 않을 경우 회사가 미사용 연차유급휴가 사용시기를 임의로 지정 통보하며, 그럼에도 불구하고 사용하지 아니한 연차유급휴가에 대하여는 보상되지 않음을 알려드립니다.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy년 M월 d일').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '근로기준법 제61조(연차유급휴가의 사용촉진) 조항에 근거하여 위와 같이 통지함.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          formattedDate,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '㈜에이에스피엔 대표이사 한창직',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '주식회사 에이에스피엔',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
