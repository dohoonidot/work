import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:ASPN_AI_AGENT/core/database/database_helper.dart'; // 로컬 DB 헬퍼 임포트
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart'; // 공휴일 모델 임포트

class ApiService {
  static String get serverUrl => AppConfig.baseUrl;
  static final DatabaseHelper _dbHelper = DatabaseHelper(); // 로컬 DB 헬퍼 인스턴스

  // 서버에서 아카이브 리스트 가져오는 함수 (내부용)
  static Future<List<Map<String, dynamic>>> getArchiveListFromServer(
      String userId) async {
    final url = Uri.parse('$serverUrl/getArchiveList');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'user_id': userId});

    try {
      final response = await http.post(url, headers: headers, body: body);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final archiveList = data['archive_list'];

        if (archiveList == null || archiveList is! List) {
          return [];
        }

        return List<Map<String, dynamic>>.from(archiveList.map((archive) {
          return {
            'id': archive['id'],
            'archive_id': archive['archive_id'],
            'archive_name': archive['archive_name'],
            'summary_name': archive['summary_name'],
            'archive_time': archive['archive_time'],
            'archive_type':
                archive['archive_type'] ?? '', // archive_type이 없는 경우 빈 문자열
          };
        }));
      } else if (response.statusCode == 204) {
        // 204 응답인 경우 빈 리스트 반환
        print('No archives found (204 response)');
        return [];
      } else {
        throw Exception(
            'Failed to load archive list from server. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _getArchiveListFromServer: $e');
      throw Exception('Failed to get archive list from server: $e');
    }
  }

  // 서버에서 아카이브 상세 정보 가져오는 함수 (내부용)
  static Future<List<Map<String, dynamic>>> getArchiveDetailFromServer(
      String archiveId,
      {int? maxChatId}) async {
    final url = Uri.parse('$serverUrl/getSingleArchive');
    final headers = {'Content-Type': 'application/json'};

    final requestBody = {
      'archive_id': archiveId,
      'max_chat_id': maxChatId ?? 0
    };

    final body = jsonEncode(requestBody);
    print('아카이브 디테일 API 요청: $body');

    try {
      final response = await http.post(url, headers: headers, body: body);
      print('아카이브 디테일 API 응답 코드: ${response.statusCode}');
      print('아카이브 디테일 API 응답 본문: ${response.body}');

      // 응답 디코딩 및 파싱
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final statusCode = data['status_code'] as int;

      if (statusCode == 204) {
        print('상태 코드 204: 새로운 채팅 없음');
        return [];
      }

      if (statusCode == 200) {
        print('상태 코드 200: 새로운 채팅 있음');
        final chats = data['chats'];

        if (chats == null) {
          print('오류: 응답에 chats 필드가 없습니다');
          return [];
        }

        if (chats is! List) {
          print('오류: chats 필드가 리스트가 아닙니다: ${chats.runtimeType}');
          return [];
        }

        final chatList = chats;
        print('서버에서 반환된 채팅 수: ${chatList.length}');

        if (chatList.isEmpty) {
          print('서버가 빈 채팅 리스트를 반환했습니다 (상태코드 200)');
          return [];
        }

        // 예시로 첫 번째 채팅 내용 출력
        if (chatList.isNotEmpty) {
          print('첫 번째 채팅 구조: ${chatList[0].keys}');
        }

        // 나머지 코드는 동일
        return List<Map<String, dynamic>>.from(chatList.map((chat) => {
              'chat_id': chat['chat_id'],
              'archive_id': archiveId,
              'message': chat['message'],
              'role': chat['role'],
            }));
      }

      throw Exception('알 수 없는 상태 코드: $statusCode');
    } catch (e) {
      print('아카이브 디테일 API 오류: $e');
      throw e;
    }
  }

  // 아카이브 이름을 수정하는 함수 - 서버와 로컬 DB 모두 업데이트
  static Future<Map<String, dynamic>> updateArchive(
      String userId, String archiveId, String newName) async {
    final url = Uri.parse('$serverUrl/updateArchive');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(
        {'user_id': userId, 'archive_id': archiveId, 'archive_name': newName});

    try {
      // 서버 업데이트
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // 로컬 DB 업데이트
        await _dbHelper.updateArchiveTitle(archiveId, newName);
        print('로컬 DB에서 아카이브 제목 업데이트 완료: $archiveId -> $newName');

        return data;
      } else {
        throw Exception('Failed to update archive name');
      }
    } catch (e) {
      throw Exception('Failed to update archive name: $e');
    }
  }

  // 아카이브를 삭제하는 함수 - 서버에서는 상태 변경, 로컬에서는 완전 삭제
  static Future<void> deleteArchive(String archiveId) async {
    final url = Uri.parse('$serverUrl/deleteArchive');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'archive_id': archiveId});

    try {
      // 서버 삭제 요청
      final response = await http.post(url, headers: headers, body: body);
      print('Delete Archive Response Status: ${response.statusCode}');
      print('Delete Archive Response Body: ${response.body}');

      if (response.statusCode == 204) {
        // 서버에서 성공적으로 삭제됨

        return;
      } else {
        throw Exception(
            'Failed to delete archive. Status code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to delete archive [ApiService]: $e');
    }
  }

  static Future<Map<String, dynamic>> getMails(
      String archiveid, String userId, String type) async {
    final url = Uri.parse('$serverUrl/getMails');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'user_id': userId, 'type': 'is:unread in:inbox'});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Failed to getMails');
      }
    } catch (e) {
      throw Exception('Failed to getMails: $e');
    }
  }

  // 새로운 아카이브를 생성하는 함수 - 서버와 로컬 DB 모두 생성
  static Future<Map<String, dynamic>> createArchive(String userId, String title,
      {String archiveType = ''}) async {
    final url = Uri.parse('$serverUrl/createArchive');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': userId,
      'archive_type': archiveType, // archiveType 추가
    });

    try {
      // 서버에 아카이브 생성 요청
      final response = await http.post(url, headers: headers, body: body);
      print('Create Archive Response Status: ${response.statusCode}');
      print('Create Archive Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // 서버에서 생성된 아카이브 정보
        final newArchive = data['archive'];
        final archiveId = newArchive['archive_id'];
        final serverId = newArchive['id']; // 서버에서 할당한 ID(int)

        print('서버에서 생성된 아카이브 정보: id=${serverId}, archive_id=${archiveId}');

        // 로컬 DB에 저장할 때 id와 user_id 함께 저장
        await _dbHelper.createArchive({
          'archive_id': archiveId,
          'id': serverId, // 서버에서 받은 id 값
          'user_id': userId, // 현재 로그인한 사용자 ID
          'archive_name': title,
          'archive_type': archiveType,
          'archive_time':
              newArchive['archive_time'] ?? DateTime.now().toString(),
        });

        print(
            '로컬 DB에 새 아카이브 생성: $archiveId ($title), id: $serverId, user_id: $userId');

        return data;
      } else {
        throw Exception(
            'Failed to create archive. Status code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to create archive [ApiService]: $e');
    }
  }

  // 알림 리스트 가져오는 함수 추가 , 차후 api 만들 예정
  static Future<List<Map<String, dynamic>>> getNotifications(
      String userId) async {
    final url = Uri.parse('$serverUrl/getNotifications');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'user_id': userId});

    try {
      final response = await http.post(url, headers: headers, body: body);
      print('Notifications Response status: ${response.statusCode}');
      print('Notifications Response body: ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      rethrow;
    }
  }

  // 서버 DB 아카이브 끝번호 조회 함수
  static Future<int> getMaxSerial(String userId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/getMaxSerial');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'user_id': userId});

    try {
      final response = await http.post(url, headers: headers, body: body);
      print('getMaxSerial 응답 상태 코드: ${response.statusCode}');
      print('getMaxSerial 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['max_serial'] as int;
      } else {
        throw Exception('서버 DB 아카이브 끝번호 조회 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('getMaxSerial API 호출 실패: $e');
      throw Exception('서버 DB 아카이브 끝번호 조회 실패: $e');
    }
  }

  // 서버 DB에서 마지막 chat_id 조회 함수
  static Future<int> getlastChatId(String archiveId, String userId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/getlastChatId');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'archive_id': archiveId,
      'user_id': userId,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      print('getlastChatId 응답 상태 코드: ${response.statusCode}');
      print('getlastChatId 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['last_chat_id'] as int;
      } else {
        throw Exception(
            '서버 DB 마지막 chat_id 조회 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('getlastChatId API 호출 실패: $e');
      throw Exception('서버 DB 마지막 chat_id 조회 실패: $e');
    }
  }

  // 개인정보 동의 상태 조회 함수
  static Future<Map<String, dynamic>> checkPrivacyAgreement(
      String userId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/checkPrivacy');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': userId,
    });

    try {
      print('개인정보 동의 상태 조회 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('개인정보 동의 상태 조회 응답 상태 코드: ${response.statusCode}');
      print('개인정보 동의 상태 조회 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        print('서버 DB 개인정보 동의 상태 조회 완료: $userId -> ${data['is_agreed']}');

        return data;
      } else {
        throw Exception(
            '개인정보 동의 상태 조회 실패. 상태 코드: ${response.statusCode}, 응답: ${response.body}');
      }
    } catch (e) {
      print('개인정보 동의 상태 조회 API 호출 실패: $e');
      throw Exception('개인정보 동의 상태 조회 실패: $e');
    }
  }

  // 개인정보 동의 상태 업데이트 함수
  static Future<Map<String, dynamic>> updatePrivacyAgreement(
      String userId, bool isAgreed) async {
    final url = Uri.parse('${AppConfig.baseUrl}/updatePrivacy');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': userId,
      'is_agreed': isAgreed ? 1 : 0, // boolean을 int로 변환
    });

    try {
      print('개인정보 동의 업데이트 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('개인정보 동의 업데이트 응답 상태 코드: ${response.statusCode}');
      print('개인정보 동의 업데이트 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // 서버 응답 내용을 자세히 로깅
        print('🔍 서버 응답 상세 내용:');
        print('  - status_code: ${data['status_code']}');
        print('  - error: ${data['error']}');
        print('  - 전체 응답: $data');

        // error 필드가 null이 아닌 경우 처리
        if (data['error'] != null) {
          print('🚨 서버에서 에러 발생: ${data['error']}');
          throw Exception('서버 업데이트 실패: ${data['error']}');
        }

        print('✅ 서버 DB 개인정보 동의 상태 업데이트 완료: $userId -> $isAgreed');

        return data;
      } else {
        throw Exception(
            '개인정보 동의 업데이트 실패. 상태 코드: ${response.statusCode}, 응답: ${response.body}');
      }
    } catch (e) {
      print('개인정보 동의 업데이트 API 호출 실패: $e');
      throw Exception('개인정보 동의 업데이트 실패: $e');
    }
  }

  // 받은 선물함 조회 함수
  static Future<Map<String, dynamic>> checkGifts(String userId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/queue/checkGifts');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': userId,
    });

    try {
      print('받은 선물함 조회 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('받은 선물함 조회 응답 상태 코드: ${response.statusCode}');
      print('받은 선물함 조회 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        print('✅ 받은 선물함 조회 완료: $userId');
        print('  - 선물 개수: ${data['gifts']?.length ?? 0}');

        return data;
      } else {
        throw Exception(
            '받은 선물함 조회 실패. 상태 코드: ${response.statusCode}, 응답: ${response.body}');
      }
    } catch (e) {
      print('받은 선물함 조회 API 호출 실패: $e');
      throw Exception('받은 선물함 조회 실패: $e');
    }
  }

  // 받은선물함 선물 개수 조회 및 Provider 업데이트
  static Future<int> updateGiftCount(String userId) async {
    try {
      final response = await checkGifts(userId);
      final gifts = response['gifts'] as List?;
      final giftCount = gifts?.length ?? 0;

      print('🎁 선물 개수 업데이트: $giftCount개');
      return giftCount;
    } catch (e) {
      print('❌ 선물 개수 조회 실패: $e');
      return 0;
    }
  }

  // 알림 목록 조회 함수
  static Future<Map<String, dynamic>> checkAlerts(String userId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/queue/checkAlerts');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': userId,
    });

    try {
      print('알림 목록 조회 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('알림 목록 조회 응답 상태 코드: ${response.statusCode}');
      // print('알림 목록 조회 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        print('✅ 알림 목록 조회 완료: $userId');
        print('  - 알림 개수: ${data['alerts']?.length ?? 0}');

        return data;
      } else {
        throw Exception(
            '알림 목록 조회 실패. 상태 코드: ${response.statusCode}, 응답: ${response.body}');
      }
    } catch (e) {
      print('알림 목록 조회 API 호출 실패: $e');
      throw Exception('알림 목록 조회 실패: $e');
    }
  }

  // 알림함 메시지 수신확인 API
  static Future<Map<String, dynamic>> updateAlerts(
      String userId, int alertId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/queue/updateAlerts');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'id': alertId,
      'user_id': userId,
    });

    try {
      print('알림 수신확인 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('알림 수신확인 응답 상태 코드: ${response.statusCode}');
      print('알림 수신확인 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        print('✅ 알림 수신확인 완료: $userId, 알림 ID: $alertId');
        return data;
      } else {
        throw Exception(
            '알림 수신확인 실패. 상태 코드: ${response.statusCode}, 응답: ${response.body}');
      }
    } catch (e) {
      print('알림 수신확인 API 호출 실패: $e');
      throw Exception('알림 수신확인 실패: $e');
    }
  }

  // 알림함 메시지 삭제 API
  static Future<Map<String, dynamic>> deleteAlerts(
      String userId, int alertId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/queue/deleteAlerts');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'id': alertId,
      'user_id': userId,
    });

    try {
      print('알림 삭제 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('알림 삭제 응답 상태 코드: ${response.statusCode}');
      print('알림 삭제 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        print('✅ 알림 삭제 완료: $userId, 알림 ID: $alertId');
        return data;
      } else {
        throw Exception(
            '알림 삭제 실패. 상태 코드: ${response.statusCode}, 응답: ${response.body}');
      }
    } catch (e) {
      print('알림 삭제 API 호출 실패: $e');
      throw Exception('알림 삭제 실패: $e');
    }
  }

  // 부서 목록 조회 API
  static Future<List<String>> getDepartmentList() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/getDepartmentList');

    try {
      print('부서 목록 조회 API 요청');
      final response = await http.get(url);
      print('부서 목록 조회 응답 상태 코드: ${response.statusCode}');
      print('부서 목록 조회 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // 응답 형식에 따라 처리
        if (data is List) {
          // 리스트 형태로 반환되는 경우
          return List<String>.from(data);
        } else if (data is Map && data.containsKey('departments')) {
          // {'departments': [...]} 형태로 반환되는 경우
          return List<String>.from(data['departments']);
        } else {
          throw Exception('예상치 못한 응답 형식: ${data.runtimeType}');
        }
      } else {
        throw Exception(
            '부서 목록 조회 실패. 상태 코드: ${response.statusCode}, 응답: ${response.body}');
      }
    } catch (e) {
      print('부서 목록 조회 API 호출 실패: $e');
      throw Exception('부서 목록 조회 실패: $e');
    }
  }

  // 회사 전체 조직도(부서별 인원) 조회 API
  //
  // GET ${AppConfig.baseUrl}/api/getCompanyMembers
  //
  // 응답 예시:
  // {
  //   "AMS팀": [{ "name": "...", "user_id": "..." }, ...],
  //   "BAC사업부": [{ "name": "...", "job_position": "...", "user_id": "..." }, ...],
  //   ...
  // }
  //
  // 반환 형식:
  // {
  //   "부서명": [ { "name": "...", "user_id": "...", "job_position": "..."? }, ... ],
  //   ...
  // }
  static Map<String, List<Map<String, dynamic>>>?
      _companyMembersCache; // 한 번 로드 후 재사용

  static Future<Map<String, List<Map<String, dynamic>>>>
      getCompanyMembers() async {
    // 캐시가 있으면 그대로 반환
    if (_companyMembersCache != null && _companyMembersCache!.isNotEmpty) {
      return _companyMembersCache!;
    }

    final url = Uri.parse('${AppConfig.baseUrl}/api/getCompanyMembers'); //

    try {
      print('🏢 회사 전체 조직도 조회 API 요청: $url');
      final response = await http.get(url);
      print('🏢 회사 전체 조직도 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final raw = utf8.decode(response.bodyBytes);
        print('🏢 회사 전체 조직도 응답 바디: $raw');

        final data = jsonDecode(raw);
        if (data is! Map<String, dynamic>) {
          throw Exception('예상치 못한 응답 형식(최상위): ${data.runtimeType}');
        }

        final Map<String, List<Map<String, dynamic>>> result = {};

        data.forEach((deptName, members) {
          if (members is List) {
            result[deptName] = members.map<Map<String, dynamic>>((m) {
              if (m is Map<String, dynamic>) {
                return m;
              } else if (m is Map) {
                return Map<String, dynamic>.from(m);
              } else {
                // name 문자열만 있는 경우
                return {'name': m.toString()};
              }
            }).toList();
          }
        });

        _companyMembersCache = result;
        print('🏢 회사 전체 조직도 파싱 완료: ${result.length}개 부서');
        return result;
      } else {
        throw Exception(
            '회사 전체 조직도 조회 실패. 상태 코드: ${response.statusCode}, 응답: ${response.body}');
      }
    } catch (e) {
      print('🏢 회사 전체 조직도 API 호출 실패: $e');
      throw Exception('회사 전체 조직도 조회 실패: $e');
    }
  }

  /// 공휴일 조회 API
  static Future<HolidayResponse> getHolidays({
    required int year,
    required int month,
  }) async {
    final url =
        Uri.parse('${AppConfig.baseUrl}/api/holidays?year=$year&month=$month');

    try {
      print('🏝️ 공휴일 조회 API 요청: year=$year, month=$month');
      final response = await http.get(url);
      print('🏝️ 공휴일 조회 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        print('✅ 공휴일 조회 완료: ${data['holidays']?.length ?? 0}개 공휴일');

        return HolidayResponse.fromJson(data);
      } else {
        throw Exception('공휴일 조회 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('🏝️ 공휴일 조회 API 호출 실패: $e');
      throw Exception('공휴일 조회 실패: $e');
    }
  }
}
