import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:ASPN_AI_AGENT/shared/providers/attachment_provider.dart';

class ClipboardImageService {
  static const int maxFileSize = 20 * 1024 * 1024; // 20MB

  /// 🚀 클립보드에서 텍스트 데이터 가져오기
  static Future<String?> getClipboardText() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      return clipboardData?.text;
    } catch (e) {
      print('클립보드 텍스트 읽기 오류: $e');
      return null;
    }
  }

  /// 클립보드에서 이미지를 읽어와 CustomPlatformFile로 변환
  /// Windows에서는 제한적이므로 대안 방법을 제공
  static Future<CustomPlatformFile?> getClipboardImage() async {
    try {
      // 1. 텍스트 기반 클립보드 확인 (파일 경로나 Base64)
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

      if (clipboardData?.text != null) {
        final text = clipboardData!.text!;

        // 🔧 일반 텍스트인 경우 이미지 처리하지 않음
        if (!_isImagePath(text) && !_isBase64Image(text)) {
          return null;
        }

        // 이미지 파일 경로인지 확인
        if (_isImagePath(text)) {
          return await _createPlatformFileFromPath(text);
        }

        // Base64 이미지 데이터인지 확인
        if (_isBase64Image(text)) {
          return await _createPlatformFileFromBase64(text);
        }
      }

      // 2. Windows 임시 폴더에서 최근 스크린샷 찾기
      if (Platform.isWindows) {
        final recentScreenshot = await _findRecentScreenshot();
        if (recentScreenshot != null) {
          return recentScreenshot;
        }
      }

      // 3. 사용자에게 대안 방법 안내
      print('클립보드 이미지 직접 읽기가 제한됩니다.');
      print('대안: 1) 이미지를 파일로 저장 후 파일 첨부 사용');
      print('     2) 이미지 파일 경로를 클립보드에 복사 후 Ctrl+V');
      return null;
    } catch (e) {
      print('클립보드 이미지 읽기 오류: $e');
      return null;
    }
  }

  /// Windows에서 최근 스크린샷 파일 찾기
  static Future<CustomPlatformFile?> _findRecentScreenshot() async {
    try {
      // Windows 스크린샷 기본 저장 경로들
      final possiblePaths = [
        '${Platform.environment['USERPROFILE']}\\Pictures\\Screenshots',
        '${Platform.environment['USERPROFILE']}\\Desktop',
        '${Platform.environment['USERPROFILE']}\\Downloads',
      ];

      for (final dirPath in possiblePaths) {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) continue;

        final files = dir
            .listSync()
            .where((file) => file is File && _isImageFile(file.path))
            .cast<File>()
            .toList();

        if (files.isEmpty) continue;

        // 최근 수정된 파일 찾기 (5분 이내)
        files.sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

        final recentFile = files.first;
        final modifiedTime = recentFile.statSync().modified;
        final now = DateTime.now();

        // 5분 이내에 수정된 파일이면 스크린샷일 가능성이 높음
        if (now.difference(modifiedTime).inMinutes <= 5) {
          print('최근 스크린샷 발견: ${recentFile.path}');
          return await _createPlatformFileFromPath(recentFile.path);
        }
      }
    } catch (e) {
      print('최근 스크린샷 찾기 오류: $e');
    }
    return null;
  }

  /// 파일이 이미지 파일인지 확인
  static bool _isImageFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.png', '.jpg', '.jpeg', '.gif', '.bmp'].contains(extension);
  }

  /// 파일 경로가 이미지 파일인지 확인
  static bool _isImagePath(String text) {
    final lowerText = text.toLowerCase().trim();
    return (lowerText.endsWith('.png') ||
            lowerText.endsWith('.jpg') ||
            lowerText.endsWith('.jpeg') ||
            lowerText.endsWith('.gif') ||
            lowerText.endsWith('.bmp')) &&
        File(text).existsSync();
  }

  /// Base64 이미지 데이터인지 확인
  static bool _isBase64Image(String text) {
    return text.startsWith('data:image/') && text.contains('base64,');
  }

  /// 파일 경로에서 CustomPlatformFile 생성
  static Future<CustomPlatformFile?> _createPlatformFileFromPath(
      String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final extension = path.extension(filePath).toLowerCase().substring(1);

      return CustomPlatformFile(
        name: path.basename(filePath),
        path: filePath,
        size: bytes.length,
        bytes: bytes,
        mimeType: _getMimeType(extension),
      );
    } catch (e) {
      print('파일 경로에서 이미지 생성 오류: $e');
      return null;
    }
  }

  /// Base64 데이터에서 CustomPlatformFile 생성
  static Future<CustomPlatformFile?> _createPlatformFileFromBase64(
      String base64Data) async {
    try {
      final parts = base64Data.split(',');
      if (parts.length != 2) return null;

      final mimeType = parts[0].split(':')[1].split(';')[0];
      final extension = mimeType.split('/')[1];
      final bytes = base64Decode(parts[1]);

      return await _createPlatformFile(bytes, extension);
    } catch (e) {
      print('Base64에서 이미지 생성 오류: $e');
      return null;
    }
  }

  /// MIME 타입 반환
  static String _getMimeType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/png';
    }
  }

  /// 이미지 데이터를 임시 파일로 저장하고 CustomPlatformFile 생성
  static Future<CustomPlatformFile> _createPlatformFile(
      Uint8List imageData, String format) async {
    // 파일 크기 확인
    if (imageData.length > maxFileSize) {
      throw Exception('이미지 크기가 너무 큽니다. (최대 ${maxFileSize ~/ (1024 * 1024)}MB)');
    }

    // 임시 디렉토리 가져오기
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'clipboard_image_$timestamp.$format';
    final file = File(path.join(tempDir.path, fileName));

    // 파일 저장
    await file.writeAsBytes(imageData);

    // MIME 타입 결정
    final mimeType = _getMimeType(format);

    return CustomPlatformFile(
      name: fileName,
      path: file.path,
      size: imageData.length,
      bytes: imageData,
      mimeType: mimeType,
    );
  }

  /// 임시 이미지 파일들 정리 (24시간 이상 된 파일들)
  static Future<void> cleanupTempImages() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (var file in files) {
        if (file.path.contains('clipboard_image_') && file is File) {
          final stats = await file.stat();
          if (DateTime.now().difference(stats.modified).inHours > 24) {
            await file.delete();
            print('임시 파일 삭제: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('임시 파일 정리 오류: $e');
    }
  }

  /// 플랫폼별 기본 스크린샷 키 조합 반환
  static String get defaultScreenshotKey {
    if (Platform.isWindows) return 'Win+Shift+S 또는 Shift+Alt+S';
    if (Platform.isMacOS) return 'Cmd+Shift+4';
    if (Platform.isLinux) return 'PrintScreen';
    return 'PrintScreen';
  }

  /// 사용자에게 도움말 메시지 제공
  static String getHelpMessage() {
    if (Platform.isWindows) {
      return '''
클립보드 이미지 붙여넣기 방법:

방법(권장): 
1. Win+Shift+S로 스크린샷 캡처
2. ctrl + v 로 붙여넣기기

''';
    }
    return '현재 플랫폼에서는 파일 첨부 버튼을 사용해주세요.';
  }

}
