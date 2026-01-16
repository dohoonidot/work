// 경로: lib/widgets/sap_module_messages.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';

// 모듈별 설명 맵
final Map<String, String> moduleDescriptions = {
  'BC': 'Basis Components',
  'CO': 'Controlling',
  'FI': 'Financial Accounting',
  'HR': 'Human Resources',
  'IS': 'Industry Solutions',
  'MM': 'Materials Management',
  'PM': 'Plant Maintenance',
  'PP': 'Production Planning',
  'PS': 'Project Systems',
  'QM': 'Quality Management',
  'SD': 'Sales & Distribution',
  'TR': 'Treasury',
  'WF': 'Workflow',
  'General': 'General SAP Topics',
};

// 모듈별 상세 안내 메시지 - 모든 <br> 태그를 마크다운 줄바꿈으로 대체
final Map<String, String> moduleGuidanceMessages = {
  'BC': '**SAP BC (Basis Components) 모듈 안내**  \n\n'
      'SAP 시스템의 **운영 및 유지보수**에 대한 전문적인 도움을 드립니다.  \n\n'
      '시스템 관리, 데이터베이스 관리, 사용자 및 권한 관리 등에 대한 질문이 가능합니다.',
  'CO': '**SAP CO (Controlling) 모듈 안내**\n\n'
      'SAP의 **관리 회계** 기능을 다루는 모듈로,\n\n'
      '원가 관리, 이익 분석, 원가 센터 회계, 내부 주문 등에 대한 질문이 가능합니다.',
  'FI': '**SAP FI (Financial Accounting) 모듈 안내**\n\n'
      '**재무회계**와 관련된 기능을 지원하는 모듈로,\n\n'
      '총계정원장, 매출채권, 매입채무, 자산 관리 등의 질문을 받을 수 있습니다.',
  'HR': '**SAP HR (Human Resources) 모듈 안내**\n\n'
      '기업의 **인사 및 급여 관리**를 담당하는 모듈로,\n\n'
      '조직 관리, 근태 관리, 인력 개발 등에 대한 질문이 가능합니다.',
  'IS': '**SAP IS (Industry Solutions) 모듈 안내**\n\n'
      'SAP의 **산업별 특화 솔루션**을 제공하는 모듈로,\n\n'
      '특정 업계의 요구사항을 충족하는 맞춤형 기능에 대한 질문이 가능합니다.',
  'MM': '**SAP MM (Materials Management) 모듈 안내**\n\n'
      '**구매 및 재고 관리**를 위한 핵심 모듈로,\n\n'
      '구매 프로세스, 재고 최적화, 공급업체 관리 등에 대한 질문이 가능합니다.',
  'PM': '**SAP PM (Plant Maintenance) 모듈 안내**\n\n'
      '설비 및 **예방 정비 관리**를 위한 모듈로,\n\n'
      '유지보수 계획, 정비 작업 관리 등에 대한 질문이 가능합니다.',
  'PP': '**SAP PP (Production Planning) 모듈 안내**\n\n'
      '기업의 **생산 계획 및 실행**을 담당하는 모듈로,\n\n'
      '자재 소요량 계획(MRP), 생산 일정 수립 등에 대한 질문이 가능합니다.',
  'PS': '**SAP PS (Project Systems) 모듈 안내**\n\n'
      '**프로젝트 관리**를 지원하는 모듈로,\n\n'
      '프로젝트 계획, 예산 관리, 자원 할당, 진행 상황 모니터링 등에 대한 질문이 가능합니다.',
  'QM': '**SAP QM (Quality Management) 모듈 안내**\n\n'
      'SAP의 **품질 관리** 모듈로,\n\n'
      '품질 계획, 품질 검사, 품질 보증, 품질 통제 등에 대한 질문이 가능합니다.',
  'SD': '**SAP SD (Sales & Distribution) 모듈 안내**\n\n'
      '**영업 및 유통 관리**를 담당하는 모듈로,\n\n 판매 주문 처리, 출하, 청구, 가격 결정, 고객 관리 등에 대한 질문이 가능합니다.',
  'TR': '**SAP TR (Treasury) 모듈 안내**\n\n'
      '**재무 및 자금 관리** 기능을 제공하는 모듈로,\n\n'
      '현금 흐름 관리, 투자 관리, 위험 관리 등에 대한 질문이 가능합니다.',
  'WF': '**SAP WF (Workflow) 모듈 안내**\n\n'
      '기업 내 **업무 프로세스 자동화**를 위한 모듈로,\n\n'
      '승인 프로세스, 알림 관리, 업무 흐름 최적화 등에 대한 질문이 가능합니다.',
  'General': '**SAP 일반 주제 안내**\n\n'
      'SAP 시스템의 **기본 개념 및 모듈 간 통합**에 대한 지원을 제공합니다.\n\n'
      'SAP HANA, S/4HANA, 시스템 아키텍처 등에 대한 질문이 가능합니다.',
};

// 모듈 안내 메시지를 대화에 추가하는 함수
void addModuleGuidanceMessage(BuildContext context, WidgetRef ref,
    String module, ScrollController scrollController) {
  // ChatNotifier에 직접 접근
  final chatNotifier = ref.read(chatProvider.notifier);
  final chatState = ref.read(chatProvider);

  // 안내 메시지 생성
  final guidanceMessage = moduleGuidanceMessages[module] ??
      "SAP ${module} 모듈에 대한 더 전문적인 답변을 도와드릴게요. ${moduleDescriptions[module]}에 관련된 질문을 입력해주세요.";

  // 새 메시지 생성
  Map<String, dynamic> newMessage = {
    'archive_id': chatState.currentArchiveId,
    'user_id': '',
    'message': guidanceMessage,
    'role': 1,
    'chat_time': DateTime.now().toString(),
    'isStreaming': false,
  };

  // 마지막 메시지가 AI 안내 메시지인지 확인
  bool lastMessageIsGuidance = false;
  if (chatState.arvChatDetail.isNotEmpty &&
      chatState.arvChatDetail.last['role'] == 1) {
    final lastMessage = chatState.arvChatDetail.last['message'].toString();
    lastMessageIsGuidance = lastMessage.contains("모듈에 대한 더 전문적인 답변을 도와드릴게요");
  }

  // 기존 안내 메시지가 있으면 수정된 채팅 목록 생성, 없으면 새 메시지 추가
  List<Map<String, dynamic>> updatedChatDetail = [];

  if (lastMessageIsGuidance) {
    // 마지막 메시지를 교체
    updatedChatDetail = List.from(chatState.arvChatDetail);
    updatedChatDetail[updatedChatDetail.length - 1] = newMessage;
  } else {
    // 새 메시지 추가
    updatedChatDetail = [...chatState.arvChatDetail, newMessage];
  }

  // ChatState 객체를 만들어 상태 복사
  // final updatedState = chatState.copyWith(
  //   arvChatDetail: updatedChatDetail,
  // );

  // 값을 직접 대입하지 않고, state에 반영
  chatNotifier.updateChatDetailManually(updatedChatDetail);

  // 스크롤 다운
  Future.delayed(const Duration(milliseconds: 100), () {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}
