import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants.dart';
import '../services/tts_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _storage = const FlutterSecureStorage();
  final TTSService _ttsService = TTSService();
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String _selectedRange = '7days';
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  bool _isSpeaking = false;

  final Map<String, String> _ranges = {
    'today': 'Today',
    'yesterday': 'Yesterday',
    '7days': 'Last 7 Days',
    '30days': 'Last 30 Days',
    'this_month': 'This Month',
    'last_month': 'Last Month',
    'all_time': 'All Time',
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
    _ttsService.init();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/analysis/emotions?range=$_selectedRange'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _data = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        debugPrint('Failed to load analysis: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching analysis: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onRangeSelected(String range) {
    setState(() {
      _selectedRange = range;
    });
    _fetchData();
  }

  Future<void> _readSummary() async {
    if (_data == null) return;

    if (_isSpeaking) {
      await _ttsService.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    final score = (_data!['mentalHealthScore'] ?? 75).toDouble();
    String status = score >= 80 ? 'Excellent' : (score >= 60 ? 'Good' : (score >= 40 ? 'Fair' : 'Needs Attention'));
    
    final overview = _data!['overview'];
    final positive = (overview['positive'] ?? 0).toDouble();
    final negative = (overview['negative'] ?? 0).toDouble();
    final total = positive + negative;
    String emotionSummary = "";
    if (total > 0) {
      int posPct = ((positive / total) * 100).round();
      emotionSummary = "You have experienced $posPct percent positive emotions.";
    }

    String summary = "Here is your analysis for ${_ranges[_selectedRange]}. "
        "Your mental health score is ${score.toInt()}, which is considered $status. "
        "$emotionSummary";

    setState(() => _isSpeaking = true);
    await _ttsService.speak(summary);
    // We don't know exactly when it ends, but we can reset state if needed or let user stop it.
    // For better UX, we could listen to completion handler in TTSService if we exposed it, 
    // but for now manual toggle is fine.
  }

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Light grey background
      appBar: AppBar(
        title: const Text('Mental Health Analysis', style: TextStyle(color: Color(0xFF1F2937))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        actions: [
          IconButton(
            icon: Icon(_isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
            onPressed: _readSummary,
            tooltip: _isSpeaking ? 'Stop Reading' : 'Read Summary',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _ranges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final key = _ranges.keys.elementAt(index);
                final label = _ranges.values.elementAt(index);
                final isSelected = _selectedRange == key;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => _onRangeSelected(key),
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF4B5563),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                );
              },
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _data == null
                    ? const Center(child: Text('No data available'))
                    : Column(
                        children: [
                          const SizedBox(height: 20),
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (index) => setState(() => _currentPage = index),
                              children: [
                                _buildEmotionalOverviewCard(),
                                _buildTimeBasedAnalysisCard(),
                                _buildDailyMoodTimelineCard(),
                                _buildMentalHealthScoreCard(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Page Indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentPage == index
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey.shade300,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildEmotionalOverviewCard() {
    final overview = _data!['overview'];
    final positive = (overview['positive'] ?? 0).toDouble();
    final negative = (overview['negative'] ?? 0).toDouble();
    final total = positive + negative;

    if (total == 0) {
      return _buildCard(
        title: 'Emotional Overview',
        child: const Center(child: Text('No emotional data recorded yet.')),
      );
    }

    return _buildCard(
      title: 'Emotional Overview',
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: const Color(0xFF34D399), // Green
                    value: positive,
                    title: '${((positive / total) * 100).toStringAsFixed(0)}%',
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: const Color(0xFFEF4444), // Red
                    value: negative,
                    title: '${((negative / total) * 100).toStringAsFixed(0)}%',
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Positive', const Color(0xFF34D399), positive.toInt()),
              _buildLegendItem('Negative', const Color(0xFFEF4444), negative.toInt()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('$label ($count)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTimeBasedAnalysisCard() {
    final trend = _data!['trend'];
    final morning = (trend['morning'] ?? 0).toDouble();
    final afternoon = (trend['afternoon'] ?? 0).toDouble();
    final evening = (trend['evening'] ?? 0).toDouble();
    final night = (trend['night'] ?? 0).toDouble();

    return _buildCard(
      title: 'Time-Based Analysis',
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  rod.toY.round().toString(),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const titles = ['Morning', 'Afternoon', 'Evening', 'Night'];
                  if (value.toInt() >= 0 && value.toInt() < titles.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(titles[value.toInt()], style: const TextStyle(fontSize: 12)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            _buildBarGroup(0, morning, const Color(0xFFFDBA74)), // Orange
            _buildBarGroup(1, afternoon, const Color(0xFF60A5FA)), // Blue
            _buildBarGroup(2, evening, const Color(0xFF818CF8)), // Indigo
            _buildBarGroup(3, night, const Color(0xFF4B5563)), // Grey
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 20,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 100,
            color: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyMoodTimelineCard() {
    final List<dynamic> timeline = _data!['dailyTimeline'] ?? [];
    
    if (timeline.isEmpty) {
      return _buildCard(
        title: 'Daily Mood Timeline',
        child: const Center(child: Text('No timeline data available.')),
      );
    }

    return _buildCard(
      title: 'Daily Mood Timeline',
      child: ListView.separated(
        itemCount: timeline.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final item = timeline[index];
          final date = item['date'];
          final score = (item['score'] as num).toDouble();
          final icon = item['icon'];

          return ListTile(
            leading: Text(icon, style: const TextStyle(fontSize: 24)),
            title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  score > 60 ? const Color(0xFF34D399) : (score > 40 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444)),
                ),
                minHeight: 8,
              ),
            ),
            trailing: Text('${score.toInt()}/100', style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }

  Widget _buildMentalHealthScoreCard() {
    final score = (_data!['mentalHealthScore'] ?? 75).toDouble();
    Color color = score >= 80 ? const Color(0xFF34D399) : (score >= 60 ? const Color(0xFF60A5FA) : (score >= 40 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444)));
    String status = score >= 80 ? 'Excellent' : (score >= 60 ? 'Good' : (score >= 40 ? 'Fair' : 'Needs Attention'));

    return _buildCard(
      title: 'Mental Health Score',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 15,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          score.toInt().toString(),
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color),
                        ),
                        const Text('out of 100', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              status,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 10),
            const Text(
              'Based on your recent interactions and emotional patterns.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
