### 코드 분석 결과

1.  **`leave_request_screen.dart`**:
    *   `ConsumerStatefulWidget`을 사용하여 Riverpod과 함께 상태를 관리하고 있습니다.
    *   휴가 신청 폼의 데이터는 `leaveRequestDraftProvider`라는 `StateNotifierProvider`를 통해 관리되며, 데이터 타입은 `Map<String, dynamic>` 입니다.
    *   AI 챗봇과의 대화 내용은 `leaveRequestChatProvider` (`StateNotifierProvider`)를 통해 관리됩니다.
    *   `_applyAiSuggestion` 함수에서 `lastAiJsonPatch`를 가져와 폼에 적용하는 로직이 이미 존재합니다. 이 구조를 확장하면 되겠습니다.
    *   폼 필드를 업데이트하기 위한 `TextEditingController`가 직접적으로 보이지 않고, `FormBuilder`와 `leaveRequestDraftProvider`를 통해 값이 관리되고 있습니다. `_formKey.currentState?.patchValue()`를 사용하여 폼 값을 업데이트하는 방식이 적절해 보입니다.

2.  **`api_service.dart`**:
    *   다양한 API 호출 함수들이 정의되어 있지만, 휴가 신청 AI와 직접적으로 통신하는 함수는 보이지 않습니다. `leave_request_screen.dart` 내의 `LeaveRequestChatNotifier`에서 Mock AI 응답을 생성하고 있습니다.
    *   실제 AI 연동을 위해서는 이 파일에 새로운 API 호출 함수를 만들어야 합니다.

3.  **`provider/providers.dart`**:
    *   앱 전반에 사용되는 다양한 Provider들이 정의되어 있습니다. 휴가 신청 관련 Provider는 `leave_request_screen.dart`에 지역적으로 정의되어 있습니다. 전역적으로 사용할 필요가 있다면 이 파일로 옮기는 것을 고려할 수 있지만, 현재 구조도 괜찮습니다.

### 구현 방안 제시

분석 결과를 바탕으로, 다음과 같이 4단계로 기능을 구현할 것을 제안합니다.

---

#### **1단계: AI 응답을 위한 데이터 모델 정의**

현재는 `Map<String, dynamic>`을 사용하고 있지만, 타입 안정성과 코드 가독성을 위해 AI가 반환할 데이터 구조를 담는 별도의 Dart 클래스를 정의합니다.

`lib/models/` 디렉터리를 만들고 그 안에 `leave_request_data.dart` 파일을 생성하여 아래 코드를 추가합니다.

```dart
// lib/models/leave_request_data.dart

class LeaveRequestData {
  final String? vacationType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? vacationDays;
  final String? vacationReason;
  final String? emergencyContact;

  LeaveRequestData({
    this.vacationType,
    this.startDate,
    this.endDate,
    this.vacationDays,
    this.vacationReason,
    this.emergencyContact,
  });

  // AI가 반환한 JSON을 객체로 변환하는 factory 생성자
  factory LeaveRequestData.fromJson(Map<String, dynamic> json) {
    return LeaveRequestData(
      vacationType: json['vacationType'],
      // 날짜 문자열을 DateTime 객체로 파싱
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
      vacationDays: json['vacationDays'],
      vacationReason: json['vacationReason'],
      emergencyContact: json['emergencyContact'],
    );
  }

  // 폼에 적용할 수 있도록 Map으로 변환하는 메서드
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (vacationType != null) map['vacationType'] = vacationType;
    if (startDate != null) map['vacationStart'] = startDate;
    if (endDate != null) map['vacationEnd'] = endDate;
    if (vacationDays != null) map['vacationDays'] = vacationDays;
    if (vacationReason != null) map['vacationReason'] = vacationReason;
    if (emergencyContact != null) map['emergencyContact'] = emergencyContact;
    return map;
  }
}
```

#### **2단계: AI 통신 서비스 구현 (`api_service.dart`)**

실제 AI 서버와 통신하여 구조화된 JSON을 받아오는 함수를 `ApiService`에 추가합니다. 이 함수는 사용자의 프롬프트와 현재 폼 상태를 받아 AI에게 전달합니다.

```dart
// lib/services/api_service.dart 파일에 추가

// ... 기존 ApiService 클래스 내용 ...

  // 휴가 신청 AI 프롬프트 전송 함수
  static Future<Map<String, dynamic>> sendLeaveRequestPrompt({
    required String prompt,
    required Map<String, dynamic> currentFormState,
  }) async {
    // << 중요 >>
    // 이 부분은 실제 AI 서버의 엔드포인트와 요청/응답 형식에 맞게 수정해야 합니다.
    // 여기서는 가상의 엔드포인트 'https://your-ai-server.com/leave-request'를 사용합니다.
    final url = Uri.parse('https://your-ai-server.com/leave-request');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'prompt': prompt,
      'current_state': currentFormState, // 현재 폼 상태를 함께 보내 AI가 맥락을 파악하도록 함
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        // data는 AI의 텍스트 답변과 JSON 패치를 모두 포함해야 함
        // 예: {"reply": "알겠습니다. 연차로 처리해 드릴까요?", "patch": {"vacationType": "연차"}}
        return data;
      } else {
        // 오류 처리
        return {
          "reply": "AI 서버와 통신 중 오류가 발생했습니다.",
          "patch": null,
        };
      }
    } catch (e) {
      // 예외 처리
      return {
        "reply": "AI 서비스 연결에 실패했습니다: $e",
        "patch": null,
      };
    }
  }

// ... ApiService 클래스 나머지 부분 ...
```

#### **3단계: `LeaveRequestChatNotifier` 수정 (`leave_request_screen.dart`)**

기존의 Mock 로직을 실제 `ApiService` 호출로 변경하고, AI가 반환한 JSON patch를 `LeaveRequestData` 모델로 변환하여 상태를 관리하도록 수정합니다.

```dart
// lib/screens/leave_request_screen.dart 파일 내

// ... LeaveRequestChatNotifier 클래스 상단 ...
import 'package:ASPN_AI_AGENT/models/leave_request_data.dart'; // 1단계에서 만든 모델 import
import 'package:ASPN_AI_AGENT/services/api_service.dart'; // ApiService import

class LeaveRequestChatNotifier extends StateNotifier<List<LeaveRequestMessage>> {
  // _lastAiJsonPatch의 타입을 Map<String, dynamic>? 에서 LeaveRequestData? 로 변경
  LeaveRequestData? _lastAiSuggestion;
  LeaveRequestData? get lastAiSuggestion => _lastAiSuggestion;

  final Function() getFormState; // 현재 폼 상태를 가져오기 위한 콜백

  LeaveRequestChatNotifier(this.getFormState) : super([]);

  Future<void> sendPrompt(String userPrompt) async {
    if (userPrompt.trim().isEmpty) return;

    // 사용자 메시지 추가
    state = [...state, LeaveRequestMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: userPrompt,
      isUser: true,
      timestamp: DateTime.now(),
    )];

    // 실제 AI 서비스 호출
    final currentForm = getFormState();
    final response = await ApiService.sendLeaveRequestPrompt(
      prompt: userPrompt,
      currentFormState: currentForm,
    );

    final aiReply = response['reply'] as String;
    final patchData = response['patch'] as Map<String, dynamic>?;

    // AI 메시지 추가
    state = [...state, LeaveRequestMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: aiReply,
      isUser: false,
      timestamp: DateTime.now(),
    )];

    // JSON patch가 있으면 LeaveRequestData 객체로 변환하여 저장
    if (patchData != null) {
      _lastAiSuggestion = LeaveRequestData.fromJson(patchData);
    } else {
      _lastAiSuggestion = null;
    }
    
    // 상태 변경을 알림 (중요)
    state = List.from(state); 
  }

  void clearChat() {
    state = [];
    _lastAiSuggestion = null;
  }
}

// leaveRequestChatProvider 정의 수정
final leaveRequestChatProvider =
    StateNotifierProvider<LeaveRequestChatNotifier, List<LeaveRequestMessage>>((ref) {
  // ref.watch를 사용하여 draftProvider의 최신 상태를 가져오도록 함
  final draftState = ref.watch(leaveRequestDraftProvider);
  return LeaveRequestChatNotifier(() => draftState);
});

// ... 나머지 코드는 그대로 ...
```

#### **4단계: UI 로직 연동 (`leave_request_screen.dart`)**

사용자가 AI와 대화할 때마다, AI가 제안한 값을 폼에 **즉시** 반영하도록 `_LeaveRequestScreenState`를 수정합니다. `ref.listen`을 사용하여 `leaveRequestChatProvider`의 상태 변경을 감지하고 폼 값을 업데이트합니다.

```dart
// lib/screens/leave_request_screen.dart 파일 내 _LeaveRequestScreenState 클래스

class _LeaveRequestScreenState extends ConsumerState<LeaveRequestScreen>
    with TickerProviderStateMixin {
  // ... 기존 변수들 ...

  @override
  void initState() {
    super.initState();
    // initState에서 리스너 설정
    setupAiSuggestionListener();
  }

  void setupAiSuggestionListener() {
    ref.listen<List<LeaveRequestMessage>>(leaveRequestChatProvider, (previous, next) {
      // 채팅 메시지가 변경될 때마다 호출됨
      final notifier = ref.read(leaveRequestChatProvider.notifier);
      final suggestion = notifier.lastAiSuggestion;

      if (suggestion != null) {
        // AI 제안이 있으면 폼에 즉시 적용
        final patch = suggestion.toMap();
        ref.read(leaveRequestDraftProvider.notifier).applyJsonPatch(patch);
        _formKey.currentState?.patchValue(patch);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('AI 제안이 폼에 반영되었습니다.'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    });
  }

  // ... 기존 dispose, build 메서드 ...

  // _buildChatInput 메서드에서 "AI 제안 적용하기" 버튼은 이제 필요 없으므로 제거하거나,
  // 사용자가 원할 경우를 대비해 남겨둘 수 있습니다. 즉시 반영되므로 버튼의 역할이 모호해집니다.
  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: const InputDecoration(
                hintText: 'AI에게 질문하세요...',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
              onSubmitted: (_) => _sendChatMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendChatMessage,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  // _applyAiSuggestion 메서드는 이제 ref.listen에서 처리하므로 필요 없어집니다.
  // void _applyAiSuggestion() { ... } // 이 메서드 삭제 또는 주석 처리

  // ... 나머지 코드는 그대로 ...
}
```
