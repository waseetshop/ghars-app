import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin       = true;
  bool _loading       = false;
  bool _showPassword  = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
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
          email: email,
          password: password,
        );
      } else {
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        // If email confirmation is enabled, user.identities will be empty
        if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = null;
              _isLogin = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إرسال رابط التأكيد إلى بريدك الإلكتروني'),
                backgroundColor: GharsColors.green,
              ),
            );
          }
          return;
        }
      }
      // GoRouter redirect will handle navigation automatically
    } on AuthException catch (e) {
      setState(() => _error = _translateError(e.message));
    } catch (e) {
      setState(() => _error = 'حدث خطأ غير متوقع، حاول مجدداً');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _translateError(String message) {
    if (message.contains('Invalid login credentials'))  return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    if (message.contains('Email not confirmed'))        return 'يرجى تأكيد بريدك الإلكتروني أولاً';
    if (message.contains('User already registered'))    return 'هذا البريد الإلكتروني مسجّل مسبقاً';
    if (message.contains('Password should be'))        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    if (message.contains('rate limit'))                 return 'محاولات كثيرة، حاول بعد قليل';
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GharsColors.charcoal900,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo ─────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: GharsColors.charcoal800,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: GharsColors.charcoal700),
                          boxShadow: [
                            BoxShadow(
                              color: GharsColors.green.withAlpha(30),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'غَرْس',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: GharsColors.gold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLogin ? 'مرحباً بعودتك 🌿' : 'ابدأ رحلتك الخضراء 🌱',
                        style: const TextStyle(
                          fontSize: 14,
                          color: GharsColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Mode toggle ───────────────────────────────────
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: GharsColors.charcoal700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _TabButton(
                        label: 'تسجيل الدخول',
                        active: _isLogin,
                        onTap: () => setState(() { _isLogin = true; _error = null; }),
                      ),
                      _TabButton(
                        label: 'حساب جديد',
                        active: !_isLogin,
                        onTap: () => setState(() { _isLogin = false; _error = null; }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Email ─────────────────────────────────────────
                _Field(
                  controller: _emailCtrl,
                  hint: 'البريد الإلكتروني',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),

                // ── Password ──────────────────────────────────────
                _Field(
                  controller: _passwordCtrl,
                  hint: 'كلمة المرور',
                  icon: Icons.lock_outline,
                  obscure: !_showPassword,
                  suffix: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: GharsColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                  onSubmit: (_) => _submit(),
                ),

                // ── Error ─────────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: GharsColors.diseased.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GharsColors.diseased.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: GharsColors.diseased, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
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

                const SizedBox(height: 24),

                // ── CTA button ────────────────────────────────────
                SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [GharsColors.goldDim, GharsColors.gold],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: GharsColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: GharsColors.textPrimary,
                              ),
                            )
                          : Text(
                              _isLogin ? 'تسجيل الدخول' : 'إنشاء الحساب',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Footer ────────────────────────────────────────
                const Center(
                  child: Text(
                    'حديقتك الذكية 🌿',
                    style: TextStyle(
                      color: GharsColors.textMuted,
                      fontSize: 12,
                    ),
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

// ── Reusable widgets ──────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? GharsColors.charcoal800 : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6)]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? GharsColors.textPrimary : GharsColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onSubmitted: onSubmit,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      style: const TextStyle(
        color: GharsColors.textPrimary,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: GharsColors.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: GharsColors.textMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: GharsColors.charcoal700,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GharsColors.green, width: 1.5),
        ),
      ),
    );
  }
}
