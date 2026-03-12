import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/sermon.dart';
import '../../domain/entities/event.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;
  static const String _dbName = 'tcgc_cache.db';
  static const int _dbVersion = 2;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Sermons table
    await db.execute('''
      CREATE TABLE sermons (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        speaker TEXT,
        image_url TEXT,
        audio_url TEXT,
        video_url TEXT,
        transcript TEXT,
        category TEXT,
        category_name TEXT,
        date TEXT,
        duration_minutes INTEGER,
        is_recommended INTEGER DEFAULT 0,
        cached_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // Events table
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        image_url TEXT,
        schedule TEXT,
        icon_color TEXT,
        is_live INTEGER DEFAULT 0,
        is_teens_event INTEGER DEFAULT 0,
        youtube_url TEXT,
        location TEXT,
        cached_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // Audio cache metadata table
    await db.execute('''
      CREATE TABLE audio_cache (
        sermon_id TEXT PRIMARY KEY,
        audio_url TEXT NOT NULL,
        file_path TEXT NOT NULL,
        total_bytes INTEGER,
        cached_bytes INTEGER DEFAULT 0,
        duration_seconds INTEGER,
        cached_duration_seconds INTEGER DEFAULT 0,
        is_complete INTEGER DEFAULT 0,
        cached_at INTEGER NOT NULL,
        last_accessed INTEGER
      )
    ''');

    // Sync metadata table
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        last_sync INTEGER,
        etag TEXT,
        data_hash TEXT
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        image_url TEXT,
        is_active INTEGER DEFAULT 1,
        latest_message_date TEXT,
        has_new_message INTEGER DEFAULT 0,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for faster queries
    await db.execute('CREATE INDEX idx_sermons_date ON sermons(date DESC)');
    await db.execute('CREATE INDEX idx_sermons_category ON sermons(category)');
    await db.execute('CREATE INDEX idx_sermons_recommended ON sermons(is_recommended)');
    await db.execute('CREATE INDEX idx_events_cached ON events(cached_at DESC)');
    await db.execute('CREATE INDEX idx_categories_active ON categories(is_active)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          image_url TEXT,
          is_active INTEGER DEFAULT 1,
          latest_message_date TEXT,
          has_new_message INTEGER DEFAULT 0,
          cached_at INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_categories_active ON categories(is_active)');
    }
  }

  // Sermon methods
  Future<void> cacheSermons(List<Sermon> sermons) async {
    final db = await database;
    final batch = db.batch();
    final cachedAt = DateTime.now().millisecondsSinceEpoch;

    for (final sermon in sermons) {
      batch.insert(
        'sermons',
        {
          'id': sermon.id,
          'title': sermon.title,
          'description': sermon.description,
          'speaker': sermon.speaker,
          'image_url': sermon.imageUrl,
          'audio_url': sermon.audioUrl,
          'video_url': sermon.videoUrl,
          'transcript': sermon.transcript,
          'category': sermon.category,
          'category_name': sermon.categoryName,
          'date': sermon.date.toIso8601String(),
          'duration_minutes': sermon.duration.inMinutes,
          'is_recommended': sermon.isRecommended ? 1 : 0,
          'cached_at': cachedAt,
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('Cached ${sermons.length} sermons to local database');
  }

  Future<List<Sermon>> getCachedSermons({int? limit}) async {
    final db = await database;
    final results = await db.query(
      'sermons',
      orderBy: 'date DESC',
      limit: limit,
    );

    return results.map((row) => _sermonFromRow(row)).toList();
  }

  Future<List<Sermon>> getCachedRecommendedSermons() async {
    final db = await database;
    final results = await db.query(
      'sermons',
      where: 'is_recommended = ?',
      whereArgs: [1],
      orderBy: 'date DESC',
    );

    return results.map((row) => _sermonFromRow(row)).toList();
  }

  Future<Sermon?> getCachedSermonById(String id) async {
    final db = await database;
    final results = await db.query(
      'sermons',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _sermonFromRow(results.first);
  }

  Future<Set<String>> getCachedSermonIds() async {
    final db = await database;
    final results = await db.query('sermons', columns: ['id']);
    return results.map((row) => row['id'] as String).toSet();
  }

  Sermon _sermonFromRow(Map<String, dynamic> row) {
    return Sermon(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      speaker: row['speaker'] as String?,
      imageUrl: row['image_url'] as String?,
      audioUrl: row['audio_url'] as String?,
      videoUrl: row['video_url'] as String?,
      transcript: row['transcript'] as String?,
      category: row['category'] as String? ?? '',
      categoryName: row['category_name'] as String? ?? '',
      date: DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now(),
      duration: Duration(minutes: row['duration_minutes'] as int? ?? 0),
      isRecommended: (row['is_recommended'] as int? ?? 0) == 1,
    );
  }

  // Event methods
  Future<void> cacheEvents(List<Event> events) async {
    final db = await database;
    final batch = db.batch();
    final cachedAt = DateTime.now().millisecondsSinceEpoch;

    for (final event in events) {
      batch.insert(
        'events',
        {
          'id': event.id,
          'title': event.title,
          'description': event.description,
          'image_url': event.imageUrl,
          'schedule': event.schedule,
          'icon_color': event.iconColor,
          'is_live': event.isLive ? 1 : 0,
          'is_teens_event': event.isTeensEvent ? 1 : 0,
          'youtube_url': event.youtubeUrl,
          'location': event.location,
          'cached_at': cachedAt,
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('Cached ${events.length} events to local database');
  }

  Future<List<Event>> getCachedEvents() async {
    final db = await database;
    final results = await db.query('events', orderBy: 'cached_at DESC');

    return results.map((row) => _eventFromRow(row)).toList();
  }

  Future<Set<String>> getCachedEventIds() async {
    final db = await database;
    final results = await db.query('events', columns: ['id']);
    return results.map((row) => row['id'] as String).toSet();
  }

  Event _eventFromRow(Map<String, dynamic> row) {
    return Event(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      schedule: row['schedule'] as String? ?? '',
      iconColor: row['icon_color'] as String?,
      isLive: (row['is_live'] as int? ?? 0) == 1,
      isTeensEvent: (row['is_teens_event'] as int? ?? 0) == 1,
      youtubeUrl: row['youtube_url'] as String?,
      location: row['location'] as String?,
    );
  }

  // Category methods
  Future<void> cacheCategories(List<MessageCategory> categories) async {
    final db = await database;
    final batch = db.batch();
    final cachedAt = DateTime.now().millisecondsSinceEpoch;

    for (final category in categories) {
      batch.insert(
        'categories',
        {
          'id': category.id,
          'name': category.name,
          'description': category.description,
          'image_url': category.imageUrl,
          'is_active': category.isActive ? 1 : 0,
          'latest_message_date': category.latestMessageDate?.toIso8601String(),
          'has_new_message': category.hasNewMessage ? 1 : 0,
          'is_service_team_only': category.isServiceTeamOnly ? 1 : 0,
          'cached_at': cachedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('Cached ${categories.length} categories to local database');
  }

  Future<List<MessageCategory>> getCachedCategories() async {
    final db = await database;
    final results = await db.query(
      'categories',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    return results.map((row) => _categoryFromRow(row)).toList();
  }

  MessageCategory _categoryFromRow(Map<String, dynamic> row) {
    return MessageCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      imageUrl: row['image_url'] as String?,
      isActive: (row['is_active'] as int? ?? 1) == 1,
      latestMessageDate: row['latest_message_date'] != null
          ? DateTime.tryParse(row['latest_message_date'] as String)
          : null,
      hasNewMessage: (row['has_new_message'] as int? ?? 0) == 1,
      isServiceTeamOnly: (row['is_service_team_only'] as int? ?? 0) == 1,
    );
  }

  // Audio cache metadata methods
  Future<void> saveAudioCacheMetadata({
    required String sermonId,
    required String audioUrl,
    required String filePath,
    int? totalBytes,
    int cachedBytes = 0,
    int? durationSeconds,
    int cachedDurationSeconds = 0,
    bool isComplete = false,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'audio_cache',
      {
        'sermon_id': sermonId,
        'audio_url': audioUrl,
        'file_path': filePath,
        'total_bytes': totalBytes,
        'cached_bytes': cachedBytes,
        'duration_seconds': durationSeconds,
        'cached_duration_seconds': cachedDurationSeconds,
        'is_complete': isComplete ? 1 : 0,
        'cached_at': now,
        'last_accessed': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getAudioCacheMetadata(String sermonId) async {
    final db = await database;
    final results = await db.query(
      'audio_cache',
      where: 'sermon_id = ?',
      whereArgs: [sermonId],
      limit: 1,
    );

    if (results.isEmpty) return null;

    // Update last accessed time
    await db.update(
      'audio_cache',
      {'last_accessed': DateTime.now().millisecondsSinceEpoch},
      where: 'sermon_id = ?',
      whereArgs: [sermonId],
    );

    return results.first;
  }

  Future<List<Map<String, dynamic>>> getIncompleteAudioCaches() async {
    final db = await database;
    return await db.query(
      'audio_cache',
      where: 'is_complete = ? AND cached_bytes > 0',
      whereArgs: [0],
    );
  }

  Future<void> updateAudioCacheProgress({
    required String sermonId,
    required int cachedBytes,
    int? cachedDurationSeconds,
    bool isComplete = false,
  }) async {
    final db = await database;
    await db.update(
      'audio_cache',
      {
        'cached_bytes': cachedBytes,
        if (cachedDurationSeconds != null)
          'cached_duration_seconds': cachedDurationSeconds,
        'is_complete': isComplete ? 1 : 0,
      },
      where: 'sermon_id = ?',
      whereArgs: [sermonId],
    );
  }

  Future<void> deleteAudioCache(String sermonId) async {
    final db = await database;
    await db.delete(
      'audio_cache',
      where: 'sermon_id = ?',
      whereArgs: [sermonId],
    );
  }

  // Sync metadata methods
  Future<void> updateSyncMetadata(String key, {String? etag, String? dataHash}) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'key': key,
        'last_sync': DateTime.now().millisecondsSinceEpoch,
        'etag': etag,
        'data_hash': dataHash,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getSyncMetadata(String key) async {
    final db = await database;
    final results = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  Future<bool> needsSync(String key, {Duration maxAge = const Duration(minutes: 15)}) async {
    final metadata = await getSyncMetadata(key);
    if (metadata == null) return true;

    final lastSync = metadata['last_sync'] as int?;
    if (lastSync == null) return true;

    final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
    return DateTime.now().difference(lastSyncTime) > maxAge;
  }

  // Cleanup methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('sermons');
    await db.delete('events');
    await db.delete('audio_cache');
    await db.delete('sync_metadata');
    debugPrint('All cached data cleared');
  }

  Future<void> clearOldData({int daysOld = 30}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: daysOld))
        .millisecondsSinceEpoch;

    final deletedSermons = await db.delete(
      'sermons',
      where: 'cached_at < ?',
      whereArgs: [cutoff],
    );

    final deletedEvents = await db.delete(
      'events',
      where: 'cached_at < ?',
      whereArgs: [cutoff],
    );

    debugPrint('Cleared $deletedSermons old sermons and $deletedEvents old events');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
