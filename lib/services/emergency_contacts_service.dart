import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class EmergencyContact {
  const EmergencyContact({
    this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.isPrimary,
  });

  final int? id;
  final String userId;
  final String name;
  final String phoneNumber;
  final bool isPrimary;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone_number': phoneNumber,
      'is_primary': isPrimary ? 1 : 0,
    };
  }

  EmergencyContact copyWith({
    int? id,
    String? userId,
    String? name,
    String? phoneNumber,
    bool? isPrimary,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  factory EmergencyContact.fromMap(Map<String, Object?> map) {
    return EmergencyContact(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      phoneNumber: map['phone_number'] as String,
      isPrimary: (map['is_primary'] as int? ?? 0) == 1,
    );
  }
}

class EmergencyContactsService {
  EmergencyContactsService._();
  static final EmergencyContactsService _instance =
      EmergencyContactsService._();
  factory EmergencyContactsService() => _instance;

  static const _dbName = 'protego_contacts.db';
  static const _table = 'emergency_contacts';
  static const _skipKeyPrefix = 'emergency_contacts_setup_skipped_';
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(dbPath, _dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            phone_number TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _database!;
  }

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User must be signed in to manage emergency contacts.');
    }
    return user.uid;
  }

  Future<List<EmergencyContact>> getContacts() async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
      orderBy: 'is_primary DESC, id ASC',
    );
    return rows.map(EmergencyContact.fromMap).toList();
  }

  Future<bool> hasContacts() async {
    final contacts = await getContacts();
    return contacts.isNotEmpty;
  }

  Future<void> saveContact(EmergencyContact contact) async {
    final db = await database;
    final userId = _currentUserId;

    await db.transaction((txn) async {
      if (contact.isPrimary) {
        await txn.update(
          _table,
          {'is_primary': 0},
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }

      final existingContacts = await txn.query(
        _table,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final shouldBePrimary = contact.isPrimary || existingContacts.isEmpty;
      final data = contact
          .copyWith(
            userId: userId,
            isPrimary: shouldBePrimary,
          )
          .toMap()
        ..remove('id');

      if (contact.id == null) {
        await txn.insert(_table, data);
      } else {
        await txn.update(
          _table,
          data,
          where: 'id = ? AND user_id = ?',
          whereArgs: [contact.id, userId],
        );
      }
    });

    await markOnboardingSkipped(false);
  }

  Future<void> deleteContact(int id) async {
    final db = await database;
    final userId = _currentUserId;
    await db.transaction((txn) async {
      await txn.delete(
        _table,
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );

      final remaining = await txn.query(
        _table,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'id ASC',
        limit: 1,
      );
      if (remaining.isNotEmpty) {
        final firstId = remaining.first['id'] as int;
        final isPrimary = (remaining.first['is_primary'] as int? ?? 0) == 1;
        if (!isPrimary) {
          await txn.update(
            _table,
            {'is_primary': 1},
            where: 'id = ?',
            whereArgs: [firstId],
          );
        }
      }
    });
  }

  Future<bool> shouldShowOnboarding() async {
    if (await hasContacts()) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('$_skipKeyPrefix$_currentUserId') ?? false);
  }

  Future<void> markOnboardingSkipped(bool skipped) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_skipKeyPrefix$_currentUserId', skipped);
  }
}
