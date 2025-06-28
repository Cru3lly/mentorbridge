import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

class HomeWeeklySummary extends StatefulWidget {
  const HomeWeeklySummary({super.key});

  @override
  State<HomeWeeklySummary> createState() => _HomeWeeklySummaryState();
}

class _HomeWeeklySummaryState extends State<HomeWeeklySummary> {
  List<BarChartGroupData> _barGroups = [];
  bool _loading = true;
  double maxY = 0.0;
  Map<String, dynamic>? _goalData;
  Map<String, int> _weeklyTotals = {'quran': 0, 'prayer': 0, 'dhikr': 0};

  final List<String> _days = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = DateTime.now();
    final weekDates = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    List<BarChartGroupData> groups = [];
    int quranTotal = 0;
    int prayerTotal = 0;
    int dhikrTotal = 0;

    // Hedefleri çek
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    _goalData = userDoc.data()?['goalData'] as Map<String, dynamic>?;

    for (int i = 0; i < weekDates.length; i++) {
      final date = weekDates[i];
      final dateId = DateFormat('yyyy-MM-dd').format(date);
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('entries')
          .doc(dateId)
          .get();

      final quran = int.tryParse(doc.data()?['quran']?.toString() ?? '0') ?? 0;
      final prayer = int.tryParse(doc.data()?['prayer']?.toString() ?? '0') ?? 0;
      final dhikr = int.tryParse(doc.data()?['dhikr']?.toString() ?? '0') ?? 0;
      quranTotal += quran;
      prayerTotal += prayer;
      dhikrTotal += dhikr;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(toY: quran.toDouble(), width: 12)],
        ),
      );
      if (quran.toDouble() > maxY) maxY = quran.toDouble();
    }
    _weeklyTotals = {
      'quran': quranTotal,
      'prayer': prayerTotal,
      'dhikr': dhikrTotal,
    };
    setState(() {
      _barGroups = groups;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Weekly Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _barGroups.isEmpty
          ? const Center(child: Text('No data available.'))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Hedeflerle karşılaştırmalı özet
            Card(
              color: Colors.orange.shade50,
              margin: const EdgeInsets.only(bottom: 18),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildGoalRow('Quran', 'quran'),
                    const SizedBox(height: 8),
                    _buildGoalRow('Prayer', 'prayer'),
                    const SizedBox(height: 8),
                    _buildGoalRow('Dhikr', 'dhikr'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY + 5,
                  barGroups: _barGroups,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < _days.length) {
                            return Text(_days[idx]);
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalRow(String label, String key) {
    final total = _weeklyTotals[key] ?? 0;
    final goal = _goalData?[key] ?? 0;
    final percent = (goal > 0) ? (total / goal).clamp(0, 1.0) : 0.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: LinearProgressIndicator(
              value: percent.toDouble(),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: Colors.deepOrange,
            ),
          ),
        ),
        Text('$total / $goal'),
      ],
    );
  }
}
