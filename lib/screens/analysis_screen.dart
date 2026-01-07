import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants.dart';
import '../services/tts_service.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final TTSService _ttsService = TTSService();
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String _selectedRange = '7days';
  String _selectedModel = 'Mental Health'; // Default to Mental Health
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  bool _isSpeaking = false;
  late TabController _tabController;

  final List<String> _models = ['Mental Health', 'Chat', 'Funny', 'Study'];

  Map<String, String> _getRanges(AppLocalizations l10n) => {
    'today': l10n.translate('today'),
    'yesterday': l10n.translate('yesterday'),
    '7days': l10n.translate('last_7_days'),
    '30days': l10n.translate('last_30_days'),
    'this_month': l10n.translate('this_month'),
    'last_month': l10n.translate('last_month'),
    'all_time': l10n.translate('all_time'),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _models.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedModel = _models[_tabController.index];
        });
        _fetchData();
      }
    });
    _fetchData();
    _ttsService.init();
  }


  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/analysis/emotions?range=$_selectedRange&model=$_selectedModel'),
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
    final l10n = AppLocalizations.of(context);

    if (_isSpeaking) {
      await _ttsService.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    final score = (_data!['mentalHealthScore'] ?? 75).toDouble();
    String status = score >= 80 ? l10n.translate('excellent') : (score >= 60 ? l10n.translate('good') : (score >= 40 ? l10n.translate('fair') : l10n.translate('needs_attention')));
    
    final overview = _data!['overview'];
    final positive = (overview['positive'] ?? 0).toDouble();
    final negative = (overview['negative'] ?? 0).toDouble();
    final total = positive + negative;
    String emotionSummary = "";
    if (total > 0) {
      int posPct = ((positive / total) * 100).round();
      emotionSummary = "You have experienced $posPct percent positive emotions.";
    }

    String summary = "Here is your analysis for ${_getRanges(l10n)[_selectedRange]}. "
        "Your mental health score is ${score.toInt()}, which is considered $status. "
        "$emotionSummary";

    setState(() => _isSpeaking = true);
    await _ttsService.speak(summary);
  }

  @override
  void dispose() {
    _ttsService.stop();
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ranges = _getRanges(l10n);

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF3E5F5),
      appBar: AppBar(
        title: Text(l10n.translate('mental_health_analysis'), style: TextStyle(color: isDark ? Colors.white : Colors.white)),
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFF9C27B0),
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
            onPressed: _readSummary,
            tooltip: _isSpeaking ? 'Stop Reading' : 'Read Summary',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: isDark ? Colors.white : Colors.white,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.white70,
          tabs: _models.map((model) => Tab(text: model)).toList(),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          return Column(
            children: [
              // Filters
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: ranges.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final key = ranges.keys.elementAt(index);
                    final label = ranges.values.elementAt(index);
                    final isSelected = _selectedRange == key;
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) => _onRangeSelected(key),
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
                      side: BorderSide(color: isSelected ? Colors.transparent : (isDark ? Colors.grey[700]! : Colors.grey.shade300)),
                    );
                  },
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                    : _data == null
                        ? Center(child: Text(l10n.translate('no_data'), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)))
                        : Column(
                            children: [
                              const SizedBox(height: 20),
                              Expanded(
                                child: PageView(
                                  controller: _pageController,
                                  onPageChanged: (index) => setState(() => _currentPage = index),
                                  children: [
                                    _buildEmotionalOverviewCard(l10n),
                                    _buildTimeBasedAnalysisCard(l10n),
                                    _buildDailyMoodTimelineCard(l10n),
                                    _buildMentalHealthScoreCard(l10n),
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
                                          : (isDark ? Colors.grey[700] : Colors.grey.shade300),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildEmotionalOverviewCard(AppLocalizations l10n) {
    final overview = _data!['overview'];
    final positive = (overview['positive'] ?? 0).toDouble();
    final negative = (overview['negative'] ?? 0).toDouble();
    final total = positive + negative;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (total == 0) {
      return _buildCard(
        title: l10n.translate('emotional_overview'),
        child: Center(child: Text(l10n.translate('no_emotional_data'), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
      );
    }

    return _buildCard(
      title: l10n.translate('emotional_overview'),
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
              _buildLegendItem(l10n.translate('positive'), const Color(0xFF34D399), positive.toInt()),
              _buildLegendItem(l10n.translate('negative'), const Color(0xFFEF4444), negative.toInt()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('$label ($count)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87)),
      ],
    );
  }

  Widget _buildTimeBasedAnalysisCard(AppLocalizations l10n) {
    final trend = _data!['trend'];
    final morning = (trend['morning'] ?? 0).toDouble();
    final afternoon = (trend['afternoon'] ?? 0).toDouble();
    final evening = (trend['evening'] ?? 0).toDouble();
    final night = (trend['night'] ?? 0).toDouble();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildCard(
      title: l10n.translate('time_based_analysis'),
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
                  final titles = [
                    l10n.translate('morning'),
                    l10n.translate('afternoon'),
                    l10n.translate('evening'),
                    l10n.translate('night')
                  ];
                  if (value.toInt() >= 0 && value.toInt() < titles.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(titles[value.toInt()], style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: isDark ? Colors.grey[800] : Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyMoodTimelineCard(AppLocalizations l10n) {
    final List<dynamic> timeline = _data!['dailyTimeline'] ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (timeline.isEmpty) {
      return _buildCard(
        title: l10n.translate('daily_mood_timeline'),
        child: Center(child: Text(l10n.translate('no_timeline_data'), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
      );
    }

    return _buildCard(
      title: l10n.translate('daily_mood_timeline'),
      child: ListView.separated(
        itemCount: timeline.length,
        separatorBuilder: (_, __) => Divider(color: isDark ? Colors.grey[800] : Colors.grey.shade200),
        itemBuilder: (context, index) {
          final item = timeline[index];
          final dateStr = item['date'];
          final score = (item['score'] as num).toDouble();
          final icon = item['icon'];

          // Try to format date if it's a valid date string
          String displayDate = dateStr;
          try {
            final dt = DateTime.parse(dateStr);
            displayDate = SettingsService().formatDate(dt);
          } catch (_) {}

          return ListTile(
            leading: Text(icon, style: const TextStyle(fontSize: 24)),
            title: Text(displayDate, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            subtitle: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  score > 60 ? const Color(0xFF34D399) : (score > 40 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444)),
                ),
                minHeight: 8,
              ),
            ),
            trailing: Text('${score.toInt()}/100', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
          );
        },
      ),
    );
  }

  Widget _buildMentalHealthScoreCard(AppLocalizations l10n) {
    final score = (_data!['mentalHealthScore'] ?? 75).toDouble();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color = score >= 80 ? const Color(0xFF34D399) : (score >= 60 ? const Color(0xFF60A5FA) : (score >= 40 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444)));
    String status = score >= 80 ? l10n.translate('excellent') : (score >= 60 ? l10n.translate('good') : (score >= 40 ? l10n.translate('fair') : l10n.translate('needs_attention')));

    return _buildCard(
      title: l10n.translate('mental_health_score'),
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
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey.shade200,
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
                        Text(l10n.translate('out_of_100'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
            Text(
              l10n.translate('score_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
