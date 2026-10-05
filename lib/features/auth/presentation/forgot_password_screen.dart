import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../domain/validators.dart';
import 'auth_controllers.dart';
import 'widgets/auth_card.dart';
import 'widgets/auth_form_parts.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({this.from, super.key});

  final String? from;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(forgotPasswordControllerProvider.notifier).submit(_email.text);
  }

  void _backToLogin() =>
      context.go(RoutePaths.withFrom(RoutePaths.login, widget.from));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);
    final sent = state.value ?? false;
    final scheme = Theme.of(context).colorScheme;

    if (sent) {
      return AuthCard(
        title: AppStrings.forgotSentTitle,
        subtitle: AppStrings.forgotSentMessage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 56,
              color: scheme.secondary,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _backToLogin,
              child: const Text(AppStrings.backToLogin),
            ),
          ],
        ),
      );
    }

    return AuthCard(
      title: AppStrings.forgotTitle,
      subtitle: AppStrings.forgotSubtitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthErrorBanner(error: state.error),
            EmailField(
              controller: _email,
              validator: Validators.email,
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 24),
            SubmitButton(
              label: AppStrings.forgotButton,
              isLoading: state.isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _backToLogin,
              child: const Text(AppStrings.backToLogin),
            ),
          ],
        ),
      ),
    );
  }
}
