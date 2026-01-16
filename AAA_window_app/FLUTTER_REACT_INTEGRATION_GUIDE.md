# Flutter ↔ React WebView 통합 가이드
## 매출/매입계약 기안서 HTML 동적 렌더링 및 편집 기능 연동

---

## 📋 목차
1. [개요](#개요)
2. [전체 프로세스 흐름](#전체-프로세스-흐름)
3. [Flutter 측 구현](#flutter-측-구현)
4. [React 측 구현](#react-측-구현)
5. [연동 테스트](#연동-테스트)
6. [트러블슈팅](#트러블슈팅)

---

## 개요

### 목적
AI 서버로부터 받은 **값이 채워진 HTML 계약서 테이블**을 React 웹뷰 에디터에 동적으로 로드하고, 사용자가 편집할 수 있도록 하는 양방향 통신 구현

### 현재 상황
- **Flutter 앱**: AI 서버로부터 JSON 데이터 수신 (HTML 콘텐츠 포함)
- **React 웹뷰**:
  - 상단: 에디팅 툴바 (서식, 표 편집 등)
  - 하단: 하드코딩된 빈 계약서 테이블

### 해결 과제
1. Flutter → React로 서버에서 받은 HTML 전달
2. React 에디터에 HTML 렌더링
3. 에디팅 기능이 새로운 HTML에도 적용
4. (선택) 편집된 HTML을 Flutter로 다시 전달

---

## 전체 프로세스 흐름

```
[사용자] → [Flutter 앱]
    ↓
[채팅으로 데이터+파일 전송]
    ↓
[AI 서버] → 양식 파악 + HTML 생성
    ↓
[Flutter 앱] ← JSON 응답 (title, content(HTML) 등)
    ↓
[전자결재 상신 초안 모달 오픈]
    ↓
[React WebView 초기화]
    ↓
[Flutter → React] JavaScript 통신으로 HTML 전달
    ↓
[React 에디터] HTML 렌더링 + 편집 기능 적용
    ↓
[사용자 편집]
    ↓
[저장/제출] → [React → Flutter] 편집된 HTML 전달
    ↓
[Flutter] 서버로 전송
```

---

## Flutter 측 구현

### 📂 파일 위치
`lib/features/approval/common_electronic_approval_modal.dart`

### 1️⃣ HTML 전송 함수 추가

```dart
/// HTML을 React 앱에 전달하는 함수
Future<void> _sendHtmlToReactApp(String htmlContent) async {
  if (_contractWebviewController == null) {
    print('❌ WebView 컨트롤러가 초기화되지 않음');
    return;
  }

  try {
    // HTML 이스케이프 처리 (따옴표, 줄바꿈, 백슬래시)
    final escapedHtml = htmlContent
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');

    // React 앱의 전역 함수 호출
    await _contractWebviewController!.executeScript('''
      (function() {
        if (window.receiveHtmlContent) {
          window.receiveHtmlContent('$escapedHtml');
          console.log('✅ HTML 수신 완료');
          return true;
        } else {
          console.error('❌ window.receiveHtmlContent 함수를 찾을 수 없음');
          return false;
        }
      })();
    ''');

    print('✅ Flutter → React: HTML 콘텐츠 전달 완료 (${htmlContent.length} bytes)');
  } catch (e) {
    print('❌ HTML 전달 실패: $e');
  }
}
```

### 2️⃣ WebView 로딩 완료 시 HTML 전달

`_initializeContractWebview` 함수 수정:

```dart
Future<void> _initializeContractWebview(String webUrl, List<String>? allowedUrlPatterns) async {
  if (_isContractWebviewInitialized) return;

  try {
    _contractWebviewController = WebviewController();
    await _contractWebviewController!.initialize();

    _contractCurrentAllowedUrl = webUrl;

    // URL 변경 감지
    _contractUrlSubscription = _contractWebviewController!.url.listen((url) {
      if (url.isNotEmpty) {
        bool isAllowed = true;
        if (allowedUrlPatterns != null && allowedUrlPatterns.isNotEmpty) {
          isAllowed = allowedUrlPatterns.any((pattern) => url.contains(pattern));
        }

        if (!isAllowed) {
          print('🚫 허용되지 않은 URL로 이동 시도 차단: $url');
          _contractWebviewController!.loadUrl(_contractCurrentAllowedUrl!);
        } else {
          _contractCurrentAllowedUrl = url;
          print('✅ 허용된 URL: $url');
        }
      }
    });

    // ⭐ 로딩 상태 감지 - HTML 전달 타이밍
    _contractWebviewController!.loadingState.listen((LoadingState state) {
      if (mounted) {
        setState(() {
          _isContractWebviewLoading = state == LoadingState.loading;
        });

        // ⭐ React 앱 로딩 완료 시 HTML 전달
        if (state == LoadingState.navigationCompleted) {
          print('🌐 React 앱 로딩 완료');

          // React 앱이 완전히 마운트될 때까지 대기
          if (_serverHtmlContent != null && _serverHtmlContent!.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 800), () {
              print('📤 서버 HTML을 React 앱으로 전송 시작...');
              _sendHtmlToReactApp(_serverHtmlContent!);
            });
          }
        }
      }
    });

    await _contractWebviewController!.loadUrl(webUrl);

    if (mounted) {
      setState(() {
        _isContractWebviewInitialized = true;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isContractWebviewLoading = false;
        _contractWebviewError = '웹뷰 초기화 실패: $e';
      });
    }
  }
}
```

### 3️⃣ 데이터 초기화 시 HTML 전달

`initializeWithContractApprovalData` 함수 수정:

```dart
/// 매출/매입 계약 기안서 초기화 (JSON 데이터로)
void initializeWithContractApprovalData(Map<String, dynamic> jsonData) async {
  print('🏢 [CommonElectronicApprovalModal] 매출/매입 계약 기안서 초기화 시작');

  setState(() {
    _isLoadingHtmlContent = true;
    // 결재종류를 매출/매입계약 기안서로 강제 설정
    _selectedApprovalType = '매출/매입계약 기안서';
  });

  // 로딩 시뮬레이션 (짧게)
  await Future.delayed(const Duration(milliseconds: 500));

  // JSON 데이터 매핑
  _mapContractApprovalJsonToFields(jsonData);

  // ⭐ WebView가 이미 초기화된 경우 즉시 HTML 전달
  if (_isContractWebviewInitialized &&
      _serverHtmlContent != null &&
      _serverHtmlContent!.isNotEmpty) {
    print('📤 WebView 초기화 완료, HTML 즉시 전송');
    await _sendHtmlToReactApp(_serverHtmlContent!);
  }

  setState(() {
    _isLoadingHtmlContent = false;
  });

  print('🏢 [CommonElectronicApprovalModal] 매출/매입 계약 기안서 초기화 완료');
  print('🏢 [CommonElectronicApprovalModal] 제목: $_title');
  print('🏢 [CommonElectronicApprovalModal] HTML 콘텐츠 길이: ${_serverHtmlContent?.length ?? 0}');
}
```

### 4️⃣ (선택) 편집된 HTML 가져오기

저장/제출 시 사용:

```dart
/// React 앱으로부터 편집된 HTML 가져오기
Future<String?> _getEditedHtmlFromReactApp() async {
  if (_contractWebviewController == null) {
    print('❌ WebView 컨트롤러가 초기화되지 않음');
    return null;
  }

  try {
    final result = await _contractWebviewController!.executeScript('''
      (function() {
        if (window.getEditedContent) {
          return window.getEditedContent();
        } else {
          console.error('❌ window.getEditedContent 함수를 찾을 수 없음');
          return null;
        }
      })();
    ''');

    print('✅ React → Flutter: 편집된 HTML 수신 (${result?.length ?? 0} bytes)');
    return result;
  } catch (e) {
    print('❌ 편집된 HTML 가져오기 실패: $e');
    return null;
  }
}

/// 제출 시 사용 예시
Future<void> _submitApproval() async {
  // ... 기존 검증 로직

  // 매출/매입계약 기안서인 경우 편집된 HTML 가져오기
  if (_selectedApprovalType == '매출/매입계약 기안서') {
    final editedHtml = await _getEditedHtmlFromReactApp();
    if (editedHtml != null) {
      _serverHtmlContent = editedHtml; // 업데이트
      print('📝 편집된 HTML로 업데이트됨');
    }
  }

  // ... 서버 전송 로직
}
```

---

## React 측 구현

### 📂 파일 위치
React 서버 (`http://210.107.96.193:3001/`) 코드

### 구현해야 할 것
1. `window.receiveHtmlContent()` - Flutter로부터 HTML 받기
2. `window.getEditedContent()` - 편집된 HTML 전달
3. 에디터에 HTML 동적 로드 기능

### 사용 중인 에디터 확인 필요
- **Quill**: `quillRef.current.clipboard.dangerouslyPasteHTML(html)`
- **TinyMCE**: `tinymce.activeEditor.setContent(html)`
- **Draft.js**: `EditorState.createWithContent(convertFromHTML(html))`
- **CKEditor**: `editor.setData(html)`
- **기타**: 사용 중인 에디터에 따라 달라짐

---

### 예시 1: Quill 에디터 사용 시

```javascript
// src/App.js 또는 메인 에디터 컴포넌트

import React, { useEffect, useRef } from 'react';
import ReactQuill from 'react-quill';
import 'react-quill/dist/quill.snow.css';

function ContractEditor() {
  const quillRef = useRef(null);
  const [editorHtml, setEditorHtml] = React.useState('');

  useEffect(() => {
    // ⭐ Flutter로부터 HTML을 받는 전역 함수 등록
    window.receiveHtmlContent = (htmlContent) => {
      console.log('📥 Flutter로부터 HTML 수신:', htmlContent.substring(0, 100) + '...');

      try {
        // Quill 에디터에 HTML 설정
        if (quillRef.current) {
          const editor = quillRef.current.getEditor();
          editor.clipboard.dangerouslyPasteHTML(htmlContent);
          console.log('✅ HTML 렌더링 완료');
        } else {
          // ref가 아직 준비되지 않은 경우 state로 설정
          setEditorHtml(htmlContent);
          console.log('✅ HTML state에 저장됨 (에디터 준비 대기 중)');
        }
      } catch (error) {
        console.error('❌ HTML 렌더링 실패:', error);
      }
    };

    // ⭐ Flutter에 편집된 HTML 전달하는 함수
    window.getEditedContent = () => {
      console.log('📤 Flutter로 편집된 HTML 전송 요청');

      if (quillRef.current) {
        const editor = quillRef.current.getEditor();
        const html = editor.root.innerHTML;
        console.log('✅ 편집된 HTML 전송:', html.substring(0, 100) + '...');
        return html;
      }

      console.warn('⚠️ 에디터가 초기화되지 않음');
      return null;
    };

    // 디버깅용: Flutter 통신 테스트 함수
    window.testFlutterConnection = () => {
      console.log('🧪 Flutter 통신 테스트');
      console.log('- receiveHtmlContent:', typeof window.receiveHtmlContent);
      console.log('- getEditedContent:', typeof window.getEditedContent);
    };

    console.log('✅ Flutter 통신 함수 등록 완료');

    // 클린업
    return () => {
      delete window.receiveHtmlContent;
      delete window.getEditedContent;
      delete window.testFlutterConnection;
    };
  }, []);

  return (
    <div className="contract-editor">
      <h2>매출/매입 계약 기안서</h2>

      <ReactQuill
        ref={quillRef}
        value={editorHtml}
        onChange={setEditorHtml}
        modules={{
          toolbar: [
            [{ 'header': [1, 2, 3, false] }],
            ['bold', 'italic', 'underline', 'strike'],
            [{ 'list': 'ordered'}, { 'list': 'bullet' }],
            [{ 'align': [] }],
            ['link', 'image'],
            ['clean'],
            // 표 편집 기능
            [{ 'table': 'insert-table' }]
          ]
        }}
        formats={[
          'header',
          'bold', 'italic', 'underline', 'strike',
          'list', 'bullet',
          'align',
          'link', 'image',
          'table'
        ]}
      />
    </div>
  );
}

export default ContractEditor;
```

---

### 예시 2: TinyMCE 에디터 사용 시

```javascript
// src/App.js

import React, { useEffect, useRef } from 'react';
import { Editor } from '@tinymce/tinymce-react';

function ContractEditor() {
  const editorRef = useRef(null);

  useEffect(() => {
    // ⭐ Flutter로부터 HTML을 받는 함수
    window.receiveHtmlContent = (htmlContent) => {
      console.log('📥 Flutter로부터 HTML 수신');

      if (editorRef.current) {
        editorRef.current.setContent(htmlContent);
        console.log('✅ TinyMCE에 HTML 설정 완료');
      }
    };

    // ⭐ 편집된 HTML 전달
    window.getEditedContent = () => {
      console.log('📤 편집된 HTML 전송');

      if (editorRef.current) {
        return editorRef.current.getContent();
      }
      return null;
    };

    console.log('✅ Flutter 통신 함수 등록 완료');

    return () => {
      delete window.receiveHtmlContent;
      delete window.getEditedContent;
    };
  }, []);

  return (
    <Editor
      onInit={(evt, editor) => editorRef.current = editor}
      initialValue="<p>계약서를 불러오는 중...</p>"
      init={{
        height: 600,
        menubar: true,
        plugins: [
          'table', 'lists', 'link', 'image', 'paste',
          'searchreplace', 'visualblocks', 'fullscreen'
        ],
        toolbar: 'undo redo | formatselect | bold italic | \
                  alignleft aligncenter alignright | \
                  table | bullist numlist | link image',
        content_style: 'body { font-family:Helvetica,Arial,sans-serif; font-size:14px }',
        // 표 편집 기능 활성화
        table_toolbar: 'tableprops tabledelete | tableinsertrowbefore tableinsertrowafter tabledeleterow | tableinsertcolbefore tableinsertcolafter tabledeletecol',
        table_appearance_options: true,
        table_default_styles: {
          width: '100%',
          borderCollapse: 'collapse'
        }
      }}
    />
  );
}

export default ContractEditor;
```

---

### 예시 3: 순수 contentEditable 사용 시

에디터 라이브러리 없이 구현:

```javascript
// src/ContractEditor.js

import React, { useEffect, useRef, useState } from 'react';
import './ContractEditor.css';

function ContractEditor() {
  const editorRef = useRef(null);
  const [htmlContent, setHtmlContent] = useState('<p>계약서를 불러오는 중...</p>');

  useEffect(() => {
    // ⭐ Flutter로부터 HTML 받기
    window.receiveHtmlContent = (html) => {
      console.log('📥 HTML 수신:', html.substring(0, 100));
      setHtmlContent(html);

      // DOM에 직접 설정
      if (editorRef.current) {
        editorRef.current.innerHTML = html;
      }
    };

    // ⭐ 편집된 HTML 전달
    window.getEditedContent = () => {
      console.log('📤 편집된 HTML 전송');
      return editorRef.current ? editorRef.current.innerHTML : null;
    };

    console.log('✅ Flutter 통신 준비 완료');

    return () => {
      delete window.receiveHtmlContent;
      delete window.getEditedContent;
    };
  }, []);

  const handleInput = (e) => {
    setHtmlContent(e.target.innerHTML);
  };

  // 서식 적용 함수들
  const applyFormat = (command, value = null) => {
    document.execCommand(command, false, value);
  };

  return (
    <div className="contract-editor-container">
      {/* 에디팅 툴바 */}
      <div className="toolbar">
        <button onClick={() => applyFormat('bold')} title="굵게">
          <strong>B</strong>
        </button>
        <button onClick={() => applyFormat('italic')} title="기울임">
          <em>I</em>
        </button>
        <button onClick={() => applyFormat('underline')} title="밑줄">
          <u>U</u>
        </button>
        <div className="separator"></div>
        <button onClick={() => applyFormat('insertOrderedList')} title="번호 목록">
          1. 목록
        </button>
        <button onClick={() => applyFormat('insertUnorderedList')} title="글머리 기호">
          • 목록
        </button>
        <div className="separator"></div>
        <button onClick={() => applyFormat('justifyLeft')} title="왼쪽 정렬">
          ←
        </button>
        <button onClick={() => applyFormat('justifyCenter')} title="가운데 정렬">
          ↔
        </button>
        <button onClick={() => applyFormat('justifyRight')} title="오른쪽 정렬">
          →
        </button>
      </div>

      {/* 편집 가능한 영역 */}
      <div
        ref={editorRef}
        className="editor-content"
        contentEditable={true}
        onInput={handleInput}
        dangerouslySetInnerHTML={{ __html: htmlContent }}
      />
    </div>
  );
}

export default ContractEditor;
```

```css
/* src/ContractEditor.css */

.contract-editor-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
  padding: 16px;
}

.toolbar {
  display: flex;
  gap: 8px;
  padding: 12px;
  background: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 8px 8px 0 0;
  flex-wrap: wrap;
}

.toolbar button {
  padding: 8px 12px;
  border: 1px solid #ccc;
  background: white;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.toolbar button:hover {
  background: #e9ecef;
}

.toolbar button:active {
  background: #dee2e6;
}

.separator {
  width: 1px;
  background: #ccc;
  margin: 0 4px;
}

.editor-content {
  flex: 1;
  padding: 24px;
  border: 1px solid #ddd;
  border-top: none;
  border-radius: 0 0 8px 8px;
  background: white;
  overflow-y: auto;
  outline: none;
  font-family: 'Malgun Gothic', sans-serif;
  font-size: 14px;
  line-height: 1.6;
}

.editor-content:focus {
  border-color: #4A6CF7;
  box-shadow: 0 0 0 2px rgba(74, 108, 247, 0.1);
}

/* 테이블 스타일 */
.editor-content table {
  border-collapse: collapse;
  width: 100%;
  margin: 16px 0;
}

.editor-content table td,
.editor-content table th {
  border: 1px solid #ddd;
  padding: 12px;
  min-width: 50px;
}

.editor-content table th {
  background: #4A6CF7;
  color: white;
  font-weight: bold;
}

.editor-content table tr:nth-child(even) {
  background: #f8f9fa;
}
```

---

## 연동 테스트

### 1️⃣ React 앱 개발 서버 실행

```bash
cd /path/to/react-app
npm install
npm start
# http://localhost:3000 또는 http://210.107.96.193:3001
```

### 2️⃣ Flutter 앱 실행

```bash
cd /path/to/flutter-app
flutter run -d windows
```

### 3️⃣ 테스트 시나리오

**Step 1: React 앱 통신 함수 확인**
- React 앱이 로드되면 브라우저 개발자 도구 콘솔에서:
```javascript
window.testFlutterConnection()
// 출력 확인:
// - receiveHtmlContent: function
// - getEditedContent: function
```

**Step 2: Flutter에서 HTML 전송 테스트**
1. Flutter 앱에서 매출/매입계약 기안서 모달 오픈
2. AI 서버로부터 HTML 데이터 수신 (또는 테스트 데이터)
3. 디버그 콘솔 확인:
```
✅ Flutter → React: HTML 콘텐츠 전달 완료
```
4. React 앱에서 HTML이 렌더링되는지 확인

**Step 3: 편집 기능 테스트**
1. React 에디터에서 텍스트 수정
2. 표 셀 편집
3. 서식 적용 (굵게, 밑줄 등)

**Step 4: Flutter로 편집된 HTML 전송 테스트**
1. Flutter 앱에서 저장/제출 버튼 클릭
2. `_getEditedHtmlFromReactApp()` 호출
3. 편집된 HTML이 정상적으로 수신되는지 확인

### 4️⃣ 디버깅 로그 확인

**Flutter 콘솔**
```
🌐 React 앱 로딩 완료
📤 서버 HTML을 React 앱으로 전송 시작...
✅ Flutter → React: HTML 콘텐츠 전달 완료 (1234 bytes)
```

**React 브라우저 콘솔**
```
✅ Flutter 통신 함수 등록 완료
📥 Flutter로부터 HTML 수신: <table><tr><td>...
✅ HTML 렌더링 완료
📤 Flutter로 편집된 HTML 전송 요청
✅ 편집된 HTML 전송: <table><tr><td>...
```

---

## 트러블슈팅

### 문제 1: `window.receiveHtmlContent is not a function`

**원인**: React 앱이 완전히 로드되기 전에 Flutter가 함수 호출

**해결**:
```dart
// Flutter에서 딜레이 증가
Future.delayed(const Duration(milliseconds: 1500), () {
  _sendHtmlToReactApp(_serverHtmlContent!);
});
```

### 문제 2: HTML이 렌더링되지 않음

**원인**: 에디터 ref가 아직 준비되지 않음

**해결**:
```javascript
// React에서 state로 먼저 저장
window.receiveHtmlContent = (html) => {
  setEditorHtml(html); // state 업데이트

  if (editorRef.current) {
    editorRef.current.setContent(html); // 즉시 설정
  }
};
```

### 문제 3: HTML 이스케이프 오류

**원인**: 특수문자가 제대로 이스케이프되지 않음

**해결**:
```dart
// 더 강력한 이스케이프
final escapedHtml = htmlContent
    .replaceAll('\\', '\\\\')
    .replaceAll("'", "\\'")
    .replaceAll('"', '\\"')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\r')
    .replaceAll('\t', '\\t')
    .replaceAll('\b', '\\b')
    .replaceAll('\f', '\\f');
```

또는 Base64 인코딩 사용:
```dart
import 'dart:convert';

final base64Html = base64.encode(utf8.encode(htmlContent));
await _contractWebviewController!.executeScript('''
  window.receiveHtmlContent(atob('$base64Html'));
''');
```

### 문제 4: 편집된 HTML이 null로 반환됨

**원인**: `executeScript`가 비동기적으로 동작하지 않음

**해결**:
```javascript
// React에서 전역 변수로 저장
window.editedHtmlCache = '';

// 편집 시마다 업데이트
const handleEditorChange = (content) => {
  setEditorHtml(content);
  window.editedHtmlCache = content;
};

window.getEditedContent = () => {
  return window.editedHtmlCache;
};
```

### 문제 5: 한글 깨짐

**원인**: UTF-8 인코딩 문제

**해결**:
```javascript
// React - UTF-8 meta 태그 확인
<meta charset="UTF-8" />
```

```dart
// Flutter - UTF-8 인코딩 명시
import 'dart:convert';
final utf8Html = utf8.decode(utf8.encode(htmlContent));
```

---

## 📌 체크리스트

### Flutter 측
- [ ] `_sendHtmlToReactApp()` 함수 구현
- [ ] `_initializeContractWebview()` 로딩 완료 리스너 추가
- [ ] `initializeWithContractApprovalData()` HTML 전송 로직 추가
- [ ] `_getEditedHtmlFromReactApp()` 함수 구현 (선택)
- [ ] 디버그 로그 확인

### React 측
- [ ] `window.receiveHtmlContent()` 함수 구현
- [ ] `window.getEditedContent()` 함수 구현
- [ ] 에디터 라이브러리 선택 및 설정
- [ ] HTML 렌더링 테스트
- [ ] 편집 기능 테스트
- [ ] 콘솔 로그 확인

### 연동 테스트
- [ ] React 앱 정상 로드 확인
- [ ] Flutter → React HTML 전송 확인
- [ ] React 에디터 렌더링 확인
- [ ] 편집 기능 동작 확인
- [ ] React → Flutter HTML 회신 확인 (선택)

---

## 📞 문의 및 지원

구현 중 문제가 발생하면:
1. Flutter 콘솔 로그 확인
2. React 브라우저 개발자 도구 콘솔 확인
3. 위 트러블슈팅 섹션 참고
4. 필요시 추가 지원 요청

---

**작성일**: 2025-11-25
**버전**: 1.0
