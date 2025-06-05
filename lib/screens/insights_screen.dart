import 'package:flutter/material.dart';
import 'package:mindlog/services/database_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final DatabaseService _dbService = DatabaseService.instance;

  List<JournalEntry> _allEntries = [];
  List<Habit> _activeHabits = [];
  Map<String, Map<String, dynamic>> _analyticsResults = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataAndAnalyze();
  }

  Future<void> _loadDataAndAnalyze() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    _allEntries = await _dbService.getAllEntries();
    _activeHabits = await _dbService.getAllActiveHabits();
    _analyticsResults = {};

    if (_allEntries.isEmpty || _activeHabits.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    for (var habit in _activeHabits) {
      if (habit.id == null) continue;

      List<int> moodsWithHabit = [];
      List<int> moodsWithoutHabit = [];

      for (var entry in _allEntries) {
        bool habitWasDoneInThisEntry =
            entry.completedHabits[habit.id!] ?? false;

        if (habitWasDoneInThisEntry) {
          moodsWithHabit.add(entry.mood);
        } else {
          moodsWithoutHabit.add(entry.mood);
        }
      }

      double avgMoodWith = moodsWithHabit.isNotEmpty
          ? moodsWithHabit.reduce((a, b) => a + b) / moodsWithHabit.length
          : 0.0;
      double avgMoodWithout = moodsWithoutHabit.isNotEmpty
          ? moodsWithoutHabit.reduce((a, b) => a + b) / moodsWithoutHabit.length
          : 0.0;

      _analyticsResults[habit.name] = {
        'withHabitAvgMood': avgMoodWith,
        'withoutHabitAvgMood': avgMoodWithout,
        'withHabitCount': moodsWithHabit.length,
        'withoutHabitCount': moodsWithoutHabit.length,
      };
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatMood(double mood) {
    if (mood == 0.0) return "N/A";
    return mood.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Инсайты по настроению'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить анализ',
            onPressed: _loadDataAndAnalyze,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analyticsResults.isEmpty || _activeHabits.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _allEntries.isEmpty
                      ? 'Нет записей для анализа. Добавьте несколько записей в журнал.'
                      : 'Нет активных привычек для анализа. Добавьте их в Управлении привычками.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: _analyticsResults.entries.map((resultEntry) {
                String habitName = resultEntry.key;
                Map<String, dynamic> data = resultEntry.value;

                double moodWith = data['withHabitAvgMood']!;
                double moodWithout = data['withoutHabitAvgMood']!;
                int countWith = data['withHabitCount']!;
                int countWithout = data['withoutHabitCount']!;

                String insightText;
                if (countWith == 0 && countWithout == 0) {
                  insightText =
                      "Нет записей, где эта привычка была бы отмечена.";
                } else if (countWith == 0) {
                  insightText =
                      "Привычка '${habitName.toLowerCase()}' ни разу не выполнялась. Среднее настроение в дни без нее: ${_formatMood(moodWithout)} (по $countWithout дням).";
                } else if (countWithout == 0) {
                  insightText =
                      "Привычка '${habitName.toLowerCase()}' выполнялась всегда! Среднее настроение: ${_formatMood(moodWith)} (по $countWith дням).";
                } else if (moodWith > moodWithout) {
                  insightText =
                      "Когда вы '${habitName.toLowerCase()}', ваше среднее настроение выше (${_formatMood(moodWith)} по $countWith дн.) по сравнению с днями без (${_formatMood(moodWithout)} по $countWithout дн.). Отлично!";
                } else if (moodWithout > moodWith) {
                  insightText =
                      "Интересно, когда вы не '${habitName.toLowerCase()}', ваше среднее настроение выше (${_formatMood(moodWithout)} по $countWithout дн.) по сравнению с днями, когда привычка выполнена (${_formatMood(moodWith)} по $countWith дн.).";
                } else {
                  insightText =
                      "Выполнение привычки '${habitName.toLowerCase()}' пока не показывает явной разницы в настроении. С привычкой: ${_formatMood(moodWith)} (по $countWith дн.), без: ${_formatMood(moodWithout)} (по $countWithout дн.).";
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habitName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColorDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          insightText,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        if (countWith > 0 || countWithout > 0) ...[
                          Divider(
                            height: 20,
                            thickness: 0.5,
                            color: Colors.grey.shade400,
                          ),
                          Text(
                            "• С привычкой: ${_formatMood(moodWith)} (записей: $countWith)",
                            style: TextStyle(
                              color: moodWith > moodWithout && countWithout > 0
                                  ? Colors.green.shade700
                                  : Colors.black87,
                              fontWeight:
                                  moodWith > moodWithout && countWithout > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            "• Без привычки: ${_formatMood(moodWithout)} (записей: $countWithout)",
                            style: TextStyle(
                              color: moodWithout > moodWith && countWith > 0
                                  ? Colors.green.shade700
                                  : Colors.black87,
                              fontWeight:
                                  moodWithout > moodWith && countWith > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
