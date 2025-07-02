import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class UniversityUnitCoordinatorDashboard extends StatefulWidget {
  const UniversityUnitCoordinatorDashboard({super.key});

  @override
  State<UniversityUnitCoordinatorDashboard> createState() => _UniversityUnitCoordinatorDashboardState();
}

class _UniversityUnitCoordinatorDashboardState extends State<UniversityUnitCoordinatorDashboard> {
  static const List<Map<String, dynamic>> items = [
    {
      'label': 'Assign Role',
      'icon': Icons.person_add,
      'route': '/universityUnitCoordinatorIdAuthPage',
    },
    {
      'label': 'Stats',
      'icon': Icons.bar_chart,
      'route': '/universityUnitCoordinatorStats',
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
            'University Unit Coordinator',
            style: TextStyle(fontSize: 24),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.settings,
                size: 30,
              ),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snapshot.data?.data() as Map<String, dynamic>?;
                    final assignedTo = (data?['assignedTo'] as List<dynamic>? ?? []).cast<String>();
                    if (assignedTo.isEmpty) {
                      return const Center(child: Text('No assigned users yet.'));
                    }
                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .where(FieldPath.documentId, whereIn: assignedTo)
                          .get(),
                      builder: (context, userSnap) {
                        if (userSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final users = userSnap.data?.docs ?? [];
                        return ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, i) {
                            final user = users[i].data() as Map<String, dynamic>;
                            return Card(
                              child: ListTile(
                                title: Text(user['username'] ?? users[i].id),
                                subtitle: Text(user['role'] ?? ''),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
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
            ],
          ),
        ),
      ),
    );
  }
} 