import 'package:flutter/material.dart';

void main() => runApp(const SmartCoupleApp());

class SmartCoupleApp extends StatelessWidget {
  const SmartCoupleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smart Couple',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF986079)),
      scaffoldBackgroundColor: const Color(0xFFFFF8F5),
      useMaterial3: true,
    ),
    home: const CoupleHome(),
  );
}

class CoupleHome extends StatefulWidget {
  const CoupleHome({super.key});
  @override
  State<CoupleHome> createState() => _CoupleHomeState();
}

class _CoupleHomeState extends State<CoupleHome> {
  int _page = 0;
  String? _mood;
  final _tasks = <({String title, bool done})>[];

  Future<void> _addPlan() async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => const _PlanDialog(),
    );
    if (mounted && title != null) {
      setState(() => _tasks.add((title: title, done: false)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Smart Couple'),
      backgroundColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_page == 0) ...[
                Text(
                  'Little moments.\nA stronger us.',
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Make time for each other, one day at a time.'),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 32),
                        const SizedBox(height: 16),
                        Text(
                          'How are you feeling?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final mood in ['Happy', 'Okay', 'Low'])
                              ChoiceChip(
                                label: Text(mood),
                                selected: _mood == mood,
                                onSelected: (selected) => setState(
                                  () => _mood = selected ? mood : null,
                                ),
                              ),
                          ],
                        ),
                        if (_mood != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Today you feel ${_mood!.toLowerCase()}. Thank you for checking in.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'A conversation for today',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'What is one small thing we could do this week to feel more connected?',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => setState(() => _page = 1),
                  icon: const Icon(Icons.add),
                  label: const Text('Make a plan together'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Personal demo: check-ins and plans last for this session only.',
                ),
              ] else ...[
                Text(
                  'Our plans',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  '${_tasks.where((task) => task.done).length} of ${_tasks.length} complete',
                ),
                const SizedBox(height: 24),
                if (_tasks.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Add a date idea, a shared task, or a little adventure.',
                      ),
                    ),
                  ),
                for (var i = 0; i < _tasks.length; i++)
                  Card(
                    child: CheckboxListTile(
                      title: Text(
                        _tasks[i].title,
                        style: TextStyle(
                          decoration: _tasks[i].done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      value: _tasks[i].done,
                      onChanged: (value) => setState(
                        () => _tasks[i] = (
                          title: _tasks[i].title,
                          done: value ?? false,
                        ),
                      ),
                      secondary: IconButton(
                        tooltip: 'Delete plan',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _tasks.removeAt(i)),
                      ),
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            ],
          ),
        ),
      ),
    ),
    floatingActionButton: _page == 1
        ? FloatingActionButton.extended(
            onPressed: _addPlan,
            icon: const Icon(Icons.add),
            label: const Text('Add plan'),
          )
        : null,
    bottomNavigationBar: NavigationBar(
      selectedIndex: _page,
      onDestinationSelected: (value) => setState(() => _page = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.favorite_outline),
          label: 'Together',
        ),
        NavigationDestination(icon: Icon(Icons.checklist), label: 'Our plans'),
      ],
    ),
  );
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog();
  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.pop(context, title);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Plan something together'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 120,
      decoration: const InputDecoration(
        labelText: 'What would you like to do?',
      ),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Add plan')),
    ],
  );
}
