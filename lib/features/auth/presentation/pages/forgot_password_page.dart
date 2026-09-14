import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/utils/input_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/forgot_password_form.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSuccess = false;
  String? _localErrorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPasswordSubmit() async {
    setState(() {
      _localErrorMessage = null;
    });
    ref.read(authNotifierProvider.notifier).clearError();

    final email = _emailController.text;

    final emailError = InputValidators.validateEmail(email);
    if (emailError != null) {
      setState(() => _localErrorMessage = emailError);
      return;
    }

    final success = await ref
        .read(authNotifierProvider.notifier)
        .resetPassword(email: email.trim());

    if (success && mounted) {
      setState(() {
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final effectiveErrorMessage = _localErrorMessage ?? authState.errorMessage;

    return ForgotPasswordForm(
      isLoading: authState.isLoading,
      isSuccess: _isSuccess,
      errorMessage: effectiveErrorMessage,
      emailController: _emailController,
      onSubmit: _handleForgotPasswordSubmit,
      onBackToLogin: () {
        ref.read(authNotifierProvider.notifier).clearError();
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRouteNames.auth);
        }
      },
    );
  }
}
