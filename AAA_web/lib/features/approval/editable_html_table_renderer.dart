import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';

/// 편집 가능한 HTML 테이블 렌더러
/// HTML 테이블을 렌더링하되, contenteditable 속성이 있는 셀을 편집 가능하게 만듦
/// 데이터 길이에 따라 동적으로 크기가 조절됩니다
class EditableHtmlTableRenderer extends ConsumerStatefulWidget {
  /// 서버에서 받은 HTML 콘텐츠
  final String? htmlContent;

  /// 로딩 상태 여부
  final bool isLoading;

  /// 최소 높이 (기본값: 400)
  final double minHeight;

  /// HTML 콘텐츠 변경 콜백
  final Function(String)? onContentChanged;

  const EditableHtmlTableRenderer({
    super.key,
    this.htmlContent,
    this.isLoading = false,
    this.minHeight = 400,
    this.onContentChanged,
  });

  @override
  ConsumerState<EditableHtmlTableRenderer> createState() =>
      _EditableHtmlTableRendererState();
}

class _EditableHtmlTableRendererState
    extends ConsumerState<EditableHtmlTableRenderer> {
  String? _currentHtmlContent;
  bool _isEditing = false;
  double? _estimatedHeight;

  @override
  void initState() {
    super.initState();
    _currentHtmlContent = widget.htmlContent;
  }

  @override
  void didUpdateWidget(EditableHtmlTableRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent) {
      _currentHtmlContent = widget.htmlContent;
      _calculateEstimatedHeight();
    }
  }

  /// HTML 콘텐츠의 길이를 기반으로 예상 높이 계산
  void _calculateEstimatedHeight() {
    if (_currentHtmlContent == null || _currentHtmlContent!.isEmpty) {
      _estimatedHeight = widget.minHeight;
      return;
    }

    // 테이블 행의 개수 추정
    final tableRowCount = '<tr'.allMatches(_currentHtmlContent!).length;
    final paragraphCount = '<p>'.allMatches(_currentHtmlContent!).length;
    final listItemCount = '<li>'.allMatches(_currentHtmlContent!).length;

    // 기본 높이 계산 (행당 약 50px, 문단당 30px, 리스트 항목당 25px)
    double estimatedContentHeight = (tableRowCount * 50.0) +
        (paragraphCount * 30.0) +
        (listItemCount * 25.0) +
        200; // 여백 및 헤더

    // 최소/최대 높이 제한
    _estimatedHeight = estimatedContentHeight.clamp(
        widget.minHeight, MediaQuery.of(context).size.height * 0.7);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 높이 계산이 안 되어 있으면 계산
    if (_estimatedHeight == null) {
      _calculateEstimatedHeight();
    }

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: widget.minHeight,
        // 예상 높이 사용, 없으면 기본 최대 높이
        maxHeight:
            _estimatedHeight ?? (MediaQuery.of(context).size.height * 0.7),
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF1A202C) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
        ),
      ),
      child: _buildContent(isDarkTheme),
    );
  }

  /// 콘텐츠 빌드
  Widget _buildContent(bool isDarkTheme) {
    if (widget.isLoading) {
      return _buildLoadingView(isDarkTheme);
    }

    if (_currentHtmlContent == null || _currentHtmlContent!.isEmpty) {
      return _buildEmptyView(isDarkTheme);
    }

    return Column(
      children: [
        // 편집 모드 토글 버튼
        Row(
          children: [
            Expanded(
              child: Text(
                '기본양식 내용',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
                ),
              ),
            ),
            Switch(
              value: _isEditing,
              onChanged: (value) {
                setState(() {
                  _isEditing = value;
                });
              },
              activeColor: const Color(0xFF4A6CF7),
            ),
            const SizedBox(width: 8),
            Text(
              _isEditing ? '편집 모드' : '보기 모드',
              style: TextStyle(
                fontSize: 12,
                color: isDarkTheme
                    ? const Color(0xFFA0AEC0)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // HTML 콘텐츠 렌더링 - 동적 크기 조절
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: _isEditing
                    ? _buildEditableTable(isDarkTheme)
                    : _buildHtmlRenderer(isDarkTheme),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 편집 가능한 테이블 빌드
  Widget _buildEditableTable(bool isDarkTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 기본 정보 테이블
        _buildEditableTableSection(
          title: '1. 기본 정보',
          headers: const ['항목', '내용'],
          data: _extractTableData(_currentHtmlContent!, '기본 정보'),
          isDarkTheme: isDarkTheme,
        ),
        const SizedBox(height: 24),

        // 상세 내용 테이블
        _buildEditableTableSection(
          title: '2. 상세 내용',
          headers: const ['항목', '내용', '비고'],
          data: _extractTableData(_currentHtmlContent!, '상세 내용'),
          isDarkTheme: isDarkTheme,
        ),
        const SizedBox(height: 24),

        // 기타 정보 테이블
        _buildEditableTableSection(
          title: '3. 기타 정보',
          headers: const ['구분', '내용'],
          data: _extractTableData(_currentHtmlContent!, '기타 정보'),
          isDarkTheme: isDarkTheme,
        ),
      ],
    );
  }

  /// 편집 가능한 테이블 섹션 빌드
  Widget _buildEditableTableSection({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
    required bool isDarkTheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 테이블 헤더
              Container(
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? const Color(0xFF2D3748)
                      : const Color(0xFFF8F9FA),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: headers.map((header) {
                    return Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: isDarkTheme
                                  ? const Color(0xFF4A5568)
                                  : const Color(0xFFE9ECEF),
                            ),
                          ),
                        ),
                        child: Text(
                          header,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF1A1D1F),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // 테이블 바디
              ...data.asMap().entries.map((rowEntry) {
                final rowIndex = rowEntry.key;
                final row = rowEntry.value;

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDarkTheme
                            ? const Color(0xFF4A5568)
                            : const Color(0xFFE9ECEF),
                      ),
                    ),
                  ),
                  child: Row(
                    children: row.asMap().entries.map((colEntry) {
                      final colIndex = colEntry.key;
                      final cellValue = colEntry.value;

                      return Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: isDarkTheme
                                    ? const Color(0xFF4A5568)
                                    : const Color(0xFFE9ECEF),
                              ),
                            ),
                          ),
                          child: TextField(
                            controller: TextEditingController(text: cellValue),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkTheme
                                  ? Colors.white
                                  : const Color(0xFF1A1D1F),
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: '입력하세요',
                              hintStyle: TextStyle(
                                color: isDarkTheme
                                    ? const Color(0xFFA0AEC0)
                                    : const Color(0xFF8B95A1),
                                fontSize: 14,
                              ),
                            ),
                            onChanged: (value) {
                              // 테이블 데이터 업데이트
                              _updateTableData(
                                  title, rowIndex, colIndex, value);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  /// HTML 렌더러 빌드
  Widget _buildHtmlRenderer(bool isDarkTheme) {
    return Html(
      data: _currentHtmlContent!,
      shrinkWrap: true, // 콘텐츠 크기에 맞게 축소
      style: {
        "body": Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(14),
          color:
              isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748),
        ),
        "h2": Style(
          color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          fontSize: FontSize(20),
          fontWeight: FontWeight.w700,
          margin: Margins.only(bottom: 16),
        ),
        "h3": Style(
          color: const Color(0xFF4A6CF7),
          fontSize: FontSize(16),
          fontWeight: FontWeight.w600,
          margin: Margins.only(bottom: 12, top: 20),
        ),
        "p": Style(
          margin: Margins.only(bottom: 8),
          color:
              isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748),
        ),
        "ul": Style(
          margin: Margins.only(bottom: 16),
          padding: HtmlPaddings.only(left: 20),
        ),
        "li": Style(
          margin: Margins.only(bottom: 6),
          color:
              isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748),
        ),
        "table": Style(
          border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
          ),
          width: Width(100, Unit.percent),
          margin: Margins.only(bottom: 16, top: 16),
        ),
        "th": Style(
          backgroundColor:
              isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
          padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 8),
          border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
          ),
          color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          fontWeight: FontWeight.w600,
          textAlign: TextAlign.center,
        ),
        "td": Style(
          padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 8),
          border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
          ),
          color:
              isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748),
        ),
        ".highlight": Style(
          backgroundColor: isDarkTheme
              ? const Color(0xFF4A6CF7).withValues(alpha: 0.3)
              : const Color(0xFF4A6CF7).withValues(alpha: 0.1),
          padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        ),
        ".warning": Style(
          backgroundColor: isDarkTheme
              ? const Color(0xFFD69E2E).withValues(alpha: 0.3)
              : const Color(0xFFD69E2E).withValues(alpha: 0.1),
          padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        ),
      },
      // 링크 처리
      onLinkTap: (url, attributes, element) {
        print('링크 클릭: $url');
        // TODO: URL 처리 로직 추가 (예: url_launcher 사용)
      },
    );
  }

  /// 로딩 뷰 빌드
  Widget _buildLoadingView(bool isDarkTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDarkTheme ? const Color(0xFF4A6CF7) : const Color(0xFF4A6CF7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'HTML 콘텐츠를 불러오는 중...',
            style: TextStyle(
              fontSize: 14,
              color: isDarkTheme
                  ? const Color(0xFFA0AEC0)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  /// 빈 뷰 빌드
  Widget _buildEmptyView(bool isDarkTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 48,
            color:
                isDarkTheme ? const Color(0xFFA0AEC0) : const Color(0xFF6B7280),
          ),
          const SizedBox(height: 16),
          Text(
            'HTML 콘텐츠가 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkTheme
                  ? const Color(0xFFA0AEC0)
                  : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '서버에서 HTML 템플릿을 불러와주세요',
            style: TextStyle(
              fontSize: 12,
              color: isDarkTheme
                  ? const Color(0xFFA0AEC0)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  /// HTML에서 테이블 데이터 추출
  List<List<String>> _extractTableData(String html, String sectionTitle) {
    // 간단한 파싱 로직 (실제로는 더 정교한 HTML 파싱이 필요)
    List<List<String>> data = [];

    if (sectionTitle == '기본 정보') {
      data = [
        ['제목', '[제목을 입력하세요]'],
        ['기안일자', '[기안일자]'],
        ['기안부서', '[기안부서]'],
        ['기안자', '[기안자명]'],
        ['보존기간', '[보존기간]'],
      ];
    } else if (sectionTitle == '상세 내용') {
      data = [
        ['예산', '1,000,000원', '부가세 별도'],
        ['일정', '2024년 1월 ~ 3월', '3개월 소요 예정'],
        ['담당자', '김담당 (AI사업부)', '프로젝트 PM'],
        ['위험요소', '일정 지연 가능성', '대비책 수립 필요'],
      ];
    } else if (sectionTitle == '기타 정보') {
      data = [
        ['참조자', '[참조자명]'],
        ['첨부파일', '[첨부파일 목록]'],
        ['긴급도', '보통'],
      ];
    }

    return data;
  }

  /// 테이블 데이터 업데이트
  void _updateTableData(
      String sectionTitle, int rowIndex, int colIndex, String value) {
    // 실제 구현에서는 HTML을 파싱하여 해당 셀의 값을 업데이트하고
    // 새로운 HTML을 생성하여 _currentHtmlContent를 업데이트해야 함
    print('테이블 데이터 업데이트: $sectionTitle, 행: $rowIndex, 열: $colIndex, 값: $value');

    // TODO: HTML 업데이트 로직 구현
    if (widget.onContentChanged != null) {
      widget.onContentChanged!(_currentHtmlContent!);
    }
  }
}
