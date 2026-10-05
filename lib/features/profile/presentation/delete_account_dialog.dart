import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../auth/domain/validators.dart';
import '../../auth/presentation/widgets/auth_form_parts.dart';
import 'account_controllers.dart';

/// Asks for confirmation (and the password, for email accounts), then
/// deletes the account. [onDeleted] runs after a successful deletion — even
/// if the router has already moved away from the page that opened this.
Future<void> showDeleteAccountDialog(
  BuildContext context, {
  required bool hasPassword,
  required VoidCallback onDeleted,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _DeleteAccountDialog(hasPassword: hasPassword, onDeleted: onDeleted),
  );
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({
    required this.hasPassword,
    required this.onDeleted,
  });

  final bool hasPassword;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.hasPassword && !_formKey.currentState!.validate()) return;
    ref
        .read(deleteAccountControllerProvider.notifier)
        .submit(
          password: widget.hasPassword ? _password.text : null,
          onDeleted: widget.onDeleted,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deleteAccountControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 36),
      title: const Text(AppStrings.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthErrorBanner(error: state.error),
              const Text(AppStrings.deleteAccountMessage),
              const SizedBox(height: 16),
              if (widget.hasPassword) ...[
                const Text(AppStrings.deleteAccountPasswordHint),
                const SizedBox(height: 8),
                PasswordField(
                  controller: _password,
                  label: AppStrings.fieldPassword,
                  validator: Validators.passwordRequired,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                ),
              ] else
                const Text(AppStrings.deleteAccountGoogleHint),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: state.isLoading ? null : _submit,
          child: state.isLoading
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onError,
                  ),
                )
              : const Text(AppStrings.deleteAccountConfirm),
        ),
      ],
    );
  }
}
