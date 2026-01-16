import 'package:flutter_riverpod/flutter_riverpod.dart';

// 웹검색 사용 여부 토글 상태 provider (withModel API 전용)
final selectedWebSearchProvider = StateProvider<bool>(
  (ref) => false,
);
