import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Habit {
  final int? id;
  final String name;
  bool isActive;

  Habit({this.id, required this.name, this.isActive = true});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'isActive': isActive ? 1 : 0};
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as int?,
      name: map['name'] as String,
      isActive: map['isActive'] == 1,
    );
  }

  @override
  String toString() {
    return 'Habit{id: $id, name: $name, isActive: $isActive}';
  }
}

class JournalEntry {
  final int? id;
  final int mood;
  final String notes;
  final DateTime timestamp;
  final Map<int, bool> completedHabits;

  JournalEntry({
    this.id,
    required this.mood,
    required this.notes,
    required this.timestamp,
    required this.completedHabits,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mood': mood,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
      'completed_habits_json': jsonEncode(
        completedHabits.map((key, value) => MapEntry(key.toString(), value)),
      ),
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> decodedHabitsJson = jsonDecode(
      map['completed_habits_json'] as String,
    );
    Map<int, bool> completedHabitsMap = decodedHabitsJson.map(
      (key, value) => MapEntry(int.parse(key), value as bool),
    );

    return JournalEntry(
      id: map['id'] as int?,
      mood: map['mood'] as int,
      notes: map['notes'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      completedHabits: completedHabitsMap,
    );
  }

  @override
  String toString() {
    return 'JournalEntry{id: $id, mood: $mood, notes: $notes, timestamp: $timestamp, completedHabits: $completedHabits}';
  }
}

class DatabaseService {
  static const String _databaseName = "mindlog_v2.db";
  static const int _databaseVersion = 3;

  static const String columnId = 'id';
  static const String columnMood = 'mood';
  static const String columnNotes = 'notes';
  static const String columnTimestamp = 'timestamp';
  static const String columnCompletedHabitsJson = 'completed_habits_json';

  static const String tableHabits = 'habits';
  static const String columnHabitId = 'id';
  static const String columnHabitName = 'name';
  static const String columnHabitIsActive = 'isActive';

  static const String tableEntries = 'journal_entries';

  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableHabits (
        $columnHabitId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnHabitName TEXT NOT NULL UNIQUE,
        $columnHabitIsActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableEntries (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnMood INTEGER NOT NULL,
        $columnNotes TEXT NOT NULL,
        $columnTimestamp TEXT NOT NULL,
        $columnCompletedHabitsJson TEXT NOT NULL
      )
    ''');
    await _insertDefaultHabits(db);
  }

  Future<void> _insertDefaultHabits(Database db) async {
    List<String> defaultHabitNames = [
      'ходил в вуз',
      'трогал траву',
      'говорил с людьми',
    ];
    for (String name in defaultHabitNames) {
      try {
        await db.rawInsert(
          'INSERT INTO $tableHabits ($columnHabitName, $columnHabitIsActive) VALUES (?, ?)',
          [name, 1],
        );
      } catch (e) {
        // print("Error inserting default habit $name: $e");
      }
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      await db.execute("DROP TABLE IF EXISTS $tableEntries");
      await db.execute("DROP TABLE IF EXISTS $tableHabits");
      await _onCreate(db, newVersion);
    }
  }

  Future<int> insertEntry(JournalEntry entry) async {
    Database db = await instance.database;
    Map<String, dynamic> row = entry.toMap();
    if (row[columnId] == null) {
      row.remove(columnId);
    }
    return await db.insert(tableEntries, row);
  }

  Future<List<JournalEntry>> getAllEntries() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableEntries,
      orderBy: "$columnTimestamp DESC",
    );
    if (maps.isEmpty) return [];
    return List.generate(maps.length, (i) => JournalEntry.fromMap(maps[i]));
  }

  Future<int> deleteEntry(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableEntries,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertHabit(Habit habit) async {
    Database db = await instance.database;
    Map<String, dynamic> row = habit.toMap();
    if (row[columnHabitId] == null) {
      row.remove(columnHabitId);
    }
    try {
      return await db.insert(tableHabits, row);
    } catch (e) {
      if (e.toString().toLowerCase().contains('unique constraint failed')) {
        return -1;
      }
      rethrow;
    }
  }

  Future<List<Habit>> getAllActiveHabits() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableHabits,
      where: '$columnHabitIsActive = ?',
      whereArgs: [1],
      orderBy: '$columnHabitName ASC',
    );
    return List.generate(maps.length, (i) => Habit.fromMap(maps[i]));
  }

  Future<List<Habit>> getAllHabits() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableHabits,
      orderBy: '$columnHabitName ASC',
    );
    return List.generate(maps.length, (i) => Habit.fromMap(maps[i]));
  }

  Future<int> updateHabitActiveState(int id, bool isActive) async {
    Database db = await instance.database;
    return await db.update(
      tableHabits,
      {columnHabitIsActive: isActive ? 1 : 0},
      where: '$columnHabitId = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateHabitName(int id, String newName) async {
    Database db = await instance.database;
    try {
      return await db.update(
        tableHabits,
        {columnHabitName: newName},
        where: '$columnHabitId = ?',
        whereArgs: [id],
      );
    } catch (e) {
      if (e.toString().toLowerCase().contains('unique constraint failed')) {
        return -1;
      }
      rethrow;
    }
  }
}
