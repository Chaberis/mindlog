import 'package:flutter/material.dart';
import 'package:mindlog/services/database_service.dart';

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final DatabaseService _dbService = DatabaseService.instance;
  int? _selectedMood;
  final TextEditingController _notesController = TextEditingController();

  List<Habit> _activeHabits = [];
  Map<int, bool> _selectedHabitsState = {};
  bool _isLoadingHabits = true;

  @override
  void initState() {
    super.initState();
    _loadActiveHabits();
  }

  Future<void> _loadActiveHabits() async {
    if (mounted) {
      setState(() {
        _isLoadingHabits = true;
      });
    }
    _activeHabits = await _dbService.getAllActiveHabits();
    if (mounted) {
      setState(() {
        _selectedHabitsState = {
          for (var habit in _activeHabits) habit.id!: false,
        };
        _isLoadingHabits = false;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _saveEntry() async {
    if (_selectedMood == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите ваше настроение.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    Map<int, bool> completedHabitsForEntry = {};
    for (var habit in _activeHabits) {
      if (habit.id != null) {
        completedHabitsForEntry[habit.id!] =
            _selectedHabitsState[habit.id!] ?? false;
      }
    }

    final newEntry = JournalEntry(
      mood: _selectedMood!,
      notes: _notesController.text.trim(),
      timestamp: DateTime.now(),
      completedHabits: completedHabitsForEntry,
    );

    try {
      await _dbService.insertEntry(newEntry);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Запись успешно сохранена!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить запись')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Как ваше настроение?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (index) {
                int moodValue = index + 1;
                String moodEmoji;
                switch (moodValue) {
                  case 1:
                    moodEmoji = '😞';
                    break;
                  case 2:
                    moodEmoji = '😕';
                    break;
                  case 3:
                    moodEmoji = '😐';
                    break;
                  case 4:
                    moodEmoji = '😊';
                    break;
                  case 5:
                    moodEmoji = '😄';
                    break;
                  default:
                    moodEmoji = '';
                }
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = moodValue;
                    });
                  },
                  child: Opacity(
                    opacity: _selectedMood == moodValue ? 1.0 : 0.5,
                    child: Column(
                      children: [
                        Text(moodEmoji, style: const TextStyle(fontSize: 30)),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            const Text(
              'Заметка (необязательно):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Что сегодня произошло?',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            const Text(
              'Отметьте выполненные привычки:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _isLoadingHabits
                ? const Center(child: CircularProgressIndicator())
                : _activeHabits.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'Нет активных привычек. Добавьте их в Управлении привычками.',
                      ),
                    ),
                  )
                : Column(
                    children: _activeHabits.map((habit) {
                      if (habit.id == null) return const SizedBox.shrink();

                      return CheckboxListTile(
                        title: Text(habit.name),
                        value: _selectedHabitsState[habit.id!],
                        onChanged: (bool? newValue) {
                          if (mounted) {
                            setState(() {
                              _selectedHabitsState[habit.id!] = newValue!;
                            });
                          }
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
