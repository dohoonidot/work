import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart';

/// 공모전 안내 화면
class ContestGuideScreen extends ConsumerWidget {
  const ContestGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.colorScheme.name == 'Dark';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1B1F) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF202123) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '공모전 안내',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                _buildHeader(isDark),
                const SizedBox(height: 48),

                // 공모전 개요
                _buildOverview(isDark),
                const SizedBox(height: 48),

                // 참여 방법
                _buildParticipationProcess(isDark),
                const SizedBox(height: 48),

                // 투표 규칙
                _buildVotingRules(isDark),
                const SizedBox(height: 48),

                // 시스템 플로우 다이어그램
                _buildSystemDiagram(isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202123) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Color(0xFF14B8A6),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '사내 AI 활용 사례 공모전',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI를 활용한 업무 개선 사례를 공유하고 경쟁하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('공모전 개요', isDark),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202123) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                '목적',
                'AI 도구를 활용한 업무 개선 사례를 발굴하고 공유하여 조직 전체의 생산성 향상',
                isDark,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                '대상',
                '전 임직원 (1인당 1개 사례 제출 가능)',
                isDark,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                '제출 내용',
                'AI 도구 활용 사례 (사용한 도구, 적용 업무, 사용 방식, Before & After)',
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipationProcess(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('참여 방법', isDark),
        const SizedBox(height: 20),
        _buildProcessStep(
          1,
          'AI 브레인스토밍',
          'AI 채팅을 통해 사례 아이디어를 구체화하고 신청서 초안을 자동 작성',
          Icons.chat_bubble_outline,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildProcessStep(
          2,
          '신청서 작성',
          '자동 생성된 내용을 검토하고 수정하여 신청서 완성',
          Icons.edit_note,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildProcessStep(
          3,
          '첨부 파일 업로드',
          'Before & After를 보여주는 이미지나 스크린샷 첨부 (선택)',
          Icons.attach_file,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildProcessStep(
          4,
          '제출 및 검토',
          '신청서를 제출하면 관리자 검토 후 투표 화면에 공개',
          Icons.send,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildProcessStep(
          5,
          '투표 참여',
          '다른 사람의 우수 사례에 투표하고 댓글로 피드백 공유',
          Icons.how_to_vote,
          isDark,
        ),
      ],
    );
  }

  Widget _buildVotingRules(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('투표 규칙', isDark),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202123) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRuleItem(
                '1인 3표 제한',
                '각 임직원은 최대 3개의 사례에 투표할 수 있습니다',
                Icons.looks_3,
                isDark,
              ),
              const SizedBox(height: 20),
              _buildRuleItem(
                '중복 투표 금지',
                '동일한 사례에는 1번만 투표 가능합니다',
                Icons.block,
                isDark,
              ),
              const SizedBox(height: 20),
              _buildRuleItem(
                '실시간 집계',
                '투표 결과는 실시간으로 집계되어 순위가 변동됩니다',
                Icons.trending_up,
                isDark,
              ),
              const SizedBox(height: 20),
              _buildRuleItem(
                '좋아요 기능',
                '투표와 별개로 마음에 드는 사례에 좋아요를 누를 수 있습니다',
                Icons.favorite_border,
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemDiagram(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('시스템 플로우', isDark),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202123) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildFlowNode('사용자', '신청서 작성 및 제출', Icons.person, isDark),
              _buildFlowArrow(isDark),
              _buildFlowNode(
                  '시스템', 'AI 자동 분석 및 초안 생성', Icons.auto_awesome, isDark),
              _buildFlowArrow(isDark),
              _buildFlowNode('데이터베이스', '사례 정보 저장', Icons.storage, isDark),
              _buildFlowArrow(isDark),
              _buildFlowNode(
                  '관리자', '검토 및 승인', Icons.admin_panel_settings, isDark),
              _buildFlowArrow(isDark),
              _buildFlowNode('투표 화면', '전체 공개 및 투표 시작', Icons.public, isDark),
              _buildFlowArrow(isDark),
              Row(
                children: [
                  Expanded(
                    child: _buildFlowNode(
                      '임직원',
                      '투표 (최대 3표)',
                      Icons.how_to_vote,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFlowNode(
                      '임직원',
                      '좋아요 & 댓글',
                      Icons.favorite,
                      isDark,
                    ),
                  ),
                ],
              ),
              _buildFlowArrow(isDark),
              _buildFlowNode('시스템', '실시간 순위 집계', Icons.leaderboard, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.black87,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessStep(
    int stepNumber,
    String title,
    String description,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202123) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF14B8A6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            icon,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(
    String title,
    String description,
    IconData icon,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF14B8A6),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlowNode(
      String label, String description, IconData icon, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2B37) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF14B8A6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowArrow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Icon(
          Icons.arrow_downward,
          color: isDark ? Colors.grey[700] : Colors.grey[400],
          size: 20,
        ),
      ),
    );
  }
}
