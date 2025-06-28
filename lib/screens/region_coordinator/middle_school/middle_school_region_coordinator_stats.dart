import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MiddleSchoolRegionCoordinatorStats extends StatefulWidget {
  const MiddleSchoolRegionCoordinatorStats({super.key});

  @override
  State<MiddleSchoolRegionCoordinatorStats> createState() => _MiddleSchoolRegionCoordinatorStatsState();
}

class _MiddleSchoolRegionCoordinatorStatsState extends State<MiddleSchoolRegionCoordinatorStats> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Middle School Region Coordinator Stats'),
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