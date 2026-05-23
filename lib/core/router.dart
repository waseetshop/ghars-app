import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/auth_screen.dart';
import '../features/location/location_screen.dart';
import '../features/main_scaffold.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/plants/plants_screen.dart';
import '../providers/location_provider.dart';

// ── Auth notifier — يُنبّه GoRouter عند تغيّر حالة المصادقة ──
class _AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  _AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter buildAppRouter() {
  final authNotifier = _AuthNotifier();

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,

    // ── Redirect: حماية الشاشات ───────────────────────────────
    redirect: (context, state) async {
      final user    = Supabase.instance.client.auth.currentUser;
      final loc     = state.matchedLocation;
      final onAuth  = loc == '/auth';
      final onBoard = loc == '/onboarding';

      // تحقق من Onboarding أولاً — يسبق كل شيء
      final prefs    = await SharedPreferences.getInstance();
      final doneOnboarding = prefs.getBool(kOnboardingDoneKey) ?? false;
      final onLocation = loc == '/location';

      if (!doneOnboarding && !onBoard) return '/onboarding';
      if (doneOnboarding && onBoard)   return '/';

      // غير مسجّل → أرسله لشاشة الدخول (لكن ليس من Onboarding)
      if (user == null && !onAuth && !onBoard) return '/auth';
      // مسجّل دخول → لا داعي لشاشة الدخول
      if (user != null && onAuth) return '/';

      // تحقق من الموقع — فقط للمستخدم المسجّل الذي لم يختر موقعه بعد
      final locationDone = prefs.getBool(kLocationDoneKey) ?? false;
      if (user != null && !locationDone && !onLocation) return '/location';

      return null;
    },

    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/location',
        builder: (context, state) => const LocationScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScaffold(),
      ),
      GoRoute(
        path: '/garden/:gardenId',
        builder: (context, state) => PlantsScreen(
          gardenId: state.pathParameters['gardenId']!,
          gardenName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
    ],
  );
}
