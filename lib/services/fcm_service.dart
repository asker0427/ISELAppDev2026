import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

/// FCM の受信許可、端末トークンの保存、フォアグラウンド表示を管理する。
class FcmService {
  static final instance = FcmService();

  FcmService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications = localNotifications ?? taskNotificationsPlugin;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  String? _registeredUid;
  String? _registeredToken;

  Future<void> initialize() async {
    if (kIsWeb) return;

    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
    _authSubscription = _auth.authStateChanges().listen((user) async {
      try {
        await _changeUser(user);
      } catch (error, stackTrace) {
        debugPrint('FCMトークンの同期に失敗しました: $error\n$stackTrace');
      }
    });
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
  }

  /// 認証が切れる前に呼び、前ユーザーへの通知が端末に残らないようにする。
  Future<void> unregister() => _removeRegisteredToken();

  Future<void> _changeUser(User? user) async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    await _removeRegisteredToken();
    if (user == null) return;

    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;

    // iOS は APNs トークン取得前に getToken すると失敗することがある。
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await _messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }

    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) => _saveToken(user.uid, token),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCMトークンの更新に失敗しました: $error\n$stackTrace');
      },
    );
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(user.uid, token);
  }

  Future<void> _saveToken(String uid, String token) async {
    if (_registeredUid != null &&
        (_registeredUid != uid || _registeredToken != token)) {
      await _removeRegisteredToken();
    }
    await _tokenRef(uid, token).set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _registeredUid = uid;
    _registeredToken = token;
  }

  Future<void> _removeRegisteredToken() async {
    final uid = _registeredUid;
    final token = _registeredToken;
    _registeredUid = null;
    _registeredToken = null;
    if (uid != null && token != null) {
      await _tokenRef(uid, token).delete();
    }
  }

  DocumentReference<Map<String, dynamic>> _tokenRef(String uid, String token) {
    final id = base64Url.encode(utf8.encode(token)).replaceAll('=', '');
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(id);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: TaskNotificationService.details,
      payload: message.data['type'],
    );
  }
}
