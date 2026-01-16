import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';

/// 기본양식용 HTML 렌더링 위젯
/// 서버에서 받은 HTML 콘텐츠를 flutter_html을 사용하여 렌더링
class BasicFormHtmlRenderer extends ConsumerWidget {
  /// 서버에서 받은 HTML 콘텐츠
  final String? htmlContent;

  /// 로딩 상태 여부
  final bool isLoading;

  /// 최소 높이 (기본값: 200)
  final double minHeight;

  const BasicFormHtmlRenderer({
    super.key,
    this.htmlContent,
    this.isLoading = false,
    this.minHeight = 200,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        minHeight: minHeight,
        minWidth: double.infinity,
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
    if (isLoading) {
      return _buildLoadingView(isDarkTheme);
    }

    if (htmlContent == null || htmlContent!.trim().isEmpty) {
      return _buildEmptyView(isDarkTheme);
    }

    return _buildHtmlContent(isDarkTheme);
  }

  /// 로딩 뷰
  Widget _buildLoadingView(bool isDarkTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkTheme ? Colors.white : const Color(0xFF4A6CF7),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '내용을 불러오는 중...',
            style: TextStyle(
              fontSize: 14,
              color: isDarkTheme
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  /// 빈 콘텐츠 뷰
  Widget _buildEmptyView(bool isDarkTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 48,
            color:
                isDarkTheme ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
          const SizedBox(height: 16),
          Text(
            '내용이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkTheme
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '서버에서 내용을 전송하면\n여기에 표시됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDarkTheme
                  ? const Color(0xFF718096)
                  : const Color(0xFF8B95A1),
            ),
          ),
        ],
      ),
    );
  }

  /// HTML 콘텐츠 렌더링 (flutter_html 사용)
  Widget _buildHtmlContent(bool isDarkTheme) {
    return SingleChildScrollView(
      child: Html(
        data: htmlContent!,
        style: {
          "body": Style(
            fontSize: FontSize(14.0),
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
            fontFamily: 'Arial, sans-serif',
            lineHeight: LineHeight(1.6),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          "h1": Style(
            fontSize: FontSize(20.0),
            fontWeight: FontWeight.bold,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
            margin: Margins.only(bottom: 16, top: 16),
          ),
          "h2": Style(
            fontSize: FontSize(18.0),
            fontWeight: FontWeight.bold,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
            margin: Margins.only(bottom: 14, top: 14),
          ),
          "h3": Style(
            fontSize: FontSize(16.0),
            fontWeight: FontWeight.bold,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
            margin: Margins.only(bottom: 12, top: 12),
          ),
          "p": Style(
            margin: Margins.only(bottom: 12),
            color:
                isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748),
          ),
          "div": Style(
            color:
                isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748),
          ),
          "span": Style(
            color:
                isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748),
          ),
          "strong, b": Style(
            fontWeight: FontWeight.bold,
          ),
          "em, i": Style(
            fontStyle: FontStyle.italic,
          ),
          "ul": Style(
            margin: Margins.only(bottom: 12, left: 16),
          ),
          "ol": Style(
            margin: Margins.only(bottom: 12, left: 16),
          ),
          "li": Style(
            margin: Margins.only(bottom: 6),
            color:
                isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748),
          ),
          "table": Style(
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
            ),
            width: Width(100, Unit.percent),
            margin: Margins.only(bottom: 16, top: 16),
          ),
          "th": Style(
            backgroundColor:
                isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
            padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 8),
            fontWeight: FontWeight.bold,
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
            ),
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          ),
          "td": Style(
            padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 8),
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
            ),
            color:
                isDarkTheme ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748),
          ),
          "tr": Style(
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
            ),
          ),
          "a": Style(
            color: const Color(0xFF4A6CF7),
            textDecoration: TextDecoration.underline,
          ),
          "blockquote": Style(
            border: Border(
              left: BorderSide(
                color: isDarkTheme
                    ? const Color(0xFF4A5568)
                    : const Color(0xFFE9ECEF),
                width: 4,
              ),
            ),
            padding: HtmlPaddings.only(left: 16),
            margin: Margins.only(left: 0, bottom: 16, top: 16),
            backgroundColor:
                isDarkTheme ? const Color(0xFF1A202C) : const Color(0xFFF8F9FA),
          ),
          "code": Style(
            backgroundColor:
                isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF1F3F4),
            color:
                isDarkTheme ? const Color(0xFFE53E3E) : const Color(0xFFD63384),
            padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
            fontFamily: 'monospace',
            fontSize: FontSize(13),
          ),
          "pre": Style(
            backgroundColor:
                isDarkTheme ? const Color(0xFF1A202C) : const Color(0xFFF8F9FA),
            padding: HtmlPaddings.all(12),
            margin: Margins.only(bottom: 16, top: 16),
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
            ),
            fontFamily: 'monospace',
            fontSize: FontSize(13),
          ),
          "hr": Style(
            border: Border(
              bottom: BorderSide(
                color: isDarkTheme
                    ? const Color(0xFF4A5568)
                    : const Color(0xFFE9ECEF),
                width: 1,
              ),
            ),
            margin: Margins.symmetric(vertical: 16),
          ),
          // 폼 요소들
          "form": Style(
            margin: Margins.only(bottom: 16),
          ),
          "input": Style(
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
            ),
            padding: HtmlPaddings.symmetric(horizontal: 8, vertical: 4),
            backgroundColor:
                isDarkTheme ? const Color(0xFF2D3748) : Colors.white,
          ),
          "textarea": Style(
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
            ),
            padding: HtmlPaddings.all(8),
            backgroundColor:
                isDarkTheme ? const Color(0xFF2D3748) : Colors.white,
          ),
          // 사용자 정의 클래스
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
            color:
                isDarkTheme ? const Color(0xFFFBB6CE) : const Color(0xFF975A16),
            padding: HtmlPaddings.all(8),
            border: Border(
              left: BorderSide(
                color: const Color(0xFFD69E2E),
                width: 4,
              ),
            ),
          ),
          ".error": Style(
            backgroundColor: isDarkTheme
                ? const Color(0xFFE53E3E).withValues(alpha: 0.3)
                : const Color(0xFFE53E3E).withValues(alpha: 0.1),
            color:
                isDarkTheme ? const Color(0xFFFED7D7) : const Color(0xFF9B2C2C),
            padding: HtmlPaddings.all(8),
            border: Border(
              left: BorderSide(
                color: const Color(0xFFE53E3E),
                width: 4,
              ),
            ),
          ),
          ".success": Style(
            backgroundColor: isDarkTheme
                ? const Color(0xFF38A169).withValues(alpha: 0.3)
                : const Color(0xFF38A169).withValues(alpha: 0.1),
            color:
                isDarkTheme ? const Color(0xFFC6F6D5) : const Color(0xFF276749),
            padding: HtmlPaddings.all(8),
            border: Border(
              left: BorderSide(
                color: const Color(0xFF38A169),
                width: 4,
              ),
            ),
          ),
        },
        // 링크 처리
        onLinkTap: (url, attributes, element) {
          print('링크 클릭: $url');
          // TODO: URL 처리 로직 추가 (예: url_launcher 사용)
        },
      ),
    );
  }
}
