import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ASPN_AI_AGENT/features/chat/file_attachment_modal.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/providers/clipboard_provider.dart'
    as clipboard;
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/shared/utils/focus_management_utils.dart';

/// 파일 첨부 관련 공통 기능을 제공하는 유틸리티 클래스
/// ConsumerWidget에서도 사용할 수 있도록 정적 메서드로 구현
class FileAttachmentUtils {
  /// 파일 첨부 모달을 표시하는 공통 메서드
  static void showFileAttachmentModal(BuildContext context, FocusNode focusNode,
      TextEditingController controller) {
    showDialog(
      context: context,
      builder: (context) => FileAttachmentModal(
        onCompleted: () {
          // 파일 첨부 완료 후 안전한 포커스 복원 (커서를 텍스트 끝으로)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FocusManagementUtils.requestFocusWithCursorAtEndImmediate(
                focusNode, controller);
          });
        },
      ),
    );
  }

  /// 클립보드 붙여넣기 처리 (이미지가 있으면 이미지 첨부, 텍스트만 있으면 텍스트 붙여넣기)
  static Future<void> handleClipboardPaste(BuildContext context, WidgetRef ref,
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
          // 현재 커서 위치 저장
          final currentText = controller.text;
          final selection = controller.selection;

          // 텍스트 삽입
          final newText = currentText.replaceRange(
            selection.start,
            selection.end,
            text,
          );

          // Future.microtask를 사용하여 IME(한글 입력기) 조합이 완료된 후 텍스트 업데이트
          // 이전의 addPostFrameCallback보다 더 빠르게 실행되어 한글 입력 보호
          Future.microtask(() {
            if (controller.text == currentText) {
              // 중간에 다른 변경이 없었다면
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
  static Future<void> handleDragAccept(
    List<XFile> files,
    BuildContext context,
    WidgetRef ref, {
    bool isPdfRestricted = false,
  }) async {
    print('\n=== handleDragAccept 디버깅 시작 ===');
    print('isPdfRestricted: $isPdfRestricted');

    // 허용된 확장자 설정
    final allowedExtensions = isPdfRestricted
        ? ['jpg', 'jpeg', 'png'] // PDF 제한된 경우 이미지만 허용
        : ['jpg', 'jpeg', 'png', 'pdf']; // 일반적인 경우 PDF도 허용

    print('allowedExtensions: $allowedExtensions');

    // 파일 확장자 검증
    for (final file in files) {
      // 파일명에서 확장자 추출 (공백이 있어도 정상 작동)
      final fileName = file.name;
      final extension =
          fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

      print('파일: $fileName, 확장자: $extension');

      if (!allowedExtensions.contains(extension)) {
        final allowedTypes = isPdfRestricted ? 'JPG, PNG' : 'JPG, PNG, PDF';
        print('❌ 확장자 검증 실패 - 파일: $fileName, 확장자: $extension');
        _showErrorMessage(
          context,
          '지원하지 않는 파일 형식입니다. ($allowedTypes만 가능)',
        );
        return;
      } else {
        print('✅ 확장자 검증 성공 - 파일: $fileName, 확장자: $extension');
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
      print('=== handleDragAccept 성공 ===\n');
    } catch (e) {
      print('❌ handleDragAccept 실패: $e');
      _showErrorMessage(context, '파일 첨부 중 오류가 발생했습니다: $e');
    }
  }

  /// 드래그 앤 드롭 이벤트를 처리하는 공통 메서드
  static void handleDragAndDrop(
      DropDoneDetails details, BuildContext context, WidgetRef ref) {
    final chatState = ref.read(chatProvider);
    final currentArchive = chatState.arvChatHistory.firstWhere(
      (archive) => archive['archive_id'] == chatState.currentArchiveId,
      orElse: () => {'archive_name': '', 'archive_type': ''},
    );
    final archiveName = currentArchive['archive_name'] ?? '';
    final archiveType = currentArchive['archive_type'] ?? '';

    print('\n=== handleDragAndDrop 디버깅 시작 ===');
    print('현재 아카이브 ID: ${chatState.currentArchiveId}');
    print('아카이브 이름: "$archiveName"');
    print('아카이브 타입: "$archiveType"');

    // PDF 제한 해제: 모든 아카이브에서 JPG/PNG/PDF 허용
    final isPdfRestricted = false;

    print('PDF 제한 여부: $isPdfRestricted');
    print('드래그된 파일 수: ${details.files.length}');
    for (var i = 0; i < details.files.length; i++) {
      print('파일 ${i + 1}: ${details.files[i].name}');
    }
    print('=== handleDragAndDrop 정보 출력 완료 ===\n');

    FileAttachmentUtils.handleDragAccept(details.files, context, ref,
        isPdfRestricted: isPdfRestricted);
  }

  /// 파일 경로가 이미지 파일인지 확인하는 유틸리티 메서드
  static bool _isImagePath(String text) {
    final lowerText = text.toLowerCase().trim();
    return (lowerText.endsWith('.png') ||
        lowerText.endsWith('.jpg') ||
        lowerText.endsWith('.jpeg') ||
        lowerText.endsWith('.gif') ||
        lowerText.endsWith('.bmp'));
  }

  /// Base64 이미지 데이터인지 확인하는 유틸리티 메서드
  static bool _isBase64Image(String text) {
    return text.startsWith('data:image/') && text.contains('base64,');
  }

  /// 에러 메시지를 표시하는 공통 메서드
  static void _showErrorMessage(BuildContext context, String message) {
    CommonUIUtils.showErrorSnackBar(context, message);
  }

  /// 성공 메시지를 표시하는 공통 메서드
  static void _showSuccessMessage(BuildContext context, String message) {
    CommonUIUtils.showSuccessSnackBar(context, message);
  }

  /// 드래그 앤 드롭 영역을 감싸는 위젯을 생성하는 헬퍼 메서드
  static Widget buildDropZone({
    required Widget child,
    required BuildContext context,
    required WidgetRef ref,
  }) {
    return DropTarget(
      onDragDone: (detail) {
        handleDragAndDrop(detail, context, ref);
      },
      child: child,
    );
  }
}
