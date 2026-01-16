import 'package:flutter/material.dart';

/// 캐시 관리를 담당하는 클래스
///
/// 이 클래스는 메시지 렌더링에 사용되는 다양한 객체들의 캐시를 관리합니다.
/// 메모리 사용량을 줄이고 성능을 향상시키기 위해 사용됩니다.
class MessageCacheManager {
  // 캐싱을 위한 자료구조들
  static final Map<String, TextStyle> _styleSheetCache = {};
  static final Map<String, Widget> _messageWidgetCache = {};
  static final Map<String, Widget> _codeBlockCache = {};
  static final Map<String, Map<String, dynamic>> _parsedMessageCache = {};
  static final Map<String, bool> _renderingDecisionCache = {};

  // 최대 캐시 크기 정의
  static const int _maxCacheSize = 100;

  /// 캐시 크기 관리
  static void checkCacheSize() {
    // 메시지 위젯 캐시 관리
    if (_messageWidgetCache.length > _maxCacheSize) {
      final keysToRemove = _messageWidgetCache.keys.take(20).toList();
      for (final key in keysToRemove) {
        _messageWidgetCache.remove(key);
      }
    }

    // 코드 블록 캐시 관리
    if (_codeBlockCache.length > _maxCacheSize) {
      final keysToRemove = _codeBlockCache.keys.take(20).toList();
      for (final key in keysToRemove) {
        _codeBlockCache.remove(key);
      }
    }

    // 파싱 결과 캐시 관리
    if (_parsedMessageCache.length > _maxCacheSize) {
      final keysToRemove = _parsedMessageCache.keys.take(20).toList();
      for (final key in keysToRemove) {
        _parsedMessageCache.remove(key);
      }
    }

    // 렌더링 결정 캐시 관리
    if (_renderingDecisionCache.length > _maxCacheSize) {
      final keysToRemove = _renderingDecisionCache.keys.take(20).toList();
      for (final key in keysToRemove) {
        _renderingDecisionCache.remove(key);
      }
    }

    // 스타일시트 캐시 관리
    if (_styleSheetCache.length > _maxCacheSize) {
      final keysToRemove = _styleSheetCache.keys.take(20).toList();
      for (final key in keysToRemove) {
        _styleSheetCache.remove(key);
      }
    }
  }

  /// 모든 캐시 초기화
  static void clearAllCaches() {
    _messageWidgetCache.clear();
    _codeBlockCache.clear();
    _parsedMessageCache.clear();
    _renderingDecisionCache.clear();
    _styleSheetCache.clear();
  }

  // === 메시지 위젯 캐시 관련 메서드 ===

  /// 메시지 위젯 캐시 등록
  static void cacheMessageWidget(String key, Widget widget) {
    _messageWidgetCache[key] = widget;
  }

  /// 메시지 위젯 캐시 확인
  static bool hasMessageWidget(String key) {
    return _messageWidgetCache.containsKey(key);
  }

  /// 메시지 위젯 캐시 조회
  static Widget? getMessageWidget(String key) {
    return _messageWidgetCache[key];
  }

  // === 코드 블록 캐시 관련 메서드 ===

  /// 코드 블록 캐시 등록
  static void cacheCodeBlock(String key, Widget widget) {
    _codeBlockCache[key] = widget;
  }

  /// 코드 블록 캐시 확인
  static bool hasCodeBlock(String key) {
    return _codeBlockCache.containsKey(key);
  }

  /// 코드 블록 캐시 조회
  static Widget? getCodeBlock(String key) {
    return _codeBlockCache[key];
  }

  // === 렌더링 결정 캐시 관련 메서드 ===

  /// 렌더링 결정 캐시 등록
  static void cacheRenderingDecision(String key, bool decision) {
    _renderingDecisionCache[key] = decision;
  }

  /// 렌더링 결정 캐시 확인
  static bool hasRenderingDecision(String key) {
    return _renderingDecisionCache.containsKey(key);
  }

  /// 렌더링 결정 캐시 조회
  static bool? getRenderingDecision(String key) {
    return _renderingDecisionCache[key];
  }

  // === 스타일시트 캐시 관련 메서드 ===

  /// 스타일시트 캐시 등록
  static void cacheStyleSheet(String key, TextStyle styleSheet) {
    _styleSheetCache[key] = styleSheet;
  }

  /// 스타일시트 캐시 확인
  static bool hasStyleSheet(String key) {
    return _styleSheetCache.containsKey(key);
  }

  /// 스타일시트 캐시 조회
  static TextStyle? getStyleSheet(String key) {
    return _styleSheetCache[key];
  }

  // === 파싱 결과 캐시 관련 메서드 ===

  /// 파싱 결과 캐시 등록
  static void cacheParsedMessage(String key, Map<String, dynamic> parsedData) {
    _parsedMessageCache[key] = parsedData;
  }

  /// 파싱 결과 캐시 확인
  static bool hasParsedMessage(String key) {
    return _parsedMessageCache.containsKey(key);
  }

  /// 파싱 결과 캐시 조회
  static Map<String, dynamic>? getParsedMessage(String key) {
    return _parsedMessageCache[key];
  }
}
