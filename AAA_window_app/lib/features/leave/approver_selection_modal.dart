import 'package:flutter/material.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';

/// 승인자 선택 모달
///
/// **기능**:
/// - API를 통해 승인자 목록을 불러옴
/// - 체크박스 방식으로 여러 승인자 선택 가능
/// - 순차결재 모드를 지원하여 선택 순서를 추적
/// - 선택된 승인자 ID 리스트를 반환
class ApproverSelectionModal extends StatefulWidget {
  /// 이미 선택된 승인자 ID 리스트 (기본값)
  final List<String> initialSelectedApproverIds;

  /// 순차결재 모드 활성화 여부
  final bool sequentialApproval;

  const ApproverSelectionModal({
    super.key,
    this.initialSelectedApproverIds = const [],
    this.sequentialApproval = false,
  });

  @override
  State<ApproverSelectionModal> createState() => _ApproverSelectionModalState();
}

class _ApproverSelectionModalState extends State<ApproverSelectionModal> {
  List<Approver> _approverList = [];
  Set<String> _selectedApproverIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  /// 순차결재 모드에서 선택된 승인자의 순서를 추적 (user_id를 순서대로 저장)
  List<String> _selectedApproverOrder = [];

  // 검색 기능
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  /// 선택된 승인자 객체 가져오기
  List<Approver> get _selectedApprovers {
    return _approverList
        .where((approver) => _selectedApproverIds.contains(approver.approverId))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedApproverIds = Set.from(widget.initialSelectedApproverIds);
    // 순차결재 모드인 경우 초기 순서 리스트 설정
    if (widget.sequentialApproval) {
      _selectedApproverOrder = List.from(widget.initialSelectedApproverIds);
    }
    _loadApprovers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 검색어로 필터링된 승인자 목록
  List<Approver> get _filteredApproverList {
    if (_searchText.isEmpty) {
      return _approverList;
    }

    return _approverList.where((approver) {
      final searchLower = _searchText.toLowerCase();
      return approver.approverName.toLowerCase().contains(searchLower) ||
          approver.department.toLowerCase().contains(searchLower) ||
          approver.jobPosition.toLowerCase().contains(searchLower) ||
          approver.approverId.toLowerCase().contains(searchLower);
    }).toList();
  }

  /// 승인자 목록 불러오기
  Future<void> _loadApprovers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await LeaveApiService.getApprover();

      if (response.isSuccess) {
        setState(() {
          _approverList = response.approverList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.error ?? '승인자 목록을 불러오는데 실패했습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '승인자 목록을 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.people_alt_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.sequentialApproval ? '승인자 선택 (순차결재)' : '승인자 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1E2B3C),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedApproverIds.length}명 선택됨',
              style: TextStyle(
                fontSize: 13,
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // 검색 필드
            TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDarkTheme ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: '이름, 부서, 직급, 이메일로 검색',
                hintStyle: TextStyle(
                  color: isDarkTheme ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDarkTheme ? Colors.grey[500] : Colors.grey[400],
                  size: 20,
                ),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color:
                              isDarkTheme ? Colors.grey[500] : Colors.grey[400],
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchText = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDarkTheme
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF505050)
                        : const Color(0xFFE9ECEF),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E88E5),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // 선택된 승인자 표시 영역
            if (_selectedApproverIds.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: const Color(0xFF1E88E5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '선택된 승인자 (${_selectedApproverIds.length}명)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E88E5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (() {
                        // 순차결재 모드인 경우 선택 순서에 따라 표시
                        if (widget.sequentialApproval) {
                          return _selectedApproverOrder.map((approverId) {
                            final approver = _approverList.firstWhere(
                              (a) => a.approverId == approverId,
                              orElse: () => Approver(
                                approverId: approverId,
                                approverName: '알 수 없음',
                                department: '',
                                jobPosition: '',
                              ),
                            );
                            final sequenceNumber =
                                _selectedApproverOrder.indexOf(approverId) + 1;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E88E5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 순차 번호 표시
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$sequenceNumber',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E88E5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        approver.approverName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (approver.jobPosition.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${approver.department} · ${approver.jobPosition}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white
                                                .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedApproverIds
                                            .remove(approver.approverId);
                                        _selectedApproverOrder
                                            .remove(approver.approverId);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        } else {
                          // 일반 모드는 기존과 동일
                          return _selectedApprovers.map((approver) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E88E5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        approver.approverName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (approver.jobPosition.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${approver.department} · ${approver.jobPosition}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white
                                                .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedApproverIds
                                            .remove(approver.approverId);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        }
                      })(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 승인자 리스트
            Expanded(
              child: _buildContent(isDarkTheme),
            ),

            const SizedBox(height: 20),

            // 버튼들
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isDarkTheme
                            ? Colors.grey[600]!
                            : const Color(0xFF1E88E5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? Colors.grey[400]
                            : const Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // 순차결재 모드인 경우 순서가 있는 리스트 반환
                      // 일반 모드인 경우 Set을 List로 변환하여 반환
                      final result = widget.sequentialApproval
                          ? _selectedApproverOrder
                          : _selectedApproverIds.toList();
                      Navigator.pop(context, result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      disabledBackgroundColor:
                          Colors.grey[400], // 더 이상 사용되지 않지만 유지
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDarkTheme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('승인자 목록을 불러오는 중...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
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
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadApprovers,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_approverList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: isDarkTheme ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '승인자 목록이 없습니다.',
              style: TextStyle(
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // 필터링된 승인자 목록 사용
    final filteredList = _filteredApproverList;

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDarkTheme ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"$_searchText"와 일치하는 승인자가 없습니다.',
              style: TextStyle(
                fontSize: 13,
                color: isDarkTheme ? Colors.grey[500] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: filteredList.map((approver) {
          final isSelected = _selectedApproverIds.contains(approver.approverId);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1E88E5).withValues(alpha: 0.1)
                  : (isDarkTheme
                      ? const Color(0xFF3A3A3A)
                      : const Color(0xFFF8F9FA)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1E88E5)
                    : (isDarkTheme
                        ? const Color(0xFF505050)
                        : const Color(0xFFE9ECEF)),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedApproverIds.add(approver.approverId);
                    // 순차결재 모드인 경우 선택 순서 추적
                    if (widget.sequentialApproval) {
                      _selectedApproverOrder.add(approver.approverId);
                    }
                  } else {
                    _selectedApproverIds.remove(approver.approverId);
                    // 순차결재 모드인 경우 순서 리스트에서도 제거
                    if (widget.sequentialApproval) {
                      _selectedApproverOrder.remove(approver.approverId);
                    }
                  }
                });
              },
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      approver.approverName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? Colors.white
                            : const Color(0xFF1E2B3C),
                      ),
                    ),
                  ),
                  if (approver.jobPosition.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        approver.jobPosition,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 14,
                        color:
                            isDarkTheme ? Colors.grey[500] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        approver.department,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.email,
                        size: 14,
                        color:
                            isDarkTheme ? Colors.grey[500] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          approver.approverId,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkTheme
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              activeColor: const Color(0xFF1E88E5),
              checkColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
