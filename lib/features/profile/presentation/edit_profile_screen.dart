import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/university.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/university_repository.dart';
import '../../auth/data/current_user_providers.dart';
import '../../auth/domain/validators.dart';
import '../../auth/presentation/widgets/auth_form_parts.dart';
import 'profile_controllers.dart';

/// Semesters offered in the dropdown (matches firestore.rules: 1–10).
const _semesters = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.editProfile)),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
        data: (p) => p == null
            ? const EmptyView(
                icon: Icons.hourglass_top,
                title: AppStrings.profileSettingUpTitle,
                message: AppStrings.profileSettingUpMessage,
              )
            : _EditForm(profile: p),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late String? _universityId = widget.profile.universityId;
  late int? _semester = widget.profile.semester;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(editProfileControllerProvider.notifier)
        .save(
          uid: widget.profile.uid,
          name: _name.text,
          universityId: _universityId,
          semester: _semester,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileControllerProvider);
    final universities = ref.watch(activeUniversitiesProvider);

    ref.listen(editProfileControllerProvider, (_, next) {
      if (next.value == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.profileSaved)));
        context.go(RoutePaths.profile);
      }
    });

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(context.pagePadding),
            children: [
              AuthErrorBanner(error: state.error),
              TextFormField(
                controller: _name,
                validator: Validators.name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: AppStrings.fieldName,
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              _UniversityField(
                universities: universities,
                value: _universityId,
                onChanged: (id) => setState(() => _universityId = id),
                onRetry: () => ref.invalidate(activeUniversitiesProvider),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _semester,
                decoration: const InputDecoration(
                  labelText: AppStrings.fieldSemester,
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: [
                  for (final n in _semesters)
                    DropdownMenuItem(
                      value: n,
                      child: Text(AppStrings.semesterLabel(n)),
                    ),
                ],
                onChanged: (n) => setState(() => _semester = n),
              ),
              const SizedBox(height: 24),
              SubmitButton(
                label: AppStrings.save,
                isLoading: state.isLoading,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// University dropdown with its own loading / error / empty states.
class _UniversityField extends StatelessWidget {
  const _UniversityField({
    required this.universities,
    required this.value,
    required this.onChanged,
    required this.onRetry,
  });

  final AsyncValue<List<University>> universities;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const decoration = InputDecoration(
      labelText: AppStrings.fieldUniversity,
      prefixIcon: Icon(Icons.account_balance_outlined),
    );

    return universities.when(
      loading: () => const InputDecorator(
        decoration: decoration,
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => InputDecorator(
        decoration: decoration.copyWith(
          helperText: AppStrings.universitiesUnavailable,
          suffixIcon: IconButton(
            tooltip: AppStrings.retry,
            icon: const Icon(Icons.refresh),
            onPressed: onRetry,
          ),
        ),
        child: const Text(AppStrings.notSet),
      ),
      data: (list) {
        if (list.isEmpty) {
          return InputDecorator(
            decoration: decoration.copyWith(
              helperText: AppStrings.noUniversitiesYet,
            ),
            child: const Text(AppStrings.notSet),
          );
        }
        // Keep a saved value only if it still exists in the list.
        final current = list.any((u) => u.id == value) ? value : null;
        return DropdownButtonFormField<String>(
          initialValue: current,
          isExpanded: true,
          decoration: decoration,
          items: [
            for (final u in list)
              DropdownMenuItem(value: u.id, child: Text(u.name)),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
