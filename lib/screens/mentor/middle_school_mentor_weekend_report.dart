import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MiddleSchoolMentorWeekendReport extends StatefulWidget {
  const MiddleSchoolMentorWeekendReport({super.key});

  @override
  State<MiddleSchoolMentorWeekendReport> createState() => _MiddleSchoolMentorWeekendReportState();
}

class _MiddleSchoolMentorWeekendReportState extends State<MiddleSchoolMentorWeekendReport> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Middle School Weekend Activity Report'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Text(
            'Middle School Weekend Activity Report\n(Implementation in progress)',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

