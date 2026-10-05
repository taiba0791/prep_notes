import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../domain/validators.dart';
import 'auth_controllers.dart';
import 'widgets/auth_card.dart';
import 'widgets/auth_form_parts.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.from, super.key});

  /// Where to return after login (kept when switching to Register etc.).
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);

    return AuthCard(
      title: AppStrings.loginTitle,
      subtitle: AppStrings.loginSubtitle,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthErrorBanner(error: state.error),
              EmailField(controller: _email, validator: Validators.email),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: AppStrings.fieldPassword,
                validator: Validators.passwordRequired,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go(
                    RoutePaths.withFrom(RoutePaths.forgotPassword, widget.from),
                  ),
                  child: const Text(AppStrings.forgotPasswordLink),
                ),
              ),
              const SizedBox(height: 8),
              SubmitButton(
                label: AppStrings.loginButton,
                isLoading: state.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              AuthSwitchPrompt(
                prompt: AppStrings.noAccountPrompt,
                action: AppStrings.createAccountLink,
                onPressed: () => context.go(
                  RoutePaths.withFrom(RoutePaths.register, widget.from),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
