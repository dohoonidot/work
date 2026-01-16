/// 기능 표시/숨김 설정
///
/// 배포 시 미완성 기능을 숨기기 위한 설정
class FeatureConfig {
  /// 배포 모드 여부
  /// true: 배포 모드 (미완성 기능 숨김)
  /// false: 개발 모드 (모든 기능 표시)
  static const bool isProduction = true; // 배포 시 true로 변경

  /// 전자결재 기능 표시 여부
  static bool get showElectronicApproval => !isProduction;

  /// 사내AI 공모전 기능 표시 여부
  static bool get showContest => !isProduction;

  /// 연차휴가 사용촉진 통지서 기능 표시 여부
  static bool get showAnnualLeaveNotice => !isProduction;

  /// 전자결재 모달에서 모든 결재종류 표시 여부
  /// - 개발: 모든 종류 표시
  /// - 배포: '휴가 부여 상신'만 표시
  static bool get showAllApprovalTypes => !isProduction;
}
