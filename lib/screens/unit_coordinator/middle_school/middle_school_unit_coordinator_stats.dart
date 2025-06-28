import 'package:flutter/material.dart';

class MiddleSchoolUnitCoordinatorStats extends StatefulWidget {
  const MiddleSchoolUnitCoordinatorStats({super.key});

  @override
  State<MiddleSchoolUnitCoordinatorStats> createState() => _MiddleSchoolUnitCoordinatorStatsState();
}

class _MiddleSchoolUnitCoordinatorStatsState extends State<MiddleSchoolUnitCoordinatorStats> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
      ),
      body: const Center(
        child: Text('Stats content will be added here.'),
      ),
    );
  }
} 