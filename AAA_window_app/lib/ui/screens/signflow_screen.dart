/*
Required pubspec.yaml dependencies:
flutter_form_builder: ^9.1.1
form_builder_validators: ^9.1.0
multi_split_view: ^3.2.1
file_picker: ^6.1.1
pdf: ^3.10.7
printing: ^5.11.0
riverpod: ^2.4.9
flutter_riverpod: ^2.4.9
gpt_markdown: # already exists in project
sqflite: # already exists in project
*/

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// State Models
class SignflowMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  SignflowMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

class SignflowTemplate {
  final List<String> departments;
  final List<String> approvers;
  final Map<String, List<String>> organizationChart;

  const SignflowTemplate({
    required this.departments,
    required this.approvers,
    required this.organizationChart,
  });
}

// Providers
final signflowTemplateProvider = Provider<SignflowTemplate>((ref) {
  // Mock template data
  return const SignflowTemplate(
    departments: ['개발팀', '기획팀', '디자인팀', '마케팅팀', '인사팀'],
    approvers: ['김과장', '이차장', '박부장', '최팀장', '정대리'],
    organizationChart: {
      '개발팀': ['김개발', '이프론트', '박백엔드', '최풀스택', '정모바일'],
      '기획팀': ['김기획', '이전략', '박마케팅', '최분석', '정운영'],
      '디자인팀': ['김디자인', '이UI', '박UX', '최그래픽', '정브랜딩'],
      '마케팅팀': ['김마케팅', '이광고', '박홍보', '최SNS', '정콘텐츠'],
      '인사팀': ['김인사', '이채용', '박교육', '최급여', '정복리'],
    },
  );
});

class SignflowDraftNotifier extends StateNotifier<Map<String, dynamic>> {
  SignflowDraftNotifier()
      : super({
          'applicantName': '홍길동', // Read-only mock
          'title': '',
          'department': null,
          'periodStart': null,
          'periodEnd': null,
          'amount': '0',
          'reason': '',
          'approvers': <String>[],
          'readers': <String>[],
          'references': <String>[],
          'files': <PlatformFile>[],
        });

  void updateField(String key, dynamic value) {
    final newState = Map<String, dynamic>.from(state);
    newState[key] = value;
    state = newState;
  }

  void resetForm() {
    state = {
      'applicantName': '홍길동',
      'title': '',
      'department': null,
      'periodStart': null,
      'periodEnd': null,
      'amount': '0',
      'reason': '',
      'approvers': <String>[],
      'readers': <String>[],
      'references': <String>[],
      'files': <PlatformFile>[],
    };
  }

  Map<String, String?> validateForm() {
    final errors = <String, String?>{};
    final title = state['title'];
    final periodStart = state['periodStart'];
    final periodEnd = state['periodEnd'];
    final amount = state['amount'];
    final reason = state['reason'];
    final approvers = state['approvers'];
    // 전자결재 검증
    if (title == null || title.toString().trim().isEmpty) {
      errors['title'] = '기안제목은 필수입니다';
    } else if (title.toString().trim().length < 5 ||
        title.toString().trim().length > 50) {
      errors['title'] = '기안제목은 5~50자여야 합니다';
    }

    if (periodStart == null || periodEnd == null) {
      errors['period'] = '기간은 필수입니다';
    } else if (periodStart.isAfter(periodEnd)) {
      errors['period'] = '시작일이 종료일보다 늦을 수 없습니다';
    }

    final amountValue = int.tryParse(amount?.toString() ?? '0') ?? 0;
    if (amountValue < 0) {
      errors['amount'] = '금액은 0 이상이어야 합니다';
    }

    if (reason == null || reason.toString().trim().length < 10) {
      errors['reason'] = '사유는 최소 10자 이상이어야 합니다';
    }

    if ((approvers as List).isEmpty) {
      errors['approvers'] = '결재선은 1인 이상 선택해야 합니다';
    }

    return errors;
  }

  Map<String, dynamic> _serializeState() {
    final serializedState = Map<String, dynamic>.from(state);

    // DateTime 객체들을 String으로 변환
    if (serializedState['periodStart'] is DateTime) {
      serializedState['periodStart'] =
          (serializedState['periodStart'] as DateTime).toIso8601String();
    }
    if (serializedState['periodEnd'] is DateTime) {
      serializedState['periodEnd'] =
          (serializedState['periodEnd'] as DateTime).toIso8601String();
    }

    // PlatformFile 리스트를 파일명 리스트로 변환
    if (serializedState['files'] is List<PlatformFile>) {
      final files = serializedState['files'] as List<PlatformFile>;
      serializedState['files'] = files.map((file) => file.name).toList();
    }

    return serializedState;
  }

  Future<bool> saveDraft() async {
    // Stub: Save draft to local DB
    await Future.delayed(const Duration(milliseconds: 500));
    print('Draft saved: ${jsonEncode(_serializeState())}');
    return true;
  }

  Future<bool> submitDraft() async {
    // Stub: Submit draft
    await Future.delayed(const Duration(milliseconds: 1000));
    print('Draft submitted: ${jsonEncode(_serializeState())}');
    return true;
  }

  void applyJsonPatch(Map<String, dynamic> patch) {
    final newState = Map<String, dynamic>.from(state);
    patch.forEach((key, value) {
      if (newState.containsKey(key)) {
        newState[key] = value;
      }
    });
    state = newState;
  }
}

final signflowDraftProvider =
    StateNotifierProvider<SignflowDraftNotifier, Map<String, dynamic>>((ref) {
  return SignflowDraftNotifier();
});

class SignflowChatNotifier extends StateNotifier<List<SignflowMessage>> {
  SignflowChatNotifier() : super([]);

  Map<String, dynamic>? _lastAiJsonPatch;

  Map<String, dynamic>? get lastAiJsonPatch => _lastAiJsonPatch;

  Future<void> sendPrompt(String userPrompt) async {
    if (userPrompt.trim().isEmpty) return;

    // Add user message
    final userMessage = SignflowMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: userPrompt,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = [...state, userMessage];

    // Mock AI response
    await Future.delayed(const Duration(milliseconds: 1500));

    final mockResponse = _generateMockAiResponse(userPrompt);
    final aiMessage = SignflowMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: mockResponse,
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = [...state, aiMessage];

    // Extract JSON patch from AI response
    _extractJsonPatch(mockResponse);
  }

  String _generateMockAiResponse(String prompt) {
    if (prompt.contains('제목') || prompt.contains('기안')) {
      _lastAiJsonPatch = {'title': '연차휴가 신청서'};
      return '''기안제목을 "연차휴가 신청서"로 제안드립니다.

```json
{"title": "연차휴가 신청서"}
```''';
    } else if (prompt.contains('금액') || prompt.contains('예산')) {
      _lastAiJsonPatch = {'amount': '500000'};
      return '''예상 금액을 50만원으로 설정하겠습니다.

```json
{"amount": "500000"}
```''';
    } else if (prompt.contains('사유') || prompt.contains('이유')) {
      _lastAiJsonPatch = {'reason': '개인 사정으로 인한 연차 사용'};
      return '''사유를 "개인 사정으로 인한 연차 사용"으로 제안합니다.

```json
{"reason": "개인 사정으로 인한 연차 사용"}
```''';
    } else {
      _lastAiJsonPatch = null;
      return '요청사항을 처리하기 위해 더 구체적인 정보가 필요합니다. 어떤 항목을 수정하고 싶으신가요?';
    }
  }

  void _extractJsonPatch(String content) {
    final jsonRegex = RegExp(r'```json\s*(\{.*?\})\s*```', dotAll: true);
    final match = jsonRegex.firstMatch(content);

    if (match != null) {
      try {
        _lastAiJsonPatch = jsonDecode(match.group(1)!);
      } catch (e) {
        _lastAiJsonPatch = null;
      }
    }
  }

  void clearChat() {
    state = [];
    _lastAiJsonPatch = null;
  }
}

final signflowChatProvider =
    StateNotifierProvider<SignflowChatNotifier, List<SignflowMessage>>((ref) {
  return SignflowChatNotifier();
});

final signflowAiServiceProvider = Provider((ref) {
  return SignflowAiService();
});

class SignflowAiService {
  Future<Map<String, dynamic>?> proposePatches({
    required Map<String, dynamic> schema,
    required Map<String, dynamic> currentValues,
    required String userPrompt,
  }) async {
    // Stub: AI service for proposing patches
    await Future.delayed(const Duration(milliseconds: 1000));
    return {'title': 'AI 제안 제목'};
  }
}

// Main Screen
class SignFlowScreen extends ConsumerStatefulWidget {
  const SignFlowScreen({super.key});

  @override
  ConsumerState<SignFlowScreen> createState() => _SignFlowScreenState();
}

// FormType enum removed - only approval form now

class _SignFlowScreenState extends ConsumerState<SignFlowScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  Map<String, String?> _fieldErrors = {};

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전자결재'),
        actions: [
          _buildToolbarButtons(),
        ],
      ),
      body: Focus(
        onKeyEvent: _handleKeyEvent,
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: _buildFormPanel(),
            ),
            Expanded(
              flex: 4,
              child: _buildChatPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: _saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: const Text('임시저장'),
        ),
        TextButton.icon(
          onPressed: _resetForm,
          icon: const Icon(Icons.refresh),
          label: const Text('초기화'),
        ),
        TextButton.icon(
          onPressed: _previewPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('PDF 미리보기'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _submitForm,
          icon: const Icon(Icons.send),
          label: const Text('상신'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFormPanel() {
    final template = ref.watch(signflowTemplateProvider);
    final draftValues = ref.watch(signflowDraftProvider);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FormBuilder(
        key: _formKey,
        initialValue: draftValues,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 전자결재 폼
                _buildSectionTitle('기본정보', Icons.person_outline_rounded),
                const SizedBox(height: 20),
                _buildBasicInfoFields(template),

                const SizedBox(height: 40),

                _buildSectionTitle('상세정보', Icons.edit_note_rounded),
                const SizedBox(height: 20),
                _buildDetailFields(),

                const SizedBox(height: 40),

                _buildSectionTitle('첨부파일', Icons.attach_file_rounded),
                const SizedBox(height: 20),
                _buildAttachmentFields(draftValues),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4A6CF7).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF4A6CF7),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1D1F),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label,
      {bool isRequired = false, String? errorText}) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      labelStyle: const TextStyle(
        color: Color(0xFF8B95A1),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      errorText: errorText,
      errorStyle: const TextStyle(
        color: Color(0xFFFF6B6B),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9ECEF), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4A6CF7), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildBasicInfoFields(SignflowTemplate template) {
    return Column(
      children: [
        FormBuilderTextField(
          name: 'applicantName',
          decoration: _buildInputDecoration('기안자',
              errorText: _fieldErrors['applicantName']),
          readOnly: true,
          style: const TextStyle(
            color: Color(0xFF6C757D),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (value) => _updateField('applicantName', value),
        ),
        const SizedBox(height: 20),
        FormBuilderTextField(
          name: 'title',
          decoration: _buildInputDecoration('기안제목',
              isRequired: true, errorText: _fieldErrors['title']),
          style: const TextStyle(
            color: Color(0xFF1A1D1F),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(errorText: '기안제목은 필수입니다'),
            FormBuilderValidators.minLength(5, errorText: '최소 5자 이상 입력해주세요'),
            FormBuilderValidators.maxLength(50, errorText: '최대 50자까지 입력 가능합니다'),
          ]),
          onChanged: (value) => _updateField('title', value),
        ),
        const SizedBox(height: 20),
        FormBuilderDropdown<String>(
          name: 'department',
          decoration: _buildInputDecoration('부서',
              isRequired: true, errorText: _fieldErrors['department']),
          style: const TextStyle(
            color: Color(0xFF1A1D1F),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          validator: FormBuilderValidators.required(errorText: '부서는 필수입니다'),
          items: template.departments
              .map((dept) => DropdownMenuItem(
                    value: dept,
                    child: Text(
                      dept,
                      style: const TextStyle(
                        color: Color(0xFF1A1D1F),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (value) => _updateField('department', value),
        ),
      ],
    );
  }

  Widget _buildDetailFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FormBuilderDateTimePicker(
                name: 'periodStart',
                inputType: InputType.date,
                decoration: _buildInputDecoration('시작일',
                    isRequired: true, errorText: _fieldErrors['periodStart']),
                style: const TextStyle(
                  color: Color(0xFF1A1D1F),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                validator:
                    FormBuilderValidators.required(errorText: '시작일은 필수입니다'),
                onChanged: (value) => _updateField('periodStart', value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormBuilderDateTimePicker(
                name: 'periodEnd',
                inputType: InputType.date,
                decoration: _buildInputDecoration('종료일',
                    isRequired: true, errorText: _fieldErrors['periodEnd']),
                style: const TextStyle(
                  color: Color(0xFF1A1D1F),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                validator:
                    FormBuilderValidators.required(errorText: '종료일은 필수입니다'),
                onChanged: (value) => _updateField('periodEnd', value),
              ),
            ),
          ],
        ),
        if (_fieldErrors['period'] != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            child: Text(
              _fieldErrors['period']!,
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FormBuilderTextField(
          name: 'amount',
          decoration:
              _buildInputDecoration('금액', errorText: _fieldErrors['amount'])
                  .copyWith(
                      prefixText: '₩ ',
                      prefixStyle: const TextStyle(
                        color: Color(0xFF8B95A1),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      )),
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: Color(0xFF1A1D1F),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.numeric(errorText: '숫자만 입력 가능합니다'),
            FormBuilderValidators.min(0, errorText: '0 이상의 값을 입력해주세요'),
          ]),
          onChanged: (value) => _updateField('amount', value ?? '0'),
        ),
        const SizedBox(height: 20),
        FormBuilderTextField(
          name: 'reason',
          decoration: _buildInputDecoration('사유',
              isRequired: true, errorText: _fieldErrors['reason']),
          maxLines: 4,
          style: const TextStyle(
            color: Color(0xFF1A1D1F),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(errorText: '사유는 필수입니다'),
            FormBuilderValidators.minLength(10, errorText: '최소 10자 이상 입력해주세요'),
          ]),
          onChanged: (value) => _updateField('reason', value),
        ),
        const SizedBox(height: 20),
        _buildApproversField(),
      ],
    );
  }

  Widget _buildApproversField() {
    final selectedApprovers =
        ref.watch(signflowDraftProvider)['approvers'] as List<String>;
    final selectedReaders =
        ref.watch(signflowDraftProvider)['readers'] as List<String>;
    final selectedReferences =
        ref.watch(signflowDraftProvider)['references'] as List<String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 결재선
            Expanded(
              child: _buildPersonnelSection(
                '결재선 *',
                selectedApprovers,
                const Color(0xFF4A6CF7),
                Icons.how_to_reg_rounded,
                (selected) => _updateField('approvers', selected),
                _fieldErrors['approvers'],
                isRequired: true,
              ),
            ),
            const SizedBox(width: 12),
            // 열람권자
            Expanded(
              child: _buildPersonnelSection(
                '열람권자',
                selectedReaders,
                const Color(0xFF28A745),
                Icons.visibility_rounded,
                (selected) => _updateField('readers', selected),
                _fieldErrors['readers'],
              ),
            ),
            const SizedBox(width: 12),
            // 참조자
            Expanded(
              child: _buildPersonnelSection(
                '참조자',
                selectedReferences,
                const Color(0xFF6F42C1),
                Icons.people_alt_rounded,
                (selected) => _updateField('references', selected),
                _fieldErrors['references'],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonnelSection(
      String title,
      List<String> selectedPersons,
      Color themeColor,
      IconData icon,
      Function(List<String>) onSelectionChanged,
      String? errorText,
      {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF1A1D1F),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showOrganizationChart(
              title, selectedPersons, themeColor, onSelectionChanged),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: errorText != null
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFFE9ECEF),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: themeColor,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  selectedPersons.isEmpty
                      ? '선택하기'
                      : '${selectedPersons.length}명 선택됨',
                  style: TextStyle(
                    color: selectedPersons.isEmpty
                        ? const Color(0xFF8B95A1)
                        : const Color(0xFF1A1D1F),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (selectedPersons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: selectedPersons.take(2).map((person) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              person,
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList() +
                        (selectedPersons.length > 2
                            ? [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '+${selectedPersons.length - 2}',
                                    style: TextStyle(
                                      color: themeColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              ]
                            : []),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText,
            style: const TextStyle(
              color: Color(0xFFFF6B6B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentFields(Map<String, dynamic> values) {
    final files = values['files'] as List<PlatformFile>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A6CF7), Color(0xFF5B78FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A6CF7).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('파일 선택'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${files.length}개 파일 첨부됨',
              style: const TextStyle(
                color: Color(0xFF8B95A1),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (files.isNotEmpty) ...[
          const Text(
            '첨부된 파일:',
            style: TextStyle(
              color: Color(0xFF1A1D1F),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...files.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9ECEF)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_rounded,
                    color: Color(0xFF4A6CF7),
                    size: 20,
                  ),
                ),
                title: Text(
                  file.name,
                  style: const TextStyle(
                    color: Color(0xFF1A1D1F),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB',
                  style: const TextStyle(
                    color: Color(0xFF8B95A1),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete_rounded,
                        color: Color(0xFFFF6B6B), size: 18),
                    onPressed: () => _removeFile(index),
                    tooltip: '파일 삭제',
                  ),
                ),
              ),
            );
          }).toList(),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: Border.all(color: const Color(0xFFE9ECEF)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 48,
                  color: Color(0xFF8B95A1),
                ),
                SizedBox(height: 12),
                Text(
                  '첨부할 파일이 없습니다',
                  style: TextStyle(
                    color: Color(0xFF8B95A1),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChatPanel() {
    final messages = ref.watch(signflowChatProvider);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy),
                const SizedBox(width: 8),
                const Text('AI 도우미',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(signflowChatProvider.notifier).clearChat(),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('대화 초기화'),
                ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child:
                        Text('AI 도우미에게 질문해보세요!\n"제목을 제안해줘", "금액을 얼마로 할까?" 등'),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(messages[index]),
                  ),
          ),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(SignflowMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            const CircleAvatar(
              radius: 16,
              child: Icon(Icons.smart_toy, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: message.isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    final chatNotifier = ref.read(signflowChatProvider.notifier);
    final hasJsonPatch = chatNotifier.lastAiJsonPatch != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          Row(
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
          if (hasJsonPatch) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _applyAiSuggestion,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('AI 제안 적용하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          HardwareKeyboard.instance.isControlPressed) {
        _sendChatMessage();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyS &&
          HardwareKeyboard.instance.isControlPressed) {
        _saveDraft();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _showOrganizationChart(
    String title,
    List<String> currentSelection,
    Color themeColor,
    Function(List<String>) onSelectionChanged,
  ) {
    final template = ref.read(signflowTemplateProvider);
    List<String> selectedPersons = List<String>.from(currentSelection);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 600,
                height: 500,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.business_rounded,
                            color: themeColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$title 선택',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1D1F),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${selectedPersons.length}명 선택됨',
                          style: TextStyle(
                            color: themeColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 조직도
                    Expanded(
                      child: ListView.builder(
                        itemCount: template.organizationChart.keys.length,
                        itemBuilder: (context, index) {
                          final department =
                              template.organizationChart.keys.elementAt(index);
                          final members =
                              template.organizationChart[department]!;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.groups_rounded,
                                  color: themeColor,
                                  size: 16,
                                ),
                              ),
                              title: Text(
                                department,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                '${members.length}명',
                                style: const TextStyle(
                                  color: Color(0xFF8B95A1),
                                  fontSize: 12,
                                ),
                              ),
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: members.map((member) {
                                    final isSelected =
                                        selectedPersons.contains(member);
                                    return GestureDetector(
                                      onTap: () {
                                        setDialogState(() {
                                          if (isSelected) {
                                            selectedPersons.remove(member);
                                          } else {
                                            selectedPersons.add(member);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? themeColor
                                              : const Color(0xFFF8F9FA),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected
                                                ? themeColor
                                                : const Color(0xFFE9ECEF),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          member,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF1A1D1F),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // 하단 버튼
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              selectedPersons.clear();
                            });
                          },
                          child: Text(
                            '전체 해제',
                            style: TextStyle(
                              color: const Color(0xFF8B95A1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              color: Color(0xFF8B95A1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                themeColor,
                                themeColor.withValues(alpha: 0.8)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              onSelectionChanged(selectedPersons);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '선택 완료',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _updateField(String key, dynamic value) {
    ref.read(signflowDraftProvider.notifier).updateField(key, value);
    // Clear field error if it exists
    if (_fieldErrors.containsKey(key)) {
      setState(() {
        _fieldErrors.remove(key);
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      final currentFiles =
          ref.read(signflowDraftProvider)['files'] as List<PlatformFile>;
      final newFiles = [...currentFiles, ...result.files];
      ref.read(signflowDraftProvider.notifier).updateField('files', newFiles);
    }
  }

  void _removeFile(int index) {
    final files =
        ref.read(signflowDraftProvider)['files'] as List<PlatformFile>;
    final newFiles = List<PlatformFile>.from(files)..removeAt(index);
    ref.read(signflowDraftProvider.notifier).updateField('files', newFiles);
  }

  Future<void> _sendChatMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    _chatController.clear();
    await ref.read(signflowChatProvider.notifier).sendPrompt(message);

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _applyAiSuggestion() {
    final chatNotifier = ref.read(signflowChatProvider.notifier);
    final patch = chatNotifier.lastAiJsonPatch;

    if (patch != null) {
      ref.read(signflowDraftProvider.notifier).applyJsonPatch(patch);

      // Re-validate form and update field errors
      final errors = ref.read(signflowDraftProvider.notifier).validateForm();
      setState(() {
        _fieldErrors = errors;
      });

      // Update form builder state
      _formKey.currentState?.patchValue(ref.read(signflowDraftProvider));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 제안이 적용되었습니다')),
      );
    }
  }

  Future<void> _saveDraft() async {
    final success = await ref.read(signflowDraftProvider.notifier).saveDraft();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('임시저장이 완료되었습니다')),
      );
    }
  }

  void _resetForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('폼 초기화'),
        content: const Text('모든 입력 내용이 삭제됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(signflowDraftProvider.notifier).resetForm();
              ref.read(signflowChatProvider.notifier).clearChat();
              _formKey.currentState?.reset();
              setState(() {
                _fieldErrors.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('폼이 초기화되었습니다')),
              );
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }

  Future<void> _previewPdf() async {
    try {
      final values = ref.read(signflowDraftProvider);
      final pdf = await _generatePdf(values);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '전자결재_${values['title'] ?? '제목없음'}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 생성 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<pw.Document> _generatePdf(Map<String, dynamic> values) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('전자결재서',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('기안제목: ${values['title'] ?? ''}'),
              pw.Text('기안자: ${values['applicantName'] ?? ''}'),
              pw.Text('부서: ${values['department'] ?? ''}'),
              pw.Text('금액: ${values['amount'] ?? '0'}원'),
              pw.SizedBox(height: 20),
              pw.Text('사유:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('${values['reason'] ?? ''}'),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _submitForm() async {
    // Validate form
    _formKey.currentState?.save();
    final errors = ref.read(signflowDraftProvider.notifier).validateForm();

    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors = errors;
      });

      // Scroll to top to show first error
      // No need to switch tabs since it's now a single scrollable form

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력 정보를 확인해주세요')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상신 확인'),
        content: const Text('결재를 상신하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('상신'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(signflowDraftProvider.notifier).submitDraft();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('결재가 상신되었습니다')),
        );
      }
    }
  }
}
