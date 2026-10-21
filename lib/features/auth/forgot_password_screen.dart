import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../core/utils/auth_error_helper.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/neon_text_field.dart';
import '../../core/widgets/pixel_button.dart';
import '../../services/supabase_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = context.read<SupabaseService>();
      await supabase.resetPassword(_emailController.text.trim());
      if (mounted) setState(() => _emailSent = true);
    } catch (e) {
      setState(() {
        _errorMessage = formatAuthError(e);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        particleCount: 15,
        child: SafeArea(
          child: FadeTransition(
            opacity: _opacity,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _emailSent
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.warning.withValues(alpha: 0.15),
                      border: Border.all(
                        color: _emailSent
                            ? AppColors.success.withValues(alpha: 0.5)
                            : AppColors.warning.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_emailSent ? AppColors.success : AppColors.warning)
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Icon(
                      _emailSent
                          ? Icons.mark_email_read_rounded
                          : Icons.lock_reset_rounded,
                      size: 48,
                      color: _emailSent ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    _emailSent ? 'Email Sent!' : 'Reset Password',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _emailSent
                              ? AppColors.success
                              : AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _emailSent
                        ? 'Check your inbox at\n${_emailController.text.trim()}\nfor the reset link.'
                        : "Enter your email and we'll send you\na link to reset your password.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                  ),
                  const SizedBox(height: 36),

                  if (!_emailSent) ...[
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: AppColors.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          NeonTextField(
                            controller: _emailController,
                            labelText: 'Email',
                            hintText: 'fighter@pixelpunch.com',
                            prefixIcon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            glowColor: AppColors.warning,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleReset(),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Enter your email';
                              }
                              if (!val.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          _isLoading
                              ? const SizedBox(
                                  height: 56,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.warning,
                                    ),
                                  ),
                                )
                              : PixelButton(
                                  label: 'SEND RESET LINK',
                                  icon: Icons.send_rounded,
                                  color: AppColors.warning,
                                  isLarge: true,
                                  showGlow: true,
                                  width: double.infinity,
                                  onTap: _handleReset,
                                ),
                        ],
                      ),
                    ),
                  ] else ...[
                    PixelButton(
                      label: 'BACK TO LOGIN',
                      icon: Icons.login_rounded,
                      color: AppColors.primary,
                      isLarge: true,
                      onTap: () => context.go('/login'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
