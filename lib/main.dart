import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/constants.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // تفعيل اللغة العربية للتواريخ النسبية
  timeago.setLocaleMessages('ar', timeago.ArMessages());

  await NotificationService.init();

  // بناء الـ router بعد تهيئة Supabase
  final router = buildAppRouter();

  runApp(ProviderScope(child: GharsApp(router: router)));
}

class GharsApp extends StatelessWidget {
  final GoRouter router;
  const GharsApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'غَرْس',
      debugShowCheckedModeBanner: false,
      theme: GharsTheme.light,
      routerConfig: router,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
  }
}
