import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../ui/motion/motion.dart';
import '../ui/widgets/async_action_button.dart';

/// 注册界面 - 简洁友好的设计
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  AsyncActionState _actionState = AsyncActionState.idle;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// 处理注册逻辑
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _actionState = AsyncActionState.loading);

    try {
      await context.read<AuthController>().signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          );

      if (mounted) {
        setState(() => _actionState = AsyncActionState.success);
        await Future<void>.delayed(AppMotion.fast);
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _actionState = AsyncActionState.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(error.toString())),
            backgroundColor: Colors.red,
          ),
        );
        await Future<void>.delayed(AppMotion.slow);
        if (mounted) {
          setState(() => _actionState = AsyncActionState.idle);
        }
      }
    }
  }

  /// 转换错误信息为中文
  String _getErrorMessage(String? message) {
    if (message == null) return '注册失败';
    if (message.contains('validation_invalid_email') ||
        message.contains('valid email')) {
      return '请输入有效的邮箱地址';
    }
    if (message.contains('validation_not_unique') ||
        message.contains('already')) {
      return '该邮箱已被注册';
    }
    if (message.contains('Password')) {
      return '密码格式不符合要求';
    }
    if (message.contains('Network')) {
      return '网络连接失败，请检查网络';
    }
    return '注册失败：$message';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.green[700]),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 标题
                  Icon(
                    Icons.person_add_outlined,
                    size: 60,
                    color: Colors.green[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '创建新账号',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 姓名输入框
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '姓名',
                      hintText: '请输入您的姓名',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入姓名';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 邮箱输入框
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '邮箱',
                      hintText: '请输入您的邮箱',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入邮箱';
                      }
                      if (!value.contains('@')) {
                        return '请输入有效的邮箱地址';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 密码输入框
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '至少6位字符',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      if (value.length < 6) {
                        return '密码至少需要6位';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 确认密码输入框
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: '确认密码',
                      hintText: '请再次输入密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请确认密码';
                      }
                      if (value != _passwordController.text) {
                        return '两次输入的密码不一致';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // 注册按钮
                  AsyncActionButton(
                    onPressed: _handleRegister,
                    label: '注 册',
                    icon: Icons.person_add_outlined,
                    state: _actionState,
                    successLabel: '已创建',
                    errorLabel: '注册失败',
                  ),
                  const SizedBox(height: 16),

                  // 提示信息
                  const Text(
                    '注册后需要验证邮箱才能登录',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
