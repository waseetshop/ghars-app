import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// يبث تغيّرات حالة المصادقة (تسجيل دخول / خروج)
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// المستخدم الحالي — null إذا لم يُسجّل الدخول
final currentUserProvider = Provider<User?>((ref) {
  // إعادة التقييم عند تغيّر حالة المصادقة
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

/// معرّف المستخدم الحالي — يُستخدم في الـ providers الأخرى
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});
