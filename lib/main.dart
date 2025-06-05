import 'package:flutter/material.dart';
import 'package:mindlog/screens/add_entry_screen.dart';
import 'package:mindlog/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:mindlog/screens/insights_screen.dart';
import 'package:mindlog/screens/manage_habits_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindLog',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          elevation: 6.0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<JournalEntry>> _entriesFuture;
  Map<int, String> _allHabitNamesMap = {};
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() {
        _isLoadingData = true;
      });
    }
    final habits = await DatabaseService.instance.getAllHabits();
    if (mounted) {
      setState(() {
        _allHabitNamesMap = {for (var habit in habits) habit.id!: habit.name};
        _entriesFuture = DatabaseService.instance.getAllEntries();
        _isLoadingData = false;
      });
    }
  }

  void _reloadEntries() {
    if (mounted) {
      setState(() {
        _entriesFuture = DatabaseService.instance.getAllEntries();
      });
    }
  }

  String _formatHabits(JournalEntry entry) {
    if (entry.completedHabits.isEmpty) {
      return "Нет отмеченных привычек";
    }

    List<String> doneHabitNames = [];
    entry.completedHabits.forEach((habitId, isDone) {
      if (isDone) {
        String habitName = _allHabitNamesMap[habitId] ?? 'Привычка #$habitId';
        doneHabitNames.add(habitName);
      }
    });

    return doneHabitNames.isNotEmpty
        ? doneHabitNames.join(', ')
        : "Нет отмеченных привычек";
  }

  String _getMoodEmoji(int mood) {
    switch (mood) {
      case 1:
        return '😞';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '😊';
      case 5:
        return '😄';
      default:
        return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindLog - Мои Записи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Инсайты',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InsightsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'Управление привычками',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageHabitsScreen(),
                ),
              );
              if (mounted) {
                _loadInitialData();
              }
            },
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Загрузка данных...',
              ),
            )
          : FutureBuilder<List<JournalEntry>>(
              future: _entriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Ошибка загрузки данных: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final List<JournalEntry>? entries = snapshot.data;

                if (entries == null || entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'Пока нет ни одной записи.\nНажмите "+", чтобы добавить первую!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Dismissible(
                      key: Key(
                        entry.id.toString() + entry.timestamp.toString(),
                      ),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.redAccent.shade100,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "УДАЛИТЬ",
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.delete_sweep_outlined,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        final bool? res = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return AlertDialog(
                              title: const Text("Подтвердить удаление"),
                              content: const Text(
                                "Вы уверены, что хотите удалить эту запись?",
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text("ОТМЕНА"),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text("УДАЛИТЬ"),
                                ),
                              ],
                            );
                          },
                        );
                        return res ?? false;
                      },
                      onDismissed: (direction) async {
                        if (entry.id != null) {
                          await DatabaseService.instance.deleteEntry(entry.id!);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Запись от "${DateFormat('dd.MM.yyyy HH:mm').format(entry.timestamp)}" удалена',
                                ),
                                backgroundColor: Colors.orangeAccent,
                              ),
                            );
                            _reloadEntries();
                          }
                        }
                      },
                      child: Card(
                        elevation: 2.0,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 5.0,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 16.0,
                          ),
                          leading: Text(
                            _getMoodEmoji(entry.mood),
                            style: const TextStyle(fontSize: 32),
                          ),
                          title: Text(
                            DateFormat(
                              'dd.MM.yyyy HH:mm',
                            ).format(entry.timestamp),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColorDark,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (entry.notes.isNotEmpty) ...[
                                  Text(
                                    'Заметка: ${entry.notes}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Text(
                                  'Привычки: ${_formatHabits(entry)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          isThreeLine: entry.notes.isNotEmpty,
                          onTap: () {},
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool? saveSuccess = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const AddEntryScreen()),
          );
          if (saveSuccess == true && mounted) {
            _reloadEntries();
          }
        },
        tooltip: 'Добавить запись',
        child: const Icon(Icons.add),
      ),
    );
  }
}
