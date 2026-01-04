import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

class AnalysisDashboardScreen extends StatefulWidget {
  AnalysisDashboardScreen({super.key});

  @override
  State<AnalysisDashboardScreen> createState() => _AnalysisDashboardScreenState();
}

class _AnalysisDashboardScreenState extends State<AnalysisDashboardScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  
  String _selectedMode = 'mental_health';
  String _selectedRange = 'this_week';

  final Map<String, String> _modes = {
    'mental_health': 'Mental Health',
    'study': 'Study',
    'funny': 'Funny',
    'searching': 'Searching',
  };

  final Map<String, String> _ranges = {
    'today': 'Today',
    'yesterday': 'Yesterday',
    'this_week': 'This Week',
    'last_week': 'Last Week',
    'this_month': 'This Month',
    'last_month': 'Last Month',
  };
  
  // Data State
  Map<String, dynamic> _data = {
    'overview': {'positive': 0, 'negative': 0},
    'trend': {'morning': 50, 'afternoon': 50, 'evening': 50, 'night': 50},
    'dailyTimeline': [],
    'mentalHealthScore': 75
  };

  @override
  void initState() {
    super.initState();
    _fetchAnalysisData();
  }

  Future<void> _fetchAnalysisData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final queryParams = {
        'mode': _selectedMode,
        'range': _selectedRange,
      };
      final uri = Uri.parse(ApiConstants.analysisUrl).replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _data = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        debugPrint('Failed to load analysis data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error fetching analysis: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBFF),
      appBar: AppBar(
        title: const Text(
          'Analysis Dashboard',
          style: TextStyle(color: Color(0xFF2D3436), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2D3436)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildModeSelector(),
          const SizedBox(height: 10),
          _buildRangeSelector(),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverviewCard(),
                        const SizedBox(height: 20),
                        _buildTrendCard(),
                        const SizedBox(height: 20),
                        _buildDailyTimelineCard(),
                        const SizedBox(height: 20),
                        _buildScoreCard(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _modes.entries.map((entry) {
          final isSelected = _selectedMode == entry.key;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedMode = entry.key);
              _fetchAnalysisData();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6A11CB) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (!isSelected)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF2D3436),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _ranges.entries.map((entry) {
          final isSelected = _selectedRange == entry.key;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedRange = entry.key);
              _fetchAnalysisData();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0E6FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF6A11CB) : Colors.grey.shade300,
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF6A11CB) : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final positive = _data['overview']['positive'] ?? 0;
    final negative = _data['overview']['negative'] ?? 0;
    final total = positive + negative;
    final isMostlyPositive = positive >= negative;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_modes[_selectedMode]} Insights',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
              ),
              Icon(
                isMostlyPositive ? Icons.sentiment_satisfied_alt : Icons.sentiment_dissatisfied,
                color: isMostlyPositive ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _legendItem(const Color(0xFFA3D9A5), 'Positive'),
              const SizedBox(width: 15),
              _legendItem(const Color(0xFFFFB74D), 'Negative'),
            ],
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.7,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (total > 0 ? total : 10).toDouble(),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12);
                        switch (value.toInt()) {
                          case 0: return const Text('Pos', style: style);
                          case 1: return const Text('Neg', style: style);
                          default: return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: positive.toDouble(),
                        color: const Color(0xFFA3D9A5),
                        width: 30,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: negative.toDouble(),
                        color: const Color(0xFFFFB74D),
                        width: 30,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isMostlyPositive 
                  ? 'Great job! Keep up the positive vibes! 😊' 
                  : 'A bit challenging? That\'s okay, keep going! 💪',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
    final trend = _data['trend'];
    final spots = [
      FlSpot(0, (trend['morning'] ?? 50).toDouble()),
      FlSpot(1, (trend['afternoon'] ?? 50).toDouble()),
      FlSpot(2, (trend['evening'] ?? 50).toDouble()),
      FlSpot(3, (trend['night'] ?? 50).toDouble()),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emotion Trend Over Time',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.7,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Colors.grey, fontSize: 12);
                        switch (value.toInt()) {
                          case 0: return const Text('Morning', style: style);
                          case 1: return const Text('Afternoon', style: style);
                          case 2: return const Text('Evening', style: style);
                          case 3: return const Text('Night', style: style);
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 3,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF6A11CB),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6A11CB).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              Text('😊 Happy', style: TextStyle(fontSize: 12)),
              Text('😔 Sad', style: TextStyle(fontSize: 12)),
              Text('😡 Angry', style: TextStyle(fontSize: 12)),
              Text('😌 Calm', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTimelineCard() {
    final List daily = _data['dailyTimeline'] ?? [];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Mood Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
          ),
          const SizedBox(height: 20),
          daily.isEmpty 
            ? const Center(child: Text('No data for this period', style: TextStyle(color: Colors.grey)))
            : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: daily.map((day) {
                final date = DateTime.parse(day['date']);
                final dayName = DateFormat('E').format(date); // Mon, Tue
                final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == day['date'];

                return Container(
                  margin: const EdgeInsets.only(right: 15),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isToday ? const Color(0xFFE8D5FF) : Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: isToday ? Border.all(color: const Color(0xFF8B5CF6), width: 2) : null,
                        ),
                        child: Text(
                          day['icon'],
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dayName,
                        style: TextStyle(
                          color: isToday ? const Color(0xFF8B5CF6) : Colors.grey,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    final score = _data['mentalHealthScore'] ?? 75;
    Color scoreColor = Colors.green;
    String status = 'Good';
    
    if (score >= 80) {
      scoreColor = Colors.green;
      status = 'Excellent';
    } else if (score >= 60) {
      scoreColor = Colors.lightGreen;
      status = 'Good';
    } else if (score >= 40) {
      scoreColor = Colors.orange;
      status = 'Moderate';
    } else {
      scoreColor = Colors.red;
      status = 'Needs Attention';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_modes[_selectedMode]} Score',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$score',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: scoreColor),
                          ),
                          Text(
                            '/100',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: scoreColor),
                    ),
                    const SizedBox(height: 10),
                    _bulletPoint('Based on your recent interactions.', Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.black54))),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
