import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/attachment_provider.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';

class AttachmentPreview extends ConsumerWidget {
  const AttachmentPreview({super.key});

  // 파일이 이미지인지 확인하는 헬퍼 메서드
  bool _isImageFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  // 파일 타입에 따른 아이콘 반환
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(attachmentProvider).files;
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.themeMode != AppThemeMode.light;

    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    // 테마에 따른 색상 설정
    final backgroundColor =
        isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100];
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final cardColor = isDarkMode ? const Color(0xFF2D2D30) : Colors.white;
    final cardBorderColor = isDarkMode ? Colors.grey[600]! : Colors.grey[300]!;
    final imagePlaceholderColor =
        isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, size: 16, color: textColor),
                const SizedBox(width: 4),
                Text(
                  '첨부파일 ${attachments.length}개',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(attachmentProvider.notifier).clearFiles();
                  },
                  child: Text(
                    '모두 삭제',
                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                constraints:
                    const BoxConstraints(maxHeight: 100), // 높이를 100으로 줄임
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: attachments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      final isImage = _isImageFile(file.name);

                      return Container(
                        padding: const EdgeInsets.all(6), // 패딩을 줄임
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cardBorderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDarkMode ? 0.3 : 0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: isImage
                            ? _buildImagePreview(file, index, ref, isDarkMode,
                                textColor, subtitleColor, imagePlaceholderColor)
                            : _buildFilePreview(file, index, ref, isDarkMode,
                                textColor, subtitleColor),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 이미지 파일 미리보기 위젯
  Widget _buildImagePreview(
      dynamic file,
      int index,
      WidgetRef ref,
      bool isDarkMode,
      Color textColor,
      Color subtitleColor,
      Color imagePlaceholderColor) {
    return Stack(
      children: [
        SizedBox(
          width: 70, // 너비를 줄임
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 이미지 썸네일
              Container(
                width: 50, // 크기를 줄임
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color:
                          isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: file.bytes != null
                      ? Image.memory(
                          file.bytes!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 50,
                              color: imagePlaceholderColor,
                              child: Icon(
                                Icons.broken_image,
                                color: isDarkMode
                                    ? Colors.grey[400]!
                                    : Colors.grey,
                                size: 20,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: imagePlaceholderColor,
                          child: Icon(
                            Icons.image,
                            color: isDarkMode ? Colors.grey[400]! : Colors.grey,
                            size: 20,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 2),
              // 파일명 (축약)
              Text(
                file.name.length > 8
                    ? '${file.name.substring(0, 5)}...'
                    : file.name,
                style: TextStyle(fontSize: 9, color: textColor),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // 파일 크기
              Text(
                '${(file.size / 1024).toStringAsFixed(1)}KB',
                style: TextStyle(
                  fontSize: 8,
                  color: subtitleColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // 삭제 버튼
        Positioned(
          top: -2,
          right: -2,
          child: GestureDetector(
            onTap: () {
              ref.read(attachmentProvider.notifier).removeFile(index);
            },
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.red[400],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 일반 파일 미리보기 위젯 (기존 방식 개선)
  Widget _buildFilePreview(dynamic file, int index, WidgetRef ref,
      bool isDarkMode, Color textColor, Color subtitleColor) {
    // PDF 파일인지 확인
    final isPdfFile = file.name.toLowerCase().endsWith('.pdf');

    // PDF 파일이고 다크 테마일 때 텍스트 색상을 검정색으로 설정
    final fileTextColor = (isPdfFile && isDarkMode) ? Colors.black : textColor;
    final fileSizeColor =
        (isPdfFile && isDarkMode) ? Colors.black87 : subtitleColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_getFileIcon(file.name),
            size: 18, color: isDarkMode ? Colors.blue[300]! : Colors.blue[600]),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              file.name.length > 12
                  ? '${file.name.substring(0, 9)}...'
                  : file.name,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: fileTextColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${(file.size / 1024).toStringAsFixed(1)}KB',
              style: TextStyle(
                fontSize: 9,
                color: fileSizeColor,
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            ref.read(attachmentProvider.notifier).removeFile(index);
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close,
              size: 10,
              color: isDarkMode ? Colors.grey[300]! : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
