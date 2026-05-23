import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/colors.dart';

// ── مفتاح SharedPreferences ────────────────────────────────────
const kOnboardingDoneKey = 'onboarding_done';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      emoji: '🌱',
      title: 'مرحباً بك في غَرْس',
      body: 'رفيقك الذكي لرعاية نباتاتك\nتتبّع حدائقك وأصصك في مكان واحد',
      gradient: [Color(0xFFE9F5EB), Color(0xFFF9F9F6)],
    ),
    _Slide(
      emoji: '💧',
      title: 'جداول ري ذكية',
      body: 'يحسب غَرْس موعد الري تلقائياً\nبناءً على نوع النبتة والمناخ والموسم',
      gradient: [Color(0xFFE8F4F8), Color(0xFFF9F9F6)],
    ),
    _Slide(
      emoji: '🩺',
      title: 'تشخيص وعناية',
      body: 'صوّر نبتتك ودع الذكاء الاصطناعي\nيكشف المشكلات ويقترح العلاج',
      gradient: [Color(0xFFFAF0EB), Color(0xFFF9F9F6)],
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingDoneKey, true);
    if (mounted) context.go('/');
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GharsColors.charcoal900, // Oasis Sand
      body: Stack(
        children: [
          // ── الصفحات ──────────────────────────────────────────
          PageView.builder(
            controller: _ctrl,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
          ),

          // ── تخطّي (أعلى اليمين) ──────────────────────────────
          if (_page < _slides.length - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 20,
              child: TextButton(
                onPressed: _finish,
                child: const Text('تخطّي',
                    style: TextStyle(
                        color: GharsColors.textMuted, fontSize: 13)),
              ),
            ),

          // ── المؤشرات + زر التالي (أسفل) ─────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // نقاط المؤشر
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? GharsColors.green
                            : GharsColors.charcoal600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // زر التالي / ابدأ
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GharsColors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      _page < _slides.length - 1 ? 'التالي' : 'ابدأ الآن',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── بيانات الشريحة ────────────────────────────────────────────
class _Slide {
  final String emoji;
  final String title;
  final String body;
  final List<Color> gradient;

  const _Slide({
    required this.emoji,
    required this.title,
    required this.body,
    required this.gradient,
  });
}

// ── واجهة الشريحة ─────────────────────────────────────────────
class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: slide.gradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // أيقونة كبيرة مع هالة
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GharsColors.charcoal800,
                  border: Border.all(
                      color: GharsColors.charcoal500, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: GharsColors.green.withValues(alpha: 0.1),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(slide.emoji,
                      style: const TextStyle(fontSize: 64)),
                ),
              ),
              const SizedBox(height: 40),
              // العنوان
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: GharsColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              // الوصف
              Text(
                slide.body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: GharsColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const Spacer(flex: 3),
              // مساحة للأزرار في الأسفل
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}
