import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/auth_service.dart';

/// ログイン / 新規登録画面（メール・パスワード）。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = ref.read(authServiceProvider);
    try {
      if (_isSignUp) {
        await auth.signUp(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
      } else {
        await auth.signIn(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
      }
      // 成功時は authStateProvider の変化で自動的に画面遷移する。
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.checklist_rounded,
                        size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'カレンダー TODO',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignUp ? '新規アカウントを作成' : 'ログインして続ける',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'メールアドレスを入力してください'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'パスワード',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? '6文字以上で入力してください'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? '登録する' : 'ログイン'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                              }),
                      child: Text(_isSignUp
                          ? 'すでにアカウントをお持ちですか？ ログイン'
                          : 'アカウントを作成する'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
