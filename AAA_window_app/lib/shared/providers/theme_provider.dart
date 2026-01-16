import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';

class ThemeState {
  final AppThemeMode themeMode;
  final AppColorScheme colorScheme;
  final bool userSelectedTheme;

  ThemeState({
    required this.themeMode,
    required this.colorScheme,
    this.userSelectedTheme = false,
  });

  ThemeState copyWith({
    AppThemeMode? themeMode,
    AppColorScheme? colorScheme,
    bool? userSelectedTheme,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      colorScheme: colorScheme ?? this.colorScheme,
      userSelectedTheme: userSelectedTheme ?? this.userSelectedTheme,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier()
      : super(ThemeState(
          themeMode: AppThemeMode.light,
          colorScheme: AppColorSchemes.lightScheme,
        )) {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt('theme_mode') ?? 0;

      // system 모드를 light로 강제 변환
      AppThemeMode themeMode;
      if (themeModeIndex == 2) {
        // system 모드인 경우
        themeMode = AppThemeMode.light; // light로 강제 변환
        await prefs.setInt('theme_mode', 0); // 저장도 light로 변경
      } else {
        themeMode = AppThemeMode
            .values[themeModeIndex.clamp(0, AppThemeMode.values.length - 1)];
      }

      final colorScheme =
          AppColorSchemes.allSchemes[themeMode] ?? AppColorSchemes.lightScheme;

      final userSelectedTheme = prefs.getBool('user_selected_theme') ?? false;

      state = ThemeState(
        themeMode: themeMode,
        colorScheme: colorScheme,
        userSelectedTheme: userSelectedTheme,
      );

      print('테마 로딩 완료: $themeMode, 배경색: ${colorScheme.backgroundColor}');
    } catch (e) {
      print('테마 설정 로딩 중 오류: $e');
      // 기본값 유지
    }
  }

  Future<void> setTheme(AppThemeMode themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', themeMode.index);
      await prefs.setBool('user_selected_theme', true);

      final colorScheme =
          AppColorSchemes.allSchemes[themeMode] ?? AppColorSchemes.lightScheme;

      state = state.copyWith(
        themeMode: themeMode,
        colorScheme: colorScheme,
        userSelectedTheme: true,
      );
    } catch (e) {
      print('테마 설정 저장 중 오류: $e');
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
