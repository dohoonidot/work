import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ASPN_AI_AGENT/shared/services/clipboard_image_service.dart';
// import 'providers.dart';

// PlatformFile을 확장한 커스텀 클래스
class CustomPlatformFile extends PlatformFile {
  final String mimeType;

  CustomPlatformFile({
    required super.name,
    required super.path,
    required super.size,
    required super.bytes,
    required this.mimeType,
  });

  // extension getter 오버라이드
  @override
  String? get extension {
    if (name.contains('.')) {
      return name.split('.').last.toLowerCase();
    }
    return null;
  }

  // PlatformFile을 CustomPlatformFile로 변환하는 팩토리 메서드
  static CustomPlatformFile fromPlatformFile(PlatformFile file) {
    final extension = file.extension?.toLowerCase() ?? '';
    String mimeType;

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      case 'pdf':
        mimeType = 'application/pdf';
        break;
      default:
        mimeType = 'application/octet-stream';
    }

    return CustomPlatformFile(
      name: file.name,
      path: file.path ?? '',
      size: file.size,
      bytes: file.bytes,
      mimeType: mimeType,
    );
  }
}

class AttachmentState {
  final List<CustomPlatformFile> files;

  AttachmentState({
    this.files = const [],
  });

  AttachmentState copyWith({
    List<CustomPlatformFile>? files,
  }) {
    return AttachmentState(
      files: files ?? this.files,
    );
  }
}

class AttachmentNotifier extends StateNotifier<AttachmentState> {
  AttachmentNotifier() : super(AttachmentState());

  void addFiles(List<PlatformFile> newFiles, {WidgetRef? ref}) {
    // PDF 제한 해제 - 모든 아카이브에서 PDF 허용
    final customFiles = newFiles
        .map((file) => CustomPlatformFile.fromPlatformFile(file))
        .toList();
    state = state.copyWith(
      files: [...state.files, ...customFiles],
    );
  }

  /// 클립보드 이미지 추가
  Future<bool> addClipboardImage() async {
    try {
      final clipboardFile = await ClipboardImageService.getClipboardImage();
      if (clipboardFile != null) {
        state = state.copyWith(
          files: [...state.files, clipboardFile],
        );
        return true;
      }
      return false;
    } catch (e) {
      print('클립보드 이미지 추가 오류: $e');
      return false;
    }
  }

  /// CustomPlatformFile 직접 추가 (클립보드 이미지용)
  void addCustomFile(CustomPlatformFile file) {
    state = state.copyWith(
      files: [...state.files, file],
    );
  }

  void removeFile(int index) {
    final newFiles = List<CustomPlatformFile>.from(state.files);
    newFiles.removeAt(index);
    state = state.copyWith(files: newFiles);
  }

  void clearFiles() {
    state = AttachmentState();
  }
}

final attachmentProvider =
    StateNotifierProvider<AttachmentNotifier, AttachmentState>((ref) {
  return AttachmentNotifier();
});
