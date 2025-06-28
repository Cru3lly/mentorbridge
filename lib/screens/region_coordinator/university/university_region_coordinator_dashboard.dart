import 'package:flutter/material.dart';

class UniversityRegionCoordinatorDashboard extends StatefulWidget {
  const UniversityRegionCoordinatorDashboard({super.key});

  @override
  State<UniversityRegionCoordinatorDashboard> createState() => _UniversityRegionCoordinatorDashboardState();
}

class _UniversityRegionCoordinatorDashboardState extends State<UniversityRegionCoordinatorDashboard> {
  static const List<Map<String, dynamic>> items = [
    {
      'label': 'Assign Role',
      'icon': Icons.person_add,
      'route': '/universityRegionCoordinatorIdAuthPage',
    },
    {
      'label': 'Stats',
      'icon': Icons.bar_chart,
      'route': '/universityRegionCoordinatorStats',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'University Region Coordinator',
            style: TextStyle(fontSize: 24),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.settings,
                size: 30,
              ),
              tooltip: 'Settings',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 3),
                  color: Colors.white,
                ),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: items.map((item) {
                    return Card(
                      child: InkWell(
                        onTap: item['route'] != ''
                            ? () => Navigator.pushNamed(context, item['route'] as String)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item['icon'] as IconData, size: 30),
                              const SizedBox(height: 8),
                              Text(
                                item['label'] as String,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
} 