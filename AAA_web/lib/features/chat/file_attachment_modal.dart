import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ASPN_AI_AGENT/shared/providers/attachment_provider.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/shared/utils/file_attachment_utils.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';

class FileAttachmentModal extends ConsumerStatefulWidget {
  final VoidCallback? onCompleted;

  const FileAttachmentModal({
    super.key,
    this.onCompleted,
  });

  @override
  ConsumerState<FileAttachmentModal> createState() =>
      _FileAttachmentModalState();
}

class _FileAttachmentModalState extends ConsumerState<FileAttachmentModal> {
  List<PlatformFile> selectedFiles = [];
  bool isDragging = false;
  bool isHovering = false;

  @override
  void initState() {
    super.initState();
    // 이미 선택된 파일이 있다면 가져오기
    selectedFiles = List.from(ref.read(attachmentProvider).files);
  }

  Future<void> _pickFiles() async {
    try {
      // 현재 아카이브 확인하여 PDF 제한 설정
      // PDF 허용
      // print('아카이브 이름: "$archiveName"');
      // print('아카이브 타입: "$archiveType"');

      // 허용된 확장자 설정 (PDF 허용)
      final allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];

      print('FilePicker allowedExtensions: $allowedExtensions');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: allowedExtensions,
        withData: true, // 바이트 데이터 포함
      );

      if (result != null) {
        // 파일 선택 로그 제거

        // 바이트 데이터가 없는 파일 필터링
        final validFiles =
            result.files.where((file) => file.bytes != null).toList();

        if (validFiles.isEmpty) {
          if (mounted) {
            CommonUIUtils.showInfoSnackBar(
                context, '파일을 읽을 수 없습니다. 다시 시도해주세요.');
          }
          return;
        }

        // PlatformFile을 직접 사용 (XFile 변환 제거)
        // 파일을 provider에 추가 (attachmentProvider에서 처리)
        final attachmentNotifier = ref.read(attachmentProvider.notifier);
        attachmentNotifier.addFiles(validFiles, ref: ref);

        // 성공 메시지 표시
        if (mounted) {
          CommonUIUtils.showSuccessSnackBar(context, '파일이 첨부되었습니다.');
        }

        // attachmentProvider에서 현재 파일 목록을 가져와 selectedFiles 업데이트
        setState(() {
          selectedFiles = List.from(ref.read(attachmentProvider).files);
        });
        print('=== _pickFiles 성공 ===\n');
      }
    } catch (e) {
      print('❌ _pickFiles 실패: $e');
      if (mounted) {
        CommonUIUtils.showErrorSnackBar(context, '파일 선택 중 오류가 발생했습니다: $e');
      }
    }
  }

  Future<void> _handleDragAccept(List<XFile> files) async {
    // 현재 아카이브 확인하여 PDF 제한 설정
    // FileAttachmentUtils의 handleDragAccept를 직접 호출
    await FileAttachmentUtils.handleDragAccept(files, context, ref,
        isPdfRestricted: false);

    // FileAttachmentUtils에서 이미 스낵바를 표시하므로 여기서는 제거
    // setState는 FileAttachmentUtils에서 처리하지 않으므로 여기서 처리
    setState(() {
      selectedFiles.addAll(ref.read(attachmentProvider).files);
    });
  }

  void removeFile(int index) {
    setState(() {
      selectedFiles.removeAt(index);
      ref.read(attachmentProvider.notifier).removeFile(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.themeMode != AppThemeMode.light;

    // 현재 아카이브 확인하여 PDF 제한 설정
    // 아카이브에 따른 파일 타입 안내 텍스트
    final fileTypesText = 'jpg, jpeg, png, pdf 파일만 첨부 가능';

    // 테마에 따른 색상 설정
    final backgroundColor = isDarkMode ? const Color(0xFF2D2D30) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final dragAreaColor = isDarkMode ? Colors.grey[800]! : Colors.grey.shade50;
    final dragAreaBorderColor =
        isDarkMode ? Colors.grey[600]! : Colors.grey.shade400;
    final iconColor = isDarkMode ? Colors.grey[300]! : Colors.grey.shade600;
    final subtitleColor = isDarkMode ? Colors.grey[400]! : Colors.grey.shade500;

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '파일 첨부',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 드래그 앤 드롭 영역
            GestureDetector(
              onTap: _pickFiles,
              child: DropTarget(
                onDragDone: (DropDoneDetails details) {
                  _handleDragAccept(details.files);
                },
                onDragEntered: (details) {
                  setState(() {
                    isDragging = true;
                  });
                },
                onDragExited: (details) {
                  setState(() {
                    isDragging = false;
                  });
                },
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDragging ? Colors.blue : dragAreaBorderColor,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isDragging
                        ? Colors.blue.withValues(alpha: 0.1)
                        : dragAreaColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDarkMode ? 0.3 : 0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDragging
                              ? Colors.blue.withValues(alpha: 0.1)
                              : isHovering
                                  ? Colors.blue.withValues(alpha: 0.1)
                                  : isDarkMode
                                      ? Colors.grey[700]!
                                      : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: MouseRegion(
                          onEnter: (_) => setState(() => isHovering = true),
                          onExit: (_) => setState(() => isHovering = false),
                          child: Icon(
                            Icons.cloud_upload,
                            size: 40,
                            color: isDragging
                                ? Colors.blue
                                : isHovering
                                    ? Colors.blue
                                    : iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '파일을 드래그하여 첨부하거나\n클릭하여 파일 선택',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDragging ? Colors.blue : textColor,
                        ),
                      ),
                      Text(
                        fileTypesText,
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 선택된 파일 목록
            if (selectedFiles.isNotEmpty) ...[
              Text(
                '선택된 파일',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = selectedFiles[index];
                    return ListTile(
                      leading: Icon(Icons.insert_drive_file, color: textColor),
                      title: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        '${(file.size / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(color: subtitleColor),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.close, color: textColor),
                        onPressed: () => removeFile(index),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('취소', style: TextStyle(color: textColor)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? Colors.grey[600] : null,
                    foregroundColor: isDarkMode ? Colors.white : null,
                  ),
                  onPressed: () {
                    // 이미 provider에 파일이 추가되어 있으므로 추가 작업 불필요
                    Navigator.of(context).pop();
                    // 파일 첨부 완료 후 콜백 실행
                    if (widget.onCompleted != null) {
                      // 약간의 지연을 주고 포커스 설정 (모달이 완전히 닫힌 후)
                      Future.delayed(const Duration(milliseconds: 100), () {
                        widget.onCompleted!();
                      });
                    }
                  },
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
