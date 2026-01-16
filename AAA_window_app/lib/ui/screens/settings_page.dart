import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';
import 'package:ASPN_AI_AGENT/update/update_provider.dart';
import 'package:ASPN_AI_AGENT/update/update_config.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '환경 설정',
          style: TextStyle(
            color: themeState.themeMode == AppThemeMode.light
                ? themeState.colorScheme.appBarTextColor // Light 테마일 때 테마 색상 사용
                : null, // 다른 테마는 기본 색상 사용
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: themeState.themeMode == AppThemeMode.light
                ? themeState.colorScheme.appBarTextColor // Light 테마일 때 테마 색상 사용
                : null, // 다른 테마는 기본 색상 사용
          ),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: themeState.themeMode == AppThemeMode.light
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      themeState
                          .colorScheme.appBarGradientStart, // ChatGPT 스타일 시작 색상
                      themeState
                          .colorScheme.appBarGradientEnd, // ChatGPT 스타일 끝 색상
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 내 계정정보 섹션
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_circle,
                        color: themeState.colorScheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '내 계정정보',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 사용자 ID 표시
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeState.colorScheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: themeState.colorScheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '사용자 ID',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ref.watch(userIdProvider) ?? '로그인되지 않음',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      themeState.colorScheme.onBackgroundColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 20,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 계정 정보 안내 메시지
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '현재 로그인된 계정 정보입니다. 계정 변경은 로그아웃 후 다시 로그인하세요.',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 테마 설정 섹션
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '테마 설정',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // 테마 선택 그리드
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3,
                    ),
                    itemCount: [AppThemeMode.light, AppThemeMode.codingDark]
                        .length, // light와 dark만 표시
                    itemBuilder: (context, index) {
                      final availableThemes = [
                        AppThemeMode.light,
                        AppThemeMode.codingDark
                      ];
                      final themeMode = availableThemes[index];
                      final colorScheme =
                          AppColorSchemes.allSchemes[themeMode]!;
                      final isSelected = themeState.themeMode == themeMode;

                      return InkWell(
                        onTap: () => ref
                            .read(themeProvider.notifier)
                            .setTheme(themeMode),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primaryColor
                                  : Colors.grey.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            color: colorScheme.backgroundColor,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(7),
                                    bottomLeft: Radius.circular(7),
                                  ),
                                  gradient: themeMode == AppThemeMode.light
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            colorScheme
                                                .sidebarGradientStart, // ChatGPT 스타일 시작 색상
                                            colorScheme
                                                .sidebarGradientEnd, // ChatGPT 스타일 끝 색상
                                          ],
                                        )
                                      : null,
                                  color: themeMode != AppThemeMode.light
                                      ? colorScheme.sidebarBackgroundColor
                                      : null,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        colorScheme.name,
                                        style: TextStyle(
                                          color: colorScheme.onBackgroundColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: themeMode ==
                                                      AppThemeMode.light
                                                  ? colorScheme
                                                      .sidebarGradientStart // ChatGPT 스타일 시작 색상
                                                  : themeMode ==
                                                          AppThemeMode
                                                              .codingDark
                                                      ? const Color(
                                                          0xFF1A1A1A) // 어두운 검정
                                                      : colorScheme
                                                          .primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: themeMode ==
                                                      AppThemeMode.light
                                                  ? colorScheme
                                                      .sidebarGradientEnd // ChatGPT 스타일 끝 색상
                                                  : themeMode ==
                                                          AppThemeMode
                                                              .codingDark
                                                      ? const Color(
                                                          0xFF2A2A2A) // 밝은 검정
                                                      : colorScheme
                                                          .secondaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // 테마 선택 안내 메시지 추가
                  if (themeState.userSelectedTheme)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '선택한 ${themeState.colorScheme.name} 테마가 모든 페이지에 적용됩니다. '
                              '페이지 전환 시에도 이 테마가 유지됩니다.',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 개인정보 수집·이용 동의서 섹션
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        color: themeState.colorScheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '개인정보 처리방침',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 개인정보 수집·이용 동의서 보기 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showPrivacyAgreementDialog(context, themeState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeState.colorScheme.primaryColor
                            .withValues(alpha: 0.1),
                        foregroundColor: themeState.colorScheme.primaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: themeState.colorScheme.primaryColor
                                .withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.description_outlined, size: 20),
                      label: const Text(
                        '개인정보 수집·이용 동의서 보기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 안내 메시지
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AAA 서비스 이용을 위한 개인정보 수집·이용 동의서를 확인할 수 있습니다.',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ✨ 앱 정보 및 업데이트 섹션
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: themeState.colorScheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '앱 정보',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 현재 버전 정보
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeState.colorScheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.app_settings_alt,
                          color: themeState.colorScheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '현재 버전',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'v${ref.watch(currentVersionProvider)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      themeState.colorScheme.onBackgroundColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 업데이트 사용 가능 배지
                        if (ref.watch(hasUpdateAvailableProvider))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.update,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '업데이트',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 업데이트 확인 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: ref.watch(isCheckingUpdateProvider)
                          ? null
                          : () async {
                              // 로딩 다이얼로그 표시
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('업데이트 확인 중...'),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              // 업데이트 확인
                              final result = await ref
                                  .read(updateNotifierProvider.notifier)
                                  .checkForUpdatesManually();

                              // 로딩 다이얼로그 닫기
                              Navigator.of(context).pop();

                              // 결과에 따라 메시지 표시
                              if (result == UpdateCheckResult.noUpdate) {
                                // UpdateCheckResult 추가
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '현재 최신 버전(v${ref.read(currentVersionProvider)})을 사용하고 있습니다.',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else if (result ==
                                  UpdateCheckResult.networkError) {
                                // UpdateCheckResult 추가
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '네트워크 연결을 확인해주세요.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } else if (result !=
                                  UpdateCheckResult.available) {
                                // UpdateCheckResult 추가
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ref.read(updateErrorMessageProvider) ??
                                          '업데이트 확인 중 오류가 발생했습니다.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              // available인 경우 desktop_updater가 자동으로 다이얼로그 표시
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeState.colorScheme.primaryColor
                            .withValues(alpha: 0.1),
                        foregroundColor: themeState.colorScheme.primaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: themeState.colorScheme.primaryColor
                                .withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      icon: ref.watch(isCheckingUpdateProvider)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.system_update, size: 20),
                      label: Text(
                        ref.watch(isCheckingUpdateProvider)
                            ? '확인 중...'
                            : '업데이트 확인',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 업데이트 상태 안내 메시지
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ref.watch(hasUpdateAvailableProvider)
                          ? Colors.orange.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ref.watch(hasUpdateAvailableProvider)
                            ? Colors.orange.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          ref.watch(hasUpdateAvailableProvider)
                              ? Icons.info_outline
                              : Icons.check_circle_outline,
                          color: ref.watch(hasUpdateAvailableProvider)
                              ? Colors.orange
                              : Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ref.watch(hasUpdateAvailableProvider)
                                ? '새로운 버전이 있습니다. 위 버튼을 눌러 업데이트하세요.'
                                : '앱 시작 시 자동으로 업데이트를 확인합니다.',
                            style: TextStyle(
                              color: ref.watch(hasUpdateAvailableProvider)
                                  ? Colors.orange[800]
                                  : Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 마지막 확인 시간 표시
                  if (ref.watch(lastCheckTimeProvider) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '마지막 확인: ${_formatDateTime(ref.watch(lastCheckTimeProvider)!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 날짜/시간 포맷팅 헬퍼 함수
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // 개인정보 수집·이용 동의서 다이얼로그 표시
  void _showPrivacyAgreementDialog(BuildContext context, themeState) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(40),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF4A90E2),
                        Color(0xFF7BB3F0),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.privacy_tip_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '개인정보 수집·이용 동의서',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                // 내용
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '㈜ASPN(이하 "회사")는 AI 앱 서비스 AAA(이하 "서비스") 제공을 위하여 다음과 같이 개인정보를 수집·이용합니다. 아래 내용을 충분히 읽고 동의 여부를 결정해주시기 바랍니다.',
                                style: TextStyle(fontSize: 14, height: 1.6),
                              ),
                              SizedBox(height: 20),
                              _PolicySection(
                                title: '1. 수집·이용 목적',
                                content:
                                    '• AAA 서비스 제공 및 맞춤형 기능 지원\n• 직원 식별, 내부 커뮤니케이션 및 기념일(생일 등) 알림 기능 제공\n• 서비스 운영 및 품질 개선을 위한 통계 분석',
                              ),
                              _PolicySection(
                                title: '2. 수집 항목',
                                content:
                                    '• 기본정보: 이름, 사번, 부서, 직책\n• 생일 등 기념일 정보\n• 서비스 이용 기록, 기기정보(자동 수집 항목 포함)',
                              ),
                              _PolicySection(
                                title: '3. 보유 및 이용기간',
                                content:
                                    '• 수집일로부터 퇴사일 또는 서비스 이용 종료 시까지\n• 관련 법령에 따른 보존 필요 시 해당 법령 기준에 따름',
                              ),
                              _PolicySection(
                                title: '4. 동의 거부 권리 및 불이익',
                                content:
                                    '• 귀하는 개인정보 수집·이용에 동의하지 않을 수 있습니다. 단, 동의하지 않을 경우 AAA 서비스의 일부 또는 전체 기능 이용이 제한될 수 있습니다.',
                              ),
                              SizedBox(height: 20),
                              Text(
                                '위 내용을 확인하였으며, 개인정보 수집·이용에 동의합니다.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 확인 버튼
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 정책 섹션 위젯 (개인정보 팝업에서 가져옴)
class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
