import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CountryCoordinatorStats extends StatefulWidget {
  const CountryCoordinatorStats({super.key});

  @override
  State<CountryCoordinatorStats> createState() => _CountryCoordinatorStatsState();
}

class _CountryCoordinatorStatsState extends State<CountryCoordinatorStats> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Country Coordinator Stats'),
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