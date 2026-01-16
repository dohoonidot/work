import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:ASPN_AI_AGENT/core/database/database_helper.dart';

class AutoLoginService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 비밀번호 해시 생성
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // 로그인 토큰 생성
  String generateLoginToken() {
    const uuid = Uuid();
    return uuid.v4();
  }

  // 토큰 만료일 계산 (기본 30일)
  DateTime calculateTokenExpiration({int days = 30}) {
    return DateTime.now().add(Duration(days: days));
  }

  // 토큰 유효성 검사
  Future<bool> isTokenValid(String userId, String token) async {
    await _dbHelper.cleanupExpiredLoginInfo(); // 만료된 로그인 정보 정리
    return await _dbHelper.isLoginTokenValid(userId, token);
  }

  // 로그인 정보 저장
  Future<bool> saveAutoLoginInfo(
      String userId, String password, bool rememberMe) async {
    if (!rememberMe) {
      // 자동 로그인을 원하지 않는 경우 기존 정보 삭제
      await _dbHelper.deleteLoginInfo(userId);
      return false;
    }

    try {
      final salt = DateTime.now().millisecondsSinceEpoch.toString();
      final passwordHash = _hashPassword(password, salt);
      final token = generateLoginToken();
      final expirationDate = calculateTokenExpiration();

      // 로그인 정보 저장
      await _dbHelper.saveLoginInfo({
        'user_id': userId,
        'password_hash': passwordHash,
        'password': password, // 🔥 추가: 원본 비밀번호 평문 저장
        'token': token,
        'created_at': DateTime.now().toIso8601String(),
        'expiration_date': expirationDate.toIso8601String(),
      });

      return true;
    } catch (e) {
      print('자동 로그인 정보 저장 실패: $e');
      return false;
    }
  }

  // 저장된 최신 로그인 정보 가져오기
  Future<Map<String, dynamic>?> getLatestLoginInfo() async {
    try {
      await _dbHelper.cleanupExpiredLoginInfo(); // 만료된 로그인 정보 정리
      return await _dbHelper.getLatestLoginInfo();
    } catch (e) {
      print('로그인 정보 조회 실패: $e');
      return null;
    }
  }

  // 특정 사용자의 로그인 정보 가져오기
  Future<Map<String, dynamic>?> getLoginInfo(String userId) async {
    try {
      await _dbHelper.cleanupExpiredLoginInfo(); // 만료된 로그인 정보 정리
      return await _dbHelper.getLoginInfo(userId);
    } catch (e) {
      print('로그인 정보 조회 실패: $e');
      return null;
    }
  }

  // 로그인 정보 삭제 (로그아웃 시)
  Future<bool> deleteLoginInfo(String userId) async {
    try {
      final result = await _dbHelper.deleteLoginInfo(userId);
      return result > 0;
    } catch (e) {
      print('로그인 정보 삭제 실패: $e');
      return false;
    }
  }

  // 모든 로그인 정보 삭제
  Future<void> deleteAllLoginInfo() async {
    try {
      await _dbHelper.deleteAllLoginInfo();
    } catch (e) {
      print('모든 로그인 정보 삭제 실패: $e');
    }
  }
}
