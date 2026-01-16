import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/services/contest_api_service.dart';
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';

/// 나의 제출 현황 화면
class MySubmissionsScreen extends ConsumerStatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  ConsumerState<MySubmissionsScreen> createState() =>
      _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends ConsumerState<MySubmissionsScreen> {
  Map<String, dynamic>? _submission;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = '로그인한 사용자 정보를 찾을 수 없습니다.';
        });
        return;
      }

      final submission =
          await ContestApiService.getUserSubmissions(userId: userId);
      if (!mounted) return;
      setState(() {
        _submission = submission;
        _isLoading = false;
        // submission이 null이면 데이터가 없는 것 (에러 아님)
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '나의 제출 현황을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      });
      print('❌ [MySubmissionsScreen] 제출 현황 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.colorScheme.name == 'Dark';

    return Scaffold(
      backgroundColor: themeState.colorScheme.backgroundColor,
      body: Row(
        children: [
          // 사이드바 (뒤로가기 버튼만)
          Container(
            width: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF202123),
                        const Color(0xFF1A1B1F),
                        const Color(0xFF17181C),
                      ]
                    : [
                        const Color(0xFFFAFAFA),
                        const Color(0xFFF7F7F8),
                        const Color(0xFFF0F0F0),
                      ],
              ),
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.grey[800]!.withValues(alpha: 0.6)
                      : Colors.grey[300]!.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF2A2B37).withValues(alpha: 0.8),
                              const Color(0xFF1F2023).withValues(alpha: 0.9),
                            ]
                          : [
                              const Color(0xFFFAFAFA),
                              const Color(0xFFF0F0F0),
                            ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.grey[800]!.withValues(alpha: 0.5)
                            : Colors.grey[300]!.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 뒤로가기 버튼
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[800]!.withValues(alpha: 0.5)
                              : Colors.grey[100]!.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context),
                          tooltip: '뒤로가기',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.assignment_turned_in_rounded,
                        size: 18,
                        color: const Color(0xFF14B8A6),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isDark
                                ? [
                                    Colors.white,
                                    Colors.grey[300]!,
                                  ]
                                : [
                                    const Color(0xFF202123),
                                    const Color(0xFF404040),
                                  ],
                          ).createShader(bounds),
                          child: const Text(
                            '나의 제출 현황',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 메인 콘텐츠 영역
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          const Color(0xFF1F2023).withValues(alpha: 0.5),
                          themeState.colorScheme.backgroundColor,
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.8),
                          themeState.colorScheme.backgroundColor,
                        ],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 페이지 제목
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF2A2B37),
                                  const Color(0xFF1F2023),
                                ]
                              : [
                                  const Color(0xFFCCFBF1),
                                  const Color(0xFF99F6E4),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF14B8A6).withValues(alpha: 0.3)
                              : const Color(0xFF14B8A6).withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.3)
                                : const Color(0xFF14B8A6)
                                    .withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '나의 제출 현황',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF115E59),
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '제출한 항목들을 확인하고 관리하세요',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : const Color(0xFF0F766E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    Builder(
                      builder: (context) {
                        if (_isLoading) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 80),
                            child: Center(
                              child: Column(
                                children: const [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('제출 현황을 불러오는 중입니다...'),
                                ],
                              ),
                            ),
                          );
                        }

                        if (_error != null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              children: [
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.red[200]
                                        : const Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _loadSubmissions,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('다시 시도'),
                                ),
                              ],
                            ),
                          );
                        }

                        if (_submission == null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 48,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '제출한 공모전이 없습니다.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '공모전에 참여하고 나의 제출 현황을 확인해보세요.',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : const Color(0xFF6B7280),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        // 상세내역 형식으로 바로 표시
                        return _buildDetailView(
                            _submission!, themeState, isDark);
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView(
    Map<String, dynamic> submission,
    ThemeState themeState,
    bool isDark,
  ) {
    // 첨부 파일 리스트 가져오기
    final attachmentsList = submission['attachment_urls'];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF2A2B37),
                  const Color(0xFF1F2023),
                ]
              : [
                  Colors.white,
                  const Color(0xFFFAFAFA),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!.withValues(alpha: 0.5)
              : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목과 수정하기 버튼
            Row(
              children: [
                Expanded(
                  child: Text(
                    submission['title'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showEditModal(context, submission, themeState, isDark),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('수정하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // AI 활용 사례 정보
            // 1. 사용한 AI TOOL
            if (submission['tool_name'] != null &&
                (submission['tool_name'] as String).trim().isNotEmpty)
              _buildDetailSection(
                '1. 사용한 AI TOOL',
                submission['tool_name'] as String? ?? '',
                Icons.psychology,
                isDark,
              ),
            if (submission['tool_name'] != null &&
                (submission['tool_name'] as String).trim().isNotEmpty)
              const SizedBox(height: 24),

            // 2. 어떤 업무에 적용 했나요?
            if (submission['work_scope'] != null &&
                (submission['work_scope'] as String).trim().isNotEmpty)
              _buildDetailSection(
                '2. 어떤 업무에 적용 했나요?',
                submission['work_scope'] as String? ?? '',
                Icons.work_outline,
                isDark,
              ),
            if (submission['work_scope'] != null &&
                (submission['work_scope'] as String).trim().isNotEmpty)
              const SizedBox(height: 24),

            // 3. 어떤 방식으로 사용 했나요?
            if (submission['work_method'] != null &&
                (submission['work_method'] as String).trim().isNotEmpty)
              _buildDetailSection(
                '3. 어떤 방식으로 사용 했나요?',
                submission['work_method'] as String? ?? '',
                Icons.settings,
                isDark,
              ),
            if (submission['work_method'] != null &&
                (submission['work_method'] as String).trim().isNotEmpty)
              const SizedBox(height: 24),

            // 4. Before & After
            if (submission['before_after'] != null &&
                (submission['before_after'] as String).trim().isNotEmpty)
              _buildDetailSection(
                '4. Before & After',
                submission['before_after'] as String? ?? '',
                Icons.compare_arrows,
                isDark,
              ),
            if (submission['before_after'] != null &&
                (submission['before_after'] as String).trim().isNotEmpty)
              const SizedBox(height: 24),

            // 첨부 파일
            if (attachmentsList != null) ...[
              // attachment_urls가 List인 경우
              if (attachmentsList is List && attachmentsList.isNotEmpty) ...[
                _buildAttachmentsSection(
                  attachmentsList,
                  isDark,
                ),
                const SizedBox(height: 24),
              ] else if (attachmentsList is String &&
                  attachmentsList.trim().isNotEmpty) ...[
                // attachment_urls가 String인 경우 (하위 호환성)
                _buildAttachmentsSection(
                  attachmentsList,
                  isDark,
                ),
                const SizedBox(height: 24),
              ],
            ],

            // 통계 정보
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '투표수',
                    '${submission['votes'] as int? ?? 0}',
                    Icons.how_to_vote,
                    isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    '조회수',
                    '${submission['view_count'] as int? ?? 0}',
                    Icons.visibility,
                    isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    '좋아요',
                    '${submission['like_count'] as int? ?? 0}',
                    Icons.favorite,
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    String title,
    String content,
    IconData icon,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4A6CF7).withValues(alpha: 0.2),
                    const Color(0xFF6366F1).withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF4A6CF7),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey[50]!.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection(dynamic attachmentsList, bool isDark) {
    List<dynamic> attachments = [];

    // attachment_urls가 List인 경우
    if (attachmentsList is List) {
      attachments = attachmentsList;
    }
    // attachment_urls가 String인 경우 (하위 호환성 - JSON 문자열 파싱)
    else if (attachmentsList is String) {
      try {
        final decoded = jsonDecode(attachmentsList);
        if (decoded is List) {
          attachments = decoded;
        }
      } catch (e) {
        print('⚠️ 첨부 파일 파싱 실패: $e');
        return const SizedBox.shrink();
      }
    } else {
      return const SizedBox.shrink();
    }

    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    // attachments가 List인 경우 처리
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4A6CF7).withValues(alpha: 0.2),
                    const Color(0xFF6366F1).withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.attach_file,
                size: 18,
                color: Color(0xFF4A6CF7),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '첨부 파일',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: attachments.map<Widget>((attachment) {
            if (attachment is Map<String, dynamic>) {
              final url = attachment['url'] as String?;
              if (url != null && url.isNotEmpty) {
                return GestureDetector(
                  onTap: () {
                    _showImageDialog(context, url, isDark);
                  },
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: Icon(
                              Icons.broken_image,
                              color:
                                  isDark ? Colors.grey[600] : Colors.grey[400],
                              size: 40,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }
            }
            return const SizedBox.shrink();
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.grey[800]!.withValues(alpha: 0.3),
                  Colors.grey[850]!.withValues(alpha: 0.2),
                ]
              : [
                  Colors.grey[100]!.withValues(alpha: 0.8),
                  Colors.grey[50]!.withValues(alpha: 0.5),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!.withValues(alpha: 0.5)
              : Colors.grey[300]!.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditModal(
    BuildContext context,
    Map<String, dynamic> submission,
    ThemeState themeState,
    bool isDark,
  ) {
    final contestId = submission['contest_id'] as int?;
    print('📝 [MySubmissionsScreen] 수정 모달 열기');
    print('  - contest_id: $contestId');
    print('  - title: ${submission['title']}');

    if (contestId == null || contestId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('contest_id를 찾을 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => ContestEditModal(
        submission: submission,
        themeState: themeState,
        isDark: isDark,
        onUpdated: () {
          // 수정 후 목록 새로고침
          _loadSubmissions();
          Navigator.pop(context);
        },
      ),
    );
  }

  /// 이미지 확대 다이얼로그
  void _showImageDialog(BuildContext context, String imageUrl, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // 배경 클릭 시 닫기
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
              ),
            ),
            // 이미지
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 64,
                              color:
                                  isDark ? Colors.grey[600] : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '이미지를 불러올 수 없습니다',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // 닫기 버튼
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 공모전 수정 모달
class ContestEditModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> submission;
  final ThemeState themeState;
  final bool isDark;
  final VoidCallback onUpdated;

  const ContestEditModal({
    super.key,
    required this.submission,
    required this.themeState,
    required this.isDark,
    required this.onUpdated,
  });

  @override
  ConsumerState<ContestEditModal> createState() => _ContestEditModalState();
}

class _ContestEditModalState extends ConsumerState<ContestEditModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _toolNameController;
  late final TextEditingController _workScopeController;
  late final TextEditingController _workMethodController;
  late final TextEditingController _beforeAfterController;

  // 기존 첨부파일 (서버에서 가져온 파일들)
  List<Map<String, dynamic>> _existingFiles = [];
  // 새로 추가한 첨부파일 (로컬에서 선택한 파일들)
  List<Map<String, dynamic>> _newFiles = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 기존 데이터로 컨트롤러 초기화
    _titleController = TextEditingController(
        text: widget.submission['title'] as String? ?? '');
    _toolNameController = TextEditingController(
        text: widget.submission['tool_name'] as String? ?? '');
    _workScopeController = TextEditingController(
        text: widget.submission['work_scope'] as String? ?? '');
    _workMethodController = TextEditingController(
        text: widget.submission['work_method'] as String? ?? '');
    _beforeAfterController = TextEditingController(
        text: widget.submission['before_after'] as String? ?? '');

    // 기존 첨부파일 초기화
    _loadExistingFiles();
  }

  void _loadExistingFiles() {
    final attachmentUrls = widget.submission['attachment_urls'];
    if (attachmentUrls != null) {
      List<dynamic> attachments = [];

      if (attachmentUrls is List) {
        attachments = attachmentUrls;
      } else if (attachmentUrls is String) {
        try {
          final decoded = jsonDecode(attachmentUrls);
          if (decoded is List) {
            attachments = decoded;
          }
        } catch (e) {
          print('⚠️ 기존 첨부파일 파싱 실패: $e');
        }
      }

      setState(() {
        _existingFiles = attachments.map<Map<String, dynamic>>((item) {
          if (item is Map<String, dynamic>) {
            // 서버에서 받은 실제 파일명 사용
            final fileName = item['file_name'] as String? ?? '';
            final url = item['url'] as String? ?? '';
            final prefix = item['prefix'] as String? ?? '';

            print('📎 [ContestEditModal] 기존 파일 로드:');
            print('  - file_name: $fileName');
            print('  - url: $url');
            print('  - prefix: $prefix');

            return {
              'type': 'existing', // 기존 파일 표시
              'file_name': fileName, // 실제 파일명 사용
              'url': url,
              'prefix': prefix,
            };
          }
          return {'type': 'existing'};
        }).toList();
      });

      print('📎 [ContestEditModal] 총 ${_existingFiles.length}개 기존 파일 로드 완료');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _toolNameController.dispose();
    _workScopeController.dispose();
    _workMethodController.dispose();
    _beforeAfterController.dispose();
    super.dispose();
  }

  Future<void> _submitUpdate() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요.')),
      );
      return;
    }

    if (_toolNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용한 AI TOOL을 입력해주세요.')),
      );
      return;
    }

    final userId = ref.read(userIdProvider);
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final contestId = widget.submission['contest_id'] as int?;

      if (contestId == null || contestId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('contest_id가 유효하지 않습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('📝 [ContestEditModal] 수정 요청');
      print('  - contest_id: $contestId');
      print('  - user_id: $userId');
      print('  - 기존 파일 개수 (남아있는): ${_existingFiles.length}');
      print('  - 새 파일 개수: ${_newFiles.length}');

      // 새로 추가한 파일만 전송 (기존 파일은 서버에 이미 있음)
      final List<Uint8List>? fileBytes = _newFiles.isNotEmpty
          ? _newFiles.map((file) => file['data'] as Uint8List).toList()
          : null;

      // 남아있는 기존 파일 정보 전달 (삭제된 파일은 제외)
      // 서버에 남아있어야 할 기존 파일 목록 (attachment_urls 형태로 전송)
      final List<Map<String, dynamic>> remainingExistingFiles =
          _existingFiles.map((file) {
        final fileName = file['file_name'] as String? ?? '';
        final url = file['url'] as String? ?? '';

        print('📤 [ContestEditModal] 기존 파일 전송:');
        print('  - file_name: $fileName');
        print('  - url: $url');

        return {
          'file_name': fileName, // 실제 파일명 사용
          'url': url,
        };
      }).toList();

      print(
          '📤 [ContestEditModal] 총 ${remainingExistingFiles.length}개 기존 파일 전송 준비 완료');

      await ContestApiService.updateContest(
        userId: userId,
        contestId: contestId,
        title: _titleController.text.trim(),
        toolName: _toolNameController.text.trim(),
        workScope: _workScopeController.text.trim(),
        workMethod: _workMethodController.text.trim(),
        beforeAfter: _beforeAfterController.text.trim(),
        files: fileBytes,
        existingFiles: remainingExistingFiles, // 남아있는 기존 파일 정보 전달
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수정이 완료되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수정 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            final fileBytes = file.bytes;
            if (fileBytes != null) {
              final fileName = file.name.isNotEmpty
                  ? file.name
                  : 'image_${_newFiles.length}.jpg';

              _newFiles.add({
                'type': 'new', // 새 파일 표시
                'name': fileName,
                'data': fileBytes,
              });
            }
          }
        });
      }
    } catch (e) {
      print('❌ 파일 선택 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('파일 선택에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 기존 첨부파일 삭제
  void _removeExistingFile(int index) {
    setState(() {
      _existingFiles.removeAt(index);
    });
  }

  /// 새 첨부파일 삭제
  void _removeNewFile(int index) {
    setState(() {
      _newFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isDark
                ? [
                    const Color(0xFF40414F),
                    const Color(0xFF343541),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFFAFAFA),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '공모전 수정',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color:
                          widget.isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 내용
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      '제목',
                      '제목을 입력하세요',
                      _titleController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      '1. 사용한 AI TOOL',
                      '사용한 AI 도구를 입력하세요',
                      _toolNameController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextArea(
                      '2. 어떤 업무에 적용 했나요?',
                      '어떤 업무에 AI를 적용했는지 작성해주세요',
                      _workScopeController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextArea(
                      '3. 어떤 방식으로 사용 했나요?',
                      'AI를 어떤 방식으로 활용했는지 상세히 작성해주세요',
                      _workMethodController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextArea(
                      '4. Before & After',
                      'AI 활용 전후의 변화를 작성해주세요',
                      _beforeAfterController,
                    ),
                    const SizedBox(height: 16),

                    // 첨부 파일 섹션
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '첨부 파일',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.grey[300]
                                : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 파일 추가 버튼
                        OutlinedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('파일 추가'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 기존 첨부파일 표시
                        if (_existingFiles.isNotEmpty) ...[
                          Text(
                            '기존 첨부파일',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: widget.isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                List.generate(_existingFiles.length, (index) {
                              final file = _existingFiles[index];
                              final url = file['url'] as String? ?? '';
                              final prefix = file['prefix'] as String? ?? '';

                              // URL 구성 (prefix + url 또는 url만)
                              String imageUrl = '';
                              if (url.isNotEmpty) {
                                if (prefix.isNotEmpty &&
                                    !url.startsWith('http')) {
                                  imageUrl = '${AppConfig.baseUrl}/$prefix$url';
                                } else if (url.startsWith('http')) {
                                  imageUrl = url;
                                } else {
                                  imageUrl = '${AppConfig.baseUrl}/$url';
                                }
                              }

                              return Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: widget.isDark
                                            ? Colors.grey[600]!
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              loadingBuilder:
                                                  (context, child, progress) {
                                                if (progress == null)
                                                  return child;
                                                return Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    value: progress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? progress
                                                                .cumulativeBytesLoaded /
                                                            progress
                                                                .expectedTotalBytes!
                                                        : null,
                                                    strokeWidth: 2,
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  color: widget.isDark
                                                      ? Colors.grey[800]
                                                      : Colors.grey[200],
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: widget.isDark
                                                        ? Colors.grey[600]
                                                        : Colors.grey[400],
                                                    size: 30,
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              color: widget.isDark
                                                  ? Colors.grey[800]
                                                  : Colors.grey[200],
                                              child: Icon(
                                                Icons.image,
                                                color: widget.isDark
                                                    ? Colors.grey[600]
                                                    : Colors.grey[400],
                                                size: 30,
                                              ),
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: IconButton(
                                      onPressed: () =>
                                          _removeExistingFile(index),
                                      icon: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 새 첨부파일 표시
                        if (_newFiles.isNotEmpty) ...[
                          Text(
                            '새로 추가한 파일',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: widget.isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_newFiles.length, (index) {
                              return Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: widget.isDark
                                            ? Colors.grey[600]!
                                            : Colors.grey[300]!,
                                      ),
                                      image: DecorationImage(
                                        image: MemoryImage(_newFiles[index]
                                            ['data'] as Uint8List),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: IconButton(
                                      onPressed: () => _removeNewFile(index),
                                      icon: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // 하단 버튼
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('수정 완료'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            filled: true,
            fillColor: widget.isDark
                ? Colors.grey[900]!.withValues(alpha: 0.5)
                : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            filled: true,
            fillColor: widget.isDark
                ? Colors.grey[900]!.withValues(alpha: 0.5)
                : Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
