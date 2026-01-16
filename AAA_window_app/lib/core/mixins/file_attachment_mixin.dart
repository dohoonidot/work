import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ASPN_AI_AGENT/features/chat/file_attachment_modal.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/providers/clipboard_provider.dart' as clipboard;
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/shared/utils/file_attachment_utils.dart';
import 'package:ASPN_AI_AGENT/shared/utils/focus_management_utils.dart';

/// 파일 첨부 관련 공통 기능을 제공하는 Mixin
/// 여러 화면에서 중복되는 파일 첨부 로직을 통합하여 관리
mixin FileAttachmentMixin<T extends StatefulWidget> on State<T> {
  /// 파일 첨부 모달을 표시하는 공통 메서드
  void showFileAttachmentModal(BuildContext context, FocusNode focusNode, TextEditingController controller) {
    showDialog(
      context: context,
      builder: (context) => FileAttachmentModal(
        onCompleted: () {
          // 파일 첨부 완료 후 텍스트 필드로 포커스 이동 (커서를 텍스트 끝으로)
          FocusManagementUtils.requestFocusWithCursorAtEndImmediate(focusNode, controller);
        },
      ),
    );
  }

  /// 클립보드 붙여넣기 처리 (이미지가 있으면 이미지 첨부, 텍스트만 있으면 텍스트 붙여넣기)
  Future<void> handleClipboardPaste(BuildContext context, WidgetRef ref,
      TextEditingController controller) async {
    try {
      // 먼저 클립보드에 텍스트가 있는지 확인
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

      if (clipboardData?.text != null) {
        final text = clipboardData!.text!;

        // 이미지 파일 경로나 Base64 이미지 데이터인지 확인
        final isImagePath = _isImagePath(text);
        final isBase64Image = _isBase64Image(text);

        // 이미지 관련 데이터가 아니면 일반 텍스트 붙여넣기
        if (!isImagePath && !isBase64Image) {
          // 현재 커서 위치에 텍스트 삽입
          final currentText = controller.text;
          final selection = controller.selection;
          final newText = currentText.replaceRange(
            selection.start,
            selection.end,
            text,
          );

          // Future.microtask를 사용하여 IME(한글 입력기) 조합이 완료된 후 텍스트 업데이트
          // 이렇게 하면 한글 입력 시 자음과 모음이 분리되지 않음
          Future.microtask(() {
            // 텍스트가 중간에 변경되지 않았는지 확인 (안전성 체크)
            if (controller.text == currentText) {
              controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(
                  offset: selection.start + text.length,
                ),
              );
            }
          });
          return;
        }
      }

      // 이미지 관련 데이터이거나 텍스트가 없으면 이미지 처리 시도
      final clipboardNotifier = ref.read(clipboard.clipboardProvider.notifier);
      await clipboardNotifier.handleClipboardImage();
    } catch (e) {
      print('클립보드 처리 오류: $e');
    }
  }

  /// 드래그 앤 드롭 처리 공통 메서드
  Future<void> handleDragAccept(
      List<XFile> files, BuildContext context, WidgetRef ref) async {
    // 허용된 확장자 설정 (handleDragAndDrop에서 isPdfRestricted를 통해 필터링됨)
    final allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];

    // 파일 확장자 검증
    for (final file in files) {
      final extension = file.path.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(extension)) {
        _showErrorMessage(
          context,
          '지원하지 않는 파일 형식입니다. (JPG, PNG, PDF만 가능)',
        );
        return;
      }
    }

    // 파일 크기 검증 (20MB 제한)
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (bytes.length > 20 * 1024 * 1024) {
        _showErrorMessage(context, '파일 크기가 20MB를 초과할 수 없습니다.');
        return;
      }
    }

    // 첨부 파일 처리
    try {
      final attachmentNotifier = ref.read(attachmentProvider.notifier);

      // XFile을 PlatformFile로 변환하여 추가
      final platformFiles = <PlatformFile>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final platformFile = PlatformFile(
          name: file.name,
          path: file.path,
          size: bytes.length,
          bytes: bytes,
        );
        platformFiles.add(platformFile);
      }

      attachmentNotifier.addFiles(platformFiles);
      _showSuccessMessage(context, '파일이 첨부되었습니다.');
    } catch (e) {
      _showErrorMessage(context, '파일 첨부 중 오류가 발생했습니다: $e');
    }
  }

  /// 파일 경로가 이미지 파일인지 확인하는 유틸리티 메서드
  bool _isImagePath(String text) {
    final lowerText = text.toLowerCase().trim();
    return (lowerText.endsWith('.png') ||
        lowerText.endsWith('.jpg') ||
        lowerText.endsWith('.jpeg') ||
        lowerText.endsWith('.gif') ||
        lowerText.endsWith('.bmp'));
  }

  /// Base64 이미지 데이터인지 확인하는 유틸리티 메서드
  bool _isBase64Image(String text) {
    return text.startsWith('data:image/') && text.contains('base64,');
  }

  /// 에러 메시지를 표시하는 공통 메서드
  void _showErrorMessage(BuildContext context, String message) {
    CommonUIUtils.showErrorSnackBar(context, message);
  }

  /// 성공 메시지를 표시하는 공통 메서드
  void _showSuccessMessage(BuildContext context, String message) {
    CommonUIUtils.showSuccessSnackBar(context, message);
  }

  /// 드래그 앤 드롭 영역을 감싸는 위젯을 생성하는 헬퍼 메서드
  Widget buildDropZone({
    required Widget child,
    required BuildContext context,
    required WidgetRef ref,
  }) {
    return DropTarget(
      onDragDone: (detail) {
        // FileAttachmentUtils의 정적 메서드 호출
        FileAttachmentUtils.handleDragAndDrop(detail, context, ref);
      },
      child: child,
    );
  }
}
