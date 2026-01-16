import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';

class AiModelSelector extends ConsumerWidget {
  const AiModelSelector({super.key});

  // 모델 아이콘 빌드 메서드 (다크 테마에서 특정 모델 아이콘 색상 반전)
  Widget _buildModelIcon(String iconPath, String modelId, dynamic themeState,
      {double? size}) {
    final isDarkMode = themeState.themeMode != AppThemeMode.light;
    final isGptModel = modelId.contains('gpt');
    final isClaudeModel = modelId.contains('claude');
    final iconSize = size ?? 18.0;

    // GPT 모델은 다크 테마에서 색상 반전 적용
    if (isGptModel && isDarkMode) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          // 색상 반전 매트릭스 (흰색으로 변환)
          -1.0, 0.0, 0.0, 0.0, 255.0,
          0.0, -1.0, 0.0, 0.0, 255.0,
          0.0, 0.0, -1.0, 0.0, 255.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]),
        child: Image.asset(
          iconPath,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
      );
    }

    // Claude 모델도 다크 테마에서 색상 반전 적용 (필요한 경우)
    if (isClaudeModel && isDarkMode) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          // 색상 반전 매트릭스 (흰색으로 변환)
          -1.0, 0.0, 0.0, 0.0, 255.0,
          0.0, -1.0, 0.0, 0.0, 255.0,
          0.0, 0.0, -1.0, 0.0, 255.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]),
        child: Image.asset(
          iconPath,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
      );
    }

    return Image.asset(
      iconPath,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedModel = ref.watch(selectedAiModelProvider);
    final themeState = ref.watch(themeProvider);

    final List<Map<String, dynamic>> models = [
      {
        'id': 'gemini-pro-3',
        'name': 'Gemini Pro 3',
        'iconPath': 'assets/icon/ai_models/gemini_icon.png',
      },
      {
        'id': 'gpt-5.2',
        'name': 'GPT-5.2',
        'iconPath': 'assets/icon/ai_models/chatgpt_icon.png',
      },
      {
        'id': 'claude-sonnet-4.5',
        'name': 'Claude Sonnet 4.5',
        'iconPath': 'assets/icon/ai_models/claude_icon.png',
      },
    ];

    // 현재 선택된 모델 찾기
    final currentModel = models.firstWhere(
      (model) => model['id'] == selectedModel,
      orElse: () => models.first,
    );

    return IntrinsicWidth(
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
        ),
        child: PopupMenuButton<String>(
          itemBuilder: (BuildContext context) {
            return models.map((model) {
              return PopupMenuItem<String>(
                value: model['id'],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      // 모델별 고유 아이콘 표시
                      _buildModelIcon(
                          model['iconPath'], model['id'], themeState),
                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          model['name']!,
                          style: TextStyle(
                            color: themeState.themeMode == AppThemeMode.light
                                ? Colors.black87
                                : const Color(0xFFB19CD9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // 선택된 항목에만 체크 아이콘 표시
                      if (selectedModel == model['id'])
                        Icon(
                          Icons.check,
                          size: 12,
                          color: themeState.themeMode == AppThemeMode.light
                              ? const Color(0xFF6B46C1)
                              : const Color(0xFF8B5CF6),
                        ),
                    ],
                  ),
                ),
              );
            }).toList();
          },
          onSelected: (String newValue) {
            print('🎛️ AI 모델 선택기 - 모델 변경 시작: $newValue');
            final oldValue = ref.read(selectedAiModelProvider);
            print('🎛️ AI 모델 선택기 - 이전 모델: "$oldValue" → 새로운 모델: "$newValue"');
            ref.read(selectedAiModelProvider.notifier).state = newValue;
            final updatedValue = ref.read(selectedAiModelProvider);
            print('🎛️ AI 모델 선택기 - 상태 업데이트 완료: "$updatedValue"');
          },
          color: themeState.themeMode == AppThemeMode.light
              ? Colors.white
              : const Color(0xFF2D2D30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 8,
          offset: const Offset(0, 8), // 메뉴가 버튼 아래로 나타나도록
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModelIcon(
                    currentModel['iconPath'], currentModel['id'], themeState,
                    size: 16),
                const SizedBox(width: 4),
                Text(
                  currentModel['name']!,
                  style: TextStyle(
                    color: themeState.themeMode == AppThemeMode.light
                        ? const Color(0xFF6B46C1)
                        : const Color(0xFFB19CD9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: themeState.themeMode == AppThemeMode.light
                      ? const Color(0xFF6B46C1)
                      : const Color(0xFF8B5CF6),
                  size: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
