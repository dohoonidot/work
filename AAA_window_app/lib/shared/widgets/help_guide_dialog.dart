import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';

// 현재 선택된 탭 인덱스를 관리하는 Provider
final helpGuideTabIndexProvider = StateProvider((ref) => 0);

// TabController 문제를 해결하기 위해 StatefulWidget과 ConsumerStateMixin 함께 사용
class HelpGuideDialog extends ConsumerStatefulWidget {
  const HelpGuideDialog({Key? key}) : super(key: key);

  @override
  HelpGuideDialogState createState() => HelpGuideDialogState();
}

class HelpGuideDialogState extends ConsumerState
    with SingleTickerProviderStateMixin {
  // TabController 추가
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // TabController 초기화
    _tabController = TabController(length: 4, vsync: this);

    // 컨트롤러와 Provider 동기화
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(helpGuideTabIndexProvider.notifier).state =
            _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.themeMode != AppThemeMode.light;

    // Riverpod에서 선택된 탭 인덱스 가져오기
    final selectedTabIndex = ref.watch(helpGuideTabIndexProvider);

    // Provider와 TabController 동기화
    if (_tabController.index != selectedTabIndex) {
      _tabController.animateTo(selectedTabIndex);
    }

    return Container(
      width: 800,
      height: 600,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ASPN AI 에이전트 사용 가이드',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Divider(
            color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
          ),
          TabBar(
            // TabController 연결
            controller: _tabController,
            onTap: (index) {
              // 탭 선택 시 Provider 상태 업데이트
              ref.read(helpGuideTabIndexProvider.notifier).state = index;
            },
            isScrollable: true,
            labelColor:
                isDarkMode ? Colors.white : Theme.of(context).primaryColor,
            unselectedLabelColor: isDarkMode ? Colors.grey[400] : Colors.grey,
            indicatorColor:
                isDarkMode ? Colors.grey[600] : Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: '기본 기능', icon: Icon(Icons.home)),
              Tab(text: '사내업무 AI', icon: Icon(Icons.work)),
              Tab(text: '코딩 어시스턴트', icon: Icon(Icons.code)),
              Tab(text: 'SAP 어시스턴트', icon: Icon(Icons.business)),
            ],
          ),
          Expanded(
            // TabBarView 사용 (IndexedStack 대신)
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicGuide(context),
                _buildBusinessGuide(context),
                _buildCodingGuide(context),
                _buildSapGuide(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicGuide(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGuideSection(
              title: '사용자 앱 안내 가이드',
              content:
                  "• 이제 **auto update** 기능으로 setup 파일을 한 번만 다운로드 받으면 그 이후로는 **자동 업데이트**가 됩니다. 처음 배포한 setup 버전은 **1.3.0** 입니다.\n\n• **aspn_agent.db**는 **documents/** 폴더 아래에 생성되는 **로컬 데이터베이스 파일**이에요. 지우면 데이터가 날아가서 문제 발생 가능성이 있습니다. 지우지 말아주세요. \n\n• 비밀번호는 현재 **'aspn1234'** 입니다. 앱 시작후 비밀번호 변경을 클릭하여 비밀번호를 변경해주세요.\n\n• **ASPN AI Agent** 는 실수할 수 있습니다. 화면 우측상단의 **이슈리스트**를 클릭하여 피드백 부탁드립니다.",
            ),
            _buildGuideSection(
              title: '앱 사용시 유의사항',
              content:
                  '• 기본적으로 AI 모델이 **이전 대화를 참조**하여 답변합니다.\n\n• **모델이 과거 데이터를 학습**하므로 최신 정보를 검색하실 경우 답변이 부정확할 수 있습니다.\n\n• **현재 메일 보내기 기능**은 베타 테스터 등록자끼리만 가능합니다.\n\n• **"우리 팀원", "사업부장님"** 과 같은 호칭은 지원되지 않으며, 조직도 상의 이름을 입력해 주셔야 합니다.\n\n• 간혹, 데이터 조회 실패시, \'**데이터를 조회하는 데 실패했습니다. 질문을 다시 검토해 주세요**.\' 라는 메시지가 나올때는, **새 채팅방을 만들거나 초기화** 시켜주시기 바랍니다. \n\n• **현재 답변이 불가능한 주제**: 잔여 연차 (연차 규정은 답변 가능 합니다), 전자 결제 관련 (추후에 서비스 예정입니다)',
            ),
            _buildGuideSection(
              title: 'Coming Soon...',
              content:
                  '• **프로젝트 관련 정보 및 인사카드 이력 자동 업데이트**\n\n• **그룹웨어 관련 정보 및 이메일 요약 알림 서비스**\n\n• **e-Accounting 경비 정보 및 AI 간편상신**\n\n• **AI 간편 기안 및 결재 상신**',
            ),
            _buildGuideSection(
              title: '기본 인터페이스 안내',
              content:
                  '• **좌측의 사이드바** : 대화 목록을 관리합니다.\n\n• **상단 대시보드** : 메뉴와 주요 아이콘이 위치합니다.\n\n• **중앙 영역** : 메인 채팅 화면입니다.',
            ),
            _buildGuideSection(
              title: '대화 관리하기',
              content:
                  '• **새 대화 추가** : 사이드바 상단의 + 버튼을 클릭합니다.\n\n• **대화 선택** : 사이드바에서 대화를 클릭하면 전환됩니다.\n\n• **대화 삭제** : 사이드바의 휴지통 아이콘을 클릭하거나 대화 우측의 메뉴에서 삭제할 수 있습니다.',
            ),
            _buildGuideSection(
              title: '주요 버튼 설명',
              content:
                  '• **GroupWare** : 그룹웨어로 이동\n\n• **e-Acc** : 전자결재 시스템으로 이동\n\n• **CSR** : 고객 지원 요청 시스템(추후에 구현 예정)\n\n• **알림** : 알림 확인(추후에 구현 예정)',
            ),
            _buildGuideSection(
              title: '기본 기능 팁',
              content:
                  '• 메시지 입력 후 **Enter** 키를 누르면 전송됩니다.\n\n• **Shift+Enter**를 누르면 줄바꿈이 됩니다.\n\n• AI 응답 도중 정지하려면 전송 버튼을 다시 클릭하세요.\n\n• 특정 주제에 대해 질문할 때는 **관련 키워드**를 포함하는 것이 좋습니다.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessGuide(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGuideSection(
              title: '사내업무 AI 어시스턴트란?',
              content:
                  '• **ASPN 사내 규정, 업무 프로세스, 회사 정보** 등에 대한 질문에 답변해주는 AI 어시스턴트입니다.\n\n• 현재 시스템상 **권한에 따라 조회 가능한 데이터의 범위**가 나뉘어 있습니다. 참고하시어, 사용 부탁드립니다.\n\n• 예를 들어, 일반 사원의 경우 인사관련 HR 질문은 **본인에 한정**됩니다.\n\n• CSR 관련 질문의 경우 **담당자만 조회**가 가능합니다.\n\n• 부서장급 인원께서는 담당하는 부서에 한하여 HR , CSR 조회 및 추론 질문이 가능합니다.',
            ),
            _buildGuideSection(
              title: '주요 기능',
              content:
                  '• 회사 규정 및 정책 안내\n\n• 직원 정보 검색 (조직도, 연락처)\n\n• CSR 관련 문의 지원',
            ),
            _buildGuideSection(
              title: '질문 예시',
              content: '## 📋 CSR\n\n'
                  '• "이번 달에 들어온 CSR요청서 중 지체된 건 알려주세요"\n\n'
                  '• "위 내용에서 지체일수가 가장 높은 건에 대해 상세 내용 알려주세요"\n\n'
                  '• "고객 대응을 제일 잘하는 CSM 이 누군가요?"\n\n'
                  '• "진행중인 CSR 개발 요청 건 알려주세요"\n\n'
                  '---\n\n'
                  '## 👥 HR\n\n'
                  '• "우리 부서에 가장 마지막에 들어온 인원은 누구인가요?"\n\n'
                  '• "회사 조직도를 표로 보여주세요"\n\n'
                  '• "HR 관련 해서 어떤 질문들을 할 수 있나요?"\n\n'
                  '• "OO부서의 담당자는 누구인가요?"\n\n'
                  '---\n\n'
                  '## 📑 Policy\n\n'
                  '• "병가 관련 규정은 어떻게 되나요?"\n\n'
                  '• "연차 신청은 어떻게 하나요?"\n\n'
                  '• "현재 내 권한은 어느정도 범위를 조회할 수 있나요?"\n\n'
                  '• "제 권한으로 어느정도 범위를 조회할 수 있나요?"\n\n'
                  '• "사업부별로 무슨 일 하는지 알려주세요"',
            ),
            _buildGuideSection(
              title: '효과적인 질문 방법',
              content:
                  '1. **🔍 키워드**: 구체적인 핵심 키워드를 포함하세요. (예: "연차", "출장", "CSR")\n\n'
                  '2. **📅 기간**: 기간이나 날짜 범위를 명시하세요. (예: "이번 달", "2023년 3분기", "지난 6개월")\n\n'
                  '3. **👤 담당자**: 부서나 담당자를 구체적으로 언급하세요. (예: "경영지원팀", "홍길동 담당자")\n\n'
                  '4. **🔢 문서번호**: 문서 번호나 참조 코드가 있다면 함께 언급하세요. (예: "CSR-2023-0456")\n\n'
                  '5. **📊 형식**: 찾고자 하는 정보의 형태를 명시하세요. (예: "목록으로", "간략하게 요약해서", "상세 내용")\n\n'
                  '6. **🔄 재질문**: 만족스럽지 않은 답변은 질문을 다시 구체화하여 요청하세요.\n\n'
                  '7. **📚 단계적 접근**: 복잡한 정보는 단계적으로 질문을 이어나가세요.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodingGuide(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGuideSection(
              title: '코딩 어시스턴트란?',
              content:
                  '프로그래밍, 개발, 코드 작성에 도움을 주는 전문 AI 도구입니다. 다양한 프로그래밍 언어와 프레임워크를 지원합니다.',
            ),
            _buildGuideSection(
              title: '주요 기능',
              content:
                  '• 코드 작성 및 수정\n\n• 버그 해결 및 디버깅\n\n• 코드 설명 및 최적화\n\n• 개발 관련 질문 응답',
            ),
            _buildGuideSection(
              title: '지원하는 주요 언어',
              content:
                  '• Java, C#, Python, JavaScript, TypeScript\n\n• ABAP, SQL\n\n• HTML, CSS\n\n• 기타 다양한 프로그래밍 언어',
            ),
            _buildGuideSection(
              title: '질문 예시',
              content: '''• "Java로 파일을 읽고 쓰는 코드를 작성해주세요."

• "이 Python 코드의 문제점을 찾아주세요: [코드 붙여넣기]"

• "React 컴포넌트에서 상태 관리하는 방법을 알려주세요."

• "SQL 쿼리 최적화 방법을 알려주세요."

• "ABAP에서 ALV 그리드를 사용하는 방법을 알려주세요."''',
            ),
            _buildGuideSection(
              title: '효과적인 코드 질문 방법',
              content:
                  '• 목표와 현재 상황을 명확히 설명하세요.\n\n• 코드가 있다면 전체 코드를 공유하세요.\n\n• 오류 메시지가 있다면 정확히 붙여넣으세요.\n\n• 사용 중인 언어와 프레임워크 버전을 명시하세요.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSapGuide(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGuideSection(
              title: 'SAP 어시스턴트란?',
              content:
                  'SAP 시스템과 관련된 모든 질문에 답변해주는 전문 AI 도구입니다. SAP의 다양한 모듈과 기능에 대한 정보를 제공합니다.',
            ),
            _buildGuideSection(
              title: '모듈 선택하기',
              content:
                  '• 화면 하단에 있는 모듈 버튼을 클릭하여 적합한 SAP 모듈을 선택하세요.\n\n• 선택한 모듈에 특화된 더 정확한 응답을 받을 수 있습니다.',
            ),
            _buildGuideSection(
              title: '지원하는 주요 SAP 모듈',
              content: '''• **FI (Financial Accounting)** : 재무회계

• **CO (Controlling)** : 관리회계

• **MM (Materials Management)** : 자재관리

• **SD (Sales & Distribution)** : 판매/유통

• **PP (Production Planning)** : 생산계획

• **HR (Human Resources)** : 인사관리

• 그 외 다양한 모듈''',
            ),
            _buildGuideSection(
              title: '질문 예시',
              content: '''• "SAP FI 모듈에서 총계정원장 설정 방법을 알려주세요."

• "SAP MM에서 구매 프로세스 흐름을 설명해주세요."

• "SAP SD에서 가격 결정 방법은 어떻게 되나요?"

• "SAP CO에서 원가 센터 회계 설정 방법은?"

• "SAP 트랜잭션 코드 ME21N의 기능은 무엇인가요?"''',
            ),
            _buildGuideSection(
              title: '효과적인 SAP 질문 방법',
              content:
                  '• 관련 모듈을 먼저 선택하세요.\n\n• 구체적인 트랜잭션 코드나 프로세스 이름을 언급하세요.\n\n• 현재 버전이나 환경을 명시하면 더 정확한 답변을 받을 수 있습니다.',
            ),
            _buildGuideSection(
              title: '참고사항',
              content:
                  '• SAP ABAP 개발 관련 질문은 코딩 어시스턴트를 이용해주세요.\n\n• 실제 시스템 접속 관련 문제는 IT 지원팀에 문의하세요.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection({required String title, required String content}) {
    // 테마에 맞는 다양한 색상 팔레트 정의
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.themeMode != AppThemeMode.light;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = const Color(0xFF2E7D32); // 강조색 (녹색)
    final Color warningColor = const Color(0xFFF57F17); // 주의색 (주황색)
    final Color infoColor = const Color(0xFF0277BD); // 정보색 (파란색)
    final Color sectionBgColor = isDarkMode
        ? const Color(0xFF2D2D30) // Dark 테마: 어두운 회색
        : const Color(0xFFF5F9FF); // Light 테마: 연한 파란색

    // 제목에 따라 다른 아이콘과 색상 선택 (카테고리별 구분을 위함)
    IconData sectionIcon = Icons.info_outline;
    Color sectionColor = infoColor;

    // 제목 텍스트 기반으로 섹션 유형 구분
    if (title.toLowerCase().contains('유의사항') ||
        title.toLowerCase().contains('참고사항')) {
      sectionIcon = Icons.warning_amber_outlined;
      sectionColor = warningColor;
    } else if (title.toLowerCase().contains('기능') ||
        title.toLowerCase().contains('지원')) {
      sectionIcon = Icons.check_circle_outline;
      sectionColor = accentColor;
    } else if (title.toLowerCase().contains('질문') ||
        title.toLowerCase().contains('예시')) {
      sectionIcon = Icons.help_outline;
      sectionColor = primaryColor;
    }

    // 모든 섹션은 gpt_markdown으로 처리
    Widget contentWidget = GptMarkdown(
      content,
      style: TextStyle(
        fontSize: 15,
        height: 1.7,
        color: isDarkMode ? Colors.white : const Color(0xFF333333),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 컨테이너 - 시각적으로 더 강조하고 생생한 그라데이션 적용
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  sectionColor.withValues(alpha: 0.7),
                  sectionColor.withValues(alpha: 0.4)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
              boxShadow: [
                BoxShadow(
                  color: sectionColor.withValues(alpha: 0.2),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  sectionIcon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2,
                          color: Color(0x40000000),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 내용 부분에 더 풍부한 스타일 및 시각적 디자인 적용
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sectionBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(0),
                topRight: Radius.circular(0),
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border.all(
                  color: sectionColor.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.3) // Dark 테마: 더 진한 그림자
                      : Colors.black
                          .withValues(alpha: 0.05), // Light 테마: 연한 그림자
                  offset: const Offset(0, 3),
                  blurRadius: 5,
                ),
              ],
            ),
            child: contentWidget,
          ),
        ],
      ),
    );
  }
}
