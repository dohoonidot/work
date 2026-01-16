import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';

// 선택 영역을 관리하는 SelectionContainer 위젯
// SelectionArea 대신 커스텀 구현으로 더 나은 사용자 경험 제공
class SelectionContainer extends StatefulWidget {
  final Widget child;

  const SelectionContainer({super.key, required this.child});

  @override
  State<SelectionContainer> createState() => _SelectionContainerState();
}

class _SelectionContainerState extends State<SelectionContainer> {
  // 현재 선택된 텍스트
  String? _selectedText;
  // 선택 영역 표시 여부
  bool _showSelectionToolbar = false;
  // 툴바 위치
  Offset _toolbarPosition = Offset.zero;
  // FocusNode 관리
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTapUp,
      child: SelectionArea(
        focusNode: _focusNode,
        selectionControls: MaterialTextSelectionControls(),
        onSelectionChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedText = value.plainText;
              if (_selectedText?.isNotEmpty ?? false) {
                _showSelectionToolbar = true;
              }
            });
          }
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            if (_showSelectionToolbar && _selectedText != null)
              Positioned(
                left: _toolbarPosition.dx,
                top: _toolbarPosition.dy,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF2A2A2A),
                  child: InkWell(
                    onTap: _copySelectedText,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.copy, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('복사',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 탭 이벤트 처리 - 툴바 위치 설정
  void _handleTapUp(TapUpDetails details) {
    if (_selectedText != null && _selectedText!.trim().isNotEmpty) {
      setState(() {
        // 탭 위치에 툴바 표시 (약간 위쪽으로 조정)
        _toolbarPosition = Offset(
          details.globalPosition.dx - 30, // 왼쪽으로 약간 조정
          details.globalPosition.dy - 40, // 위쪽으로 조정
        );
        _showSelectionToolbar = true;
      });
    }
  }

  // 선택된 텍스트 복사
  void _copySelectedText() {
    if (_selectedText != null) {
      Clipboard.setData(ClipboardData(text: _selectedText!));
      if (mounted) {
        // mounted 체크 추가
        CommonUIUtils.showInfoSnackBar(context, '선택한 텍스트가 복사되었습니다.');
      }
      // 복사 후 툴바 숨김
      setState(() {
        _showSelectionToolbar = false;
      });
    }
  }
}
