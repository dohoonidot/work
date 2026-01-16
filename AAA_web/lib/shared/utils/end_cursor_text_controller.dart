import 'package:flutter/widgets.dart';

/// TextEditingController that always keeps the caret at the end of the text.
/// Preserves IME composing state to support Korean and other IME-based input.
class EndCursorTextEditingController extends TextEditingController {
  EndCursorTextEditingController({super.text});

  @override
  set value(TextEditingValue newValue) {
    final endOffset = newValue.text.length;

    // IME 조합 중일 때는 composing 정보를 유지하여 한글 중복 입력 방지
    // composing.isValid가 true면 조합 중, false면 조합 완료
    final composingRange = newValue.composing.isValid
        ? newValue.composing  // 조합 중: composing 유지
        : TextRange.empty;    // 조합 완료: composing 비움

    super.value = newValue.copyWith(
      selection: TextSelection.collapsed(offset: endOffset),
      composing: composingRange,
    );
  }
}

