import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';

class ContestApiService {
  static String get baseUrl => AppConfig.baseUrl;

  /// 공모전 신청서 생성 API 호출
  ///
  /// [contestType] 공모전, 이벤트 유형
  /// [userId] 사용자 아이디
  /// [message] 사용자 채팅
  /// [files] 이미지 byte 파일 리스트
  /// [fileNames] 파일명 리스트 (files와 동일한 순서)
  static Future<Map<String, dynamic>> requestContest({
    required String contestType,
    required String userId,
    required String message,
    List<Uint8List>? files,
    List<String>? fileNames,
  }) async {
    final url = Uri.parse('$baseUrl/contest/chat');

    try {
      print('🏆 [ContestApiService] ===== 공모전 신청서 API 요청 =====');
      print('  - URL: $url');
      print('  - contest_type: $contestType');
      print('  - user_id: $userId');
      print('  - message: $message');
      print('  - files: ${files?.length ?? 0}개');
      print('  - fileNames: ${fileNames?.length ?? 0}개');

      // 항상 multipart/form-data로 전송
      final request = http.MultipartRequest('POST', url);

      // 텍스트 필드 추가
      request.fields['contest_type'] = 'test';
      request.fields['user_id'] = userId;
      request.fields['message'] = message;

      // files 필드 처리
      if (files != null && files.isNotEmpty) {
        // 파일이 있는 경우 파일 추가
        for (int i = 0; i < files.length; i++) {
          // 실제 파일명 사용 (없으면 기본값)
          final fileName = (fileNames != null && i < fileNames.length)
              ? fileNames[i]
              : 'image_$i.jpg';

          // 파일 확장자로 MIME 타입 결정
          String mimeType = 'image/jpeg';
          String mimeSubtype = 'jpeg';
          if (fileName.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
            mimeSubtype = 'png';
          } else if (fileName.toLowerCase().endsWith('.gif')) {
            mimeType = 'image/gif';
            mimeSubtype = 'gif';
          } else if (fileName.toLowerCase().endsWith('.webp')) {
            mimeType = 'image/webp';
            mimeSubtype = 'webp';
          } else if (fileName.toLowerCase().endsWith('.jpg') ||
              fileName.toLowerCase().endsWith('.jpeg')) {
            mimeType = 'image/jpeg';
            mimeSubtype = 'jpeg';
          }

          request.files.add(
            http.MultipartFile.fromBytes(
              'files',
              files[i],
              filename: fileName,
              contentType: MediaType('image', mimeSubtype),
            ),
          );
          print('  - File #${i + 1}: $fileName (${files[i].length} bytes, $mimeType)');
        }
        print('  - Content-Type: multipart/form-data');
        print('  - Files count: ${files.length}');
      } else {
        // 파일이 없는 경우 files 필드를 보내지 않음
        // 서버가 multipart의 files 필드와 충돌할 수 있으므로 필드를 추가하지 않음
        print('  - Content-Type: multipart/form-data');
        print('  - Files count: 0');
        print('  - files field: (not sent)');
      }

      // 요청 필드 전체 출력 (디버깅용)
      print('  - Request fields: ${request.fields}');
      print('  - Request files count: ${request.files.length}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        print('✅ [ContestApiService] API 호출 성공');
        return data;
      } else {
        print('❌ [ContestApiService] API 호출 실패: ${response.statusCode}');
        throw Exception('공모전 신청서 생성 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ContestApiService] API 호출 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 공모전 신청서 제출 API 호출
  ///
  /// [userId] 사용자 아이디
  /// [name] 이름
  /// [jobPosition] 직급
  /// [department] 부서
  /// [contestType] 공모전 유형
  /// [toolName] 사용한 AI TOOL
  /// [workScope] 어떤 업무에 적용 했나요?
  /// [workMethod] 어떤 방식으로 사용 했나요?
  /// [beforeAfter] Before & After
  /// [files] 이미지 byte 파일 리스트 (null 가능)
  /// [fileNames] 파일명 리스트 (files와 동일한 순서)
  /// [attachmentUrls] 채팅 API에서 받은 attachment_urls (file_name, url, prefix 포함)
  static Future<Map<String, dynamic>> submitContest({
    required String userId,
    required String name,
    required String jobPosition,
    required String department,
    required String contestType,
    required String toolName,
    required String workScope,
    required String workMethod,
    required String beforeAfter,
    List<Uint8List>? files,
    List<String>? fileNames,
    List<Map<String, dynamic>>? attachmentUrls,
  }) async {
    final url = Uri.parse('$baseUrl/contest/request');

    try {
      print('🏆 [ContestApiService] ===== 공모전 신청서 제출 API 요청 =====');
      print('  - URL: $url');
      print('  - user_id: $userId');
      print('  - name: $name');
      print('  - job_position: $jobPosition');
      print('  - department: $department');
      print('  - contest_type: $contestType');
      print('  - tool_name: $toolName');
      print('  - work_scope length: ${workScope.length}');
      print('  - work_method length: ${workMethod.length}');
      print('  - before_after length: ${beforeAfter.length}');
      print('  - files: ${files?.length ?? 0}개');

      // approval_date는 현재 시간으로 설정 (서버가 기대하는 형식: 2025-11-11T13:16:34.008510939+09:00)
      final now = DateTime.now();
      // 타임존 오프셋 계산 (+09:00 형식)
      final offset = now.timeZoneOffset;
      final hours = offset.inHours;
      final minutes = offset.inMinutes.remainder(60);
      final offsetString =
          '${hours >= 0 ? '+' : ''}${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

      // 나노초까지 포함 (마이크로초를 나노초로 변환)
      final microseconds = now.microsecond;
      final nanoseconds = microseconds * 1000; // 마이크로초를 나노초로 변환

      final approvalDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T'
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.'
          '${nanoseconds.toString().padLeft(9, '0')}$offsetString';

      print('  - approval_date: $approvalDate');

      // multipart/form-data로 전송 (파일 포함)
      print('\n📤 [ContestApiService] ===== 요청 데이터 준비 =====');
      print('  ✅ 전송 방식: multipart/form-data');
      final request = http.MultipartRequest('POST', url);

      // JSON 형식의 필드 추가 (새로운 형식에 맞춤)
      request.fields['user_id'] = userId;
      request.fields['name'] = name;
      request.fields['job_position'] = jobPosition;
      request.fields['department'] = department;
      request.fields['contest_type'] = 'test';
      request.fields['tool_name'] = toolName;
      request.fields['work_scope'] = workScope;
      request.fields['work_method'] = workMethod;
      request.fields['before_after'] = beforeAfter;
      request.fields['approval_date'] = approvalDate;

      // attachment_urls 필드 추가 (채팅 API에서 받은 URL들)
      if (attachmentUrls != null && attachmentUrls.isNotEmpty) {
        final attachmentUrlsJson = jsonEncode(attachmentUrls);
        request.fields['attachment_urls'] = attachmentUrlsJson;
        print('  - attachment_urls: ${attachmentUrls.length}개 (JSON: $attachmentUrlsJson)');
      }

      // 전송할 필드 값들 로그 출력
      print('\n📋 [ContestApiService] ===== 전송 필드 값 (제출 API) =====');
      print('  🔑 user_id: "${request.fields['user_id']}" (길이: ${request.fields['user_id']?.length ?? 0})');
      print('  - name: ${request.fields['name']}');
      print('  - job_position: ${request.fields['job_position']}');
      print('  - department: ${request.fields['department']}');
      print('  - contest_type: ${request.fields['contest_type']}');
      print('  - tool_name: ${request.fields['tool_name']}');
      print('  - work_scope length: ${request.fields['work_scope']?.length ?? 0} characters');
      print('  - work_method length: ${request.fields['work_method']?.length ?? 0} characters');
      print('  - before_after length: ${request.fields['before_after']?.length ?? 0} characters');
      print('  - approval_date: ${request.fields['approval_date']}');

      // 첨부 파일 처리 (files 바이트 리스트로 전송)
      print('\n📁 [ContestApiService] ===== 첨부 파일 바이트 데이터 (files) =====');
      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          final fileData = files[i];

          // 실제 파일명 사용 (없으면 시그니처로 타입 감지)
          String filename;
          String mimeType;

          if (fileNames != null && i < fileNames.length) {
            // 파일명이 제공된 경우
            filename = fileNames[i];

            // 파일 확장자로 MIME 타입 결정
            if (filename.toLowerCase().endsWith('.png')) {
              mimeType = 'image/png';
            } else if (filename.toLowerCase().endsWith('.gif')) {
              mimeType = 'image/gif';
            } else if (filename.toLowerCase().endsWith('.webp')) {
              mimeType = 'image/webp';
            } else {
              mimeType = 'image/jpeg';
            }
          } else {
            // 파일명이 없으면 시그니처로 타입 감지
            String extension = 'jpg';
            mimeType = 'image/jpeg';
            if (fileData.length >= 4) {
              final signature = fileData.take(4).toList();
              if (signature[0] == 0x89 &&
                  signature[1] == 0x50 &&
                  signature[2] == 0x4E &&
                  signature[3] == 0x47) {
                extension = 'png';
                mimeType = 'image/png';
              } else if (signature[0] == 0xFF &&
                  signature[1] == 0xD8 &&
                  signature[2] == 0xFF) {
                extension = 'jpg';
                mimeType = 'image/jpeg';
              } else if (signature[0] == 0x47 &&
                  signature[1] == 0x49 &&
                  signature[2] == 0x46) {
                extension = 'gif';
                mimeType = 'image/gif';
              }
            }
            filename = 'image_$i.$extension';
          }

          // MultipartFile 생성
          final multipartFile = http.MultipartFile.fromBytes(
            'files',
            fileData,
            filename: filename,
            contentType: MediaType.parse(mimeType),
          );

          print('  - 파일 #${i + 1}:');
          print('    * 필드명: ${multipartFile.field}');
          print('    * filename: $filename');
          print('    * contentType: $mimeType');
          print('    * size: ${fileData.length} bytes');
          print('    * 첫 10바이트: ${fileData.take(10).toList()}');

          request.files.add(multipartFile);
        }
        print('  - 총 ${files.length}개 첨부 파일 처리 완료');
      } else {
        print('  - 첨부 파일 없음');
      }

      // 요청 헤더 및 요약 정보 출력
      print('\n📡 [ContestApiService] ===== 요청 정보 요약 =====');
      print('  ✅ Content-Type: multipart/form-data');
      print('  - URL: $url');
      print('  - Method: POST');
      print('  - 필드 개수: ${request.fields.length}');
      print('  - 파일 개수: ${request.files.length}');
      print('  - 모든 필드 키: ${request.fields.keys.toList()}');
      print('  - 모든 파일 필드명: ${request.files.map((f) => f.field).toList()}');

      // Request Body의 모든 파라미터 전송값 확인
      print('\n📦 [ContestApiService] ===== Request Body 모든 파라미터 전송값 =====');
      print('  📋 텍스트 필드 (fields):');
      request.fields.forEach((key, value) {
        if (value.length > 500) {
          print(
              '    * $key: ${value.substring(0, 500)}... (총 ${value.length}자)');
        } else {
          print('    * $key: $value');
        }
      });

      print('  📁 파일 필드 (files):');
      if (request.files.isEmpty) {
        print('    * files: (전송 안 됨 - 파일 없음)');
      } else {
        for (int i = 0; i < request.files.length; i++) {
          final file = request.files[i];
          print('    * files[$i]:');
          print('      - 필드명: ${file.field}');
          print('      - filename: ${file.filename ?? "NULL"}');
          print('      - content_type: ${file.contentType}');
          print(
              '      - 데이터 크기: ${file.length} bytes (${(file.length / 1024).toStringAsFixed(2)} KB)');

          // 바이너리 데이터 샘플 출력 (원본 데이터 사용)
          if (files != null && i < files.length) {
            final bytes = files[i];
            print('      - 데이터 샘플 (처음 50바이트): ${bytes.take(50).toList()}');
            print(
                '      - 데이터 샘플 (16진수): ${bytes.take(50).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
            // 파일 시그니처 확인
            if (bytes.length >= 4) {
              final signature = bytes
                  .take(4)
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join(' ')
                  .toUpperCase();
              print('      - 파일 시그니처: $signature');
              if (signature.contains('89 50 4E 47')) {
                print('      - 파일 타입: PNG 이미지');
              } else if (signature.contains('FF D8 FF')) {
                print('      - 파일 타입: JPEG 이미지');
              } else if (signature.contains('25 50 44 46')) {
                print('      - 파일 타입: PDF');
              }
            }
            print('      - ✅ 바이너리 데이터 전송 확인됨 (${bytes.length} bytes)');
          } else {
            print('      - ⚠️ 원본 데이터를 찾을 수 없음');
          }
        }
        print('    * 총 ${request.files.length}개 파일이 전송됩니다');
      }

      // 실제 MultipartFile 객체들의 상세 정보 확인
      print('\n🔍 [ContestApiService] ===== MultipartFile 객체 상세 정보 =====');
      for (int i = 0; i < request.files.length; i++) {
        final file = request.files[i];
        print('  - 파일 #${i + 1} MultipartFile 객체:');
        print('    * field: ${file.field}');
        print('    * filename: ${file.filename ?? "NULL"}');
        print('    * filename length: ${file.filename?.length ?? 0}');
        print('    * contentType: ${file.contentType}');
        print('    * length: ${file.length}');
        if (file.filename == null || file.filename!.isEmpty) {
          print('    ❌ ERROR: filename이 비어있습니다!');
        }
      }

      // 실제 요청 헤더 확인 (MultipartRequest는 자동으로 boundary를 생성)
      print('\n🔍 [ContestApiService] ===== 실제 요청 헤더 =====');
      final headers = request.headers;
      print(
          '  - Content-Type: ${headers['content-type'] ?? '자동 생성됨 (send() 시점에 설정)'}');
      print('  - Content-Length: ${headers['content-length'] ?? '자동 계산'}');
      if (headers.isNotEmpty) {
        headers.forEach((key, value) {
          if (key != 'content-type' && key != 'content-length') {
            print('  - $key: $value');
          }
        });
      }

      print('\n🚀 [ContestApiService] ===== API 요청 전송 시작 =====');
      final streamedResponse = await request.send();

      // 실제 전송된 요청의 Content-Type 확인
      print('\n📤 [ContestApiService] ===== 실제 전송된 요청 정보 =====');
      print(
          '  - Content-Type: ${streamedResponse.request?.headers['content-type'] ?? '확인 불가'}');

      final response = await http.Response.fromStream(streamedResponse);

      print('\n📥 [ContestApiService] ===== 응답 데이터 =====');
      print('  - Status Code: ${response.statusCode}');
      print('  - Response Headers:');
      response.headers.forEach((key, value) {
        print('    * $key: $value');
      });
      print('  - Response Body Length: ${response.bodyBytes.length} bytes');

      // 응답 본문 출력 (너무 크면 일부만)
      if (response.bodyBytes.length > 10000) {
        print(
            '  - Response Body (처음 1000자): ${response.body.substring(0, 1000)}...');
      } else {
        print('  - Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('\n✅ [ContestApiService] ===== 제출 API 호출 성공 =====');

        // 응답이 JSON인지 확인
        final responseBody = response.body.trim();
        if (responseBody == 'OK' || responseBody.isEmpty) {
          // 단순 텍스트 응답 (OK 또는 빈 응답)
          print('  - 응답: $responseBody');
          return {'success': true, 'message': responseBody};
        }

        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          print('  - 응답 데이터 전체:');
          data.forEach((key, value) {
            if (value is String && value.length > 200) {
              print(
                  '    * $key: ${value.substring(0, 200)}... (길이: ${value.length})');
            } else {
              print('    * $key: $value');
            }
          });
          return data;
        } catch (e) {
          // JSON 파싱 실패해도 성공으로 처리
          print('  - JSON 파싱 실패, 텍스트 응답으로 처리: ${response.body}');
          return {'success': true, 'message': response.body};
        }
      } else {
        print('\n❌ [ContestApiService] ===== 제출 API 호출 실패 =====');
        print('  - Status Code: ${response.statusCode}');
        print('  - Response Body: ${response.body}');

        // 서버 오류인 경우 클라이언트 전송 데이터 검증
        print('\n🔍 [ContestApiService] ===== 클라이언트 전송 데이터 최종 검증 =====');
        print('  ✅ 모든 필드 전송 확인:');
        request.fields.forEach((key, value) {
          if (value.isEmpty) {
            print('    ⚠️ $key: 비어있음');
          } else {
            print('    ✅ $key: 전송됨 (길이: ${value.length})');
          }
        });
        print('  ✅ 파일 전송 확인:');
        if (request.files.isEmpty) {
          print('    ⚠️ 파일 없음');
        } else {
          for (int i = 0; i < request.files.length; i++) {
            final file = request.files[i];
            print('    ✅ 파일 #${i + 1}:');
            print('      - field: ${file.field}');
            print('      - filename: ${file.filename ?? "NULL"}');
            print('      - length: ${file.length} bytes');
            if (file.filename == null || file.filename!.isEmpty) {
              print('      ❌ ERROR: filename이 비어있음!');
            }
          }
        }

        // 서버 오류 메시지 파싱
        String errorMessage;
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
          if (errorData != null && errorData.containsKey('error')) {
            final serverError = errorData['error'] as String;
            errorMessage = '서버 오류: $serverError\n'
                '(클라이언트는 모든 데이터를 올바르게 전송했습니다. 서버 측 문제일 수 있습니다.)';
            print('\n⚠️ [ContestApiService] 서버 오류 감지: $serverError');
            print('  - 클라이언트 전송 데이터는 모두 정상입니다.');
            print('  - 이는 서버 측 처리 문제일 가능성이 높습니다.');
          } else {
            errorMessage = response.body.isNotEmpty
                ? response.body
                : '공모전 신청서 제출 실패. 상태 코드: ${response.statusCode}';
          }
        } catch (e) {
          errorMessage = response.body.isNotEmpty
              ? response.body
              : '공모전 신청서 제출 실패. 상태 코드: ${response.statusCode}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ [ContestApiService] 제출 API 호출 중 오류 발생: $e');
      print('  - 오류 타입: ${e.runtimeType}');
      rethrow;
    }
  }

  /// 공모전 목록 조회 API 호출
  ///
  /// [contestType] 공모전 유형 (기본값: "test")
  /// [viewType] 정렬 기준 ("random", "view_count", "votes")
  /// [userId] 사용자 아이디 (좋아요 상태 확인용)
  /// [category] 카테고리 필터 (빈값이면 전체)
  static Future<Map<String, dynamic>> getContestList({
    String contestType = 'test',
    String viewType = 'random',
    required String userId,
    String category = '',
  }) async {
    final url = Uri.parse('$baseUrl/contest/management');

    try {
      print('🏆 [ContestApiService] ===== 공모전 목록 조회 API 요청 =====');
      print('  - URL: $url');
      print('  - contest_type: $contestType');
      print('  - view_type: $viewType');
      print('  - user_id: $userId');
      print('  - category: $category');
      print('  - include comments: true');

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'contest_type': 'test',
        'view_type': viewType,
        'user_id': userId,
        'category': category,
        'comments': true,
      });

      print('  - Content-Type: application/json');
      print('  - Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        print('✅ [ContestApiService] 목록 조회 API 호출 성공');
        print(
            '  - documents count: ${(data['documents'] as List?)?.length ?? 0}');
        return data;
      } else {
        print('❌ [ContestApiService] 목록 조회 API 호출 실패: ${response.statusCode}');
        throw Exception('공모전 목록 조회 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ContestApiService] 목록 조회 API 호출 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 남은 투표 수 조회 API 호출
  ///
  /// [userId] 사용자 아이디
  /// 반환값: 남은 투표 수
  static Future<int> getRemainingVotes({
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/contest/user/remainVotes');

    try {
      print('🗳️ [ContestApiService] ===== 남은 투표 수 조회 API 요청 =====');
      print('  - URL: $url');
      print('  - contest_type: test');
      print('  - user_id: $userId');

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'contest_type': 'test',
        'user_id': userId,
      });

      print('  - Content-Type: application/json');
      print('  - Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final remainVotes = data['remain_votes'] as int? ?? 0;
        print('✅ [ContestApiService] 남은 투표 수 조회 성공');
        print('  - remain_votes: $remainVotes');
        return remainVotes;
      } else if (response.statusCode == 404) {
        print('⚠️ [ContestApiService] API 엔드포인트가 존재하지 않음 (404) - 기본값 0 반환');
        return 0;
      } else {
        print('❌ [ContestApiService] 남은 투표 수 조회 실패: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      print('❌ [ContestApiService] 남은 투표 수 조회 중 오류 발생: $e');
      return 0; // 에러 시 0 반환
    }
  }

  /// 나의 제출 현황 조회 API 호출 (1인 1사례 정책)
  ///
  /// [userId] 사용자 아이디
  /// 반환값: 단일 제출 현황 객체 (없으면 null)
  static Future<Map<String, dynamic>?> getUserSubmissions({
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/contest/user/management');

    try {
      print('🏆 [ContestApiService] ===== 나의 제출 현황 API 요청 =====');
      print('  - URL: $url');
      print('  - contest_type: test');
      print('  - user_id: $userId');

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'contest_type': 'test',
        'user_id': userId,
      });

      final response = await http.post(url, headers: headers, body: body);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        
        // 응답이 직접 객체로 반환됨 (documents 배열 없음)
        if (data.isEmpty) {
          print('✅ [ContestApiService] 제출 현황 없음 (응답 데이터가 비어있음)');
          return null;
        }
        
        print('✅ [ContestApiService] 제출 현황 조회 성공');
        print('  - contest_id: ${data['contest_id']}');
        print('  - title: ${data['title']}');
        print('  - votes: ${data['votes']}');
        print('  - view_count: ${data['view_count']}');
        print('  - like_count: ${data['like_count']}');
        print('  - tool_name: ${data['tool_name']}');
        print('  - work_scope: ${data['work_scope'] != null ? '${(data['work_scope'] as String).length}자' : '없음'}');
        print('  - work_method: ${data['work_method'] != null ? '${(data['work_method'] as String).length}자' : '없음'}');
        print('  - before_after: ${data['before_after'] != null ? '${(data['before_after'] as String).length}자' : '없음'}');
        print('  - attachment_urls: ${data['attachment_urls'] != null ? '있음' : '없음'}');
        
        return data;
      } else {
        print('❌ [ContestApiService] 제출 현황 조회 실패: ${response.statusCode}');
        throw Exception('나의 제출 현황 조회 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ContestApiService] 제출 현황 조회 중 오류 발생: $e');

      // ClientException 등 네트워크 오류 시 데이터 없음으로 처리
      if (e.toString().contains('ClientException') ||
          e.toString().contains('Connection closed') ||
          e.toString().contains('SocketException')) {
        print('ℹ️ [ContestApiService] 네트워크 오류 또는 데이터 없음으로 처리');
        return null;
      }

      rethrow;
    }
  }

  /// 공모전 상세 조회 시 조회수 증가 API 호출
  ///
  /// [contestId] 공모전 ID
  static Future<void> incrementViewCount(int contestId) async {
    // TODO: 조회수 증가 API가 별도로 있다면 구현
    // 현재는 상세보기 클릭 시 자동으로 증가한다고 가정
    print('📊 [ContestApiService] 조회수 증가: contest_id=$contestId');
  }

  /// 파일 URL 조회 API 호출
  ///
  /// [fileName] 파일명
  /// [prefix] 파일 경로 prefix
  /// [approvalType] 승인 타입 (기본값: "contest")
  /// [isDownload] 다운로드 여부 (0: 미리보기, 1: 다운로드)
  static Future<String?> getFileUrl({
    required String fileName,
    required String prefix,
    String approvalType = 'contest',
    int isDownload = 0,
  }) async {
    final url = Uri.parse('$baseUrl/api/getFileUrl');

    try {
      print('🖼️ [ContestApiService] ===== 파일 URL 조회 API 요청 =====');
      print('  - URL: $url');
      print('  - file_name: $fileName');
      print('  - prefix: $prefix');
      print('  - approval_type: $approvalType');
      print('  - is_download: $isDownload');

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'file_name': fileName,
        'prefix': prefix,
        'approval_type': approvalType,
        'is_download': isDownload,
      });

      final response = await http.post(url, headers: headers, body: body);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.body.trim();

        // JSON 응답인 경우
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map<String, dynamic>) {
            final fileUrl =
                data['url'] as String? ?? data['file_url'] as String?;
            print('✅ [ContestApiService] 파일 URL 조회 성공: $fileUrl');
            return fileUrl;
          } else if (data is String) {
            print('✅ [ContestApiService] 파일 URL 조회 성공: $data');
            return data;
          }
        } catch (e) {
          // JSON이 아닌 경우 문자열로 처리
          if (responseBody.isNotEmpty) {
            print('✅ [ContestApiService] 파일 URL 조회 성공: $responseBody');
            return responseBody;
          }
        }
        return null;
      } else {
        print('❌ [ContestApiService] 파일 URL 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [ContestApiService] 파일 URL 조회 중 오류 발생: $e');
      return null;
    }
  }

  /// 공모전 상세 정보 조회 API 호출
  ///
  /// [contestId] 공모전 ID
  static Future<Map<String, dynamic>> getContestDetail(int contestId) async {
    final url = Uri.parse('$baseUrl/contest/management/detail');

    try {
      print('🏆 [ContestApiService] ===== 공모전 상세 조회 API 요청 =====');
      print('  - URL: $url');
      print('  - contest_id: $contestId');

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'contest_type': 'test',
        'contest_id': contestId,
      });

      print('  - Content-Type: application/json');
      print('  - Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        print('✅ [ContestApiService] 상세 조회 API 호출 성공');
        print('  - title: ${data['title']}');
        print('  - tool_name: ${data['tool_name'] ?? '없음'}');
        print('  - work_scope: ${data['work_scope'] != null ? '${(data['work_scope'] as String).length}자' : '없음'}');
        print('  - work_method: ${data['work_method'] != null ? '${(data['work_method'] as String).length}자' : '없음'}');
        print('  - before_after: ${data['before_after'] != null ? '${(data['before_after'] as String).length}자' : '없음'}');
        print('  - votes: ${data['votes']}');
        print(
            '  - attachment_urls: ${data['attachment_urls'] != null ? '${(data['attachment_urls'] as List).length}개' : '없음'}');
        return data;
      } else {
        print('❌ [ContestApiService] 상세 조회 API 호출 실패: ${response.statusCode}');
        throw Exception('공모전 상세 조회 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ContestApiService] 상세 조회 API 호출 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 투표 API 호출
  ///
  /// [contestType] 공모전 유형 (예: "사내 혁신 아이디어 공모전")
  /// [contestId] 공모전 ID
  /// [userId] 사용자 ID
  static Future<Map<String, dynamic>> voteContest({
    required String contestType,
    required int contestId,
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/contest/vote');
    const timeoutDuration = Duration(seconds: 30);

    try {
      print('🏆 [ContestApiService] ===== 투표 API 요청 =====');
      print('  - URL: $url');

      final headers = {'Content-Type': 'application/json'};
      final requestBody = {
        'contest_type': 'test',
        'contest_id': contestId,
        'user_id': userId,
      };
      final body = jsonEncode(requestBody);

      // 실제 전송되는 파라미터 3개 출력
      print('  - contest_type: ${requestBody['contest_type']}');
      print('  - contest_id: ${requestBody['contest_id']}');
      print('  - user_id: ${requestBody['user_id']}');
      print('  - Content-Type: application/json');
      print('  - Body: $body');

      final response =
          await http.post(url, headers: headers, body: body).timeout(
        timeoutDuration,
        onTimeout: () {
          throw TimeoutException(
            '투표 API 요청 시간 초과 (${timeoutDuration.inSeconds}초)',
            timeoutDuration,
          );
        },
      );

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 응답이 "OK" 문자열인 경우 처리
        final responseBody = response.body.trim();
        if (responseBody == 'OK' || responseBody.isEmpty) {
          print('✅ [ContestApiService] 투표 API 호출 성공 (OK 응답)');
          return {'success': true, 'message': '투표가 완료되었습니다.'};
        }

        // JSON 응답인 경우 파싱
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;

          // error 필드 확인
          if (data.containsKey('error') && data['error'] != null) {
            final errorMessage = data['error'] as String;
            print('⚠️ [ContestApiService] 투표 API 응답에 오류 포함: $errorMessage');
            return {'error': errorMessage};
          }

          print('✅ [ContestApiService] 투표 API 호출 성공');
          return data;
        } on FormatException catch (e) {
          print('⚠️ [ContestApiService] JSON 파싱 실패, 응답을 문자열로 처리: $e');
          print('✅ [ContestApiService] 투표 API 호출 성공 (비JSON 응답)');
          return {'success': true, 'message': responseBody};
        }
      } else {
        print('❌ [ContestApiService] 투표 API 호출 실패: ${response.statusCode}');
        String errorMessage = '투표 실패. 상태 코드: ${response.statusCode}';

        // 응답이 JSON인 경우 에러 메시지 추출 시도
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>?;
          errorMessage = errorData?['error'] as String? ?? errorMessage;
        } catch (e) {
          // JSON 파싱 실패 시 원본 응답 사용
          errorMessage =
              response.body.isNotEmpty ? response.body : errorMessage;
        }

        // 중복 투표 오류 감지
        if (errorMessage
                .contains('duplicate key value violates unique constraint') ||
            errorMessage.contains('ux_vote_detail')) {
          throw Exception('중복 투표는 허용 되지 않습니다. 다른 사례에 투표 해주세요.');
        }

        throw Exception(errorMessage);
      }
    } on TimeoutException catch (e) {
      print('⏱️ [ContestApiService] 투표 API 타임아웃: $e');
      throw Exception('투표 API 요청 시간 초과. 서버 응답이 지연되고 있습니다.');
    } on http.ClientException catch (e) {
      print('🔌 [ContestApiService] 투표 API 연결 오류: $e');
      throw Exception('투표 API 연결 실패. 네트워크 연결을 확인해주세요.');
    } catch (e) {
      print('❌ [ContestApiService] 투표 API 호출 중 오류 발생: $e');

      // 중복 투표 오류 감지
      final errorString = e.toString();
      if (errorString
              .contains('duplicate key value violates unique constraint') ||
          errorString.contains('ux_vote_detail')) {
        throw Exception('중복 투표는 허용 되지 않습니다. 다른 사례에 투표 해주세요.');
      }

      rethrow;
    }
  }

  /// 댓글 목록 조회 API 호출
  ///
  /// [contestId] 공모전 ID
  static Future<List<Map<String, dynamic>>> getComments(int contestId) async {
    final url = Uri.parse('$baseUrl/contest/comment/management');

    try {
      print('💬 [ContestApiService] ===== 댓글 목록 조회 API 요청 =====');
      print('  - URL: $url');
      print('  - contest_id: $contestId');

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'contest_type': 'test',
        'contest_id': contestId,
      });

      final response = await http.post(url, headers: headers, body: body);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));

        List<dynamic> rawComments;
        if (decoded is List) {
          rawComments = decoded;
        } else if (decoded is Map<String, dynamic>) {
          rawComments = decoded['comments'] as List<dynamic>? ?? [];
        } else {
          rawComments = [];
        }

        final normalizedComments =
            rawComments.whereType<Map<String, dynamic>>().map((comment) {
          final normalized = Map<String, dynamic>.from(comment);
          final rawId = normalized['comment_id'] ??
              normalized['commentId'] ??
              normalized['id'];
          if (rawId != null) {
            final parsedId =
                rawId is int ? rawId : int.tryParse(rawId.toString());
            if (parsedId != null) {
              normalized['comment_id'] = parsedId;
            }
          }
          return normalized;
        }).toList();

        print(
            '✅ [ContestApiService] 댓글 목록 조회 성공: ${normalizedComments.length}개 (comment_id 포함)');
        return normalizedComments;
      } else {
        print('❌ [ContestApiService] 댓글 목록 조회 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ [ContestApiService] 댓글 목록 조회 중 오류 발생: $e');
      return [];
    }
  }

  /// 댓글 작성 API 호출
  ///
  /// [contestId] 공모전 ID
  /// [userId] 사용자 ID
  /// [comment] 댓글 내용
  /// [files] 이미지 byte 파일 리스트 (선택)
  /// [fileNames] 파일명 리스트 (files와 동일한 순서, 선택)
  static Future<Map<String, dynamic>> addComment({
    required int contestId,
    required String userId,
    required String comment,
    List<Uint8List>? files,
    List<String>? fileNames,
  }) async {
    final url = Uri.parse('$baseUrl/contest/comment/request');

    try {
      print('💬 [ContestApiService] ===== 댓글 작성 API 요청 =====');
      print('  - URL: $url');
      print('  - contest_id: $contestId');
      print('  - user_id: $userId');
      print('  - comment: $comment');
      print('  - files: ${files?.length ?? 0}개');

      // multipart/form-data로 전송
      final request = http.MultipartRequest('POST', url);

      // 텍스트 필드 추가
      request.fields['contest_type'] = 'test';
      request.fields['contest_id'] = contestId.toString();
      request.fields['user_id'] = userId;
      request.fields['comment'] = comment;

      // 파일 첨부
      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          // 실제 파일명 사용 (없으면 기본값)
          final fileName = (fileNames != null && i < fileNames.length)
              ? fileNames[i]
              : 'image_$i.jpg';

          // 파일 확장자로 MIME 타입 결정
          String mimeType = 'image/jpeg';
          String extension = 'jpg';
          if (fileName.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
            extension = 'png';
          } else if (fileName.toLowerCase().endsWith('.gif')) {
            mimeType = 'image/gif';
            extension = 'gif';
          } else if (fileName.toLowerCase().endsWith('.webp')) {
            mimeType = 'image/webp';
            extension = 'webp';
          }

          // 파일명에 확장자가 없으면 추가
          final finalFileName =
              fileName.contains('.') ? fileName : '$fileName.$extension';

          request.files.add(
            http.MultipartFile.fromBytes(
              'files',
              files[i],
              filename: finalFileName,
              contentType: MediaType.parse(mimeType),
            ),
          );

          print(
              '  - File #${i + 1}: $finalFileName (${files[i].length} bytes, $mimeType)');
        }
        print('  - Files count: ${files.length}');
      }

      print('  - Content-Type: multipart/form-data');
      print('  - Request fields: ${request.fields}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.body.trim();
        if (responseBody == 'OK' || responseBody.isEmpty) {
          print('✅ [ContestApiService] 댓글 작성 성공');
          return {'success': true, 'message': '댓글이 등록되었습니다.'};
        }

        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;

          final rawId = data['comment_id'] ?? data['commentId'] ?? data['id'];
          if (rawId != null) {
            final parsedId =
                rawId is int ? rawId : int.tryParse(rawId.toString());
            if (parsedId != null) {
              data['comment_id'] = parsedId;
            }
          }

          print('✅ [ContestApiService] 댓글 작성 성공');
          print('  - comment_id: ${data['comment_id']}');
          return data;
        } catch (e) {
          return {'success': true, 'message': responseBody};
        }
      } else {
        print('❌ [ContestApiService] 댓글 작성 실패: ${response.statusCode}');
        String errorMessage = '댓글 작성 실패. 상태 코드: ${response.statusCode}';

        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>?;
          errorMessage = errorData?['error'] as String? ?? errorMessage;
        } catch (e) {
          errorMessage =
              response.body.isNotEmpty ? response.body : errorMessage;
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ [ContestApiService] 댓글 작성 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 댓글 삭제 API 호출
  ///
  /// [commentId] 댓글 ID
  /// [userId] 사용자 ID
  static Future<Map<String, dynamic>> deleteComment({
    required int commentId,
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/contest/comment/delete');

    try {
      print('💬 [ContestApiService] ===== 댓글 삭제 API 요청 =====');
      print('  - URL: $url');
      print('  - comment_id: $commentId');
      print('  - user_id: $userId');

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'comment_id': commentId,
        'user_id': userId,
      });

      final response = await http.post(url, headers: headers, body: body);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.body.trim();
        if (responseBody == 'OK' || responseBody.isEmpty) {
          print('✅ [ContestApiService] 댓글 삭제 성공');
          return {'success': true, 'message': '댓글이 삭제되었습니다.'};
        }

        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;

          // error 필드 확인
          if (data.containsKey('error') && data['error'] != null) {
            final errorMessage = data['error'] as String;
            print('⚠️ [ContestApiService] 댓글 삭제 응답에 오류 포함: $errorMessage');
            throw Exception(errorMessage);
          }

          print('✅ [ContestApiService] 댓글 삭제 성공');
          return data;
        } catch (e) {
          if (e is Exception) rethrow;
          return {'success': true, 'message': responseBody};
        }
      } else {
        print('❌ [ContestApiService] 댓글 삭제 실패: ${response.statusCode}');
        String errorMessage = '댓글 삭제 실패. 상태 코드: ${response.statusCode}';

        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>?;
          errorMessage = errorData?['error'] as String? ?? errorMessage;
        } catch (e) {
          errorMessage =
              response.body.isNotEmpty ? response.body : errorMessage;
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ [ContestApiService] 댓글 삭제 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 좋아요 API 호출
  ///
  /// [contestId] 공모전 ID
  /// [userId] 사용자 ID
  ///
  /// 반환값: {'contest_id': String, 'like_count': int, 'is_canceled': int}
  /// is_canceled: 0 = 좋아요 누른 상태, 1 = 좋아요 취소 상태
  static Future<Map<String, dynamic>> likeContest({
    required int contestId,
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/contest/like');

    try {
      print('👍 [ContestApiService] ===== 좋아요 API 요청 =====');
      print('  - URL: $url');
      print('  - contest_type: test');
      print('  - contest_id: $contestId');
      print('  - user_id: $userId');

      final headers = {'Content-Type': 'application/json'};
      final requestBody = {
        'contest_type': 'test',
        'contest_id': contestId,
        'user_id': userId,
      };
      final body = jsonEncode(requestBody);

      print('📤 [ContestApiService] Request Body:');
      print('  - contest_type: ${requestBody['contest_type']}');
      print('  - contest_id: ${requestBody['contest_id']}');
      print('  - user_id: ${requestBody['user_id']}');
      print('  - JSON: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('📥 [ContestApiService] Response:');
      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body (raw): ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final likeCount = data['like_count'] as int? ?? 0;
        final isCanceled = data['is_canceled'] as int? ?? 1;
        print('✅ [ContestApiService] 좋아요 API 성공');
        print('  - like_count: $likeCount');
        print(
            '  - is_canceled: $isCanceled (${isCanceled == 0 ? "좋아요 상태" : "취소 상태"})');
        return {
          'contest_id': data['contest_id'],
          'like_count': likeCount,
          'is_canceled': isCanceled,
        };
      } else {
        print('❌ [ContestApiService] 좋아요 실패: ${response.statusCode}');
        throw Exception('좋아요 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ContestApiService] 좋아요 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 사용자 정보 조회 API 호출
  ///
  /// [userId] 사용자 아이디
  ///
  /// 반환값: {'name': String, 'department': String, 'job_position': String}
  static Future<Map<String, dynamic>> getUserInfo({
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/contest/userInfo');

    try {
      print('👤 [ContestApiService] ===== 사용자 정보 조회 API 요청 =====');
      print('  - URL: $url');
      print('  - user_id: $userId');

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'user_id': userId,
      });

      print('  - Content-Type: application/json');
      print('  - Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        print('✅ [ContestApiService] 사용자 정보 조회 성공');
        print('  - name: ${data['name']}');
        print('  - department: ${data['department']}');
        print('  - job_position: ${data['job_position']}');
        return data;
      } else {
        print('❌ [ContestApiService] 사용자 정보 조회 실패: ${response.statusCode}');
        throw Exception('사용자 정보 조회 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ContestApiService] 사용자 정보 조회 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 사용자 제출 여부 체크 API 호출
  ///
  /// [userId] 사용자 아이디
  /// [contestType] 공모전 유형 (기본값: "test")
  ///
  /// 반환값: {'status': int} (1: 제출함, 0: 미제출)
  static Future<Map<String, dynamic>> checkUserSubmission({
    required String userId,
    String contestType = 'test',
  }) async {
    final url = Uri.parse('$baseUrl/contest/user/check');

    try {
      print('🔍 [ContestApiService] ===== 사용자 제출 여부 체크 API 요청 =====');
      print('  - URL: $url');
      print('  - contest_type: $contestType');
      print('  - user_id: $userId');

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'contest_type': contestType,
        'user_id': userId,
      });

      print('  - Content-Type: application/json');
      print('  - Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final status = data['status'] as int? ?? 0;
        print('✅ [ContestApiService] 제출 여부 체크 성공');
        print('  - status: $status (${status == 1 ? "제출함" : "미제출"})');
        return data;
      } else {
        print('❌ [ContestApiService] 제출 여부 체크 실패: ${response.statusCode}');
        // 실패 시 미제출로 간주
        return {'status': 0};
      }
    } catch (e) {
      print('❌ [ContestApiService] 제출 여부 체크 중 오류 발생: $e');
      // 오류 시 미제출로 간주
      return {'status': 0};
    }
  }

  /// 공모전 신청서 수정 API 호출
  ///
  /// [userId] 사용자 아이디
  /// [contestId] 공모전 ID
  /// [title] 제목
  /// [toolName] 사용한 AI TOOL
  /// [workScope] 어떤 업무에 적용 했나요?
  /// [workMethod] 어떤 방식으로 사용 했나요?
  /// [beforeAfter] Before & After
  /// [files] 이미지 byte 파일 리스트 (null 가능)
  static Future<Map<String, dynamic>> updateContest({
    required String userId,
    required int contestId,
    required String title,
    required String toolName,
    required String workScope,
    required String workMethod,
    required String beforeAfter,
    List<Uint8List>? files,
    List<Map<String, dynamic>>? existingFiles, // 남아있는 기존 파일 정보
  }) async {
    final url = Uri.parse('$baseUrl/contest/update');

    try {
      print('🏆 [ContestApiService] ===== 공모전 신청서 수정 API 요청 =====');
      print('  - URL: $url');
      print('  - user_id: $userId');
      print('  - contest_type: test');
      print('  - contest_id: $contestId');
      print('  - title: $title');
      print('  - tool_name: $toolName');
      print('  - work_scope length: ${workScope.length}');
      print('  - work_method length: ${workMethod.length}');
      print('  - before_after length: ${beforeAfter.length}');
      print('  - files: ${files?.length ?? 0}개');

      // multipart/form-data로 전송 (파일 포함)
      print('\n📤 [ContestApiService] ===== 요청 데이터 준비 =====');
      print('  ✅ 전송 방식: multipart/form-data');
      final request = http.MultipartRequest('POST', url);

      // 필드 추가
      request.fields['user_id'] = userId;
      request.fields['contest_type'] = 'test';
      request.fields['contest_id'] = contestId.toString();
      request.fields['title'] = title;
      request.fields['tool_name'] = toolName;
      request.fields['work_scope'] = workScope;
      request.fields['work_method'] = workMethod;
      request.fields['before_after'] = beforeAfter;
      
      // 남아있는 기존 파일 정보 전달 (삭제된 파일은 제외)
      if (existingFiles != null && existingFiles.isNotEmpty) {
        final existingFilesJson = jsonEncode(existingFiles);
        request.fields['existing_files'] = existingFilesJson;
        print('  - existing_files: ${existingFiles.length}개 (JSON: $existingFilesJson)');
      } else {
        // 기존 파일이 모두 삭제된 경우 빈 배열 전달
        request.fields['existing_files'] = '[]';
        print('  - existing_files: [] (모든 기존 파일 삭제됨)');
      }

      // 첨부 파일 처리
      print('\n📁 [ContestApiService] ===== 첨부 파일 바이트 데이터 (files) =====');
      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          final fileData = files[i];

          // 파일 시그니처로 실제 타입 감지
          String extension = 'jpg';
          String mimeType = 'image/jpeg';
          if (fileData.length >= 4) {
            final signature = fileData.take(4).toList();
            if (signature[0] == 0x89 &&
                signature[1] == 0x50 &&
                signature[2] == 0x4E &&
                signature[3] == 0x47) {
              extension = 'png';
              mimeType = 'image/png';
            } else if (signature[0] == 0xFF &&
                signature[1] == 0xD8 &&
                signature[2] == 0xFF) {
              extension = 'jpg';
              mimeType = 'image/jpeg';
            } else if (signature[0] == 0x47 &&
                signature[1] == 0x49 &&
                signature[2] == 0x46) {
              extension = 'gif';
              mimeType = 'image/gif';
            }
          }

          final filename = 'image_$i.$extension';

          final multipartFile = http.MultipartFile.fromBytes(
            'files',
            fileData,
            filename: filename,
            contentType: MediaType.parse(mimeType),
          );

          print('  - 파일 #${i + 1}:');
          print('    * 필드명: ${multipartFile.field}');
          print('    * filename: $filename');
          print('    * contentType: $mimeType');
          print('    * size: ${fileData.length} bytes');

          request.files.add(multipartFile);
        }
        print('  - 총 ${files.length}개 첨부 파일 처리 완료');
      } else {
        print('  - 첨부 파일 없음');
      }

      print('\n📡 [ContestApiService] ===== 요청 정보 요약 =====');
      print('  ✅ Content-Type: multipart/form-data');
      print('  - URL: $url');
      print('  - Method: POST');
      print('  - 필드 개수: ${request.fields.length}');
      print('  - 파일 개수: ${request.files.length}');
      print('\n📋 [ContestApiService] ===== 전송 필드 값 (수정 API) =====');
      request.fields.forEach((key, value) {
        if (key == 'user_id') {
          print('    🔑 $key: "$value" (길이: ${value.length})');
        } else if (value.length > 200) {
          print('    * $key: ${value.substring(0, 200)}... (총 ${value.length}자)');
        } else {
          print('    * $key: $value');
        }
      });

      print('\n🚀 [ContestApiService] ===== API 요청 전송 시작 =====');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('\n📥 [ContestApiService] ===== 응답 데이터 =====');
      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('\n✅ [ContestApiService] ===== 수정 API 호출 성공 =====');

        final responseBody = response.body.trim();
        if (responseBody == 'OK' || responseBody.isEmpty) {
          print('  - 응답: $responseBody');
          return {'success': true, 'message': responseBody};
        }

        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          print('  - 응답 데이터 전체:');
          data.forEach((key, value) {
            if (value is String && value.length > 200) {
              print(
                  '    * $key: ${value.substring(0, 200)}... (길이: ${value.length})');
            } else {
              print('    * $key: $value');
            }
          });
          return data;
        } catch (e) {
          print('  - JSON 파싱 실패, 텍스트 응답으로 처리: ${response.body}');
          return {'success': true, 'message': response.body};
        }
      } else {
        print('\n❌ [ContestApiService] ===== 수정 API 호출 실패 =====');
        print('  - Status Code: ${response.statusCode}');
        print('  - Response Body: ${response.body}');

        String errorMessage;
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
          if (errorData != null && errorData.containsKey('error')) {
            final serverError = errorData['error'] as String;
            errorMessage = '서버 오류: $serverError';
          } else {
            errorMessage = response.body.isNotEmpty
                ? response.body
                : '공모전 신청서 수정 실패. 상태 코드: ${response.statusCode}';
          }
        } catch (e) {
          errorMessage = response.body.isNotEmpty
              ? response.body
              : '공모전 신청서 수정 실패. 상태 코드: ${response.statusCode}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ [ContestApiService] 수정 API 호출 중 오류 발생: $e');
      print('  - 오류 타입: ${e.runtimeType}');
      rethrow;
    }
  }
}
