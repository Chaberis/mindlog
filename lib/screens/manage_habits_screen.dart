import 'package:flutter/material.dart';
import 'package:mindlog/services/database_service.dart';

class ManageHabitsScreen extends StatefulWidget {
  const ManageHabitsScreen({super.key});

  @override
  State<ManageHabitsScreen> createState() => _ManageHabitsScreenState();
}

class _ManageHabitsScreenState extends State<ManageHabitsScreen> {
  final DatabaseService _dbService = DatabaseService.instance;
  List<Habit> _allHabits = [];
  bool _isLoading = true;
  final TextEditingController _newHabitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllHabits();
  }

  Future<void> _loadAllHabits() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    _allHabits = await _dbService.getAllHabits();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addHabit() async {
    final String habitName = _newHabitController.text.trim();
    if (habitName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Название привычки не может быть пустым.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final newHabit = Habit(name: habitName);
    final resultId = await _dbService.insertHabit(newHabit);

    if (mounted) {
      if (resultId != -1) {
        _newHabitController.clear();
        _loadAllHabits();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Привычка "$habitName" добавлена.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Привычка с названием "$habitName" уже существует.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleHabitActiveState(Habit habit) async {
    if (habit.id == null) return;
    await _dbService.updateHabitActiveState(habit.id!, !habit.isActive);

    if (mounted) {
      _loadAllHabits();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Привычка "${habit.name}" ${!habit.isActive ? "активирована" : "деактивирована"}.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _newHabitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Управление привычками')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newHabitController,
                          decoration: const InputDecoration(
                            labelText: 'Новая привычка',
                            hintText: 'Например, Чтение книги',
                          ),
                          onSubmitted: (_) => _addHabit(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.green,
                          size: 30,
                        ),
                        onPressed: _addHabit,
                        tooltip: 'Добавить привычку',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _allHabits.isEmpty
                      ? const Center(
                          child: Text(
                            'У вас пока нет пользовательских привычек.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: _allHabits.length,
                          itemBuilder: (context, index) {
                            final habit = _allHabits[index];
                            return ListTile(
                              title: Text(
                                habit.name,
                                style: TextStyle(
                                  decoration: !habit.isActive
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: !habit.isActive ? Colors.grey : null,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  habit.isActive
                                      ? Icons.delete_outline
                                      : Icons.refresh_outlined,
                                  color: habit.isActive
                                      ? Colors.redAccent
                                      : Colors.green,
                                ),
                                tooltip: habit.isActive
                                    ? 'Деактивировать'
                                    : 'Активировать',
                                onPressed: () => _toggleHabitActiveState(habit),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
