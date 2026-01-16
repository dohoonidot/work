import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

/// 휴가 총괄 관리 WebView 화면
class VacationManagementWebViewScreen extends StatefulWidget {
  final String webUrl;

  const VacationManagementWebViewScreen({
    super.key,
    required this.webUrl,
  });

  @override
  State<VacationManagementWebViewScreen> createState() =>
      _VacationManagementWebViewScreenState();
}

class _VacationManagementWebViewScreenState
    extends State<VacationManagementWebViewScreen> {
  final _controller = WebviewController();
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeWebView() async {
    try {
      await _controller.initialize();

      _controller.url.listen((url) {
        // URL 변경 시 처리
      });

      _controller.loadingState.listen((LoadingState state) {
        setState(() {
          isLoading = state == LoadingState.loading;
        });
      });

      await _controller.loadUrl(widget.webUrl);
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '웹뷰 초기화 실패: $e';
      });
    }
  }

  void _reload() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('휴가 총괄 관리'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D1F),
        elevation: 1,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: '새로고침',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: errorMessage != null
          ? _buildErrorWidget()
          : Stack(
              children: [
                // WebView
                Positioned.fill(
                  child: Webview(_controller),
                ),

                // 로딩 인디케이터
                if (isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF4A6CF7),
                            ),
                            SizedBox(height: 16),
                            Text(
                              '휴가 관리 페이지를 불러오는 중...',
                              style: TextStyle(
                                color: Color(0xFF6C757D),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  /// 오류 화면 위젯
  Widget _buildErrorWidget() {
    return Container(
      color: Colors.white,
      child: Center(
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
              '페이지 로드 실패',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage ?? '알 수 없는 오류가 발생했습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6C757D),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A6CF7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
