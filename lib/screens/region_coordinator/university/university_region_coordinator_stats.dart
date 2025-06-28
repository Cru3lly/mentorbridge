import 'package:flutter/material.dart';

class UniversityRegionCoordinatorStats extends StatefulWidget {
  const UniversityRegionCoordinatorStats({super.key});

  @override
  State<UniversityRegionCoordinatorStats> createState() => _UniversityRegionCoordinatorStatsState();
}

class _UniversityRegionCoordinatorStatsState extends State<UniversityRegionCoordinatorStats> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('University Region Coordinator Stats'),
      ),
      body: const Center(
        child: Text('Stats content will be added here.'),
      ),
    );
  }
} 