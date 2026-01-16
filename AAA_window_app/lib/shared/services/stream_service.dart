import 'dart:async';
import 'dart:convert';
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';
import 'package:ASPN_AI_AGENT/shared/providers/attachment_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:ASPN_AI_AGENT/core/database/database_helper.dart'; // 로컬 DB 헬퍼 임포트
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart'; // 추가된 ApiService 임포트

class StreamService {
  static final DatabaseHelper _dbHelper = DatabaseHelper(); // 로컬 DB 헬퍼 인스턴스

  static Stream<String> getEventStream(String category, String module,
      String archiveId, String userId, String message,
      {List<CustomPlatformFile>? files}) async* {
    final url =
        Uri.parse('${AppConfig.baseUrl}/streamChat/timeout'); // 엔드포인트 URL
    final client = http.Client();

    try {
      final fileList = files ?? [];

      print('\n=== StreamService.getEventStream 요청 디버깅 ===');
      print('파일 수: ${fileList.length}');
      print('URL: $url');
      print('Category: $category');
      print('Message: $message');

      late final response;

      // 모든 요청을 multipart/form-data로 통일
      print('🔄 Multipart 방식 사용 (통일)');
      var request = http.MultipartRequest('POST', url);
      // MultipartRequest가 boundary 포함 Content-Type을 자동 설정함

      // 텍스트 필드 추가
      request.fields['category'] = category;
      request.fields['module'] = module;
      request.fields['archive_id'] = archiveId;
      request.fields['user_id'] = userId;
      request.fields['message'] = message;

      print('📤 Multipart 필드:');
      request.fields.forEach((key, value) {
        print('   $key: $value');
      });

      // 파일이 있는 경우에만 첨부
      for (var file in fileList) {
        if (file.bytes != null) {
          final multipartFile = http.MultipartFile.fromBytes(
            'files', // 'attachments'에서 'files'로 변경
            file.bytes!,
            filename: file.name,
            contentType: MediaType.parse(file.mimeType),
          );
          request.files.add(multipartFile);
          print('📎 파일 첨부: ${file.name}');
          print('   - 크기: ${file.bytes!.length} bytes');
          print('   - MIME 타입: ${file.mimeType}');
          print('   - 바이너리 데이터 첫 10바이트: ${file.bytes!.take(10).toList()}');
        }
      }

      print('📤 총 첨부 파일 수: ${request.files.length}');
      print('📤 Request body 구성:');
      print('   - 텍스트 필드 수: ${request.fields.length}');
      print('   - 바이너리 파일 수: ${request.files.length}');
      request.files.forEach((file) {
        print(
            '   - 파일: ${file.filename} (${file.length} bytes, ${file.contentType})');
      });
      response = await client.send(request);

      print('📥 서버 응답 상태: ${response.statusCode}');
      print('📥 응답 헤더: ${response.headers}');

      // 응답 처리 부분 수정
      if (response.statusCode == 200 || response.statusCode == 400) {
        // message 헤더 처리 (공통)
        if (response.headers.containsKey('message')) {
          final messageHeader = response.headers['message']!;
          final decodedMessage = utf8.decode(latin1.encode(messageHeader));
          yield decodedMessage;

          // 400 상태일 때는 오류 로그만 남김
          if (response.statusCode == 400) {
            print('서버 오류 발생 (상태 코드: 400) - 메시지 저장하지 않음');
          }
        }

        // 상태 코드가 200일 때만 저장
        if (response.statusCode == 200) {
          print('All Response Headers: ${response.headers}');

          // chat_id 헤더에서 가져오기 (이전 버전 방식)
          int? userChatId;
          if (response.headers.containsKey('chat_id')) {
            try {
              userChatId = int.parse(response.headers['chat_id']!);
              print('Chat ID from header: $userChatId');

              // chat_id가 있을 때만 사용자 메시지 저장 (이전 버전 방식)
              await _dbHelper.insertUserMessage(archiveId, message, userId,
                  chat_id: userChatId);
              print('사용자 메시지를 chat_id $userChatId로 로컬 DB에 저장 완료');
            } catch (e) {
              print('chat_id 파싱 오류: $e');
            }
          } else {
            print('chat_id 헤더가 없어 사용자 메시지 저장하지 않음');
          }

          // Category 헤더 값을 확인하여 범주별 메시지를 최상단에 yield
          if (response.headers.containsKey('category')) {
            final categoryHeader = response.headers['category']!.toLowerCase();
            final contentType = response.headers['content-type'] ?? '';
            print('서버에서 받은 category 헤더: $categoryHeader');
            print('서버에서 받은 Content-Type 헤더: $contentType');

            // HR 카테고리이면서 Content-Type이 text/event-stream인 경우 특별 처리 (휴가상신초안)
            if ((categoryHeader == 'hr' ||
                    categoryHeader == 'hr_leave_apply') &&
                contentType.contains('text/event-stream')) {
              print(
                  '🏢 [StreamService] HR 휴가 데이터 SSE 응답 감지됨 (category: $categoryHeader)');
              print(
                  '🏢 [StreamService] Category: $categoryHeader, Content-Type: $contentType');
              print('🏢 [StreamService] 스트림 파싱 시작...');

              String currentEventType = '';
              int lineCount = 0;
              String accumulatedResponse = '';

              await for (String line in response.stream
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())) {
                lineCount++;
                // 라인 로그 제거됨

                if (line.startsWith('event: ')) {
                  currentEventType = line.substring(7).trim();
                  print(
                      '📡 [StreamService] SSE 이벤트 타입 감지: "$currentEventType"');
                  continue;
                }

                if (line.startsWith('data: ')) {
                  final data = line.substring(6);
                  // 데이터 로그 제거됨

                  if (data.isNotEmpty) {
                    // JSON 이벤트인 경우 휴가상신초안 모달 트리거
                    if (currentEventType == 'json') {
                      // JSON 형식인 경우에만 처리 시작 로그 출력
                      if (data.trim().startsWith('{') &&
                          data.trim().endsWith('}')) {
                        print('🎯 [StreamService] JSON 이벤트 처리 시작');
                      }
                      // JSON인지 먼저 확인
                      if (data.trim().startsWith('{') &&
                          data.trim().endsWith('}')) {
                        try {
                          final jsonData = jsonDecode(data);
                          print('✅ [StreamService] JSON 파싱 성공');
                          print('📋 [StreamService] 파싱된 데이터: $jsonData');
                          print(
                              '📋 [StreamService] JSON 키 목록: ${jsonData.keys.toList()}');

                          // 필수 필드 검증
                          final requiredFields = [
                            'user_id',
                            'start_date',
                            'end_date',
                            'leave_type'
                          ];
                          for (final field in requiredFields) {
                            if (jsonData.containsKey(field)) {
                              print(
                                  '✅ [StreamService] 필수 필드 확인: $field = ${jsonData[field]}');
                            } else {
                              print('⚠️ [StreamService] 필수 필드 누락: $field');
                            }
                          }

                          // 휴가상신초안 모달 트리거를 위한 특별한 yield
                          final triggerJson =
                              '{"type":"trigger_leave_modal","data":${jsonEncode(jsonData)}}';
                          print('🎯 [StreamService] 트리거 JSON 생성 완료');
                          print(
                              '🎯 [StreamService] 트리거 JSON 길이: ${triggerJson.length}');

                          yield triggerJson;
                          print('✅ [StreamService] 트리거 JSON yield 완료');
                        } catch (e, stackTrace) {
                          print('❌ [StreamService] HR JSON 파싱 오류 발생');
                          print('❌ [StreamService] 오류 타입: ${e.runtimeType}');
                          print('❌ [StreamService] 오류 메시지: $e');
                          print('❌ [StreamService] 원본 데이터: "$data"');
                          print('❌ [StreamService] 스택 트레이스: $stackTrace');
                          final errorMessage = '휴가 데이터 처리 중 오류가 발생했습니다: $e';
                          accumulatedResponse += errorMessage;
                          yield errorMessage;
                        }
                      } else {
                        // JSON 형식 경고 로그 제거됨
                        accumulatedResponse += data;
                        yield data; // JSON이 아니면 일반 메시지로 처리
                      }
                    } else {
                      // 일반 메시지 이벤트
                      accumulatedResponse += data;
                      yield data;
                    }
                  } else {
                    print('⚠️ [StreamService] 빈 데이터 라인 무시');
                  }
                } else if (line.trim().isNotEmpty) {
                  print('⚠️ [StreamService] 알 수 없는 라인 형식: "$line"');
                }
              }

              print('🏁 [StreamService] HR SSE 스트림 처리 완료 (총 $lineCount 라인)');

              if (accumulatedResponse.isNotEmpty) {
                try {
                  final processedResponse = accumulatedResponse
                      .replaceAll('\\n\\n', '\n\n')
                      .replaceAll('\\n', '\n');

                  int chatId;
                  try {
                    chatId = await ApiService.getlastChatId(archiveId, userId);
                    print('서버 DB에서 조회한 마지막 chat_id: $chatId');
                  } catch (e) {
                    print('getlastChatId 조회 실패: $e');
                    await _dbHelper.insertAgentMessage(
                        archiveId, processedResponse, userId);
                    print('AI 응답 메시지를 로컬 DB에 저장 완료 (chat_id 없음)');
                    return;
                  }

                  print('\n=== 로컬 DB에 저장될 AI 응답 메시지 ===');
                  print('서버 DB에서 조회한 chat_id: $chatId');
                  print('메시지 내용:\n$processedResponse');
                  print(
                      '=======================================================\n');

                  await _dbHelper.insertAgentMessage(
                      archiveId, processedResponse, userId,
                      chat_id: chatId);
                  print('AI 응답 메시지를 chat_id $chatId로 로컬 DB에 저장 완료');
                } catch (e) {
                  print('AI 응답 메시지 저장 실패: $e');
                }
              }
              return;
            }

            // HR_LEAVE_GRANT 카테고리이면서 Content-Type이 text/event-stream인 경우 특별 처리 (휴가 부여 상신)
            if (categoryHeader == 'hr_leave_grant' &&
                contentType.contains('text/event-stream')) {
              print('🏢 [StreamService] 휴가 부여 상신 SSE 응답 감지됨');
              print(
                  '🏢 [StreamService] Category: $categoryHeader, Content-Type: $contentType');
              print('🏢 [StreamService] 스트림 파싱 시작...');

              String currentEventType = '';
              int lineCount = 0;
              String accumulatedResponse = '';

              await for (String line in response.stream
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())) {
                lineCount++;
                // 라인 로그 제거됨

                if (line.startsWith('event: ')) {
                  currentEventType = line.substring(7).trim();
                  print(
                      '📡 [StreamService] SSE 이벤트 타입 감지: "$currentEventType"');
                  continue;
                }

                if (line.startsWith('data: ')) {
                  final data = line.substring(6);
                  // 데이터 로그 제거됨

                  if (data.isNotEmpty) {
                    // JSON 이벤트인 경우 휴가 부여 상신 전자결재 모달 트리거
                    if (currentEventType == 'json') {
                      // JSON 형식인 경우에만 처리 시작 로그 출력
                      if (data.trim().startsWith('{') &&
                          data.trim().endsWith('}')) {
                        print('🎯 [StreamService] JSON 이벤트 처리 시작');
                      }
                      // JSON인지 먼저 확인
                      if (data.trim().startsWith('{') &&
                          data.trim().endsWith('}')) {
                        try {
                          final jsonData = jsonDecode(data);
                          print('✅ [StreamService] JSON 파싱 성공');
                          print('📋 [StreamService] 파싱된 데이터: $jsonData');
                          print(
                              '📋 [StreamService] JSON 키 목록: ${jsonData.keys.toList()}');

                          // 필수 필드 검증 (휴가 부여 상신용)
                          final requiredFields = [
                            'department',
                            'name',
                            'approval_type',
                            'title'
                          ];
                          for (final field in requiredFields) {
                            if (jsonData.containsKey(field)) {
                              print(
                                  '✅ [StreamService] 필수 필드 확인: $field = ${jsonData[field]}');
                            } else {
                              print('⚠️ [StreamService] 필수 필드 누락: $field');
                            }
                          }

                          // 휴가 부여 상신 JSON을 직접 yield (ChatNotifier에서 처리)
                          yield data;
                          print('✅ [StreamService] 휴가 부여 상신 JSON yield 완료');
                        } catch (e, stackTrace) {
                          print('❌ [StreamService] 휴가 부여 상신 JSON 파싱 오류 발생');
                          print('❌ [StreamService] 오류 타입: ${e.runtimeType}');
                          print('❌ [StreamService] 오류 메시지: $e');
                          print('❌ [StreamService] 원본 데이터: "$data"');
                          print('❌ [StreamService] 스택 트레이스: $stackTrace');
                          final errorMessage =
                              '휴가 부여 상신 데이터 처리 중 오류가 발생했습니다: $e';
                          accumulatedResponse += errorMessage;
                          yield errorMessage;
                        }
                      } else {
                        // JSON 형식 경고 로그 제거됨
                        accumulatedResponse += data;
                        yield data; // JSON이 아니면 일반 메시지로 처리
                      }
                    } else {
                      // 일반 메시지 이벤트
                      accumulatedResponse += data;
                      yield data;
                    }
                  } else {
                    print('⚠️ [StreamService] 빈 데이터 라인 무시');
                  }
                } else if (line.trim().isNotEmpty) {
                  print('⚠️ [StreamService] 알 수 없는 라인 형식: "$line"');
                }
              }

              print(
                  '🏁 [StreamService] 휴가 부여 상신 SSE 스트림 처리 완료 (총 $lineCount 라인)');

              if (accumulatedResponse.isNotEmpty) {
                try {
                  final processedResponse = accumulatedResponse
                      .replaceAll('\\n\\n', '\n\n')
                      .replaceAll('\\n', '\n');

                  int chatId;
                  try {
                    chatId = await ApiService.getlastChatId(archiveId, userId);
                    print('서버 DB에서 조회한 마지막 chat_id: $chatId');
                  } catch (e) {
                    print('getlastChatId 조회 실패: $e');
                    await _dbHelper.insertAgentMessage(
                        archiveId, processedResponse, userId);
                    print('AI 응답 메시지를 로컬 DB에 저장 완료 (chat_id 없음)');
                    return;
                  }

                  print('\n=== 로컬 DB에 저장될 AI 응답 메시지 ===');
                  print('서버 DB에서 조회한 chat_id: $chatId');
                  print('메시지 내용:\n$processedResponse');
                  print(
                      '=======================================================\n');

                  await _dbHelper.insertAgentMessage(
                      archiveId, processedResponse, userId,
                      chat_id: chatId);
                  print('AI 응답 메시지를 chat_id $chatId로 로컬 DB에 저장 완료');
                } catch (e) {
                  print('AI 응답 메시지 저장 실패: $e');
                }
              }
              return;
            }

            final categoryMessages = {
              'csr': '[CSR 답변 입니다]',
              'code': '[Code 답변 입니다]',
              'mail': '[Mail 답변 입니다]',
              'policy': '[Policy 답변 입니다]',
              'eaccounting': '[Eaccounting 답변 입니다]',
              'budget': '[Budget 답변 입니다]',
              'common': '[Common 답변 입니다]',
              'hr': '[HR 답변 입니다]',
              'sap': '[SAP 답변 입니다]',
              'csrsearch': '[CSR 과거 이력 조회 답변 입니다]',
              'project': '[Project 답변 입니다]',
              '휴가상신': '[휴가상신 초안 작성중입니다. 잠시만 기다려 주십시오.]',
              'vacation': '[휴가상신 초안 작성중입니다. 잠시만 기다려 주십시오.]',
              'hr_leave_apply': '[휴가 초안 상신]',
            };

            if (categoryMessages.containsKey(categoryHeader)) {
              final systemMessage = '${categoryMessages[categoryHeader]}\n\n';
              yield systemMessage;
            } else {
              // 알 수 없는 카테고리의 경우 일반 답변으로 처리 (선택적)
              final systemMessage = '[일반 답변 입니다]\n\n';
              yield systemMessage;
            }
          }

          // 응답 내용을 누적할 변수
          String accumulatedResponse = '';

//아래에 조건문 넣기 data 가 데이터탐색중...\n\n 가 아니면 accumulatedResponse 에 넣기
// 즉 데이터탐색중...\n\n 는 제외한다
          // 응답 스트림 읽기
          await for (String line in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
            // 줄 단위로 나누기
            if (line.startsWith('data: ')) {
              final data = line.substring(6); // "data:" 뒤의 텍스트 추출
              if (data.isNotEmpty) {
                // "데이터 탐색 중...\n\n"이 아닌 경우만 accumulatedResponse에 추가
                if (data != "데이터 탐색 중...\\n\\n") {
                  accumulatedResponse += data;
                }
                yield data;
              }
            }
          }

          // 스트림이 완전히 종료된 후에만 DB에 저장
          if (accumulatedResponse.isNotEmpty) {
            try {
              // 줄바꿈 문자 처리
              final processedResponse = accumulatedResponse
                  .replaceAll('\\n\\n', '\n\n')
                  .replaceAll('\\n', '\n');

              // 서버 DB에서 마지막 chat_id 조회하여 AI 응답 저장
              int chatId;
              try {
                chatId = await ApiService.getlastChatId(archiveId, userId);
                print('서버 DB에서 조회한 마지막 chat_id: $chatId');
              } catch (e) {
                print('getlastChatId 조회 실패: $e');
                // 실패 시 chat_id 없이 저장
                await _dbHelper.insertAgentMessage(
                    archiveId, processedResponse, userId);
                print('AI 응답 메시지를 로컬 DB에 저장 완료 (chat_id 없음)');
                return;
              }

              print('\n=== 로컬 DB에 저장될 AI 응답 메시지 ===');
              print('서버 DB에서 조회한 chat_id: $chatId');
              print('메시지 내용:\n$processedResponse');
              print(
                  '=======================================================\n');

              // 서버 DB에서 조회한 chat_id로 AI 응답 저장
              await _dbHelper.insertAgentMessage(
                  archiveId, processedResponse, userId,
                  chat_id: chatId);
              print('AI 응답 메시지를 chat_id $chatId로 로컬 DB에 저장 완료');
            } catch (e) {
              print('AI 응답 메시지 저장 실패: $e');
            }
          }
        }
      } else {
        yield response.headers['authurl'].toString();
        throw Exception('Failed to connect to SSE server');
      }
    } catch (e) {
      print('스트림 서비스 오류: $e');
      // 오류 발생 시 로컬 DB에 오류 메시지를 AI 응답으로 저장
      try {
        await _dbHelper.insertAgentMessage(
            archiveId, "서버 연결 중 오류가 발생했습니다. 다시 시도해주세요.", userId);
        print('오류 메시지를 로컬 DB에 저장 완료');
      } catch (e) {
        print('오류 메시지 저장 실패: $e');
      }
    } finally {
      client.close();
    }
  }

  // 기존 StreamService 클래스에 새로운 메서드 추가
  static Stream<String> getAutoTitleStream(
      String userId, String archiveId, String message) async* {
    final url = Uri.parse('${AppConfig.baseUrl}/updateArchive/Auto/Stream');
    final client = http.Client();

    // POST 요청 생성
    final request = http.Request('POST', url);
    request.headers.addAll({'Content-Type': 'application/json'});

    request.body = jsonEncode({
      'user_id': userId,
      'archive_id': archiveId,
      'message': message, //사용자의 첫채팅
    });

    try {
      // API 요청 전송
      final response = await client.send(request);

      // 응답 처리
      if (response.statusCode == 200) {
        print('자동 타이틀 업데이트 요청 성공');

        String accumulatedTitle = '';

        // 응답 스트림 읽기
        await for (String line in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          // 데이터 라인 처리
          if (line.startsWith('data: ')) {
            final data = line.substring(6); // "data:" 뒤의 텍스트 추출
            if (data.isNotEmpty) {
              accumulatedTitle += data;
              yield data;
            }
          }
        }

        // 스트림이 완료되면 로컬 DB의 아카이브 제목도 업데이트
        if (accumulatedTitle.isNotEmpty) {
          await _dbHelper.updateArchiveTitle(
              archiveId, accumulatedTitle.trim());
          print('스트림 서비스: 로컬 DB에 아카이브 제목 업데이트 완료: $accumulatedTitle');
        }
      } else {
        print('자동 타이틀 업데이트 요청 실패: ${response.statusCode}');
        yield '자동 제목 생성 실패';
      }
    } catch (e) {
      print('자동 타이틀 업데이트 예외 발생: $e');
      yield '자동 제목 생성 중 오류 발생';
    } finally {
      client.close();
    }
  }

  // 파일 첨부 기능이 있는 채팅 스트림 메서드 (더 이상 사용하지 않음 - getEventStream으로 통합됨)
  @Deprecated('Use getEventStream with files parameter instead')
  static Stream<String> getAttachmentEventStream(
      String category,
      String module,
      String archiveId,
      String userId,
      String message,
      List<CustomPlatformFile> files) async* {
    final url = Uri.parse('${AppConfig.baseUrl}/streamChat/attachment');
    final client = http.Client();

    try {
      print('\n=== 파일 첨부 메시지 전송 시작 ===');
      print('사용자 ID: $userId');
      print('메시지: $message');
      print('첨부 파일 수: ${files.length}개');

      // 각 파일의 상세 정보 출력 및 크기 제한 확인
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        print('\n파일 #${i + 1} 상세 정보:');
        print('- 파일명: ${file.name}');
        print('- 크기: ${(file.size / 1024).toStringAsFixed(2)} KB');
        print('- 확장자: ${file.extension}');
        print('- MIME 타입: ${file.mimeType}');

        // 개별 파일 크기 제한 (20MB)
        if (file.size > 20 * 1024 * 1024) {
          throw Exception(
              '파일 크기가 너무 큽니다: ${file.name} (${(file.size / 1024 / 1024).toStringAsFixed(2)}MB)');
        }
      }

      // 전체 파일 크기 제한 없음

      // multipart request 생성
      var request = http.MultipartRequest('POST', url);
      // MultipartRequest가 boundary 포함 Content-Type을 자동 설정함

      // 텍스트 필드 추가
      request.fields['category'] = category;
      request.fields['module'] = module;
      request.fields['archive_id'] = archiveId;
      request.fields['user_id'] = userId;
      request.fields['message'] = message;

      // 파일 첨부 (CustomPlatformFile 사용)
      for (var file in files) {
        if (file.bytes != null) {
          final multipartFile = http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: file.name,
            contentType: MediaType.parse(file.mimeType),
          );
          request.files.add(multipartFile);
          print('\n파일 첨부 완료: ${file.name} (MIME 타입: ${file.mimeType})');
        }
      }

      // 요청 전송 (재시도 로직 제거)
      // const timeoutDuration = Duration(seconds: 30); // 타임아웃 설정 - 주석처리

      try {
        final streamedResponse = await client.send(request);
        // .timeout(
        //   timeoutDuration,
        //   onTimeout: () {
        //     throw TimeoutException(
        //         '파일 업로드 시간 초과 (${timeoutDuration.inSeconds}초)');
        //   },
        // ); // 타임아웃 로직 주석처리

        // 파일 업로드 완료 후 답변 생성 대기 상태 메시지
        if (streamedResponse.statusCode == 200) {
          // PDF 파일이 포함되어 있는지 확인
          bool hasPdfFiles =
              files.any((file) => file.extension?.toLowerCase() == 'pdf');

          // 이미지 파일이 포함되어 있는지 확인
          bool hasImageFiles = files.any((file) {
            final mimeType = file.mimeType.toLowerCase();
            return mimeType.startsWith('image/');
          });

          String waitingMessage = "답변을 생성중입니다. 잠시만 기다려주세요...";
          if (hasPdfFiles) {
            waitingMessage += "\nPDF 파일의 경우 시간이 더 소요될 수 있습니다.";
          }
          if (hasImageFiles) {
            waitingMessage += "\n이미지의 경우 대기 시간이 길어질 수 있습니다.";
          }

          yield '{"status":"generating_response","message":"$waitingMessage","show_loading":true}';
        }

        // 서버로부터 chat_id를 받아서 사용자 메시지 저장 (이전 버전 방식)
        if (streamedResponse.headers.containsKey('chat_id')) {
          try {
            final userChatId = int.parse(streamedResponse.headers['chat_id']!);
            print('서버로부터 받은 chat_id: $userChatId');

            // 사용자 메시지를 받은 chat_id로 저장 (이전 버전 방식)
            await _dbHelper.insertUserMessage(archiveId, message, userId,
                chat_id: userChatId);
            print('사용자 메시지를 chat_id $userChatId로 로컬 DB에 저장 완료');
          } catch (e) {
            print('chat_id 파싱 또는 사용자 메시지 저장 오류: $e');
          }
        } else {
          print('서버 응답에 chat_id 헤더가 없습니다');
        }

        // 응답 처리 부분
        if (streamedResponse.statusCode == 200 ||
            streamedResponse.statusCode == 400) {
          // message 헤더 처리 (공통)
          if (streamedResponse.headers.containsKey('message')) {
            final messageHeader = streamedResponse.headers['message']!;
            final decodedMessage = utf8.decode(latin1.encode(messageHeader));
            yield decodedMessage;
          }

          // 상태 코드가 200일 때만 실행하는 나머지 로직
          if (streamedResponse.statusCode == 200) {
            print('All Response Headers: ${streamedResponse.headers}');

            // Category 헤더 값을 확인하여 범주별 메시지를 최상단에 yield
            if (streamedResponse.headers.containsKey('category')) {
              final categoryHeader =
                  streamedResponse.headers['category']!.toLowerCase();
              print('서버에서 받은 category 헤더: $categoryHeader');

              // 1. 먼저 카테고리 정보를 JSON 형식으로 전달 (새로 추가)
              yield '{"category":"$categoryHeader"}';
              // 2. getAttachmentEventStream에서는 시스템 메시지도 표시 (사내업무에서 사용)
              final categoryMessages = {
                'csr': '[CSR 답변 입니다]',
                'code': '[Code 답변 입니다]',
                'mail': '[Mail 답변 입니다]',
                'policy': '[Policy 답변 입니다]',
                'eaccounting': '[Eaccounting 답변 입니다]',
                'budget': '[Budget 답변 입니다]',
                'common': '[Common 답변 입니다]',
                'hr': '[HR 답변 입니다]',
                'sap': '[SAP 답변 입니다]',
                'csrsearch': '[CSR 과거 이력 조회 답변 입니다]',
                'project': '[Project 답변 입니다]',
                '휴가상신': '[휴가상신 초안 작성중입니다. 잠시만 기다려 주십시오.]',
                'vacation': '[휴가상신 초안 작성중입니다. 잠시만 기다려 주십시오.]',
                'hr_leave_apply': '[휴가 초안 상신]',
              };

              if (categoryMessages.containsKey(categoryHeader)) {
                final systemMessage = '${categoryMessages[categoryHeader]}\n\n';
                yield systemMessage;
              } else {
                // 알 수 없는 카테고리의 경우 일반 답변으로 처리 (선택적)
                final systemMessage = '[일반 답변 입니다]\n\n';
                yield systemMessage;
              }
            }

            String accumulatedResponse = '';

            // 응답 스트림 처리
            await for (var chunk
                in streamedResponse.stream.transform(utf8.decoder)) {
              for (var line in chunk.split('\n')) {
                if (line.startsWith('data: ')) {
                  final data = line.substring(6);
                  if (data.isNotEmpty) {
                    accumulatedResponse += data;
                    yield data; // 실시간으로 UI에 전달
                  }
                }
              }
            }

            // 스트림이 완전히 종료된 후에만 DB에 저장
            if (accumulatedResponse.isNotEmpty) {
              try {
                // 줄바꿈 문자 처리
                final processedResponse = accumulatedResponse
                    .replaceAll('\\n\\n', '\n\n')
                    .replaceAll('\\n', '\n');

                // 서버 DB에서 마지막 chat_id 조회하여 AI 응답 저장
                int chatId;
                try {
                  chatId = await ApiService.getlastChatId(archiveId, userId);
                  print('서버 DB에서 조회한 마지막 chat_id: $chatId');
                } catch (e) {
                  print('getlastChatId 조회 실패: $e');
                  // 실패 시 chat_id 없이 저장
                  await _dbHelper.insertAgentMessage(
                      archiveId, processedResponse, userId);
                  print('AI 응답 메시지를 로컬 DB에 저장 완료 (chat_id 없음)');
                  return;
                }

                print('\n=== 로컬 DB에 저장될 AI 응답 메시지 (첨부파일) ===');
                print('서버 DB에서 조회한 chat_id: $chatId');
                print('메시지 내용:\n$processedResponse');
                print(
                    '==============================================================\n');

                // 서버 DB에서 조회한 chat_id로 AI 응답 저장
                await _dbHelper.insertAgentMessage(
                    archiveId, processedResponse, userId,
                    chat_id: chatId);
                print('AI 응답 메시지를 chat_id $chatId로 로컬 DB에 저장 완료');
              } catch (e) {
                print('AI 응답 메시지 저장 실패: $e');
              }
            }
          }
        } else {
          final errorMessage =
              streamedResponse.headers['message'] ?? '서버 연결 실패';
          throw Exception(
              '파일 업로드 실패: $errorMessage (상태 코드: ${streamedResponse.statusCode})');
        }
      } catch (e, stackTrace) {
        print('\n=== StreamService 첨부파일 업로드 오류 ===');
        print('오류 타입: ${e.runtimeType}');
        print('오류 내용: $e');
        print('스택 트레이스: $stackTrace');
        print('아카이브 ID: $archiveId');
        print('사용자 ID: $userId');
        print('첨부 파일 수: ${files.length}');
        for (var i = 0; i < files.length; i++) {
          print(
              '  파일 ${i + 1}: ${files[i].name} (${files[i].size} bytes, ${files[i].mimeType})');
        }
        print('=== StreamService 오류 정보 완료 ===\n');

        // 오류 발생 시 로컬 DB에 오류 메시지를 AI 응답으로 저장
        try {
          await _dbHelper.insertAgentMessage(
              archiveId, "파일 업로드 중 오류가 발생했습니다.", userId);
          print('오류 메시지를 로컬 DB에 저장 완료');
        } catch (dbError) {
          print('오류 메시지 저장 실패: $dbError');
        }
        rethrow;
      }
    } on http.ClientException catch (e) {
      print('스트림 서비스 네트워크 오류: $e');
      // 오류 발생 시 로컬 DB에 오류 메시지를 AI 응답으로 저장
      await _dbHelper.insertAgentMessage(
          archiveId, "네트워크 연결 오류가 발생했습니다. 인터넷 연결을 확인하고 다시 시도해주세요.", userId);
      throw Exception('네트워크 연결 오류가 발생했습니다.');
    } catch (e, stackTrace) {
      print('\n=== StreamService 최종 오류 처리 ===');
      print('오류 타입: ${e.runtimeType}');
      print('오류 내용: $e');
      print('스택 트레이스: $stackTrace');
      print('=== StreamService 최종 오류 정보 완료 ===\n');

      // 오류 발생 시 로컬 DB에 오류 메시지를 AI 응답으로 저장
      await _dbHelper.insertAgentMessage(
          archiveId, "파일 업로드 중 오류가 발생했습니다.", userId);
      throw Exception('파일 업로드 중 오류가 발생했습니다.');
    } finally {
      client.close();
    }
  }

  // AI 모델 선택 기능을 위한 스트림 메서드 (streamChat/withModel API 사용)
  static Stream<String> getWithModelStream(
      String category,
      String module,
      String model,
      String archiveId,
      String userId,
      String message,
      List<CustomPlatformFile> files,
      {String searchYn = 'n'}) async* {
    final url = Uri.parse('${AppConfig.baseUrl}/streamChat/withModel');
    final client = http.Client();

    try {
      print('\n🚀 === streamChat/withModel API 호출 시작 ===');
      print('🌐 API URL: ${url.toString()}');
      print('📂 카테고리: $category');
      print('🔧 모듈: $module');
      print('🤖 선택된 모델: $model');
      print('👤 사용자 ID: $userId');
      print('📁 아카이브 ID: $archiveId');
      print('💬 메시지: $message');
      print('📎 첨부 파일 수: ${files.length}개');
      print('🔍 search_yn: $searchYn');
      print('🎯 === API 요청 파라미터 확인 ===');

      // 파일이 있는 경우 상세 정보 출력 및 파일 크기 제한 확인
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        print('\n파일 #${i + 1} 상세 정보:');
        print('- 파일명: ${file.name}');
        print('- 크기: ${(file.size / 1024).toStringAsFixed(2)} KB');
        print('- 확장자: ${file.extension}');
        print('- MIME 타입: ${file.mimeType}');

        // 파일 타입 제한 제거: 이미지 + PDF 허용
        // final extension = file.extension?.toLowerCase() ?? '';

        // 개별 파일 크기 제한 (20MB)
        if (file.size > 20 * 1024 * 1024) {
          throw Exception(
              '파일 크기가 너무 큽니다: ${file.name} (${(file.size / 1024 / 1024).toStringAsFixed(2)}MB)');
        }
      }

      // multipart request 생성
      var request = http.MultipartRequest('POST', url);
      // MultipartRequest가 boundary 포함 Content-Type을 자동 설정함

      // 필수 필드 추가
      request.fields['archive_id'] = archiveId;
      request.fields['user_id'] = userId;
      request.fields['message'] = message;

      // 선택 필드 추가 (빈 값이 아닌 경우에만)
      if (category.isNotEmpty) {
        request.fields['category'] = category;
      }
      if (module.isNotEmpty) {
        request.fields['module'] = module;
      }
      if (model.isNotEmpty) {
        request.fields['model'] = model;
      }
      // 검색 여부 필드 추가 (y/n)
      request.fields['search_yn'] = (searchYn == 'y') ? 'y' : 'n';

      // 📋 최종 요청 필드 확인 로그
      print('\n📋 === 최종 API 요청 필드 ===');
      request.fields.forEach((key, value) {
        if (key == 'model') {
          print('🎯 모델 필드: $key = "$value"');
        } else {
          print('📝 필드: $key = "$value"');
        }
      });
      print('📋 === 요청 필드 확인 완료 ===\n');

      // 파일 첨부 (있는 경우에만)
      for (var file in files) {
        if (file.bytes != null) {
          final multipartFile = http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: file.name,
            contentType: MediaType.parse(file.mimeType),
          );
          request.files.add(multipartFile);
          print('\n파일 첨부 완료: ${file.name} (MIME 타입: ${file.mimeType})');
        }
      }

      // 요청 전송
      final streamedResponse = await client.send(request);

      // 파일이 있는 경우 답변 생성 대기 상태 메시지
      if (streamedResponse.statusCode == 200 && files.isNotEmpty) {
        bool hasPdfFiles =
            files.any((file) => file.extension?.toLowerCase() == 'pdf');
        bool hasImageFiles = files.any((file) {
          final mimeType = file.mimeType.toLowerCase();
          return mimeType.startsWith('image/');
        });

        String waitingMessage = "답변을 생성중입니다. 잠시만 기다려주세요...";
        if (hasPdfFiles) {
          waitingMessage += "\nPDF 파일의 경우 시간이 더 소요될 수 있습니다.";
        }
        if (hasImageFiles) {
          waitingMessage += "\n이미지의 경우 대기 시간이 길어질 수 있습니다.";
        }

        yield '{"status":"generating_response","message":"$waitingMessage","show_loading":true}';
      }

      // 서버로부터 chat_id를 받아서 사용자 메시지 저장 (이전 버전 방식)
      if (streamedResponse.headers.containsKey('chat_id')) {
        try {
          final userChatId = int.parse(streamedResponse.headers['chat_id']!);
          print('서버로부터 받은 chat_id: $userChatId');

          // 사용자 메시지를 받은 chat_id로 저장 (이전 버전 방식)
          await _dbHelper.insertUserMessage(archiveId, message, userId,
              chat_id: userChatId);
          print('사용자 메시지를 chat_id $userChatId로 로컬 DB에 저장 완료');
        } catch (e) {
          print('chat_id 파싱 또는 사용자 메시지 저장 오류: $e');
        }
      } else {
        print('서버 응답에 chat_id 헤더가 없습니다');
      }

      // 응답 처리 부분
      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 400) {
        // message 헤더 처리 (공통)
        if (streamedResponse.headers.containsKey('message')) {
          final messageHeader = streamedResponse.headers['message']!;
          final decodedMessage = utf8.decode(latin1.encode(messageHeader));
          yield decodedMessage;

          // 400 상태일 때는 오류 로그만 남김
          if (streamedResponse.statusCode == 400) {
            print('서버 오류 발생 (상태 코드: 400) - 메시지 저장하지 않음');
          }
        }

        // 상태 코드가 200일 때만 실행하는 나머지 로직
        if (streamedResponse.statusCode == 200) {
          print('All Response Headers: ${streamedResponse.headers}');

          // 모델 시스템 메시지 제거됨 - 사용자가 이미 선택한 모델을 알고 있으므로 불필요

          // streamChat/withModel API에서는 카테고리 시스템 메시지를 표시하지 않음
          // (코딩 어시스턴트, SAP 어시스턴트, AI Chatbot에서 깔끔한 답변 제공)
          if (streamedResponse.headers.containsKey('category')) {
            final categoryHeader =
                streamedResponse.headers['category']!.toLowerCase();
            print(
                '서버에서 받은 category 헤더: $categoryHeader (streamChat/withModel API - 시스템 메시지 표시 안함)');

            // JSON 형식으로만 카테고리 정보 전달 (내부 처리용)
          }

          String accumulatedResponse = '';

          // 응답 스트림 처리
          await for (var chunk
              in streamedResponse.stream.transform(utf8.decoder)) {
            for (var line in chunk.split('\n')) {
              if (line.startsWith('data: ')) {
                final data = line.substring(6);
                if (data.isNotEmpty) {
                  accumulatedResponse += data;
                  yield data; // 실시간으로 UI에 전달
                }
              }
            }
          }

          // 스트림이 완전히 종료된 후에만 DB에 저장 (이전 버전 방식 복원)
          if (accumulatedResponse.isNotEmpty) {
            try {
              // 줄바꿈 문자 처리
              final processedResponse = accumulatedResponse
                  .replaceAll('\\n\\n', '\n\n')
                  .replaceAll('\\n', '\n');

              // 서버 DB에서 마지막 chat_id 조회하여 AI 응답 저장
              int chatId;
              try {
                chatId = await ApiService.getlastChatId(archiveId, userId);
                print('서버 DB에서 조회한 마지막 chat_id: $chatId');
              } catch (e) {
                print('getlastChatId 조회 실패: $e');
                // 실패 시 chat_id 없이 저장
                await _dbHelper.insertAgentMessage(
                    archiveId, processedResponse, userId);
                print('AI 응답 메시지를 로컬 DB에 저장 완료 (chat_id 없음)');
                return;
              }

              print('\n=== 로컬 DB에 저장될 AI 응답 메시지 ===');
              print('서버 DB에서 조회한 chat_id: $chatId');
              print('메시지 내용:\n$processedResponse');
              print(
                  '=======================================================\n');

              // 서버 DB에서 조회한 chat_id로 AI 응답 저장
              await _dbHelper.insertAgentMessage(
                  archiveId, processedResponse, userId,
                  chat_id: chatId);
              print('AI 응답 메시지를 chat_id $chatId로 로컬 DB에 저장 완료');
            } catch (e) {
              print('AI 응답 메시지 저장 실패: $e');
            }
          }
        }
      } else {
        throw Exception('AI 모델 요청 중 오류가 발생했습니다.');
      }
    } catch (e) {
      print('AI 모델 스트림 서비스 오류: $e');
      // 오류 발생 시 로컬 DB에 오류 메시지를 AI 응답으로 저장
      try {
        await _dbHelper.insertAgentMessage(
            archiveId, "AI 모델 요청 중 오류가 발생했습니다. 다시 시도해주세요.", userId);
        print('오류 메시지를 로컬 DB에 저장 완료');
      } catch (e) {
        print('오류 메시지 저장 실패: $e');
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}
