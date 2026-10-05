import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../domain/validators.dart';
import 'auth_controllers.dart';
import 'widgets/auth_card.dart';
import 'widgets/auth_form_parts.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({this.from, super.key});

  final String? from;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => context.go(RoutePaths.terms);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => context.go(RoutePaths.privacy);
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(registerControllerProvider.notifier)
        .submit(name: _name.text, email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);
    final text = Theme.of(context).textTheme;
    final link = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    return AuthCard(
      title: AppStrings.registerTitle,
      subtitle: AppStrings.registerSubtitle,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthErrorBanner(error: state.error),
              TextFormField(
                controller: _name,
                validator: Validators.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: AppStrings.fieldName,
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              EmailField(controller: _email, validator: Validators.email),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: AppStrings.fieldNewPassword,
                helperText: AppStrings.passwordHint,
                validator: Validators.newPassword,
                isNewPassword: true,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: AppStrings.fieldConfirmPassword,
                validator: (v) => Validators.confirmPassword(_password.text)(v),
                isNewPassword: true,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text: AppStrings.termsPrefix,
                  children: [
                    TextSpan(
                      text: AppStrings.termsLink,
                      style: link,
                      recognizer: _termsTap,
                    ),
                    const TextSpan(text: AppStrings.termsAnd),
                    TextSpan(
                      text: AppStrings.privacyLink,
                      style: link,
                      recognizer: _privacyTap,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SubmitButton(
                label: AppStrings.registerButton,
                isLoading: state.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              AuthSwitchPrompt(
                prompt: AppStrings.haveAccountPrompt,
                action: AppStrings.loginLink,
                onPressed: () => context.go(
                  RoutePaths.withFrom(RoutePaths.login, widget.from),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
