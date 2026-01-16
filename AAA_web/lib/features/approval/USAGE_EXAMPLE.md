# 매출/매입계약 기안서 - Flutter Quill 에디터 사용 가이드

## 📋 개요

`ContractApprovalModalWithEditor`는 **flutter_quill**을 사용한 워드 프로세서 기능이 통합된 매출/매입계약 기안서 양식입니다.

## 🎨 주요 기능

### 1. **워드 프로세서 기능**

#### 파일 메뉴
- ↶ 실행 취소 (Undo)
- ↷ 다시 실행 (Redo)
- 🗑️ 포맷 제거 (Clear Format)

#### 편집 메뉴
- 🔍 검색 (Search)

#### 보기 메뉴
- 📏 글자 크기 조절 (Font Size)

#### 삽입 메뉴
- 🔗 링크 삽입 (Insert Link)
- 📊 표 삽입 (Insert Table) - 커스텀 버튼

#### 형식 메뉴
- **굵게** (Bold)
- *기울임* (Italic)
- <u>밑줄</u> (Underline)
- ~~취소선~~ (Strikethrough)
- 🎨 글자색 (Text Color)
- 🖌️ 배경색 (Background Color)
- # 헤더 스타일 (H1, H2, H3)
- ₓ 아래 첨자 (Subscript)
- ˣ 위 첨자 (Superscript)

#### 정렬 메뉴
- ⬅️ 왼쪽 정렬
- ⬆️ 가운데 정렬
- ➡️ 오른쪽 정렬
- ⬌ 양쪽 정렬

#### 리스트 메뉴
- • 불릿 리스트
- 1. 번호 리스트
- ☑ 체크 리스트
- ⇥ 들여쓰기

### 2. **추가 기능**
- 📊 표 삽입
- 🔄 템플릿 리셋
- 💾 HTML 내보내기
- 🖨️ 인쇄

### 3. **기안서 기능**
- 💾 임시저장
- ✅ 결재 요청
- ❓ 도움말

## 🚀 사용 방법

### 1. 기본 사용

```dart
import 'package:flutter/material.dart';
import 'package:ASPN_AI_AGENT/features/approval/contract_approval_modal_with_editor.dart';

// 모달로 표시
void showContractApprovalModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: ContractApprovalModalWithEditor(),
    ),
  );
}
```

### 2. 전체 화면으로 표시

```dart
void openContractApprovalScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        body: ContractApprovalModalWithEditor(),
      ),
    ),
  );
}
```

### 3. 기존 코드에서 교체

기존 `ContractApprovalModal`을 사용하던 곳에서:

```dart
// Before
import 'package:ASPN_AI_AGENT/features/approval/contract_approval_modal.dart';
showDialog(
  context: context,
  builder: (context) => Dialog(child: ContractApprovalModal()),
);

// After
import 'package:ASPN_AI_AGENT/features/approval/contract_approval_modal_with_editor.dart';
showDialog(
  context: context,
  builder: (context) => Dialog(child: ContractApprovalModalWithEditor()),
);
```

## 📝 기본 템플릿 구조

에디터는 다음과 같은 기본 템플릿으로 시작합니다:

```
매출/매입계약 기안서

===========================================

📋 계약 개요
===========================================

항목 | 금액 | 거래처 | 세금계산서 발행예정일 | 결제조건 | 특이사항
-----|------|--------|---------------------|---------|----------
H/W 매출 |  |  |  |  |
S/W 매출 |  |  |  |  |
... (중략)

===========================================

📄 매출 계약 내역서
===========================================

계약명:
계약업체:
계약기간:
... (중략)
```

## 🔧 확장 방법

### 다른 기안서 양식에 적용하기

1. **재사용 가능한 DocumentEditorWidget 사용**

```dart
import 'package:ASPN_AI_AGENT/widgets/document_editor_widget.dart';

class MyCustomFormModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DocumentEditorWidget(
      title: '내 커스텀 양식',
      initialContent: '여기에 초기 템플릿 내용...',
      onContentChanged: (htmlContent) {
        print('내용 변경됨: $htmlContent');
      },
    );
  }
}
```

2. **ContractApprovalModalWithEditor 패턴 복사**

- `_getDefaultContractTemplate()` 메서드만 수정하여 새로운 양식 생성
- 동일한 툴바 및 에디터 기능 재사용

```dart
/// 휴가 기안서 템플릿
String _getDefaultLeaveTemplate() {
  return '''휴가 신청서

신청자:
부서:
휴가 종류:
휴가 기간:
사유:
''';
}
```

## 🎯 향후 개선 사항

### 현재 구현된 기능 ✅
- ✅ 텍스트 포맷팅 (굵게, 기울임, 밑줄, 색상 등)
- ✅ 정렬 (왼쪽, 가운데, 오른쪽, 양쪽)
- ✅ 리스트 (불릿, 번호, 체크)
- ✅ 헤더 스타일
- ✅ 링크 삽입
- ✅ 실행 취소/다시 실행
- ✅ 검색 기능

### TODO 기능 ⏳
- ⏳ 표 삽입 기능 구현
- ⏳ 이미지 삽입 기능
- ⏳ Delta → HTML 변환 로직
- ⏳ HTML 내보내기 기능
- ⏳ 인쇄 기능
- ⏳ 임시저장/불러오기 (데이터베이스 연동)
- ⏳ 결재 요청 제출 (API 연동)

## 💡 팁

### 1. 표 대신 마크다운 표 사용
현재 표 삽입 기능이 구현 중이므로, 템플릿에서 마크다운 스타일 표를 사용하세요:

```
항목 | 값 | 비고
-----|-----|-----
항목1 | 값1 | 비고1
```

### 2. 템플릿 커스터마이징
`_getDefaultContractTemplate()` 메서드를 수정하여 조직의 필요에 맞게 템플릿을 변경할 수 있습니다.

### 3. 다크 모드 지원
에디터는 자동으로 다크 모드를 지원합니다. 앱의 테마 설정에 따라 자동 전환됩니다.

## 🐛 문제 해결

### Q: 한글 입력이 안 돼요
A: flutter_quill은 한글을 완벽하게 지원합니다. 입력 메서드가 올바르게 설정되었는지 확인하세요.

### Q: 표를 어떻게 삽입하나요?
A: 현재 표 삽입 기능은 개발 중입니다. 임시로 텍스트로 표를 작성하거나 마크다운 스타일을 사용하세요.

### Q: 내용을 어떻게 저장하나요?
A: "임시저장" 버튼을 클릭하면 됩니다. (현재 TODO로 구현 예정)

## 📚 참고 자료

- [flutter_quill GitHub](https://github.com/singerdmx/flutter-quill)
- [flutter_quill 문서](https://pub.dev/packages/flutter_quill)
- [Quill Delta 형식](https://quilljs.com/docs/delta/)

## 👨‍💻 개발자 정보

구현된 파일:
- `/lib/features/approval/contract_approval_modal_with_editor.dart` - 메인 구현
- `/lib/widgets/document_editor_widget.dart` - 재사용 가능한 에디터 위젯
- `/lib/features/approval/contract_approval_modal.dart` - 기존 구현 (참고용)
