import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HighSchoolRegionCoordinatorStats extends StatefulWidget {
  const HighSchoolRegionCoordinatorStats({super.key});

  @override
  State<HighSchoolRegionCoordinatorStats> createState() => _HighSchoolRegionCoordinatorStatsState();
}

class _HighSchoolRegionCoordinatorStatsState extends State<HighSchoolRegionCoordinatorStats> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('High School Region Coordinator Stats'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Text('Stats content will be added here.'),
      ),
    );
  }
} 