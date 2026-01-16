// password_change_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/core/mixins/text_editing_controller_mixin.dart';

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({super.key});

  @override
  PasswordChangePageState createState() => PasswordChangePageState();
}

class PasswordChangePageState extends State<PasswordChangePage>
    with TextEditingControllerMixin {
  final _formKey = GlobalKey<FormState>();
  late final _userIdController = getController('userId');
  late final _currentPasswordController = getController('currentPassword');
  late final _newPasswordController = getController('newPassword');
  late final _confirmPasswordController = getController('confirmPassword');
  bool _isLoading = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/updatePassword'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': _userIdController.text.trim(),
            'password': _currentPasswordController.text,
            'new_password': _newPasswordController.text,
          }),
        );

        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);

          if (jsonResponse['status_code'] == 200) {
            if (mounted) {
              CommonUIUtils.showSuccessSnackBar(
                  context, '비밀번호가 성공적으로 변경되었습니다.');
              Navigator.pop(context); // 비밀번호 변경 성공 후 이전 화면으로 돌아가기
            }
          } else {
            if (mounted) {
              CommonUIUtils.showErrorSnackBar(
                  context, '비밀번호 변경에 실패했습니다. 입력한 정보를 확인해주세요.');
            }
          }
        } else {
          if (mounted) {
            CommonUIUtils.showErrorSnackBar(
                context, '서버 연결에 문제가 발생했습니다. 나중에 다시 시도해주세요.');
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          CommonUIUtils.showErrorSnackBar(context, '오류가 발생했습니다: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 변경'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    controller: _userIdController,
                    decoration: InputDecoration(
                      labelText: '이메일(아이디)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 16.0),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이메일을 입력해 주세요.';
                      }
                      if (!value.contains('@')) {
                        return '유효한 이메일 형식이 아닙니다.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16.0),
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    controller: _currentPasswordController,
                    decoration: InputDecoration(
                      labelText: '현재 비밀번호',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 16.0),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '현재 비밀번호를 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16.0),
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: '새 비밀번호',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 16.0),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '새 비밀번호를 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16.0),
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: '새 비밀번호 확인',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 16.0),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '새 비밀번호를 다시 입력해 주세요.';
                      }
                      if (value != _newPasswordController.text) {
                        return '새 비밀번호가 일치하지 않습니다.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24.0),
                SizedBox(
                  width: 300,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('비밀번호 변경'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
