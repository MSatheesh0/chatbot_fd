import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder(
      valueListenable: SettingsService().locale,
      builder: (context, locale, _) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF3E5F5),
          appBar: AppBar(
            title: Text(
              l10n.translate('analysis_dashboard'),
              style: TextStyle(color: isDark ? Colors.white : Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: isDark ? Colors.black : const Color(0xFF9C27B0),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Column(
            children: [
              _buildModeSelector(l10n, isDark),
              const SizedBox(height: 10),
              _buildRangeSelector(l10n, isDark),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: isDark ? Colors.blue[300] : const Color(0xFF9C27B0)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildOverviewCard(l10n, isDark),
                            const SizedBox(height: 20),
                            _buildTrendCard(l10n, isDark),
                            const SizedBox(height: 20),
                            _buildDailyTimelineCard(l10n, isDark),
                            const SizedBox(height: 20),
                            _buildScoreCard(l10n, isDark),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeSelector(AppLocalizations l10n, bool isDark) {
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
                color: isSelected ? (isDark ? Colors.blue[700] : const Color(0xFF9C27B0)) : (isDark ? Colors.grey[900] : Colors.white),
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
                l10n.translate(entry.key),
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF2D3436)),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRangeSelector(AppLocalizations l10n, bool isDark) {
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
                color: isSelected ? (isDark ? Colors.blue[900]!.withOpacity(0.3) : const Color(0xFFF0E6FF)) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? (isDark ? Colors.blue[700]! : const Color(0xFF9C27B0)) : (isDark ? Colors.grey[800]! : Colors.grey.shade300),
                ),
              ),
              child: Text(
                l10n.translate(entry.key),
                style: TextStyle(
                  color: isSelected ? (isDark ? Colors.blue[300] : const Color(0xFF9C27B0)) : Colors.grey,
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

  Widget _buildOverviewCard(AppLocalizations l10n, bool isDark) {
    final positive = _data['overview']['positive'] ?? 0;
    final negative = _data['overview']['negative'] ?? 0;
    final total = positive + negative;
    final isMostlyPositive = positive >= negative;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.translate(_selectedMode)} ${l10n.translate('insights')}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D3436)),
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
              _legendItem(const Color(0xFFA3D9A5), l10n.translate('positive')),
              const SizedBox(width: 15),
              _legendItem(const Color(0xFFFFB74D), l10n.translate('negative')),
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
                        final style = TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12);
                        switch (value.toInt()) {
                          case 0: return Text(l10n.translate('positive').substring(0, 3), style: style);
                          case 1: return Text(l10n.translate('negative').substring(0, 3), style: style);
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
              color: isDark ? Colors.amber[900]!.withOpacity(0.2) : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isMostlyPositive 
                  ? l10n.translate('mostly_positive_msg') 
                  : l10n.translate('mostly_negative_msg'),
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.amber[100] : const Color(0xFF5D4037), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(AppLocalizations l10n, bool isDark) {
    final trend = _data['trend'];
    final spots = [
      FlSpot(0, (trend['morning'] ?? 50).toDouble()),
      FlSpot(1, (trend['afternoon'] ?? 50).toDouble()),
      FlSpot(2, (trend['evening'] ?? 50).toDouble()),
      FlSpot(3, (trend['night'] ?? 50).toDouble()),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('emotion_trend'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D3436)),
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
                        final style = TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12);
                        switch (value.toInt()) {
                          case 0: return Text(l10n.translate('morning'), style: style);
                          case 1: return Text(l10n.translate('afternoon'), style: style);
                          case 2: return Text(l10n.translate('evening'), style: style);
                          case 3: return Text(l10n.translate('night'), style: style);
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
                    color: isDark ? Colors.blue[300] : const Color(0xFF9C27B0),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (isDark ? Colors.blue[300] : const Color(0xFF9C27B0))!.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('😊 ${l10n.translate('happy')}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
              Text('😔 ${l10n.translate('sad')}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
              Text('😡 ${l10n.translate('angry')}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
              Text('😌 ${l10n.translate('calm')}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTimelineCard(AppLocalizations l10n, bool isDark) {
    final List daily = _data['dailyTimeline'] ?? [];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('daily_mood_timeline'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D3436)),
          ),
          const SizedBox(height: 20),
          daily.isEmpty 
            ? Center(child: Text(l10n.translate('no_data'), style: const TextStyle(color: Colors.grey)))
            : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: daily.map((day) {
                final date = DateTime.parse(day['date']);
                final dayName = DateFormat('E', SettingsService().locale.value.languageCode).format(date); // Mon, Tue
                final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == day['date'];

                return Container(
                  margin: const EdgeInsets.only(right: 15),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isToday ? (isDark ? Colors.blue[900]!.withOpacity(0.4) : const Color(0xFFE8D5FF)) : Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: isToday ? Border.all(color: isDark ? Colors.blue[300]! : const Color(0xFF8B5CF6), width: 2) : null,
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
                          color: isToday ? (isDark ? Colors.blue[300] : const Color(0xFF8B5CF6)) : Colors.grey,
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

  Widget _buildScoreCard(AppLocalizations l10n, bool isDark) {
    final score = _data['mentalHealthScore'] ?? 75;
    Color scoreColor = Colors.green;
    String status = l10n.translate('good');
    
    if (score >= 80) {
      scoreColor = Colors.green;
      status = l10n.translate('excellent');
    } else if (score >= 60) {
      scoreColor = Colors.lightGreen;
      status = l10n.translate('good');
    } else if (score >= 40) {
      scoreColor = Colors.orange;
      status = l10n.translate('moderate');
    } else {
      scoreColor = Colors.red;
      status = l10n.translate('needs_attention');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.translate(_selectedMode)} ${l10n.translate('score')}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D3436)),
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
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey.withOpacity(0.2),
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
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
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
                    _bulletPoint(l10n.translate('score_basis'), isDark ? Colors.white54 : Colors.grey, isDark),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text, Color color, bool isDark) {
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
        Expanded(child: Text(text, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54))),
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

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? Colors.grey[900] : Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
