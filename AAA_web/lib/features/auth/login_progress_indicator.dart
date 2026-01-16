import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 로그인 진행 상태
enum LoginStep {
  authenticating('로그인 인증 중...', 0.2),
  connectingAmqp('실시간 메시지 연결 중...', 0.5),
  syncingData('데이터 동기화 중...', 0.7),
  loadingUI('화면 준비 중...', 0.9),
  completed('로그인 완료!', 1.0);

  const LoginStep(this.message, this.progress);

  final String message;
  final double progress;
}

/// 로그인 진행 상태 제공자
final loginProgressProvider =
    StateNotifierProvider<LoginProgressNotifier, LoginStep>((ref) {
  return LoginProgressNotifier();
});

/// 로그인 진행 상태 관리자
class LoginProgressNotifier extends StateNotifier<LoginStep> {
  LoginProgressNotifier() : super(LoginStep.authenticating);

  void setStep(LoginStep step) {
    state = step;
  }

  void reset() {
    state = LoginStep.authenticating;
  }
}

/// 향상된 로그인 진행률 표시 위젯
class LoginProgressIndicator extends ConsumerWidget {
  const LoginProgressIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(loginProgressProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 로고 또는 아이콘
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              Icons.login_rounded,
              color: theme.primaryColor,
              size: 32,
            ),
          ),

          const SizedBox(height: 24),

          // 진행률 바
          Container(
            width: 280,
            height: 8,
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              width: 280 * currentStep.progress,
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 진행률 퍼센트
          Text(
            '${(currentStep.progress * 100).toInt()}%',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // 현재 단계 메시지
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              currentStep.message,
              key: ValueKey(currentStep.message),
              style: theme.textTheme.bodyLarge?.copyWith(
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // 상세 정보 (현재 단계/전체 단계)
          Text(
            '${currentStep.index + 1} / ${LoginStep.values.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: 24),

          // 회전하는 로딩 인디케이터 (완료되면 체크 마크)
          SizedBox(
            width: 24,
            height: 24,
            child: currentStep == LoginStep.completed
                ? Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  )
                : CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 전체화면 로딩 오버레이
class LoginLoadingOverlay extends ConsumerWidget {
  final Widget child;
  final bool isLoading;

  const LoginLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: const Center(
              child: LoginProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

/// 빠른 애니메이션을 위한 미니 로딩 인디케이터
class MiniLoginProgress extends ConsumerWidget {
  const MiniLoginProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(loginProgressProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: currentStep == LoginStep.completed
                ? Icon(Icons.check, color: Colors.green, size: 16)
                : CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            currentStep.message,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
