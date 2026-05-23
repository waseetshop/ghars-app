import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  // ── Navigation state ──────────────────────────────────────────
  bool _showEmailForm = false;

  // ── Form state ────────────────────────────────────────────────
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin       = false; // default: sign up (new user)
  bool _loading       = false;
  bool _showPassword  = false;
  String? _error;

  // ── Animation ─────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Email form ────────────────────────────────────────────────
  void _openEmailForm({bool isLogin = false}) {
    setState(() {
      _isLogin       = isLogin;
      _showEmailForm = true;
      _error         = null;
    });
    _animCtrl.forward(from: 0);
  }

  void _closeEmailForm() {
    _animCtrl.reverse().then((_) {
      if (mounted) setState(() => _showEmailForm = false);
    });
  }

  Future<void> _submit() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'يرجى إدخال البريد الإلكتروني وكلمة المرور');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email, password: password,
        );
      } else {
        final res = await Supabase.instance.client.auth.signUp(
          email: email, password: password,
        );
        if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
          if (mounted) {
            setState(() { _loading = false; _error = null; });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('تم إرسال رابط التأكيد إلى بريدك الإلكتروني'),
              backgroundColor: GharsColors.green,
            ));
          }
          return;
        }
      }
    } on AuthException catch (e) {
      setState(() => _error = _translateError(e.message));
    } catch (_) {
      setState(() => _error = 'حدث خطأ غير متوقع، حاول مجدداً');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _translateError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (message.contains('Email not confirmed')) {
      return 'يرجى تأكيد بريدك الإلكتروني أولاً';
    }
    if (message.contains('User already registered')) {
      return 'هذا البريد الإلكتروني مسجّل مسبقاً، سجّل الدخول';
    }
    if (message.contains('Password should be')) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    if (message.contains('rate limit')) {
      return 'محاولات كثيرة، حاول بعد قليل';
    }
    return message;
  }

  // ── Google OAuth ──────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.ghars://login-callback',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تسجيل الدخول بـ Google غير متاح حالياً'),
          backgroundColor: GharsColors.diseased,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GharsColors.charcoal900,
      body: Stack(
        children: [
          // ── Landing view ──────────────────────────────────────
          _LandingView(
            loading:         _loading,
            onEmail:         () => _openEmailForm(isLogin: false),
            onLogin:         () => _openEmailForm(isLogin: true),
            onGoogle:        _signInWithGoogle,
          ),

          // ── Email form overlay (slides up) ────────────────────
          if (_showEmailForm)
            SlideTransition(
              position: _slideAnim,
              child: _EmailFormOverlay(
                isLogin:      _isLogin,
                emailCtrl:    _emailCtrl,
                passwordCtrl: _passwordCtrl,
                showPassword: _showPassword,
                loading:      _loading,
                error:        _error,
                onToggleMode: () => setState(() {
                  _isLogin = !_isLogin;
                  _error   = null;
                }),
                onTogglePassword: () =>
                    setState(() => _showPassword = !_showPassword),
                onSubmit: _submit,
                onBack:   _closeEmailForm,
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Landing view — Planta-style
// ══════════════════════════════════════════════════════════════════
class _LandingView extends StatelessWidget {
  final bool loading;
  final VoidCallback onEmail;
  final VoidCallback onLogin;
  final VoidCallback onGoogle;

  const _LandingView({
    required this.loading,
    required this.onEmail,
    required this.onLogin,
    required this.onGoogle,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── مساحة علوية + شعار ────────────────────────────
            const Spacer(flex: 2),
            Center(
              child: Column(
                children: [
                  // شعار مع خلفية دائرية
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: GharsColors.greenFaint,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) => const Text(
                            '🌿',
                            style: TextStyle(fontSize: 42),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // العنوان الكبير
                  const Text(
                    'أهلاً بك في غَرْس 🌱',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: GharsColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'رفيقك الذكي لرعاية نباتاتك\nابدأ رحلتك الخضراء الآن',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: GharsColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // ── أزرار التسجيل ─────────────────────────────────
            // Google
            _AuthButton(
              onTap:    loading ? null : onGoogle,
              color:    Colors.white,
              border:   GharsColors.charcoal500,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google G icon
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: const Text(
                      'G',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'المتابعة بـ Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: GharsColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Email — إنشاء حساب
            _AuthButton(
              onTap:  loading ? null : onEmail,
              color:  GharsColors.green,
              child: const Text(
                'إنشاء حساب بالبريد الإلكتروني',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── لديك حساب؟ ───────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: loading ? null : onLogin,
                child: RichText(
                  text: const TextSpan(
                    text: 'لديك حساب بالفعل؟  ',
                    style: TextStyle(
                        color: GharsColors.textMuted, fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'تسجيل الدخول',
                        style: TextStyle(
                          color: GharsColors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(flex: 1),

            // ── تذييل — الشروط ──────────────────────────────
            Padding(
              padding: EdgeInsets.only(bottom: bottom + 8),
              child: const Text(
                'بالمتابعة أنت توافق على شروط الاستخدام وسياسة الخصوصية',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: GharsColors.textMuted,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Email form overlay — يظهر فوق Landing بانزلاق من الأسفل
// ══════════════════════════════════════════════════════════════════
class _EmailFormOverlay extends StatelessWidget {
  final bool isLogin;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool showPassword;
  final bool loading;
  final String? error;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _EmailFormOverlay({
    required this.isLogin,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.showPassword,
    required this.loading,
    required this.error,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      color: GharsColors.charcoal900,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── رأس الصفحة ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Row(
                  children: [
                    // زر الرجوع
                    GestureDetector(
                      onTap: onBack,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: GharsColors.charcoal700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: GharsColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isLogin ? 'تسجيل الدخول' : 'إنشاء حساب',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: GharsColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // ── عنوان ─────────────────────────────────────
              Text(
                isLogin ? 'مرحباً بعودتك 👋' : 'ابدأ رحلتك 🌱',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: GharsColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isLogin
                    ? 'أدخل بيانات حسابك للمتابعة'
                    : 'أنشئ حسابك المجاني الآن',
                style: const TextStyle(
                  fontSize: 14,
                  color: GharsColors.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              // ── حقول الإدخال ──────────────────────────────
              _Field(
                controller:  emailCtrl,
                hint:        'البريد الإلكتروني',
                icon:        Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: passwordCtrl,
                hint:       'كلمة المرور',
                icon:       Icons.lock_outline,
                obscure:    !showPassword,
                suffix: IconButton(
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: GharsColors.textMuted,
                    size: 20,
                  ),
                  onPressed: onTogglePassword,
                ),
                onSubmit: (_) => onSubmit(),
              ),

              // ── رسالة الخطأ ──────────────────────────────
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: GharsColors.diseased.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: GharsColors.diseased.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: GharsColors.diseased, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: GharsColors.diseased,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // ── زر الإرسال ────────────────────────────────
              _AuthButton(
                onTap: loading ? null : onSubmit,
                color: GharsColors.green,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isLogin ? 'تسجيل الدخول' : 'إنشاء الحساب',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // ── تبديل وضع الدخول ──────────────────────────
              Center(
                child: GestureDetector(
                  onTap: onToggleMode,
                  child: RichText(
                    text: TextSpan(
                      text: isLogin
                          ? 'ليس لديك حساب؟  '
                          : 'لديك حساب بالفعل؟  ',
                      style: const TextStyle(
                          color: GharsColors.textMuted, fontSize: 14),
                      children: [
                        TextSpan(
                          text: isLogin ? 'إنشاء حساب' : 'تسجيل الدخول',
                          style: const TextStyle(
                            color: GharsColors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Shared widgets
// ══════════════════════════════════════════════════════════════════

/// زر مستدير الأطراف بعرض كامل — مثل Planta
class _AuthButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color color;
  final Color? border;
  final Widget child;

  const _AuthButton({
    required this.onTap,
    required this.color,
    required this.child,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
            border: border != null
                ? Border.all(color: border!, width: 1.5)
                : null,
            boxShadow: color == Colors.white
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// حقل نص
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onSubmit;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   controller,
      keyboardType: keyboardType,
      obscureText:  obscure,
      onSubmitted:  onSubmit,
      textDirection: TextDirection.ltr,
      style: const TextStyle(
          color: GharsColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText:    hint,
        hintStyle:   const TextStyle(
            color: GharsColors.textMuted, fontSize: 14),
        prefixIcon:  Icon(icon, color: GharsColors.textMuted, size: 20),
        suffixIcon:  suffix,
        filled:      true,
        fillColor:   GharsColors.charcoal700,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: GharsColors.green, width: 1.5),
        ),
      ),
    );
  }
}
