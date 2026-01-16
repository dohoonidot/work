import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlighting/flutter_highlighting.dart';
import 'package:flutter_highlighting/themes/github.dart';
import 'package:flutter_highlighting/themes/github-dark.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'cache_manager.dart';

/// 코드 블록 렌더링을 담당하는 클래스
///
/// 이 클래스는 다양한 프로그래밍 언어의 코드 블록을 가져와 구문 강조 처리를 수행합니다.
/// 앱 테마에 따라 적절한 구문 강조 테마를 자동으로 선택합니다.
class CodeBlockRenderer {
  /// 코드 블록 렌더링
  static Widget buildCodeBlock(String code, String? languageId,
      [AppColorScheme? themeColors]) {
    // 언어 ID null 안전성 보장
    final safeLanguageId = languageId ?? 'plaintext';

    // 캐시 키 생성 (테마 정보도 포함)
    final String themeKey = themeColors?.name ?? 'default';
    final String cacheKey = '${code.hashCode}-$safeLanguageId-$themeKey';

    // 캐시에 있으면 캐시된 위젯 반환
    if (MessageCacheManager.hasCodeBlock(cacheKey)) {
      return MessageCacheManager.getCodeBlock(cacheKey)!;
    }

    // 언어 ID 정규화
    String normalizedLangId = _normalizeLanguageId(safeLanguageId);

    // 코드가 비어있으면 공백 문자로 대체 (완전히 빈 문자열 방지)
    final codeContent = code.isNotEmpty ? code : ' ';

    // 테마에 따른 코드 블록 배경색 결정
    Color codeBlockBackgroundColor;
    bool isLightTheme = themeColors?.name == 'Light';

    if (themeColors != null) {
      // 테마에 정의된 부드러운 코드 블록 배경색 사용
      codeBlockBackgroundColor = themeColors.codeBlockBackgroundColor;
    } else {
      codeBlockBackgroundColor = const Color(0xff272822); // 기본값: 모노카이
    }

    // 위젯 생성
    final widget = LayoutBuilder(
      builder: (context, constraints) {
        // 화면 크기에 따른 동적 최대 너비 계산
        final screenWidth = MediaQuery.of(context).size.width;
        final maxCodeWidth = screenWidth * 0.95; // 화면 너비의 95%

        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: maxCodeWidth, // 동적 최대 너비
            minWidth: 200, // 최소 너비 보장
          ),
          decoration: BoxDecoration(
            color: codeBlockBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            // Light 테마에서는 연한 테두리로 경계 표시
            border: isLightTheme
                ? Border.all(
                    color: Colors.grey.withValues(alpha: 0.2), width: 1)
                : null,
            boxShadow: isLightTheme
                ? null // Light 테마: 그림자 없음
                : null,
          ),
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(10),
          child: _ExpandableCodeBlock(
            code: codeContent,
            languageId: normalizedLangId,
            themeColors: themeColors,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: code));
            },
          ),
        );
      },
    );

    // 위젯 캐싱
    MessageCacheManager.cacheCodeBlock(cacheKey, widget);

    return widget;
  }

  /// 디렉토리 트리 코드 블록 렌더링 (특별 처리)
  static Widget buildDirectoryTreeBlock(String code,
      [AppColorScheme? themeColors]) {
    // 테마에 따른 색상 결정
    Color backgroundColor;
    Color textColor;
    Color iconColor;
    bool isLightTheme = themeColors?.name == 'Light';

    if (themeColors != null) {
      // 테마에 정의된 부드러운 코드 블록 배경색 사용
      backgroundColor = themeColors.codeBlockBackgroundColor;
      textColor = themeColors.codeBlockTextColor;
      iconColor = isLightTheme ? Colors.grey[600]! : Colors.grey;
    } else {
      // 기본값
      backgroundColor = const Color(0xff272822);
      textColor = Colors.white;
      iconColor = Colors.grey;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        // Light 테마에서는 연한 테두리로 경계 표시
        border: isLightTheme
            ? Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1)
            : null,
        boxShadow: isLightTheme
            ? null // Light 테마: 그림자 없음
            : null,
      ),
      child: Stack(
        children: [
          SelectableText(
            code,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 14,
              color: textColor,
              height: 1.4,
            ),
          ),
          // 복사 버튼 추가
          Positioned(
            top: 5,
            right: 5,
            child: Builder(
              builder: (BuildContext context) {
                return InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    CommonUIUtils.showInfoSnackBar(
                        context, '디렉토리 구조가 복사되었습니다.');
                  },
                  child: Icon(
                    Icons.copy,
                    size: 20,
                    color: iconColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 언어 ID 정규화
  static String _normalizeLanguageId(String? languageId) {
    // null 체크 추가
    if (languageId == null) {
      return 'plaintext';
    }

    // null, 빈 문자열, 'text', 'plaintext' 등은 모두 'plaintext'로 처리
    if (languageId.isEmpty ||
        ['text', 'plaintext', 'plain', 'trans', 'txt']
            .contains(languageId.toLowerCase())) {
      return 'plaintext';
    }

    // 특정 언어 매핑
    final Map<String, String> languageMapping = {
      'ab': 'abap',
      'html': 'xml',
      'jsx': 'javascript',
      'tsx': 'typescript',
      'react': 'javascript',
      'js': 'javascript',
      'ts': 'typescript',
      'py': 'python',
      'rb': 'ruby',
      'sh': 'bash',
      'zsh': 'bash',
      'ps1': 'powershell',
    };

    // 지원하는 언어 목록 (highlighting 패키지의 모든 언어)
    final Set<String> supportedLanguages = {
      '1c',
      'abap',
      'abnf',
      'accesslog',
      'actionscript',
      'ada',
      'angelscript',
      'apache',
      'applescript',
      'arcade',
      'arduino',
      'armasm',
      'asciidoc',
      'aspectj',
      'autohotkey',
      'autoit',
      'avrasm',
      'awk',
      'axapta',
      'bash',
      'basic',
      'bnf',
      'brainfuck',
      'c',
      'cal',
      'capnproto',
      'ceylon',
      'clean',
      'clojure-repl',
      'clojure',
      'cmake',
      'coffeescript',
      'coq',
      'cos',
      'cpp',
      'crmsh',
      'crystal',
      'csharp',
      'csp',
      'css',
      'd',
      'dart',
      'delphi',
      'diff',
      'django',
      'dns',
      'dockerfile',
      'dos',
      'dsconfig',
      'dts',
      'dust',
      'ebnf',
      'elixir',
      'elm',
      'erb',
      'erlang-repl',
      'erlang',
      'excel',
      'fix',
      'flix',
      'fortran',
      'fsharp',
      'gams',
      'gauss',
      'gcode',
      'gherkin',
      'glsl',
      'gml',
      'go',
      'golo',
      'gradle',
      'graphql',
      'groovy',
      'haml',
      'handlebars',
      'haskell',
      'haxe',
      'hsp',
      'http',
      'hy',
      'inform7',
      'ini',
      'irpf90',
      'isbl',
      'java',
      'javascript',
      'jboss-cli',
      'json',
      'julia-repl',
      'julia',
      'kotlin',
      'lasso',
      'latex',
      'ldif',
      'leaf',
      'less',
      'lisp',
      'livecodeserver',
      'livescript',
      'llvm',
      'lsl',
      'lua',
      'makefile',
      'markdown',
      'mathematica',
      'matlab',
      'maxima',
      'mel',
      'mercury',
      'mipsasm',
      'mizar',
      'mojolicious',
      'monkey',
      'moonscript',
      'n1ql',
      'nestedtext',
      'nginx',
      'nim',
      'nix',
      'node-repl',
      'nsis',
      'objectivec',
      'ocaml',
      'openscad',
      'oxygene',
      'parser3',
      'perl',
      'pf',
      'pgsql',
      'php-template',
      'php',
      'plaintext',
      'pony',
      'powershell',
      'processing',
      'profile',
      'prolog',
      'properties',
      'protobuf',
      'puppet',
      'purebasic',
      'python-repl',
      'python',
      'q',
      'qml',
      'r',
      'reasonml',
      'rib',
      'roboconf',
      'routeros',
      'rsl',
      'ruby',
      'ruleslanguage',
      'rust',
      'sas',
      'scala',
      'scheme',
      'scilab',
      'scss',
      'shell',
      'smali',
      'smalltalk',
      'sml',
      'sqf',
      'sql',
      'stan',
      'stata',
      'step21',
      'stylus',
      'subunit',
      'swift',
      'taggerscript',
      'tap',
      'tcl',
      'thrift',
      'tp',
      'twig',
      'typescript',
      'vala',
      'vbnet',
      'vbscript-html',
      'vbscript',
      'verilog',
      'vhdl',
      'vim',
      'wasm',
      'wren',
      'x86asm',
      'xl',
      'xml',
      'xquery',
      'yaml',
      'zephir'
    };

    // 먼저 매핑 확인
    String mappedLanguage =
        languageMapping[languageId.toLowerCase()] ?? languageId.toLowerCase();

    // 지원되는 언어인지 확인, 없으면 plaintext로 폴백
    return supportedLanguages.contains(mappedLanguage)
        ? mappedLanguage
        : 'plaintext';
  }

  /// GitHub Light 테마 (배경색 투명)
  static Map<String, TextStyle> _getGitHubLightTheme() {
    // GitHub 테마를 복사하고 배경색만 투명으로 변경
    final theme = Map<String, TextStyle>.from(githubTheme);
    theme['root'] = const TextStyle(
      color: Color(0xff24292e),
      backgroundColor: Colors.transparent,
    );
    return theme;
  }

  /// GitHub Dark 테마 (배경색 투명)
  static Map<String, TextStyle> _getGitHubDarkTheme() {
    // GitHub Dark 테마를 복사하고 배경색만 투명으로 변경
    final theme = Map<String, TextStyle>.from(githubDarkTheme);
    theme['root'] = const TextStyle(
      color: Color(0xffc9d1d9),
      backgroundColor: Colors.transparent,
    );
    return theme;
  }
}

/// 접을 수 있는 코드 블록 위젯
class _ExpandableCodeBlock extends StatefulWidget {
  final String code;
  final String? languageId;
  final AppColorScheme? themeColors;
  final VoidCallback onCopy;

  const _ExpandableCodeBlock({
    required this.code,
    this.languageId,
    this.themeColors,
    required this.onCopy,
  });

  @override
  State<_ExpandableCodeBlock> createState() => _ExpandableCodeBlockState();
}

class _ExpandableCodeBlockState extends State<_ExpandableCodeBlock> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    // 테마에 따른 색상 결정
    Color containerBackgroundColor;
    Color textColor;
    bool isLightTheme = widget.themeColors?.name == 'Light';

    if (widget.themeColors != null) {
      // 테마에 정의된 부드러운 코드 블록 배경색 사용
      containerBackgroundColor = widget.themeColors!.codeBlockBackgroundColor;
      textColor = widget.themeColors!.codeBlockTextColor;
    } else {
      // 기본값 (모노카이)
      containerBackgroundColor = const Color(0xff272822);
      textColor = Colors.white;
      isLightTheme = false; // 테마가 없으면 Dark로 간주
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 언어 표시
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                widget.languageId ?? 'plaintext',
                style: TextStyle(
                  color: isLightTheme ? Colors.grey[600] : Colors.grey,
                  fontSize: 12,
                  fontFamily: 'Courier',
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 접기/펼치기 버튼
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isLightTheme ? Colors.grey[600] : Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // 복사 버튼
                InkWell(
                  onTap: widget.onCopy,
                  child: Icon(
                    Icons.copy,
                    size: 20,
                    color: isLightTheme ? Colors.grey[600] : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 코드 내용
        IgnorePointer(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: _isExpanded ? double.infinity : 0,
            ),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: containerBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: Theme(
                      data: isLightTheme
                          ? ThemeData.light().copyWith(
                              textTheme: ThemeData.light().textTheme.copyWith(
                                    bodyMedium: TextStyle(color: textColor),
                                    bodyLarge: TextStyle(color: textColor),
                                    bodySmall: TextStyle(color: textColor),
                                  ),
                              textSelectionTheme: const TextSelectionThemeData(
                                selectionColor: Colors.blue,
                                selectionHandleColor: Colors.blue,
                              ),
                            )
                          : ThemeData.dark().copyWith(
                              textTheme: ThemeData.dark().textTheme.copyWith(
                                    bodyMedium: TextStyle(color: textColor),
                                    bodyLarge: TextStyle(color: textColor),
                                    bodySmall: TextStyle(color: textColor),
                                  ),
                              textSelectionTheme: const TextSelectionThemeData(
                                selectionColor: Colors.blue,
                                selectionHandleColor: Colors.blue,
                              ),
                            ),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 14,
                            color: textColor,
                            backgroundColor: Colors.transparent,
                          ),
                          child: FutureBuilder<Widget>(
                            future: Future.microtask(() {
                              // 테마에 따른 구문 강조 테마 선택
                              Map<String, TextStyle> selectedTheme;

                              if (isLightTheme) {
                                // Light 테마: GitHub 테마 사용 (배경색만 투명으로 변경)
                                selectedTheme =
                                    CodeBlockRenderer._getGitHubLightTheme();
                              } else {
                                // Dark 테마: GitHub Dark 테마 사용 (배경색만 투명으로 변경)
                                selectedTheme =
                                    CodeBlockRenderer._getGitHubDarkTheme();
                              }

                              return Container(
                                constraints: const BoxConstraints(
                                  minHeight: 100,
                                ),
                                child: HighlightView(
                                  widget.code,
                                  languageId: widget.languageId ??
                                      'plaintext', // null 안전성 보장
                                  theme: selectedTheme,
                                  textStyle: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 14,
                                    color: textColor,
                                    fontWeight: FontWeight.normal,
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              );
                            }),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.done &&
                                  snapshot.hasData) {
                                return snapshot.data!;
                              }
                              // 하이라이트 적용 전 기본 텍스트 스타일 (임시 렌더링)
                              return Container(
                                width: double.infinity,
                                height: 100, // 최소 높이 설정
                                decoration: BoxDecoration(
                                  color: containerBackgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: SelectableText(
                                    widget.code,
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 14,
                                      color: textColor,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 스크롤 중에 선택 영역이 유지되도록 하는 투명한 오버레이
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
