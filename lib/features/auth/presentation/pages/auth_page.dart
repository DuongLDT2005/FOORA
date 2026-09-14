import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/input_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_form.dart';
import '../widgets/social_login_buttons.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  bool _isLoginMode = true;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isAuthSuccess = false;
  String? _localErrorMessage;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _localErrorMessage = null;
    });
    ref.read(authNotifierProvider.notifier).clearError();

    final email = _emailController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final fullName = _fullNameController.text;

    // 1. Validate full name (Register mode only)
    if (!_isLoginMode) {
      final nameError = InputValidators.validateRequired(fullName, 'họ và tên');
      if (nameError != null) {
        setState(() => _localErrorMessage = nameError);
        return;
      }
    }

    // 2. Validate email
    final emailError = InputValidators.validateEmail(email);
    if (emailError != null) {
      setState(() => _localErrorMessage = emailError);
      return;
    }

    // 3. Validate password
    final passwordError = InputValidators.validatePassword(password);
    if (passwordError != null) {
      setState(() => _localErrorMessage = passwordError);
      return;
    }

    // 4. Validate confirm password (Register mode only)
    if (!_isLoginMode) {
      final confirmError = InputValidators.validateConfirmPassword(
        password,
        confirmPassword,
      );
      if (confirmError != null) {
        setState(() => _localErrorMessage = confirmError);
        return;
      }
    }

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success = _isLoginMode
        ? await authNotifier.login(email: email.trim(), password: password)
        : await authNotifier.register(
            fullName: fullName.trim(),
            email: email.trim(),
            password: password,
          );

    if (success && mounted) {
      setState(() {
        _isAuthSuccess = true;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _localErrorMessage = null;
    });
    ref.read(authNotifierProvider.notifier).clearError();

    final success = await ref
        .read(authNotifierProvider.notifier)
        .signInWithGoogle();

    if (success && mounted) {
      setState(() {
        _isAuthSuccess = true;
      });
    }
  }

  void _navigateToForgotPassword() {
    context.go(AppRouteNames.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final effectiveErrorMessage = _localErrorMessage ?? authState.errorMessage;

    if (_isAuthSuccess) {
      return _buildSuccessCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthForm(
          isLoginMode: _isLoginMode,
          isLoading: authState.isLoading,
          showPassword: _showPassword,
          showConfirmPassword: _showConfirmPassword,
          errorMessage: effectiveErrorMessage,
          fullNameController: _fullNameController,
          emailController: _emailController,
          passwordController: _passwordController,
          confirmPasswordController: _confirmPasswordController,
          onToggleMode: (isLogin) {
            setState(() {
              _isLoginMode = isLogin;
              _localErrorMessage = null;
              _showPassword = false;
              _showConfirmPassword = false;
              _fullNameController.clear();
              _emailController.clear();
              _passwordController.clear();
              _confirmPasswordController.clear();
            });
            ref.read(authNotifierProvider.notifier).clearError();
          },
          onTogglePasswordVisibility: () {
            setState(() {
              _showPassword = !_showPassword;
            });
          },
          onToggleConfirmPasswordVisibility: () {
            setState(() {
              _showConfirmPassword = !_showConfirmPassword;
            });
          },
          onForgotPassword: _navigateToForgotPassword,
          onSubmit: _handleSubmit,
        ),
        const SizedBox(height: 50),
        SocialLoginButtons(
          isLoading: authState.isLoading,
          onGoogleSignIn: _handleGoogleSignIn,
        ),
      ],
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 32,
            spreadRadius: -6,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.emerald100,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                LucideIcons.checkCircle2,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Xác thực thành công',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.slate800),
          ),
          const SizedBox(height: 6),
          Text(
            'Đang khởi tạo tủ lạnh điện tử của bạn...',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.slate400),
          ),
        ],
      ),
    );
  }
}
