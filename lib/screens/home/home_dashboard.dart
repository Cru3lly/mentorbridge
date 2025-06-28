import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  static const List<Map<String, dynamic>> items = [
    {
      'label': 'Daily Entry',
      'icon': Icons.edit_calendar,
      'route': '/homeDailyEntry',
    },
    {
      'label': 'Weekly Summary',
      'icon': Icons.calendar_view_week,
      'route': '/homeWeeklySummary',
    },
    {
      'label': 'Goal Setup',
      'icon': Icons.flag,
      'route': '/homeGoalSetup',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'MentorBridge',
          style: TextStyle(fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: items.map((item) {
                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push(item['route'] as String),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item['icon'] as IconData, size: 40, color: Colors.deepPurple),
                            const SizedBox(height: 16),
                            Text(
                              item['label'] as String,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 