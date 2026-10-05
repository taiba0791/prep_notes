import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/auth_failure.dart';

/// Password field with a show / hide eye button.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    required this.validator,
    this.helperText,
    this.isNewPassword = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final String? helperText;
  final bool isNewPassword;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      autofillHints: [
        if (widget.isNewPassword)
          AutofillHints.newPassword
        else
          AutofillHints.password,
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscure ? AppStrings.showPassword : AppStrings.hidePassword,
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Email field with the right keyboard and autofill.
class EmailField extends StatelessWidget {
  const EmailField({
    required this.controller,
    required this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      textInputAction: textInputAction,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: AppStrings.fieldEmail,
        prefixIcon: Icon(Icons.mail_outline),
      ),
    );
  }
}

/// Full-width primary button that shows a spinner while [isLoading].
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: onPrimary,
              ),
            )
          : Text(label),
    );
  }
}

/// "Continue with Google" — Google's branding: official G logo, neutral
/// outlined button.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
    super.key,
  });

  static const logoAsset = 'assets/images/google_g.png';

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Image.asset(logoAsset, width: 18, height: 18),
      label: const Text(AppStrings.continueWithGoogle),
    );
  }
}

/// ─── or ─── separator between Google and the email form.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              AppStrings.orDivider,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// Friendly error box under a form. Shows nothing for "cancelled".
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({required this.error, super.key});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final failure = switch (error) {
      null => null,
      AuthException(:final failure) => failure,
      _ => AuthFailure.unknown,
    };
    if (failure == null || failure == AuthFailure.cancelled) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    failure.message,
                    style: TextStyle(color: scheme.onErrorContainer),
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

/// "Don't have an account? Create one" style row.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    required this.prompt,
    required this.action,
    required this.onPressed,
    super.key,
  });

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: Theme.of(context).textTheme.bodyMedium),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
