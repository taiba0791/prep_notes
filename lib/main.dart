// TEMPORARY theme preview (Phase 0, Step 0.4).
// Replaced by the real app entry point in Step 0.8.
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';

void main() => runApp(const ThemePreviewApp());

class ThemePreviewApp extends StatefulWidget {
  const ThemePreviewApp({super.key});

  @override
  State<ThemePreviewApp> createState() => _ThemePreviewAppState();
}

class _ThemePreviewAppState extends State<ThemePreviewApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrepNotes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      home: ThemePreviewScreen(
        isDark: _mode == ThemeMode.dark,
        onToggle: () => setState(
          () => _mode = _mode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark,
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
            tooltip: 'Toggle dark mode',
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
              TextButton(onPressed: () {}, child: const Text('View details →')),
            ],
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.tertiary,
                    child: Icon(Icons.menu_book, color: scheme.onTertiary),
                  ),
                  const SizedBox(height: 12),
                  Text('Data Structures – Module 2', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Trees, heaps and graphs with solved PYQs.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  const Chip(label: Text('Semester 3')),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            label: 'Study',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: 'Resources',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
