import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/services/contest_api_service.dart';
import 'package:ASPN_AI_AGENT/shared/utils/message_renderer/gpt_markdown_renderer.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';
import 'package:ASPN_AI_AGENT/ui/screens/my_submissions_screen.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';

/// 투표 화면 (ChatGPT 스타일, 좌우 스크롤 미리보기 형식)
class VotingScreen extends ConsumerStatefulWidget {
  final int? initialContestId;

  const VotingScreen({super.key, this.initialContestId});

  @override
  ConsumerState<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends ConsumerState<VotingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  int _currentPage = 0;
  String? _selectedSubmissionId;
  bool _isScrolling = false;
  bool _isLoading = false;
  String _currentViewType = 'ai'; // 기본값: ai (AI추천순)
  Map<String, int> _voteResults = {};
  String _activeDisplay = 'submissions';

  // 페이지네이션 관련
  int _resultsCurrentPage = 0;
  final int _resultsPerPage = 10;

  List<Map<String, dynamic>> _submissions = [];

  // 좋아요 상태 관리
  final Map<int, bool> _likedContests = {};
  final Map<int, int> _likeCounts = {};

  // 카테고리 필터링
  String _selectedCategory = '';
  final List<String> _categories = [
    '영업·마케팅 지원',
    '데이터 분석·인사이트 분석',
    'SAP 개발/운영 효율화',
    '개발/운영 효율화',
    '업무 자동화',
    '교육·지식 관리',
    '창의/아이디어 부문',
  ];

  int? _highlightedContestId;
  bool _initialHighlightHandled = false;

  // 남은 투표 수
  int _remainingVotes = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.45, // 카드 크기를 약간 더 크게
    );

    // 페이지 컨트롤러 리스너 추가 (스크롤 중 감지)
    _pageController.addListener(() {
      if (_pageController.page != null) {
        final page = _pageController.page!;
        if ((page - page.round()).abs() > 0.01) {
          if (!_isScrolling) {
            setState(() {
              _isScrolling = true;
            });
          }
        } else {
          if (_isScrolling) {
            setState(() {
              _isScrolling = false;
            });
          }
        }
      }
    });

    _highlightedContestId = widget.initialContestId;

    // 초기 데이터 로드
    _loadContestList();
    _loadRemainingVotes();
  }

  /// 남은 투표 수 조회
  Future<void> _loadRemainingVotes() async {
    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        print('⚠️ [VotingScreen] 로그인 정보 없음 - 남은 투표 수 조회 스킵');
        return;
      }

      final remainVotes = await ContestApiService.getRemainingVotes(
        userId: userId,
      );

      if (mounted) {
        setState(() {
          _remainingVotes = remainVotes;
        });
        print('✅ [VotingScreen] 남은 투표 수: $_remainingVotes');
      }
    } catch (e) {
      print('❌ [VotingScreen] 남은 투표 수 조회 실패: $e');
      // 에러 발생 시 0으로 유지
    }
  }

  /// 공모전 목록 조회
  Future<void> _loadContestList({String? viewType}) async {
    setState(() {
      _isLoading = true;
      if (viewType != null) {
        _currentViewType = viewType;
      }
    });

    try {
      final userId = ref.read(userIdProvider) ?? '';
      final response = await ContestApiService.getContestList(
        contestType: 'test',
        viewType: _currentViewType,
        userId: userId,
        category: _selectedCategory,
      );

      final documents = response['documents'] as List<dynamic>? ?? [];

      setState(() {
        _submissions = documents.map((doc) {
          final contestId = doc['contest_id'] as int? ?? 0;
          final likeCount = doc['like_count'] as int? ?? 0;
          final isCanceled = doc['is_canceled'] as int? ?? 1;
          final comments = doc['comments'] as List<dynamic>? ?? [];

          // 좋아요 상태 초기화 (서버에서 받은 is_canceled 값으로 설정)
          // is_canceled == 0 이면 좋아요 누른 상태
          _likeCounts[contestId] = likeCount;
          _likedContests[contestId] = isCanceled == 0;

          // is_voted 값 안전하게 파싱 (int / bool / String 모두 처리)
          dynamic rawIsVoted = doc['is_voted'];
          int isVotedValue;
          if (rawIsVoted is int) {
            isVotedValue = rawIsVoted;
          } else if (rawIsVoted is bool) {
            isVotedValue = rawIsVoted ? 1 : 0;
          } else if (rawIsVoted is String) {
            isVotedValue = int.tryParse(rawIsVoted) ?? 0;
          } else {
            isVotedValue = 0;
          }

          // 디버깅용 로그
          print(
              '📥 [VotingScreen] contest_id=$contestId, raw is_voted=$rawIsVoted, parsed is_voted=$isVotedValue');

          return {
            'id': 'contest_$contestId',
            'contest_id': contestId,
            'title': doc['title'] as String? ?? '',
            'name': doc['name'] as String? ?? '',
            'department': doc['department'] as String? ?? '',
            'job_position': doc['job_position'] as String? ?? '',
            'description':
                doc['summary'] as String? ?? '', // summary를 description으로 사용
            'content': doc['content'] as String? ?? '',
            'votes': doc['votes'] as int? ?? 0,
            'view_count': doc['view_count'] as int? ?? 0, // 조회수 추가
            'like_count': likeCount,
            'comments': comments,
            'is_voted': isVotedValue, // 내가 투표한 사례 여부
          };
        }).toList();

        // 조회수/투표수 필터링 시 클라이언트에서도 정렬
        if (_currentViewType == 'view_count' || _currentViewType == 'votes') {
          _submissions.sort((a, b) {
            if (_currentViewType == 'view_count') {
              final aCount = a['view_count'] as int? ?? 0;
              final bCount = b['view_count'] as int? ?? 0;
              return bCount.compareTo(aCount); // 내림차순
            } else {
              final aVotes = a['votes'] as int? ?? 0;
              final bVotes = b['votes'] as int? ?? 0;
              return bVotes.compareTo(aVotes); // 내림차순
            }
          });
        }

        // 투표 결과 초기화
        _voteResults = {};
        for (var submission in _submissions) {
          final id = submission['id'] as String;
          final votes = submission['votes'] as int;
          _voteResults[id] = votes;
        }

        _isLoading = false;
        _currentPage = 0;
        _resultsCurrentPage = 0; // 페이지네이션 리셋

        // 정렬 후 페이지 컨트롤러 리셋 (다크 테마 포함 모든 테마에서 동작)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _submissions.isNotEmpty &&
              _pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        });
      });

      final shouldFocusContest =
          !_initialHighlightHandled && widget.initialContestId != null;
      if (shouldFocusContest) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusContestById(widget.initialContestId!, animate: true);
        });
      }
    } catch (e) {
      print('❌ [VotingScreen] 목록 조회 실패: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final themeState = ref.read(themeProvider);
        final isDark = themeState.colorScheme.name == 'Dark';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '목록을 불러오는 중 오류가 발생했습니다: $e',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleVote() async {
    final themeState = ref.read(themeProvider);
    final isDark = themeState.colorScheme.name == 'Dark';

    if (_selectedSubmissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '투표할 항목을 선택해주세요.',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    // 선택된 항목의 contest_id 찾기
    final selectedSubmissionList = _submissions
        .where(
          (submission) => submission['id'] == _selectedSubmissionId,
        )
        .toList();

    if (selectedSubmissionList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '선택한 항목을 찾을 수 없습니다.',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    final selectedSubmission = selectedSubmissionList.first;

    final contestId = selectedSubmission['contest_id'] as int? ?? 0;
    if (contestId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '유효하지 않은 공모전 ID입니다.',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    // user_id 가져오기
    final userId = ref.read(userIdProvider);
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '로그인이 필요합니다.',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 투표 API 호출
      final response = await ContestApiService.voteContest(
        contestType: '사내 혁신 아이디어 공모전',
        contestId: contestId,
        userId: userId,
      );

      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.pop(context);
      }

      // error 필드 확인
      if (response.containsKey('error') && response['error'] != null) {
        final errorMessage = response['error'] as String;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '투표 실패: $errorMessage',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
        return;
      }

      // 투표 성공
      setState(() {
        _voteResults[_selectedSubmissionId!] =
            (_voteResults[_selectedSubmissionId!] ?? 0) + 1;
        // 투표 후 선택 상태 초기화
        _selectedSubmissionId = null;
      });

      _loadContestList(viewType: 'votes');
      _loadRemainingVotes(); // 남은 투표 수 갱신

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '투표가 완료되었습니다!',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.pop(context);
      }

      print('❌ [VotingScreen] 투표 실패: $e');

      // 에러 메시지 처리
      String errorMessage = e.toString();
      if (errorMessage
              .contains('duplicate key value violates unique constraint') ||
          errorMessage.contains('ux_vote_detail') ||
          errorMessage.contains('중복 투표는 허용 되지 않습니다')) {
        errorMessage = '중복 투표는 허용 되지 않습니다. 다른 사례에 투표 해주세요.';
      } else if (errorMessage.contains('이미 투표를 모두 완료하셨습니다')) {
        errorMessage = '이미 투표를 모두 완료하셨습니다. 다음 공모전도 참여 부탁드려요😊';
      } else {
        errorMessage = '투표 중 오류가 발생했습니다: $e';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  int _getTotalVotes() {
    return _voteResults.values.fold(0, (sum, votes) => sum + votes);
  }

  void _focusContestById(int contestId, {bool animate = true}) {
    final targetIndex = _submissions
        .indexWhere((submission) => submission['contest_id'] == contestId);
    if (targetIndex == -1) return;

    _initialHighlightHandled = true;

    setState(() {
      _activeDisplay = 'submissions';
      _currentPage = targetIndex;
      _highlightedContestId = contestId;
    });

    if (_pageController.hasClients) {
      if (animate) {
        _pageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.jumpToPage(targetIndex);
      }
    }

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_highlightedContestId == contestId) {
        setState(() {
          _highlightedContestId = null;
        });
      }
    });
  }

  Widget _buildAnimatedCard(int index, bool isDark) {
    final submission = _submissions[index];
    final isSelected = _selectedSubmissionId == submission['id'];
    final int contestId = submission['contest_id'] as int? ?? 0;
    final bool isHighlighted =
        _highlightedContestId != null && contestId == _highlightedContestId;

    final int isVotedValue = submission['is_voted'] as int? ?? 0;
    final bool isVoted = isVotedValue == 1;

    // 디버깅 로그
    print(
        '🎯 [VotingCard #$index] contest_id: $contestId, is_voted: $isVotedValue, isVoted bool: $isVoted, title: ${submission['title']}');

    // 조회수/투표수 필터링 시 순위 계산
    int? rank;
    Color? medalShadowColor;
    if (_currentViewType == 'view_count' || _currentViewType == 'votes') {
      // 정렬된 리스트에서 현재 항목의 순위 찾기
      final sortedList = List<Map<String, dynamic>>.from(_submissions);
      sortedList.sort((a, b) {
        if (_currentViewType == 'view_count') {
          final aCount = a['view_count'] as int? ?? 0;
          final bCount = b['view_count'] as int? ?? 0;
          return bCount.compareTo(aCount); // 내림차순
        } else {
          final aVotes = a['votes'] as int? ?? 0;
          final bVotes = b['votes'] as int? ?? 0;
          return bVotes.compareTo(aVotes); // 내림차순
        }
      });

      final currentId = submission['id'] as String;
      rank = sortedList.indexWhere((item) => item['id'] == currentId) + 1;

      // 1등만 특별 색상 적용
      if (rank == 1) {
        medalShadowColor = isDark
            ? const Color(0xFFFF1493) // 다크 테마: 네온 핑크
            : const Color(0xFF8B00FF); // 라이트 테마: 네온 바이올렛
      }
    }

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double value = 0.0;
        try {
          if (_pageController.position.haveDimensions) {
            value = index.toDouble() - (_pageController.page ?? 0);
          } else {
            // 초기 로딩 시에도 애니메이션 작동하도록
            value = index.toDouble() - _currentPage.toDouble();
          }
        } catch (e) {
          value = index.toDouble() - _currentPage.toDouble();
        }

        // 3D 회전 효과 계산 (부드러운 easing 적용)
        // value 값에 smoothing 적용
        double smoothValue = value.clamp(-1.5, 1.5);

        // Y축 회전 (입체 효과) - 더 부드럽게
        double rotationY = smoothValue * 0.15;

        // 크기 조정 (중앙 카드가 더 크게) - 이징 함수 적용
        double scale = 1.0 - (smoothValue.abs() * 0.08).clamp(0.0, 0.15);
        scale = scale.clamp(0.88, 1.0);

        // 투명도 조정 (중앙 카드가 더 진하게) - 더 부드러운 페이드
        double opacity = 1.0 - (smoothValue.abs() * 0.15);
        opacity = opacity.clamp(0.75, 1.0);

        // Z축 이동 (깊이감) - 더 완만하게
        double translateZ = smoothValue.abs() * -30;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 원근감 설정
            ..rotateY(rotationY) // Y축 회전
            ..scale(scale), // 크기 조정
          child: Opacity(
            opacity: opacity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 20),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 화면 크기에 따른 반응형 카드 너비 및 스케일 계산
                        final screenWidth = MediaQuery.of(context).size.width;
                        double cardWidth;
                        double scaleFactor;
                        if (screenWidth > 1600) {
                          cardWidth = 520;
                          scaleFactor = 1.25;
                        } else if (screenWidth > 1400) {
                          cardWidth = 480;
                          scaleFactor = 1.15;
                        } else if (screenWidth > 1200) {
                          cardWidth = 440;
                          scaleFactor = 1.08;
                        } else if (screenWidth > 1000) {
                          cardWidth = 400;
                          scaleFactor = 1.0;
                        } else {
                          cardWidth = 380;
                          scaleFactor = 1.0;
                        }

                        return ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: cardWidth),
                          child: GestureDetector(
                            onTap: () =>
                                _showDetailModal(context, submission, isDark),
                            child: Container(
                              padding: EdgeInsets.all(24 * scaleFactor),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [
                                          const Color(0xFF40414F),
                                          const Color(0xFF343541),
                                        ]
                                      : [
                                          Colors.white,
                                          const Color(0xFFFAFAFA),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isHighlighted
                                      ? const Color(0xFFFFC857)
                                      : (isSelected
                                          ? const Color(0xFF4A6CF7)
                                          : (isDark
                                              ? Colors.grey[700]!
                                              : Colors.grey[300]!)),
                                  width: isHighlighted
                                      ? 4
                                      : (isSelected ? 3 : 1.5),
                                ),
                                boxShadow: [
                                  // 메달 색상 그림자 (1, 2, 3등) - 최소화
                                  if (medalShadowColor != null)
                                    BoxShadow(
                                      color: medalShadowColor.withValues(
                                          alpha: 0.12),
                                      blurRadius: 12,
                                      offset:
                                          Offset(0, 4 + translateZ.abs() * 0.1),
                                      spreadRadius: 0.5,
                                    ),
                                  // 메인 그림자 - 깊이감
                                  BoxShadow(
                                    color: isSelected
                                        ? const Color(0xFF4A6CF7)
                                            .withValues(alpha: 0.3)
                                        : (medalShadowColor != null
                                            ? medalShadowColor.withValues(
                                                alpha: 0.06)
                                            : Colors.black
                                                .withValues(alpha: 0.15)),
                                    blurRadius: isSelected ? 40 : 15,
                                    offset:
                                        Offset(0, 6 + translateZ.abs() * 0.12),
                                    spreadRadius: isSelected ? 2 : 0,
                                  ),
                                  // 보조 그림자 - 부드러운 확산 (1등일 때는 거의 안보이게)
                                  if (medalShadowColor == null || isSelected)
                                    BoxShadow(
                                      color: isSelected
                                          ? const Color(0xFF4A6CF7)
                                              .withValues(alpha: 0.15)
                                          : Colors.black
                                              .withValues(alpha: 0.08),
                                      blurRadius: isSelected ? 60 : 20,
                                      offset: Offset(
                                          0, 12 + translateZ.abs() * 0.15),
                                      spreadRadius: isSelected ? 5 : 0,
                                    ),
                                  if (isHighlighted)
                                    BoxShadow(
                                      color: const Color(0xFFFFC857)
                                          .withValues(alpha: 0.45),
                                      blurRadius: 50,
                                      offset: const Offset(0, 10),
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isHighlighted)
                                        Container(
                                          margin: EdgeInsets.only(
                                              bottom: 12 * scaleFactor),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12 * scaleFactor,
                                            vertical: 6 * scaleFactor,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF3C4),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: const Color(0xFFFFC857),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.near_me,
                                                size: 14,
                                                color: Color(0xFFCC6B00),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '채팅에서 이동됨',
                                                style: TextStyle(
                                                  color:
                                                      const Color(0xFFCC6B00),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 11 * scaleFactor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      // 투표 완료 배지
                                      if (isVoted)
                                        Container(
                                          margin: EdgeInsets.only(
                                              bottom: 12 * scaleFactor),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12 * scaleFactor,
                                            vertical: 6 * scaleFactor,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFD8B4FE), // 연보라색
                                                Color(0xFFC084FC), // 보라색
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFC084FC)
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '투표완료!',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11 * scaleFactor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      // 선택 표시 & 상세보기 힌트
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (isSelected)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12 * scaleFactor,
                                                vertical: 6 * scaleFactor,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF4A6CF7),
                                                    Color(0xFF6366F1),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        const Color(0xFF4A6CF7)
                                                            .withValues(
                                                                alpha: 0.4),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    size: 14 * scaleFactor,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(
                                                      width: 4 * scaleFactor),
                                                  Text(
                                                    '선택됨',
                                                    style: TextStyle(
                                                      fontSize:
                                                          11 * scaleFactor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            const SizedBox.shrink(),
                                          Container(
                                            padding:
                                                EdgeInsets.all(5 * scaleFactor),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.grey[800]!
                                                      .withValues(alpha: 0.5)
                                                  : Colors.grey[200]!
                                                      .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  size: 11 * scaleFactor,
                                                  color: isDark
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                                SizedBox(
                                                    width: 4 * scaleFactor),
                                                Text(
                                                  '상세보기',
                                                  style: TextStyle(
                                                    fontSize: 9 * scaleFactor,
                                                    color: isDark
                                                        ? Colors.grey[400]
                                                        : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isSelected)
                                        SizedBox(height: 14 * scaleFactor),

                                      // 제목
                                      Text(
                                        submission['title'] as String,
                                        style: TextStyle(
                                          fontSize: 18 * scaleFactor,
                                          fontWeight: FontWeight.bold,
                                          height: 1.3,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 16 * scaleFactor),

                                      // 설명
                                      Text(
                                        'AI 요약',
                                        style: TextStyle(
                                          fontSize: 12 * scaleFactor,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(height: 6 * scaleFactor),
                                      Container(
                                        constraints: BoxConstraints(
                                          maxHeight: scaleFactor >= 1.2
                                              ? 200
                                              : (scaleFactor >= 1.1
                                                  ? 160
                                                  : 130),
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.grey[900]!
                                                  .withValues(alpha: 0.3)
                                              : Colors.grey[50],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.grey[700]!
                                                    .withValues(alpha: 0.5)
                                                : Colors.grey[300]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: SingleChildScrollView(
                                          physics:
                                              const BouncingScrollPhysics(),
                                          padding:
                                              EdgeInsets.all(12 * scaleFactor),
                                          child: Text(
                                            submission['description'] as String,
                                            style: TextStyle(
                                              fontSize: 12 * scaleFactor,
                                              height: 1.5,
                                              color: isDark
                                                  ? Colors.grey[300]
                                                  : Colors.grey[800],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 12 * scaleFactor),

                                      // 선택 버튼
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () {
                                                setState(() {
                                                  // 토글 방식: 이미 선택된 경우 선택 해제
                                                  if (_selectedSubmissionId ==
                                                      submission['id']) {
                                                    _selectedSubmissionId =
                                                        null;
                                                  } else {
                                                    _selectedSubmissionId =
                                                        submission['id']
                                                            as String;
                                                  }
                                                });
                                              },
                                              style: OutlinedButton.styleFrom(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 10 * scaleFactor),
                                                side: BorderSide(
                                                  color: isSelected
                                                      ? const Color(0xFF4A6CF7)
                                                      : (isDark
                                                          ? Colors.grey[700]!
                                                          : Colors.grey[300]!),
                                                  width: isSelected ? 2 : 1.5,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: Text(
                                                isSelected ? '선택됨' : '이 항목 선택',
                                                style: TextStyle(
                                                  fontSize: 14 * scaleFactor,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? const Color(0xFF4A6CF7)
                                                      : (isDark
                                                          ? Colors.white
                                                          : Colors.black),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8 * scaleFactor),
                                          ElevatedButton.icon(
                                            onPressed: () => _showDetailModal(
                                                context, submission, isDark),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF4A6CF7),
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 14 * scaleFactor,
                                                vertical: 10 * scaleFactor,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              elevation: 0,
                                            ),
                                            icon: Icon(Icons.visibility,
                                                size: 14 * scaleFactor),
                                            label: Text(
                                              '상세보기',
                                              style: TextStyle(
                                                fontSize: 13 * scaleFactor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16 * scaleFactor),

                                      // 후기(댓글) 미리보기 영역
                                      _buildCommentPreview(
                                        submission['contest_id'] as int? ?? 0,
                                        isDark,
                                        (submission['comments']
                                                    as List<dynamic>? ??
                                                [])
                                            .whereType<Map<String, dynamic>>()
                                            .toList(),
                                        scaleFactor: scaleFactor,
                                      ),
                                      SizedBox(height: 16 * scaleFactor),

                                      // 조회수 및 투표수 표시 (카드 최하단)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12 * scaleFactor,
                                          vertical: 6 * scaleFactor,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.grey[800]!
                                                  .withValues(alpha: 0.5)
                                              : Colors.grey[100]!
                                                  .withValues(alpha: 0.8),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            // 조회수
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.visibility,
                                                  size: 14 * scaleFactor,
                                                  color: isDark
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                                SizedBox(
                                                    width: 6 * scaleFactor),
                                                Text(
                                                  '조회 ${submission['view_count'] as int? ?? 0}',
                                                  style: TextStyle(
                                                    fontSize: 12 * scaleFactor,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? Colors.grey[300]
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // 구분선
                                            Container(
                                              width: 1,
                                              height: 16 * scaleFactor,
                                              color: isDark
                                                  ? Colors.grey[700]
                                                  : Colors.grey[300],
                                            ),
                                            // 투표수
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.how_to_vote,
                                                  size: 14 * scaleFactor,
                                                  color: isDark
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                                SizedBox(
                                                    width: 6 * scaleFactor),
                                                Text(
                                                  '투표 ${submission['votes'] as int? ?? 0}',
                                                  style: TextStyle(
                                                    fontSize: 12 * scaleFactor,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? Colors.grey[300]
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // 구분선
                                            Container(
                                              width: 1,
                                              height: 16 * scaleFactor,
                                              color: isDark
                                                  ? Colors.grey[700]
                                                  : Colors.grey[300],
                                            ),
                                            // 도움이 됐어요 버튼
                                            _buildLikeButton(
                                              submission['contest_id']
                                                      as int? ??
                                                  0,
                                              submission['like_count']
                                                      as int? ??
                                                  0,
                                              isDark,
                                              scaleFactor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ], // Column children 닫기
                                  ), // Column 닫기
                                  // 왼쪽 상단 순서 번호
                                  Positioned(
                                    top: -5,
                                    left: -5,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.9)
                                            : Colors.black
                                                .withValues(alpha: 0.9),
                                        shadows: [
                                          Shadow(
                                            offset: const Offset(1, 1),
                                            blurRadius: 3,
                                            color: isDark
                                                ? Colors.black
                                                    .withValues(alpha: 0.8)
                                                : Colors.white
                                                    .withValues(alpha: 0.8),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ], // Stack children 닫기
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ); // Transform 닫기 및 return 문 완료
      },
    );
  }

  void _showDetailModal(
      BuildContext context, Map<String, dynamic> submission, bool isDark) {
    // 상세보기 클릭 시 조회수 증가
    final contestId = submission['contest_id'] as int?;
    if (contestId != null) {
      ContestApiService.incrementViewCount(contestId);
    }

    showDialog(
      context: context,
      builder: (context) => ContestDetailDialog(
        contestId: contestId ?? 0,
        initialSubmission: submission,
        isDark: isDark,
      ),
    );
  }

  Future<bool> _handleBackNavigation() async {
    if (_activeDisplay == 'results') {
      setState(() {
        _activeDisplay = 'submissions';
      });
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.colorScheme.name == 'Dark';

    return WillPopScope(
      onWillPop: _handleBackNavigation,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF343541) : const Color(0xFFF7F7F8),
        body: Column(
          children: [
            // 상단 헤더 영역 (사이드바 상단 + 메인 헤더)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 사이드바 상단 - 뒤로가기 버튼
                  Container(
                    width: 240,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2B32)
                          : const Color(0xFFFFFFFF),
                      border: Border(
                        right: BorderSide(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          onPressed: () async {
                            final shouldPop = await _handleBackNavigation();
                            if (shouldPop && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          tooltip: '뒤로가기',
                        ),
                      ),
                    ),
                  ),
                  // 메인 헤더 (타이틀 + 안내문구)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(
                          left: 24, right: 24, top: 16, bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF343541)
                            : const Color(0xFFF7F7F8),
                        border: Border(
                          bottom: BorderSide(
                            color:
                                isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '사내AI 공모전 투표',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentViewType == 'random'
                                        ? '지금까지의 모든 채팅 이력을 기반으로 한 개인별 AI 추천, 혹은 직무별 AI 추천을 제공합니다.'
                                        : '아래 제출된 사례 중 가장 인상적인 사례에 투표해주세요.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '총 ${_getTotalVotes()}표',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // 우측 상단 - 버튼들
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Row(
                              children: [
                                // 내 제출 현황 버튼
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF4A6CF7),
                                        Color(0xFF6366F1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4A6CF7)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const MySubmissionsScreen(),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.assignment_outlined,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              '내 제출 현황',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 남은 투표 수
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF4A6CF7),
                                        const Color(0xFF6366F1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4A6CF7)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.how_to_vote,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '남은 투표: $_remainingVotes표',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 하단 콘텐츠 영역 (사이드바 + 메인 콘텐츠)
            Expanded(
              child: Row(
                children: [
                  // 사이드바 하단 부분
                  _buildSidebar(isDark),

                  // 메인 콘텐츠
                  Expanded(
                    child: Column(
                      children: [
                        // 투표 카드 섹션 (좌우 스크롤)
                        Expanded(
                          child: _isLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF4A6CF7),
                                    ),
                                  ),
                                )
                              : (_activeDisplay == 'results')
                                  ? _buildResultsView(isDark)
                                  : _buildVotingCards(isDark),
                        ),

                        // 하단 버튼 (투표 현황 화면이 아닐 때만 표시)
                        if (_activeDisplay != 'results')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF343541)
                                  : const Color(0xFFF7F7F8),
                              border: Border(
                                top: BorderSide(
                                  color: isDark
                                      ? Colors.grey[800]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleVote,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A6CF7),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _selectedSubmissionId == null
                                      ? '투표할 항목을 선택해주세요'
                                      : '투표하기',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
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

  /// 사이드바 위젯 (하단 부분만)
  Widget _buildSidebar(bool isDark) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2B32) : const Color(0xFFFFFFFF),
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 스크롤 가능한 콘텐츠 영역
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 보기 방식 섹션
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, top: 8, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '보기 방식',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildSidebarButton(
                          label: '투표현황',
                          icon: Icons.how_to_vote_outlined,
                          isSelected: _activeDisplay == 'results',
                          onPressed: () {
                            if (_activeDisplay != 'results') {
                              setState(() {
                                _activeDisplay = 'results';
                              });
                            }
                            if (_currentViewType != 'votes') {
                              _loadContestList(viewType: 'votes');
                            }
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 4),
                        _buildSidebarButton(
                          label: '조회수순',
                          icon: Icons.visibility_outlined,
                          isSelected: _activeDisplay == 'submissions' &&
                              _currentViewType == 'view_count',
                          onPressed: () {
                            if (_activeDisplay != 'submissions' ||
                                _currentViewType != 'view_count') {
                              setState(() {
                                _activeDisplay = 'submissions';
                              });
                              if (_currentViewType != 'view_count') {
                                _loadContestList(viewType: 'view_count');
                              }
                            }
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 4),
                        _buildSidebarButton(
                          label: '투표수순',
                          icon: Icons.thumb_up_outlined,
                          isSelected: _activeDisplay == 'submissions' &&
                              _currentViewType == 'votes',
                          onPressed: () {
                            if (_activeDisplay != 'submissions' ||
                                _currentViewType != 'votes') {
                              setState(() {
                                _activeDisplay = 'submissions';
                              });
                              if (_currentViewType != 'votes') {
                                _loadContestList(viewType: 'votes');
                              }
                            }
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 4),
                        _buildSidebarButton(
                          label: 'AI추천순',
                          icon: Icons.auto_awesome,
                          isSelected: _activeDisplay == 'submissions' &&
                              _currentViewType == 'ai',
                          onPressed: () {
                            setState(() {
                              _activeDisplay = 'submissions';
                            });
                            if (_currentViewType != 'ai') {
                              _loadContestList(viewType: 'ai');
                            }
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // 구분선
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                  ),

                  // 카테고리 필터 섹션
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, top: 8, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '카테고리별 사례',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildSidebarButton(
                          label: '전체',
                          icon: Icons.apps,
                          isSelected: _selectedCategory.isEmpty &&
                              _currentViewType != 'ai',
                          onPressed: () {
                            // AI 추천순일 때 전체를 누르면 전체만 선택 (AI 추천순 해제)
                            if (_currentViewType == 'ai') {
                              setState(() {
                                _selectedCategory = '';
                              });
                              _loadContestList(viewType: 'votes');
                            } else if (_selectedCategory.isNotEmpty ||
                                _currentViewType != 'votes') {
                              setState(() {
                                _selectedCategory = '';
                              });
                              _loadContestList(viewType: 'votes');
                            }
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 4),
                        ..._categories.map((category) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _buildSidebarButton(
                                label: category,
                                icon: _getCategoryIcon(category),
                                isSelected: _selectedCategory == category,
                                onPressed: () {
                                  if (_selectedCategory != category ||
                                      _currentViewType != 'category') {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                    _loadContestList(viewType: 'category');
                                  }
                                },
                                isDark: isDark,
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '총 ${_submissions.length}개 사례',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 사이드바 버튼 위젯
  Widget _buildSidebarButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? const Color(0xFF4A6CF7).withValues(alpha: 0.2)
                    : const Color(0xFF4A6CF7).withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: const Color(0xFF4A6CF7).withValues(alpha: 0.5),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? const Color(0xFF4A6CF7)
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? const Color(0xFF4A6CF7)
                        : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 카테고리별 아이콘 반환
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '영업·마케팅 지원':
        return Icons.campaign_outlined;
      case '데이터 분석·인사이트 분석':
        return Icons.analytics_outlined;
      case 'SAP 개발/운영 효율화':
        return Icons.business;
      case '개발/운영 효율화':
        return Icons.code;
      case '업무 자동화':
        return Icons.auto_fix_high;
      case '교육·지식 관리':
        return Icons.school_outlined;
      case '창의/아이디어 부문':
        return Icons.lightbulb_outline;
      default:
        return Icons.folder_outlined;
    }
  }

  // 점 인디케이터 빌더 (항목 수에 관계없이 항상 점으로 표시)
  Widget _buildDotIndicator(bool isDark) {
    final totalPages = _submissions.length;

    // 표시할 최대 점 개수
    const int maxVisibleDots = 15;

    // 표시할 점 범위 계산
    int startIndex;
    int endIndex;

    if (totalPages <= maxVisibleDots) {
      // 전체 표시
      startIndex = 0;
      endIndex = totalPages;
    } else {
      // 현재 페이지 중심으로 표시
      final halfVisible = maxVisibleDots ~/ 2;
      startIndex =
          (_currentPage - halfVisible).clamp(0, totalPages - maxVisibleDots);
      endIndex = (startIndex + maxVisibleDots).clamp(0, totalPages);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 왼쪽: 현재 페이지 번호
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          child: Text(
            '${_currentPage + 1}',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // 앞쪽 생략 표시
        if (startIndex > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              '···',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // 점 인디케이터들
        ...List.generate(
          endIndex - startIndex,
          (i) {
            final index = startIndex + i;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_currentPage != index && !_isScrolling) {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: _currentPage == index
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF4A6CF7),
                                Color(0xFF6366F1),
                              ],
                            )
                          : null,
                      color: _currentPage == index
                          ? null
                          : (isDark ? Colors.grey[700] : Colors.grey[400]),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: _currentPage == index
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4A6CF7)
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // 뒤쪽 생략 표시
        if (endIndex < totalPages)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              '···',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // 오른쪽: 전체 페이지 수
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: Text(
            '$totalPages',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVotingCards(bool isDark) {
    return Column(
      children: [
        // 페이지 인디케이터 (항상 점으로 표시, 많은 경우 현재 페이지 주변만 표시)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _buildDotIndicator(isDark),
        ),

        // 좌우 스크롤 카드
        Expanded(
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.horizontal,
                pageSnapping: true,
                // 더 부드러운 스크롤 물리 효과
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                onPageChanged: (index) {
                  if (mounted) {
                    setState(() {
                      _currentPage = index;
                    });
                  }
                },
                itemCount: _submissions.length,
                itemBuilder: (context, index) {
                  return _buildAnimatedCard(index, isDark);
                },
              ),

              // 왼쪽 화살표 네비게이션
              if (_currentPage > 0)
                Positioned(
                  left: 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          if (_currentPage > 0) {
                            _pageController.animateToPage(
                              _currentPage - 1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4A6CF7).withValues(alpha: 0.9),
                                const Color(0xFF6366F1).withValues(alpha: 0.85),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4A6CF7)
                                    .withValues(alpha: 0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 오른쪽 화살표 네비게이션
              if (_currentPage < _submissions.length - 1)
                Positioned(
                  right: 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          if (_currentPage < _submissions.length - 1) {
                            _pageController.animateToPage(
                              _currentPage + 1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4A6CF7).withValues(alpha: 0.9),
                                const Color(0xFF6366F1).withValues(alpha: 0.85),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4A6CF7)
                                    .withValues(alpha: 0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 댓글 미리보기 위젯 (카드 하단에 표시)
  Widget _buildCommentPreview(
    int contestId,
    bool isDark,
    List<Map<String, dynamic>> comments, {
    double scaleFactor = 1.0,
  }) {
    return GestureDetector(
      onTap: () => _showCommentsModal(context, contestId, isDark),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[800]!.withValues(alpha: 0.3)
                : Colors.grey[100]!.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 12 * scaleFactor, vertical: 10 * scaleFactor),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 14 * scaleFactor,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        SizedBox(width: 6 * scaleFactor),
                        Text(
                          '사용 후기',
                          style: TextStyle(
                            fontSize: 12 * scaleFactor,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        if (comments.isNotEmpty) ...[
                          SizedBox(width: 4 * scaleFactor),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6 * scaleFactor,
                              vertical: 2 * scaleFactor,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A6CF7)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${comments.length}',
                              style: TextStyle(
                                fontSize: 10 * scaleFactor,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4A6CF7),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // 전체보기 버튼
                    GestureDetector(
                      onTap: () =>
                          _showCommentsModal(context, contestId, isDark),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '전체보기',
                              style: TextStyle(
                                fontSize: 11 * scaleFactor,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4A6CF7),
                              ),
                            ),
                            SizedBox(width: 2 * scaleFactor),
                            Icon(
                              Icons.open_in_new,
                              size: 12 * scaleFactor,
                              color: const Color(0xFF4A6CF7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 댓글 미리보기 (최대 2개, 페이드아웃 효과)
              if (comments.isEmpty)
                Padding(
                  padding: EdgeInsets.only(
                      left: 12 * scaleFactor,
                      right: 12 * scaleFactor,
                      bottom: 10 * scaleFactor),
                  child: Text(
                    '아직 작성된 후기가 없습니다.',
                    style: TextStyle(
                      fontSize: 11 * scaleFactor,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                          left: 12 * scaleFactor,
                          right: 12 * scaleFactor,
                          bottom: 10 * scaleFactor),
                      child: Column(
                        children: comments.take(2).map((comment) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8 * scaleFactor),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 작성자 정보
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6 * scaleFactor,
                                    vertical: 2 * scaleFactor,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[700]!
                                            .withValues(alpha: 0.5)
                                        : Colors.grey[200]!
                                            .withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${comment['department'] ?? ''} ${comment['name'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 10 * scaleFactor,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8 * scaleFactor),
                                // 댓글 내용
                                Expanded(
                                  child: Text(
                                    comment['comment'] as String? ?? '',
                                    style: TextStyle(
                                      fontSize: 12 * scaleFactor,
                                      height: 1.4,
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // 페이드아웃 효과 (댓글이 2개 이상일 때)
                    if (comments.length > 1)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 25 * scaleFactor,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (isDark ? Colors.grey[800]! : Colors.grey[100]!)
                                    .withValues(alpha: 0.0),
                                isDark
                                    ? Colors.grey[800]!.withValues(alpha: 0.8)
                                    : Colors.grey[100]!.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 도움이 됐어요 버튼 빌더
  Widget _buildLikeButton(
      int contestId, int initialLikeCount, bool isDark, double scaleFactor) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        final isLiked = _likedContests[contestId] ?? false;
        final likeCount = _likeCounts[contestId] ?? initialLikeCount;

        return GestureDetector(
          onTap: () async {
            if (contestId == 0) return; // 유효하지 않은 경우 무시

            final userId = ref.read(userIdProvider);
            if (userId == null || userId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('로그인이 필요합니다.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            try {
              print(
                  '👍 [VotingScreen] 좋아요 버튼 클릭 - contestId: $contestId, userId: $userId');

              final response = await ContestApiService.likeContest(
                contestId: contestId,
                userId: userId,
              );

              print('👍 [VotingScreen] API 응답 받음: $response');

              final newCount = response['like_count'] as int? ?? 0;
              final isCanceled = response['is_canceled'] as int? ?? 1;
              final isNowLiked = isCanceled == 0; // 0이면 좋아요 상태

              print('👍 [VotingScreen] 파싱 결과:');
              print('  - newCount: $newCount');
              print('  - isCanceled: $isCanceled');
              print('  - isNowLiked: $isNowLiked');
              print('  - 이전 좋아요 상태: ${_likedContests[contestId]}');
              print('  - 이전 좋아요 수: ${_likeCounts[contestId]}');

              // 상태 업데이트 (StatefulBuilder 내부에서 먼저 업데이트)
              _likedContests[contestId] = isNowLiked;
              _likeCounts[contestId] = newCount;

              print('👍 [VotingScreen] 상태 업데이트 완료:');
              print('  - 새 좋아요 상태: ${_likedContests[contestId]}');
              print('  - 새 좋아요 수: ${_likeCounts[contestId]}');

              // StatefulBuilder rebuild 트리거
              setLocalState(() {});

              // 좋아요를 누른 경우에만 화려한 이펙트 표시
              if (isNowLiked && mounted) {
                _showLikeEffect(context);
              }

              // 좋아요 누른 경우에만 스낵바 표시
              if (isNowLiked && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '해당 사례를 실제 본인 업무에 적용한 후기를 "사용후기" 댓글에 작성해주시면, 추첨을 통해 상품을 드립니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    backgroundColor:
                        isDark ? const Color(0xFF40414F) : Colors.grey[200],
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('좋아요 처리 중 오류가 발생했습니다: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: Tooltip(
            message: isLiked ? '좋아요 취소' : '도움이 됐어요!',
            textStyle: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : Colors.white,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF4A6CF7) : const Color(0xFF4A6CF7),
              borderRadius: BorderRadius.circular(6),
            ),
            waitDuration: const Duration(milliseconds: 100),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LikeIconAnimation(
                    isLiked: isLiked,
                    scaleFactor: scaleFactor,
                    isDark: isDark,
                  ),
                  SizedBox(width: 4 * scaleFactor),
                  Text(
                    '$likeCount',
                    style: TextStyle(
                      fontSize: 13 * scaleFactor,
                      fontWeight: FontWeight.w600,
                      color: isLiked
                          ? const Color(0xFF4A6CF7)
                          : (isDark ? Colors.grey[300] : Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 좋아요 이펙트 표시
  void _showLikeEffect(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 800),
      pageBuilder: (context, animation, secondaryAnimation) {
        return IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value < 0.5 ? value * 2 : (1 - value) * 2,
                  child: Transform.scale(
                    scale: 0.5 + value * 1.5,
                    child: const Icon(
                      Icons.thumb_up,
                      size: 80,
                      color: Color(0xFF4A6CF7),
                    ),
                  ),
                );
              },
              onEnd: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  /// 댓글 전체보기 모달
  void _showCommentsModal(
      BuildContext context, int contestId, bool isDark) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _CommentsDialog(
        contestId: contestId,
        isDark: isDark,
      ),
    );

    // 댓글이 추가/삭제되었으면 해당 contestId의 캐시를 갱신
    if (result == true && mounted) {
      await _refreshCommentsForContest(contestId);
    }
  }

  /// 단일 공모전의 댓글을 서버에서 다시 받아와 카드 미리보기 데이터 갱신
  Future<void> _refreshCommentsForContest(int contestId) async {
    try {
      final comments = await ContestApiService.getComments(contestId);
      if (!mounted) return;
      setState(() {
        final index = _submissions
            .indexWhere((submission) => submission['contest_id'] == contestId);
        if (index != -1) {
          _submissions[index]['comments'] = comments;
        }
      });
    } catch (e) {
      print('댓글 갱신 실패 (contestId: $contestId): $e');
    }
  }

  Widget _buildResultsView(bool isDark) {
    // 페이지네이션 계산
    final totalPages = (_submissions.length / _resultsPerPage).ceil();
    final startIndex = _resultsCurrentPage * _resultsPerPage;
    final endIndex =
        (startIndex + _resultsPerPage).clamp(0, _submissions.length);
    final currentPageSubmissions = _submissions.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4A6CF7),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bar_chart,
                        color: Color(0xFF4A6CF7),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '현재 투표 현황',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '실시간 투표 현황을 확인할 수 있습니다.',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 투표 결과 목록 (페이지네이션 적용)
                ...currentPageSubmissions.map((submission) => _buildResultCard(
                      context,
                      submission,
                      isDark,
                      _voteResults[submission['id']] ?? 0,
                      _getTotalVotes(),
                    )),
              ],
            ),
          ),
        ),

        // 페이지네이션 컨트롤
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF343541) : const Color(0xFFF7F7F8),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 이전 페이지 버튼
                IconButton(
                  onPressed: _resultsCurrentPage > 0
                      ? () {
                          setState(() {
                            _resultsCurrentPage--;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  color: _resultsCurrentPage > 0
                      ? (isDark ? Colors.white : Colors.black)
                      : Colors.grey,
                ),
                const SizedBox(width: 16),

                // 페이지 번호 표시
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4A6CF7).withValues(alpha: 0.15),
                        const Color(0xFF6366F1).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4A6CF7).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '${_resultsCurrentPage + 1} / $totalPages',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF4A6CF7),
                    ),
                  ),
                ),

                const SizedBox(width: 16),
                // 다음 페이지 버튼
                IconButton(
                  onPressed: _resultsCurrentPage < totalPages - 1
                      ? () {
                          setState(() {
                            _resultsCurrentPage++;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  color: _resultsCurrentPage < totalPages - 1
                      ? (isDark ? Colors.white : Colors.black)
                      : Colors.grey,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    Map<String, dynamic> submission,
    bool isDark,
    int votes,
    int totalVotes,
  ) {
    final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0.0;

    final int isVotedValue = submission['is_voted'] as int? ?? 0;
    final bool isVoted = isVotedValue == 1;

    // 디버깅 로그
    print(
        '🎯 [ResultCard] contest_id: ${submission['contest_id']}, is_voted: $isVotedValue, isVoted bool: $isVoted, title: ${submission['title']}');

    // 조회수/투표수 필터링 시 순위 계산
    int? rank;
    Color? medalShadowColor;
    Color? trophyColor;
    IconData? trophyIcon;

    if (_currentViewType == 'view_count' || _currentViewType == 'votes') {
      // 정렬된 리스트에서 현재 항목의 순위 찾기
      final sortedList = List<Map<String, dynamic>>.from(_submissions);
      sortedList.sort((a, b) {
        if (_currentViewType == 'view_count') {
          final aCount = a['view_count'] as int? ?? 0;
          final bCount = b['view_count'] as int? ?? 0;
          return bCount.compareTo(aCount); // 내림차순
        } else {
          final aVotes = a['votes'] as int? ?? 0;
          final bVotes = b['votes'] as int? ?? 0;
          return bVotes.compareTo(aVotes); // 내림차순
        }
      });

      final currentId = submission['id'] as String;
      rank = sortedList.indexWhere((item) => item['id'] == currentId) + 1;

      // 1, 2, 3등 트로피 색상 및 그림자 설정
      if (rank == 1) {
        trophyColor = const Color(0xFFF59E0B); // 금색
        trophyIcon = Icons.emoji_events_rounded;
        medalShadowColor = isDark
            ? const Color(0xFFFF1493) // 다크 테마: 네온 핑크
            : const Color(0xFF8B00FF); // 라이트 테마: 네온 바이올렛
      } else if (rank == 2) {
        trophyColor = const Color(0xFFC0C0C0); // 은색
        trophyIcon = Icons.emoji_events_rounded;
        medalShadowColor = isDark
            ? const Color(0xFF00CED1) // 다크 테마: 다크 터쿼이즈
            : const Color(0xFF9370DB); // 라이트 테마: 미디엄 퍼플
      } else if (rank == 3) {
        trophyColor = const Color(0xFFCD7F32); // 동색
        trophyIcon = Icons.emoji_events_rounded;
        medalShadowColor = isDark
            ? const Color(0xFFFF6347) // 다크 테마: 토마토
            : const Color(0xFFFF8C00); // 라이트 테마: 다크 오렌지
      }
    }

    final isSelected = _selectedSubmissionId == submission['id'];

    return GestureDetector(
      onTap: () {
        setState(() {
          // 토글 방식: 이미 선택된 경우 선택 해제
          if (_selectedSubmissionId == submission['id']) {
            _selectedSubmissionId = null;
          } else {
            _selectedSubmissionId = submission['id'] as String;
          }
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF40414F) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4A6CF7)
                  : (trophyColor ??
                      (isDark ? Colors.grey[700]! : Colors.grey[300]!)),
              width: isSelected ? 3 : (trophyColor != null ? 2 : 1),
            ),
            boxShadow: [
              // 선택된 항목 그림자
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF4A6CF7).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
              // 메달 색상 그림자 (1, 2, 3등)
              if (medalShadowColor != null)
                BoxShadow(
                  color: medalShadowColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                  spreadRadius: 2,
                ),
              // 기본 그림자
              BoxShadow(
                color: medalShadowColor != null
                    ? medalShadowColor.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.05),
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
                  if (trophyIcon != null && trophyColor != null) ...[
                    Icon(
                      trophyIcon,
                      color: trophyColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (isVoted) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFD8B4FE), // 연보라색
                            Color(0xFFC084FC), // 보라색
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFC084FC).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '투표완료!',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (isSelected) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4A6CF7),
                            Color(0xFF6366F1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '선택됨',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      submission['title'] as String,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 진행 바와 투표수를 한 줄에 배치
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 투표수 표시
                        Text(
                          '$votes표 (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // 진행 바
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 6,
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              trophyColor ?? const Color(0xFF4A6CF7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 상세보기 버튼 (콤팩트)
                  TextButton.icon(
                    onPressed: () =>
                        _showDetailModal(context, submission, isDark),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4A6CF7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.visibility, size: 14),
                    label: const Text(
                      '상세',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 공모전 상세 정보 다이얼로그
class ContestDetailDialog extends StatefulWidget {
  final int contestId;
  final Map<String, dynamic>? initialSubmission;
  final bool isDark;

  const ContestDetailDialog({
    super.key,
    required this.contestId,
    this.initialSubmission,
    required this.isDark,
  });

  @override
  State<ContestDetailDialog> createState() => _ContestDetailDialogState();
}

class _ContestDetailDialogState extends State<ContestDetailDialog> {
  bool _isLoading = true;
  Map<String, dynamic>? _detailData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (widget.contestId == 0) {
      setState(() {
        _isLoading = false;
        _detailData = widget.initialSubmission;
      });
      return;
    }

    try {
      final data = await ContestApiService.getContestDetail(widget.contestId);
      setState(() {
        _detailData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ [VotingScreen] 상세 조회 실패: $e');
      setState(() {
        _errorMessage = '상세 정보를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
        // 오류 발생 시 초기 데이터 사용
        _detailData = widget.initialSubmission;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
        child: _isLoading
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: const Color(0xFF4A6CF7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '상세 정보를 불러오는 중...',
                        style: TextStyle(
                          color: widget.isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _detailData == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        _errorMessage ?? '데이터를 불러올 수 없습니다.',
                        style: TextStyle(
                          color: widget.isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 헤더
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _detailData!['title'] as String? ??
                                    widget.initialSubmission?['title']
                                        as String? ??
                                    '',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // AI 활용 사례 정보
                        // 1. 사용한 AI TOOL
                        if (_detailData!['tool_name'] != null &&
                            (_detailData!['tool_name'] as String)
                                .trim()
                                .isNotEmpty)
                          _buildDetailSection(
                            '1. 사용한 AI TOOL',
                            _detailData!['tool_name'] as String? ?? '',
                            Icons.psychology,
                            widget.isDark,
                          ),
                        if (_detailData!['tool_name'] != null &&
                            (_detailData!['tool_name'] as String)
                                .trim()
                                .isNotEmpty)
                          const SizedBox(height: 24),

                        // 2. 어떤 업무에 적용 했나요?
                        if (_detailData!['work_scope'] != null &&
                            (_detailData!['work_scope'] as String)
                                .trim()
                                .isNotEmpty)
                          _buildDetailSection(
                            '2. 어떤 업무에 적용 했나요?',
                            _detailData!['work_scope'] as String? ?? '',
                            Icons.work_outline,
                            widget.isDark,
                          ),
                        if (_detailData!['work_scope'] != null &&
                            (_detailData!['work_scope'] as String)
                                .trim()
                                .isNotEmpty)
                          const SizedBox(height: 24),

                        // 3. 어떤 방식으로 사용 했나요?
                        if (_detailData!['work_method'] != null &&
                            (_detailData!['work_method'] as String)
                                .trim()
                                .isNotEmpty)
                          _buildDetailSection(
                            '3. 어떤 방식으로 사용 했나요?',
                            _detailData!['work_method'] as String? ?? '',
                            Icons.settings,
                            widget.isDark,
                          ),
                        if (_detailData!['work_method'] != null &&
                            (_detailData!['work_method'] as String)
                                .trim()
                                .isNotEmpty)
                          const SizedBox(height: 24),

                        // 4. Before & After
                        if (_detailData!['before_after'] != null &&
                            (_detailData!['before_after'] as String)
                                .trim()
                                .isNotEmpty)
                          _buildDetailSection(
                            '4. Before & After',
                            _detailData!['before_after'] as String? ?? '',
                            Icons.compare_arrows,
                            widget.isDark,
                          ),
                        if (_detailData!['before_after'] != null &&
                            (_detailData!['before_after'] as String)
                                .trim()
                                .isNotEmpty)
                          const SizedBox(height: 24),

                        // 첨부 파일
                        if (_detailData!['attachment_urls'] != null &&
                            (_detailData!['attachment_urls'] as List)
                                .isNotEmpty) ...[
                          _buildAttachmentsSection(
                            _detailData!['attachment_urls'] as List,
                            widget.isDark,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // 투표 수
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF10A37F).withValues(alpha: 0.1),
                                const Color(0xFF10A37F).withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF10A37F)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.how_to_vote,
                                color: const Color(0xFF10A37F),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '투표수',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '${_detailData!['votes'] as int? ?? 0}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: widget.isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 배경 클릭 시 닫기
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
              ),
            ),
            // 이미지
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                        color: const Color(0xFF4A6CF7),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '이미지를 불러올 수 없습니다',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // 닫기 버튼
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
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

  Widget _buildAttachmentsSection(List attachments, bool isDark) {
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
                  onTap: () => _showImageDialog(context, url, isDark),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
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
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                color: const Color(0xFF4A6CF7),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildAttachmentFallback(isDark);
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }
            }

            return _buildAttachmentFallback(isDark);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAttachmentFallback(bool isDark) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
        color: isDark ? Colors.grey[800] : Colors.grey[200],
      ),
      child: Icon(
        Icons.broken_image,
        color: isDark ? Colors.grey[600] : Colors.grey[500],
      ),
    );
  }

  Widget _buildDetailSection(
      String title, String content, IconData icon, bool isDark) {
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[800]!.withValues(alpha: 0.5)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.grey[700]!.withValues(alpha: 0.3)
                  : Colors.grey[200]!,
            ),
          ),
          child: Consumer(
            builder: (context, ref, child) {
              final themeState = ref.watch(themeProvider);
              final themeColors = themeState.colorScheme.name == 'Dark'
                  ? AppColorSchemes.codingDarkScheme
                  : AppColorSchemes.lightScheme;

              return GptMarkdownRenderer.renderBasicMarkdown(
                content,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
                themeColors: themeColors,
                role: 1,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 댓글 전체보기 다이얼로그
class _CommentsDialog extends ConsumerStatefulWidget {
  final int contestId;
  final bool isDark;

  const _CommentsDialog({
    required this.contestId,
    required this.isDark,
  });

  @override
  ConsumerState<_CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends ConsumerState<_CommentsDialog> {
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasChanges = false; // 댓글 변경 여부 추적

  // 댓글 작성 폼 컨트롤러
  final _contentController = TextEditingController();

  // 첨부된 이미지 파일들 (파일명과 바이트 데이터를 함께 저장)
  List<Map<String, dynamic>> _attachedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comments = await ContestApiService.getComments(widget.contestId);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      print('댓글 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    // 입력 검증
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '후기 내용을 입력해주세요.',
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          backgroundColor: widget.isDark ? Colors.grey[800] : Colors.grey[300],
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    final userId = ref.read(userIdProvider);
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '로그인이 필요합니다.',
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          backgroundColor: widget.isDark ? Colors.grey[800] : Colors.grey[300],
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 파일명과 바이트 데이터를 분리하여 전달
      final fileBytes =
          _attachedFiles.map((file) => file['bytes'] as Uint8List).toList();
      final fileNames =
          _attachedFiles.map((file) => file['name'] as String).toList();

      await ContestApiService.addComment(
        contestId: widget.contestId,
        userId: userId,
        comment: _contentController.text.trim(),
        files: fileBytes.isNotEmpty ? fileBytes : null,
        fileNames: fileNames.isNotEmpty ? fileNames : null,
      );

      // 입력 필드 초기화
      _contentController.clear();
      _attachedFiles.clear();

      // 댓글 목록 새로고침
      await _loadComments();

      // 변경 플래그 설정
      _hasChanges = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '후기가 등록되었습니다.',
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
              ),
            ),
            backgroundColor:
                widget.isDark ? Colors.grey[800] : Colors.grey[300],
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      print('댓글 작성 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '후기 등록에 실패했습니다: $e',
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
              ),
            ),
            backgroundColor:
                widget.isDark ? Colors.grey[800] : Colors.grey[300],
            duration: const Duration(milliseconds: 1500),
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

  /// 이미지 파일 선택
  Future<void> _pickImages() async {
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
              // 파일명과 바이트 데이터를 함께 저장
              final fileName = file.name;
              _attachedFiles.add({
                'name': fileName.isNotEmpty
                    ? fileName
                    : 'image_${_attachedFiles.length}.jpg',
                'bytes': fileBytes,
              });
            }
          }
        });
      }
    } catch (e) {
      print('이미지 선택 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '이미지 선택에 실패했습니다: $e',
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
              ),
            ),
            backgroundColor:
                widget.isDark ? Colors.grey[800] : Colors.grey[300],
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  /// 첨부된 이미지 제거
  void _removeAttachedFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _hasChanges);
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.5,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
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
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                ),
                child: Row(
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
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: Color(0xFF4A6CF7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '사용 후기',
                        style: TextStyle(
                          fontSize: 20,
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
                      onPressed: () => Navigator.pop(context, _hasChanges),
                    ),
                  ],
                ),
              ),

              // 댓글 목록
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFF4A6CF7),
                        ),
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 48,
                                  color: widget.isDark
                                      ? Colors.grey[600]
                                      : Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '아직 작성된 후기가 없습니다.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: widget.isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '이 사례를 사용해보셨다면 후기를 남겨주세요!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.isDark
                                        ? Colors.grey[600]
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              return _buildCommentItem(comment);
                            },
                          ),
              ),

              // 댓글 작성 폼
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.grey[800]!.withValues(alpha: 0.5)
                      : Colors.grey[100],
                  border: Border(
                    top: BorderSide(
                      color:
                          widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '후기 작성',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 파일 첨부 버튼
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickImages,
                          icon: Icon(
                            Icons.image,
                            size: 18,
                            color: const Color(0xFF4A6CF7),
                          ),
                          label: Text(
                            '이미지 첨부',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF4A6CF7),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            side: BorderSide(
                              color: const Color(0xFF4A6CF7),
                            ),
                          ),
                        ),
                        if (_attachedFiles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              '${_attachedFiles.length}개 선택됨',
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),

                    // 첨부된 이미지 미리보기
                    if (_attachedFiles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              List.generate(_attachedFiles.length, (index) {
                            return Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: widget.isDark
                                          ? Colors.grey[600]!
                                          : Colors.grey[300]!,
                                    ),
                                    image: DecorationImage(
                                      image: MemoryImage(_attachedFiles[index]
                                          ['bytes'] as Uint8List),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: IconButton(
                                    onPressed: () => _removeAttachedFile(index),
                                    icon: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // 댓글 내용 입력
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _contentController,
                            maxLines: 3,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  widget.isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: '이 사례를 직접 사용해본 경험을 공유해주세요...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: widget.isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[500],
                              ),
                              filled: true,
                              fillColor: widget.isDark
                                  ? Colors.grey[700]!.withValues(alpha: 0.5)
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: widget.isDark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: widget.isDark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4A6CF7),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitComment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A6CF7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '등록',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final userId = ref.read(userIdProvider);
    final commentId = comment['comment_id'] as int?;
    // 로그인한 사용자이고 comment_id가 있으면 삭제 버튼 표시
    // 서버에서 권한 체크 (본인 댓글만 삭제 가능)
    final canDelete = userId != null && commentId != null;
    final safeCommentId = commentId ?? 0;
    final safeUserId = userId ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.grey[800]!.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 정보
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4A6CF7).withValues(alpha: 0.15),
                      const Color(0xFF6366F1).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${comment['department'] ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4A6CF7),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${comment['job_position'] ?? ''} ${comment['name'] ?? ''}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              if (comment['comment_date'] != null)
                Text(
                  _formatDate(comment['comment_date'] as String),
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // 댓글 내용
          Text(
            comment['comment'] as String? ?? '',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: widget.isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
          // 첨부된 이미지 렌더링
          if (comment['attachments_list'] != null &&
              (comment['attachments_list'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    (comment['attachments_list'] as List).map((attachment) {
                  return _buildCommentImage(
                    attachment['file_name'] as String? ?? '',
                    attachment['prefix'] as String? ?? '',
                  );
                }).toList(),
              ),
            ),
          // 삭제 버튼
          if (canDelete)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () => _deleteComment(safeCommentId, safeUserId),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      '삭제',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            widget.isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(int commentId, String userId) async {
    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF40414F) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          '댓글 삭제',
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '이 댓글을 삭제하시겠습니까?',
          style: TextStyle(
            color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '삭제',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ContestApiService.deleteComment(
        commentId: commentId,
        userId: userId,
      );

      // 댓글 목록 새로고침
      await _loadComments();
      _hasChanges = true; // 삭제 성공 시 변경 플래그 설정

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '댓글이 삭제되었습니다.',
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
              ),
            ),
            backgroundColor:
                widget.isDark ? Colors.grey[800] : Colors.grey[300],
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      print('댓글 삭제 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '댓글 삭제에 실패했습니다: $e',
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
              ),
            ),
            backgroundColor:
                widget.isDark ? Colors.grey[800] : Colors.grey[300],
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  /// 댓글 이미지 위젯 빌드
  Widget _buildCommentImage(String fileName, String prefix) {
    return FutureBuilder<String?>(
      future: ContestApiService.getFileUrl(
        fileName: fileName,
        prefix: prefix,
        approvalType: 'contest',
        isDownload: 0,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: widget.isDark ? Colors.grey[700] : Colors.grey[200],
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFF4A6CF7),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: widget.isDark ? Colors.grey[700] : Colors.grey[200],
            ),
            child: Icon(
              Icons.image_not_supported,
              color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
            ),
          );
        }

        final imageUrl = snapshot.data!;
        return GestureDetector(
          onTap: () => _showFullImage(imageUrl),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isDark ? Colors.grey[600]! : Colors.grey[300]!,
                ),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 전체 화면으로 이미지 보기
  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true, // 외부 클릭 시 닫기
      barrierColor: Colors.black87, // 배경 어둡게
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // 외부 클릭 감지를 위한 GestureDetector
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: () {}, // 이미지 클릭 시 아무 동작 안함 (외부 클릭과 구분)
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}

/// 좋아요 아이콘 애니메이션 위젯
class _LikeIconAnimation extends StatefulWidget {
  final bool isLiked;
  final double scaleFactor;
  final bool isDark;

  const _LikeIconAnimation({
    required this.isLiked,
    required this.scaleFactor,
    required this.isDark,
  });

  @override
  State<_LikeIconAnimation> createState() => _LikeIconAnimationState();
}

class _LikeIconAnimationState extends State<_LikeIconAnimation>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _scaleController;
  late AnimationController _particleController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _particleAnimation;

  bool _wasLiked = false;

  @override
  void initState() {
    super.initState();
    _wasLiked = widget.isLiked;

    // 흔들림 애니메이션 (더 크게)
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.7), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.7, end: 0.7), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: -0.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.5, end: 0.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    // 크기 애니메이션 (더 팡 터지게)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 2.2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2.2, end: 0.7), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));

    // 파티클 애니메이션 (더 멀리 퍼지게)
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_LikeIconAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 좋아요 상태가 false -> true로 변경될 때 애니메이션 실행
    if (widget.isLiked && !_wasLiked) {
      _shakeController.forward(from: 0);
      _scaleController.forward(from: 0);
      _particleController.forward(from: 0);
    }
    _wasLiked = widget.isLiked;
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _scaleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_shakeAnimation, _scaleAnimation, _particleAnimation]),
      builder: (context, child) {
        return SizedBox(
          width: 24 * widget.scaleFactor,
          height: 24 * widget.scaleFactor,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 파티클 이펙트
              if (_particleController.isAnimating ||
                  _particleController.value > 0)
                ..._buildParticles(),

              // 메인 아이콘
              Transform.rotate(
                angle: _shakeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Icon(
                    widget.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 16 * widget.scaleFactor,
                    color: widget.isLiked
                        ? const Color(0xFF4A6CF7)
                        : (widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles() {
    final particles = <Widget>[];
    const particleCount = 16;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * 3.14159;
      final distance = 28 * widget.scaleFactor * _particleAnimation.value;
      final opacity = (1.0 - _particleAnimation.value).clamp(0.0, 1.0);
      final size =
          (5 * widget.scaleFactor * (1.0 - _particleAnimation.value * 0.3))
              .clamp(1.5, 15.0);

      particles.add(
        Positioned(
          left:
              (12 * widget.scaleFactor) + distance * math.cos(angle) - size / 2,
          top:
              (12 * widget.scaleFactor) + distance * math.sin(angle) - size / 2,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4A6CF7).withValues(alpha: opacity),
            ),
          ),
        ),
      );
    }

    return particles;
  }
}
