import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../core/utils/auth_error_helper.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/neon_text_field.dart';
import '../../core/widgets/pixel_button.dart';
import '../../core/widgets/pixel_punch_logo.dart';
import '../../services/supabase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  String? _errorMessage;
  bool _registrationComplete = false;

  late AnimationController _formController;
  late Animation<Offset> _formSlide;
  late Animation<double> _formOpacity;

  @override
  void initState() {
    super.initState();
    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    ));
    _formOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _formController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    _formController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _formController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = context.read<SupabaseService>();
      final response = await supabase.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );

      if (!mounted) return;

      if (response?.user?.emailConfirmedAt != null) {
        context.go('/transition', extra: {'mode': 'register'});
      } else {
        setState(() => _registrationComplete = true);
      }
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
    if (_registrationComplete) return _buildSuccessView();

    return Scaffold(
      body: AnimatedBackground(
        particleCount: 20,
        showFloatingPixels: true,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SlideTransition(
                position: _formSlide,
                child: FadeTransition(
                  opacity: _formOpacity,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Back button
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
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
                      const SizedBox(height: 8),

                      // Logo
                      const PixelPunchLogoWidget(
                        width: 80,
                        height: 80,
                        showShadow: true,
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        'Create Account',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join the arena and start fighting!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 28),

                      // Error message
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

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            NeonTextField(
                              controller: _nameController,
                              labelText: 'Fighter Name',
                              hintText: 'e.g. ShadowStrike',
                              prefixIcon: Icons.badge_rounded,
                              glowColor: AppColors.accent,
                              textInputAction: TextInputAction.next,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Choose a fighter name';
                                }
                                if (val.trim().length < 3) {
                                  return 'Name must be at least 3 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            NeonTextField(
                              controller: _emailController,
                              labelText: 'Email',
                              hintText: 'fighter@pixelpunch.com',
                              prefixIcon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              glowColor: AppColors.secondary,
                              textInputAction: TextInputAction.next,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Enter your email';
                                }
                                if (!val.contains('@') || !val.contains('.')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            NeonTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_rounded,
                              obscureText: !_showPassword,
                              glowColor: AppColors.primary,
                              textInputAction: TextInputAction.next,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => setState(
                                    () => _showPassword = !_showPassword),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Enter a password';
                                }
                                if (val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            NeonTextField(
                              controller: _confirmPasswordController,
                              labelText: 'Confirm Password',
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: !_showPassword,
                              glowColor: AppColors.primary,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleRegister(),
                              validator: (val) {
                                if (val != _passwordController.text) {
                                  return 'Passwords don\'t match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // Register button
                            _isLoading
                                ? const SizedBox(
                                    height: 56,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  )
                                : PixelButton(
                                    label: 'CREATE ACCOUNT',
                                    icon: Icons.person_add_rounded,
                                    color: AppColors.secondary,
                                    isLarge: true,
                                    showGlow: true,
                                    width: double.infinity,
                                    onTap: _handleRegister,
                                  ),
                            const SizedBox(height: 24),

                            // Login link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/login'),
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Scaffold(
      body: AnimatedBackground(
        particleCount: 50,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withValues(alpha: 0.15),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5),
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 48,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Check Your Email!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a confirmation link to\n${_emailController.text.trim()}\n\nClick the link to activate your account.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                  ),
                  const SizedBox(height: 36),
                  PixelButton(
                    label: 'GO TO LOGIN',
                    icon: Icons.login_rounded,
                    color: AppColors.primary,
                    isLarge: true,
                    onTap: () => context.go('/login'),
                  ),
                  const SizedBox(height: 16),
                  PixelButton(
                    label: 'PLAY AS GUEST',
                    icon: Icons.play_arrow_rounded,
                    color: AppColors.textSecondary,
                    isOutlined: true,
                    onTap: () => context.go('/transition', extra: {'mode': 'guest'}),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
