import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication のラッパー。
/// メール/パスワード認証を提供する。
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// パスワードリセットメールを送信する。           
  Future<void> sendPasswordReset({required String
  email}) {
    return _auth.sendPasswordResetEmail(email:
  email.trim());
  }

  /// FirebaseAuthException を日本語メッセージに変換する。
  static String describeError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'メールアドレスの形式が正しくありません。',
        'user-disabled' => 'このアカウントは無効化されています。',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'メールアドレスまたはパスワードが違います。',
        'email-already-in-use' => 'このメールアドレスは既に使われています。',
        'weak-password' => 'パスワードは6文字以上にしてください。',
        'network-request-failed' => 'ネットワークに接続できません。',
        _ => '認証エラー: ${error.message ?? error.code}',
      };
    }
    return 'エラーが発生しました: $error';
  }
}
