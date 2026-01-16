import 'package:flutter_riverpod/flutter_riverpod.dart';

/// HTML 테스트 데이터를 관리하는 Provider
class HtmlTestState {
  final String? htmlContent;
  final bool isLoading;

  const HtmlTestState({
    this.htmlContent,
    this.isLoading = false,
  });

  HtmlTestState copyWith({
    String? htmlContent,
    bool? isLoading,
  }) {
    return HtmlTestState(
      htmlContent: htmlContent ?? this.htmlContent,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HtmlTestNotifier extends StateNotifier<HtmlTestState> {
  HtmlTestNotifier() : super(const HtmlTestState());

  /// HTML 콘텐츠 설정
  void setHtmlContent(String htmlContent) {
    state = state.copyWith(htmlContent: htmlContent, isLoading: false);
  }

  /// HTML 콘텐츠 지우기
  void clearHtmlContent() {
    state = state.copyWith(htmlContent: null, isLoading: false);
  }

  /// 로딩 상태 설정
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// 테스트용 HTML 데이터 로드
  Future<void> loadTestHtmlData() async {
    state = state.copyWith(isLoading: true);

    try {
      // 로딩 시뮬레이션
      await Future.delayed(const Duration(milliseconds: 500));

      // 테스트용 HTML 데이터
      const testHtml = '''
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; max-width: 100%; margin: 0 auto;">
          <!-- 헤더 -->
          <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;">
            <h1 style="margin: 0; font-size: 24px; font-weight: 700;">🏢 전자결재 기본양식</h1>
            <p style="margin: 8px 0 0 0; opacity: 0.9; font-size: 14px;">ASPN AI AGENT 시스템</p>
          </div>

          <!-- 기본 정보 섹션 -->
          <div style="background: #f8f9fa; padding: 20px; border-left: 4px solid #4A6CF7;">
            <h2 style="color: #4A6CF7; margin-top: 0; font-size: 18px; display: flex; align-items: center;">
              <span style="margin-right: 8px;">📋</span> 기본 정보
            </h2>

            <table style="width: 100%; border-collapse: collapse; margin-top: 15px; background: white; border-radius: 6px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
              <tr>
                <td style="border: 1px solid #e9ecef; padding: 12px; background-color: #f8f9fa; font-weight: 600; width: 140px; color: #495057;">문서번호</td>
                <td style="border: 1px solid #e9ecef; padding: 12px; color: #212529;">DOC-2024-001234</td>
                <td style="border: 1px solid #e9ecef; padding: 12px; background-color: #f8f9fa; font-weight: 600; width: 140px; color: #495057;">작성일자</td>
                <td style="border: 1px solid #e9ecef; padding: 12px; color: #212529;">2024년 01월 15일</td>
              </tr>
              <tr>
                <td style="border: 1px solid #e9ecef; padding: 12px; background-color: #f8f9fa; font-weight: 600; color: #495057;">기안부서</td>
                <td style="border: 1px solid #e9ecef; padding: 12px; color: #212529;">Biz AI사업부</td>
                <td style="border: 1px solid #e9ecef; padding: 12px; background-color: #f8f9fa; font-weight: 600; color: #495057;">기안자</td>
                <td style="border: 1px solid #e9ecef; padding: 12px; color: #212529;">김개발 (AI사업부)</td>
              </tr>
              <tr>
                <td style="border: 1px solid #e9ecef; padding: 12px; background-color: #f8f9fa; font-weight: 600; color: #495057;">제목</td>
                <td style="border: 1px solid #e9ecef; padding: 12px; color: #212529;" colspan="3">
                  <strong style="color: #0d6efd;">신규 AI 모델 도입 및 시스템 업그레이드 승인 요청</strong>
                </td>
              </tr>
            </table>
          </div>

          <!-- 상세 내용 섹션 -->
          <div style="padding: 20px; background: white;">
            <h2 style="color: #dc3545; margin-top: 0; font-size: 18px; display: flex; align-items: center;">
              <span style="margin-right: 8px;">📝</span> 상세 내용
            </h2>

            <div style="background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 6px; margin: 15px 0;">
              <h3 style="color: #856404; margin-top: 0; font-size: 16px;">💡 요청 사유</h3>
              <p style="margin: 8px 0; color: #856404; line-height: 1.8;">
                현재 운영 중인 AI 모델의 성능 개선 및 새로운 기능 추가를 위해
                최신 GPT-4o 모델로의 업그레이드가 필요합니다. 이를 통해 고객 만족도 향상과
                업무 효율성을 20% 이상 개선할 수 있을 것으로 예상됩니다.
              </p>
            </div>

            <h3 style="color: #198754; margin-top: 25px; font-size: 16px;">🎯 주요 개선 항목</h3>
            <div style="display: flex; flex-wrap: wrap; gap: 10px; margin: 15px 0;">
              <div style="background: #d1ecf1; border: 1px solid #bee5eb; padding: 8px 12px; border-radius: 20px; font-size: 14px; color: #0c5460;">
                ⚡ 응답 속도 개선
              </div>
              <div style="background: #d4edda; border: 1px solid #c3e6cb; padding: 8px 12px; border-radius: 20px; font-size: 14px; color: #155724;">
                🧠 정확도 향상
              </div>
              <div style="background: #fce4ec; border: 1px solid #f8bbd9; padding: 8px 12px; border-radius: 20px; font-size: 14px; color: #721c24;">
                🌐 다국어 지원
              </div>
              <div style="background: #fff3e0; border: 1px solid #ffcc02; padding: 8px 12px; border-radius: 20px; font-size: 14px; color: #663c00;">
                📊 분석 기능 강화
              </div>
            </div>
          </div>

          <!-- 예산 및 일정 섹션 -->
          <div style="padding: 20px; background: #f8f9fa;">
            <h2 style="color: #6f42c1; margin-top: 0; font-size: 18px; display: flex; align-items: center;">
              <span style="margin-right: 8px;">💰</span> 예산 및 일정
            </h2>

            <!-- 예산 상세 테이블 -->
            <div style="margin-top: 20px;">
              <h3 style="color: #495057; font-size: 16px; margin-bottom: 15px;">💳 예산 상세 내역</h3>
              <table style="width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); margin-bottom: 20px;">
                <thead>
                  <tr style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;">
                    <th style="padding: 15px; text-align: left; font-weight: 600; border: none;">구분</th>
                    <th style="padding: 15px; text-align: center; font-weight: 600; border: none;">단가</th>
                    <th style="padding: 15px; text-align: center; font-weight: 600; border: none;">수량</th>
                    <th style="padding: 15px; text-align: right; font-weight: 600; border: none;">금액</th>
                    <th style="padding: 15px; text-align: center; font-weight: 600; border: none;">비고</th>
                  </tr>
                </thead>
                <tbody>
                  <tr style="border-bottom: 1px solid #e9ecef;">
                    <td style="padding: 12px 15px; font-weight: 500; color: #495057; border: none;">GPT-4o 라이선스</td>
                    <td style="padding: 12px 15px; text-align: center; color: #6c757d; border: none;">₩500,000</td>
                    <td style="padding: 12px 15px; text-align: center; color: #6c757d; border: none;">5개월</td>
                    <td style="padding: 12px 15px; text-align: right; font-weight: 600; color: #212529; border: none;">₩2,500,000</td>
                    <td style="padding: 12px 15px; text-align: center; font-size: 12px; color: #6c757d; border: none;">월 단위</td>
                  </tr>
                  <tr style="border-bottom: 1px solid #e9ecef; background: #f8f9fa;">
                    <td style="padding: 12px 15px; font-weight: 500; color: #495057; border: none;">서버 업그레이드</td>
                    <td style="padding: 12px 15px; text-align: center; color: #6c757d; border: none;">₩1,800,000</td>
                    <td style="padding: 12px 15px; text-align: center; color: #6c757d; border: none;">1식</td>
                    <td style="padding: 12px 15px; text-align: right; font-weight: 600; color: #212529; border: none;">₩1,800,000</td>
                    <td style="padding: 12px 15px; text-align: center; font-size: 12px; color: #6c757d; border: none;">일시불</td>
                  </tr>
                  <tr style="border-bottom: 1px solid #e9ecef;">
                    <td style="padding: 12px 15px; font-weight: 500; color: #495057; border: none;">개발자 교육</td>
                    <td style="padding: 12px 15px; text-align: center; color: #6c757d; border: none;">₩350,000</td>
                    <td style="padding: 12px 15px; text-align: center; color: #6c757d; border: none;">2명</td>
                    <td style="padding: 12px 15px; text-align: right; font-weight: 600; color: #212529; border: none;">₩700,000</td>
                    <td style="padding: 12px 15px; text-align: center; font-size: 12px; color: #6c757d; border: none;">1인당</td>
                  </tr>
                  <tr style="background: linear-gradient(135deg, #dc3545 0%, #c82333 100%); color: white;">
                    <td style="padding: 15px; font-weight: 700; font-size: 16px; border: none;">총 합계</td>
                    <td style="padding: 15px; border: none;" colspan="2"></td>
                    <td style="padding: 15px; text-align: right; font-weight: 700; font-size: 18px; border: none;">₩5,000,000</td>
                    <td style="padding: 15px; text-align: center; font-size: 12px; border: none; opacity: 0.9;">부가세 별도</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <!-- 일정 테이블 -->
            <div>
              <h3 style="color: #495057; font-size: 16px; margin-bottom: 15px;">📅 추진 일정표</h3>
              <table style="width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                <thead>
                  <tr style="background: linear-gradient(135deg, #28a745 0%, #20c997 100%); color: white;">
                    <th style="padding: 15px; text-align: center; font-weight: 600; border: none; width: 15%;">단계</th>
                    <th style="padding: 15px; text-align: left; font-weight: 600; border: none; width: 35%;">작업 내용</th>
                    <th style="padding: 15px; text-align: center; font-weight: 600; border: none; width: 20%;">기간</th>
                    <th style="padding: 15px; text-align: center; font-weight: 600; border: none; width: 15%;">담당자</th>
                    <th style="padding: 15px; text-align: center; font-weight: 600; border: none; width: 15%;">상태</th>
                  </tr>
                </thead>
                <tbody>
                  <tr style="border-bottom: 1px solid #e9ecef;">
                    <td style="padding: 12px 15px; text-align: center; background: #e3f2fd; color: #1976d2; font-weight: 600; border: none;">
                      1단계
                    </td>
                    <td style="padding: 12px 15px; border: none;">
                      <div style="font-weight: 500; color: #495057; margin-bottom: 4px;">시스템 분석 및 설계</div>
                      <div style="font-size: 12px; color: #6c757d;">• 현재 시스템 분석<br>• 요구사항 정의<br>• 아키텍처 설계</div>
                    </td>
                    <td style="padding: 12px 15px; text-align: center; border: none;">
                      <div style="font-weight: 600; color: #495057;">2주</div>
                      <div style="font-size: 11px; color: #6c757d;">01.15~01.31</div>
                    </td>
                    <td style="padding: 12px 15px; text-align: center; border: none;">
                      <div style="background: #f0f8ff; padding: 4px 8px; border-radius: 12px; font-size: 12px; color: #1976d2;">김개발</div>
                    </td>
                    <td style="padding: 12px 15px; text-align: center; border: none;">
                      <div style="background: #d4edda; color: #155724; padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight: 500;">완료</div>
                    </td>
                  </tr>
                  <tr style="border-bottom: 1px solid #e9ecef; background: #f8f9fa;">
                    <td style="padding: 12px 15px; text-align: center; background: #fff3cd; color: #856404; font-weight: 600; border: none;">
                      2단계
                    </td>
                    <td style="padding: 12px 15px; border: none;">
                      <div style="font-weight: 500; color: #495057; margin-bottom: 4px;">모델 업그레이드 및 통합</div>
                      <div style="font-size: 12px; color: #6c757d;">• GPT-4o 모델 적용<br>• API 연동 작업<br>• 성능 최적화</div>
                    </td>
                    <td style="padding: 12px 15px; text-align: center; border: none;">
                      <div style="font-weight: 600; color: #495057;">4주</div>
                      <div style="font-size: 11px; color: #6c757d;">02.01~02.28</div>
                    </td>
                    <td style="padding: 12px 15px; text-align: center; border: none;">
                      <div style="background: #fff3e0; padding: 4px 8px; border-radius: 12px; font-size: 12px; color: #f57c00;">이개발</div>
                    </td>
                    <td style="padding: 12px 15px; text-align: center; border: none;">
                      <div style="background: #fff3cd; color: #856404; padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight: 500;">진행중</div>
                    </td>
                  </tr>
                  <tr style="border-bottom: 1px solid #e9ecef;">
                    <td style="padding: 12px 15px; text-align: center; background: #fce4ec; color: #c2185b; font-weight: 600; border: none;">
                      3단계
                    </td>
                    <td style="padding: 12px 15px; border: none;">
                      <div style="font-weight: 500; color: #495057; margin-bottom: 4px;">테스트 및 배포</div>
                      <div style="font-size: 12px; color: #6c757d;">• 통합 테스트<br>• 사용자 테스트<br>• 운영 배포</div>
                    </td>
                    <td style="padding: 12px 15px; text-align: center; border: none;">
                      <div style="font-weight: 600; color: #495057;">2주</div>
                      <div style="font-size: 11px; color: #6c757d;">03.01~03.15</div>
                    </td>
                    <td style="padding: 12px 15px; text-align: center; border: none;">
                      <div style="background: #fce4ec; padding: 4px 8px; border-radius: 12px; font-size: 12px; color: #c2185b;">박테스트</div>
                    </td>
                    <td style="padding: 12px 15px; text-align: center; border: none;">
                      <div style="background: #f8d7da; color: #721c24; padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight: 500;">대기</div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- 기대 효과 섹션 -->
          <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; margin-top: 0;">
            <h2 style="margin-top: 0; font-size: 18px; display: flex; align-items: center;">
              <span style="margin-right: 8px;">🚀</span> 기대 효과
            </h2>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-top: 15px;">
              <div style="background: rgba(255,255,255,0.1); padding: 15px; border-radius: 8px; text-align: center; backdrop-filter: blur(10px);">
                <div style="font-size: 24px; margin-bottom: 8px;">📈</div>
                <div style="font-weight: 600; margin-bottom: 4px;">업무 효율성</div>
                <div style="font-size: 20px; font-weight: 700; color: #ffd700;">+20%</div>
              </div>
              <div style="background: rgba(255,255,255,0.1); padding: 15px; border-radius: 8px; text-align: center; backdrop-filter: blur(10px);">
                <div style="font-size: 24px; margin-bottom: 8px;">😊</div>
                <div style="font-weight: 600; margin-bottom: 4px;">고객 만족도</div>
                <div style="font-size: 20px; font-weight: 700; color: #ffd700;">+15%</div>
              </div>
              <div style="background: rgba(255,255,255,0.1); padding: 15px; border-radius: 8px; text-align: center; backdrop-filter: blur(10px);">
                <div style="font-size: 24px; margin-bottom: 8px;">💰</div>
                <div style="font-weight: 600; margin-bottom: 4px;">비용 절감</div>
                <div style="font-size: 20px; font-weight: 700; color: #ffd700;">-10%</div>
              </div>
            </div>
          </div>

          <!-- 결재선 및 승인 현황 -->
          <div style="padding: 20px; background: white;">
            <h2 style="color: #495057; margin-top: 0; font-size: 18px; display: flex; align-items: center;">
              <span style="margin-right: 8px;">✍️</span> 결재선 및 승인 현황
            </h2>

            <table style="width: 100%; border-collapse: collapse; margin-top: 15px; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
              <thead>
                <tr style="background: linear-gradient(135deg, #6c757d 0%, #495057 100%); color: white;">
                  <th style="padding: 15px; text-align: center; font-weight: 600; border: none; width: 10%;">순서</th>
                  <th style="padding: 15px; text-align: left; font-weight: 600; border: none; width: 20%;">구분</th>
                  <th style="padding: 15px; text-align: left; font-weight: 600; border: none; width: 20%;">성명</th>
                  <th style="padding: 15px; text-align: left; font-weight: 600; border: none; width: 20%;">부서/직책</th>
                  <th style="padding: 15px; text-align: center; font-weight: 600; border: none; width: 15%;">승인상태</th>
                  <th style="padding: 15px; text-align: center; font-weight: 600; border: none; width: 15%;">승인일시</th>
                </tr>
              </thead>
              <tbody>
                <tr style="border-bottom: 1px solid #e9ecef; background: #e3f2fd;">
                  <td style="padding: 12px 15px; text-align: center; font-weight: 600; color: #1976d2; border: none;">기안</td>
                  <td style="padding: 12px 15px; font-weight: 500; color: #1976d2; border: none;">기안자</td>
                  <td style="padding: 12px 15px; border: none;">
                    <div style="font-weight: 600; color: #495057;">김개발</div>
                  </td>
                  <td style="padding: 12px 15px; border: none;">
                    <div style="color: #6c757d; font-size: 14px;">Biz AI사업부</div>
                    <div style="color: #495057; font-size: 12px;">선임연구원</div>
                  </td>
                  <td style="padding: 12px 15px; text-align: center; border: none;">
                    <div style="background: #d4edda; color: #155724; padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight: 600;">기안완료</div>
                  </td>
                  <td style="padding: 12px 15px; text-align: center; font-size: 12px; color: #6c757d; border: none;">
                    2024.01.15<br>09:30
                  </td>
                </tr>
                <tr style="border-bottom: 1px solid #e9ecef; background: #fff3cd;">
                  <td style="padding: 12px 15px; text-align: center; font-weight: 600; color: #856404; border: none;">1차</td>
                  <td style="padding: 12px 15px; font-weight: 500; color: #856404; border: none;">팀장 승인</td>
                  <td style="padding: 12px 15px; border: none;">
                    <div style="font-weight: 600; color: #495057;">이팀장</div>
                  </td>
                  <td style="padding: 12px 15px; border: none;">
                    <div style="color: #6c757d; font-size: 14px;">Biz AI사업부</div>
                    <div style="color: #495057; font-size: 12px;">팀장</div>
                  </td>
                  <td style="padding: 12px 15px; text-align: center; border: none;">
                    <div style="background: #fff3cd; color: #856404; padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight: 600;">검토중</div>
                  </td>
                  <td style="padding: 12px 15px; text-align: center; font-size: 12px; color: #6c757d; border: none;">-</td>
                </tr>
                <tr style="border-bottom: 1px solid #e9ecef;">
                  <td style="padding: 12px 15px; text-align: center; font-weight: 600; color: #6c757d; border: none;">2차</td>
                  <td style="padding: 12px 15px; font-weight: 500; color: #6c757d; border: none;">부장 승인</td>
                  <td style="padding: 12px 15px; border: none;">
                    <div style="font-weight: 600; color: #6c757d;">박부장</div>
                  </td>
                  <td style="padding: 12px 15px; border: none;">
                    <div style="color: #6c757d; font-size: 14px;">Biz AI사업부</div>
                    <div style="color: #6c757d; font-size: 12px;">부장</div>
                  </td>
                  <td style="padding: 12px 15px; text-align: center; border: none;">
                    <div style="background: #f8d7da; color: #721c24; padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight: 600;">대기중</div>
                  </td>
                  <td style="padding: 12px 15px; text-align: center; font-size: 12px; color: #6c757d; border: none;">-</td>
                </tr>
                <tr style="border-bottom: 1px solid #e9ecef; background: #f8f9fa;">
                  <td style="padding: 12px 15px; text-align: center; font-weight: 600; color: #6c757d; border: none;">최종</td>
                  <td style="padding: 12px 15px; font-weight: 500; color: #6c757d; border: none;">대표이사 승인</td>
                  <td style="padding: 12px 15px; border: none;">
                    <div style="font-weight: 600; color: #6c757d;">최대표</div>
                  </td>
                  <td style="padding: 12px 15px; border: none;">
                    <div style="color: #6c757d; font-size: 14px;">경영진</div>
                    <div style="color: #6c757d; font-size: 12px;">대표이사</div>
                  </td>
                  <td style="padding: 12px 15px; text-align: center; border: none;">
                    <div style="background: #f8d7da; color: #721c24; padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight: 600;">대기중</div>
                  </td>
                  <td style="padding: 12px 15px; text-align: center; font-size: 12px; color: #6c757d; border: none;">-</td>
                </tr>
              </tbody>
            </table>

            <!-- 참조자 정보 -->
            <div style="margin-top: 20px; padding: 15px; background: #f0f8f0; border-radius: 8px; border-left: 4px solid #28a745;">
              <h4 style="color: #28a745; margin: 0 0 10px 0; font-size: 14px;">📧 참조자 (업무 공유)</h4>
              <div style="display: flex; gap: 10px; flex-wrap: wrap;">
                <div style="background: white; padding: 6px 12px; border-radius: 15px; font-size: 12px; color: #495057; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
                  정관리 (관리팀)
                </div>
                <div style="background: white; padding: 6px 12px; border-radius: 15px; font-size: 12px; color: #495057; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
                  한기획 (기획팀)
                </div>
                <div style="background: white; padding: 6px 12px; border-radius: 15px; font-size: 12px; color: #495057; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
                  송재무 (재무팀)
                </div>
              </div>
            </div>
          </div>

          <!-- 승인 요청 섹션 -->
          <div style="background: #e7f3ff; border: 2px solid #0066cc; padding: 20px; text-align: center; border-radius: 0 0 8px 8px;">
            <h3 style="color: #0066cc; margin: 0 0 10px 0; font-size: 18px;">
              ✅ 승인 요청
            </h3>
            <p style="margin: 0; color: #004499; font-size: 16px; line-height: 1.6;">
              위와 같은 사유로 <strong>신규 AI 모델 도입 및 시스템 업그레이드</strong>에 대한 승인을 요청드립니다.<br>
              본 안건에 대한 검토 및 승인 부탁드립니다.
            </p>

            <div style="margin-top: 15px; padding: 10px; background: white; border-radius: 6px; display: inline-block;">
              <span style="color: #666; font-size: 12px;">기안일: 2024년 01월 15일 | 기안자: 김개발 (Biz AI사업부)</span>
            </div>
          </div>
        </div>
      ''';

      state = state.copyWith(htmlContent: testHtml, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception('HTML 테스트 데이터 로드 실패: $e');
    }
  }
}

/// HTML 테스트 상태 Provider
final htmlTestProvider = StateNotifierProvider<HtmlTestNotifier, HtmlTestState>(
  (ref) => HtmlTestNotifier(),
);