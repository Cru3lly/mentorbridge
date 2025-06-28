import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MentorDashboard extends StatelessWidget {
  const MentorDashboard({super.key});

  // Dashboard items listesi - sadece Authorize ID olacak
  static const List<Map<String, dynamic>> items = [
    {
      'label': 'Weekly Summary',
      'icon': Icons.person_add,
      'route': '/mentorWeeklySummary', // Mentor ID yetkilendirme sayfasına yönlendirecek route
    },
    {
      'label': 'Weekend Activity Report',
      'icon': Icons.assignment,
      'route': '/mentorWeekendReport',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Geri tuşunu devre dışı bırak
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF), // Beyaz arka plan
        appBar: AppBar(
          automaticallyImplyLeading: false, // Geri okunu kaldır
          title: const Text(
            'Mentor',  // Başlık
            style: TextStyle(fontSize: 24), // Font boyutu
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.settings,
                size: 30, // Ayarlar ikonu boyutu
              ),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Center(
            child: Container(
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
                children: items.map((item) {
                  return Card(
                    child: InkWell(
                      onTap: (item['route'] as String).isNotEmpty
                          ? () => context.push(item['route'] as String)
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
          ),
        ),
      ),
    );
  }
}