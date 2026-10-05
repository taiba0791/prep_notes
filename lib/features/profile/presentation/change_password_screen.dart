import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/domain/validators.dart';
import '../../auth/presentation/widgets/auth_form_parts.dart';
import 'account_controllers.dart';

/// Email/password accounts only (the link is hidden for Google accounts).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_current, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(changePasswordControllerProvider.notifier)
        .submit(currentPassword: _current.text, newPassword: _new.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordControllerProvider);

    ref.listen(changePasswordControllerProvider, (_, next) {
      if (next.value == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.passwordChanged)),
        );
        context.go(RoutePaths.profile);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.changePassword)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(context.pagePadding),
              children: [
                AuthErrorBanner(error: state.error),
                PasswordField(
                  controller: _current,
                  label: AppStrings.fieldCurrentPassword,
                  validator: Validators.passwordRequired,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _new,
                  label: AppStrings.fieldNewPasswordShort,
                  helperText: AppStrings.passwordHint,
                  validator: Validators.newPassword,
                  isNewPassword: true,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirm,
                  label: AppStrings.fieldConfirmPassword,
                  validator: (v) => Validators.confirmPassword(_new.text)(v),
                  isNewPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 24),
                SubmitButton(
                  label: AppStrings.changePassword,
                  isLoading: state.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
