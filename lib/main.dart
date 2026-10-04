// TEMPORARY theme preview (Phase 0, Step 0.4).
// Replaced by the real app entry point in Step 0.8.
import 'package:material_ui/material_ui.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_scaffold.dart';

void main() => runApp(const ThemePreviewApp());

class ThemePreviewApp extends StatefulWidget {
  const ThemePreviewApp({super.key});

  @override
  State<ThemePreviewApp> createState() => _ThemePreviewAppState();
}

class _ThemePreviewAppState extends State<ThemePreviewApp> {
  ThemeMode _mode = ThemeMode.light;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      home: AppScaffold(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        child: _tab == 0
            ? ThemePreviewScreen(
                isDark: _mode == ThemeMode.dark,
                onToggle: () => setState(
                  () => _mode = _mode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
              )
            : Scaffold(
                appBar: AppBar(title: Text(appDestinations[_tab].label)),
                body: const Center(child: Text(AppStrings.comingSoon)),
              ),
      ),
    );
  }
}

class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({
    required this.isDark,
    required this.onToggle,
    super.key,
  });

  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PrepNotes · Theme preview'),
        actions: [
          IconButton(
            tooltip: AppStrings.toggleDarkMode,
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: onToggle,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text.rich(
            TextSpan(
              text: 'Your notes, ready for every ',
              children: [
                TextSpan(
                  text: 'exam',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: context.appColors.highlight,
                  ),
                ),
              ],
            ),
            style: text.displaySmall,
          ),
          const SizedBox(height: 12),
          Text(
            'University-wise notes, free resources and focus tools in one place.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Browse notes')),
              OutlinedButton(onPressed: () {}, child: const Text('Join free')),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Start studying'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Teal stats band (like the image's numbers strip).
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final (value, label) in [
                    ('12', 'UNIVERSITIES'),
                    ('480+', 'NOTES'),
                    ('25 min', 'FOCUS'),
                  ])
                    Column(
                      children: [
                        Text(
                          value,
                          style: text.headlineMedium?.copyWith(
                            color: scheme.onSecondary,
                          ),
                        ),
                        Text(
                          label,
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSecondary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: context.appColors.cream,
                        child: Icon(Icons.menu_book, color: scheme.secondary),
                      ),
                      const Spacer(),
                      // Marigold "pop" badge.
                      Chip(
                        label: const Text('FREE'),
                        backgroundColor: scheme.tertiary,
                        labelStyle: text.labelMedium?.copyWith(
                          color: scheme.onTertiary,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Data Structures – Module 2', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Trees, heaps and graphs with solved PYQs.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: const Text('Semester 3'),
                        backgroundColor: scheme.secondaryContainer,
                        labelStyle: text.labelLarge?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                        side: BorderSide.none,
                      ),
                      Chip(
                        label: const Text('New'),
                        backgroundColor: scheme.primaryContainer,
                        labelStyle: text.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View notes →'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const TextField(
            decoration: InputDecoration(labelText: 'Search notes'),
          ),
        ],
      ),
    );
  }
}
