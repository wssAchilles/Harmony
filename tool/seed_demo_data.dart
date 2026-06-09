import 'dart:io';

import 'package:pocketbase/pocketbase.dart';

const _defaultUrl = 'http://127.0.0.1:8090';
const _defaultEmail = 'admin@example.com';
const _defaultPassword = 'admin123456';

Future<void> main(List<String> args) async {
  final apply = args.contains('--apply');
  final dryRun = args.contains('--dry-run') || !apply;
  final unknownArgs =
      args.where((arg) => arg != '--apply' && arg != '--dry-run').toList();
  if (unknownArgs.isNotEmpty) {
    stderr.writeln('Unknown arguments: ${unknownArgs.join(', ')}');
    stderr.writeln(
        'Usage: dart run tool/seed_demo_data.dart [--dry-run|--apply]');
    exitCode = 64;
    return;
  }

  final url = Platform.environment['POCKETBASE_URL'] ?? _defaultUrl;
  final email = Platform.environment['PB_ADMIN_EMAIL'] ?? _defaultEmail;
  final password =
      Platform.environment['PB_ADMIN_PASSWORD'] ?? _defaultPassword;

  final pb = PocketBase(url);
  await pb.collection('_superusers').authWithPassword(email, password);

  final seeder = DemoDataSeeder(pb: pb, dryRun: dryRun);
  await seeder.run();
}

class DemoDataSeeder {
  DemoDataSeeder({required PocketBase pb, required bool dryRun})
      : _pb = pb,
        _dryRun = dryRun;

  final PocketBase _pb;
  final bool _dryRun;
  int _plannedWrites = 0;

  Future<void> run() async {
    stdout.writeln(
      _dryRun
          ? 'Demo data seed dry-run. No data will be written.'
          : 'Applying demo data seed.',
    );

    await _assertCollections();
    final handlerId = await _handlerProfileId();
    final categoryIds = await _ensureCategories();
    final studentIds = await _ensureStudents();
    final bookIds = await _ensureBooks(categoryIds);

    await _normalizeLegacyBookCategories(
      categoryId: categoryIds['教师用书']!,
    );
    await _ensureReminderSettings();
    await _ensureBorrowSamples(
      handlerId: handlerId,
      studentIds: studentIds,
      bookIds: bookIds,
    );
    await _syncSeededBookInventory(bookIds.values.toSet());
    await _syncBookStatuses();

    stdout.writeln(
      _dryRun
          ? 'Dry-run complete. Planned writes: $_plannedWrites.'
          : 'Demo data seed complete. Writes: $_plannedWrites.',
    );
  }

  Future<void> _assertCollections() async {
    const requiredCollections = [
      'categories',
      'students',
      'books',
      'borrow_records',
      'profiles',
      'app_settings',
    ];
    for (final name in requiredCollections) {
      await _pb.collections.getOne(name);
    }
  }

  Future<String> _handlerProfileId() async {
    final profiles = await _pb.collection('profiles').getFullList();
    RecordModel? admin;
    for (final profile in profiles) {
      if (profile.get<String?>('role') == 'admin') {
        admin = profile;
        break;
      }
    }
    admin ??= profiles.isNotEmpty ? profiles.first : null;
    if (admin == null) {
      throw StateError('profiles collection has no teacher/admin records.');
    }
    return _textValue(admin, 'source_id') ?? admin.id;
  }

  Future<Map<String, int>> _ensureCategories() async {
    final categories = await _recordsByNumericId('categories');
    final byName = _recordsByName(categories.values, 'name');
    final result = <String, int>{};

    for (final seed in _categorySeeds) {
      final existingByName = byName[seed.name];
      if (existingByName != null) {
        result[seed.name] = _numericId(existingByName.id)!;
        continue;
      }

      final existingById = categories[seed.preferredId];
      if (existingById != null &&
          seed.placeholderNames.contains(_textValue(existingById, 'name'))) {
        await _update(
          'categories',
          existingById.id,
          {'name': seed.name},
          'rename category ${seed.preferredId} to ${seed.name}',
        );
        result[seed.name] = seed.preferredId;
        continue;
      }

      if (existingById == null) {
        await _create(
          'categories',
          {
            'id': _numericRecordId(seed.preferredId),
            'name': seed.name,
            'created_at': _date(DateTime(2025, 9, 1)),
          },
          'create category ${seed.name}',
        );
        result[seed.name] = seed.preferredId;
        continue;
      }

      final nextId = await _nextNumericId('categories');
      await _create(
        'categories',
        {
          'id': _numericRecordId(nextId),
          'name': seed.name,
          'created_at': _date(DateTime(2025, 9, 1)),
        },
        'create category ${seed.name} as $nextId',
      );
      result[seed.name] = nextId;
    }

    return result;
  }

  Future<Map<String, int>> _ensureStudents() async {
    final students = await _recordsByNumericId('students');
    final byName = _recordsByName(students.values, 'full_name');
    final result = <String, int>{};

    for (final seed in _studentSeeds) {
      final existing = byName[seed.fullName];
      if (existing != null) {
        final id = _numericId(existing.id)!;
        result[seed.fullName] = id;
        final currentClass = _textValue(existing, 'class_name');
        if (_shouldPatchGenericClass(currentClass, seed.className)) {
          await _update(
            'students',
            existing.id,
            {'class_name': seed.className},
            'update class for ${seed.fullName}',
          );
        }
        continue;
      }

      final id = students.containsKey(seed.preferredId)
          ? await _nextNumericId('students')
          : seed.preferredId;
      await _create(
        'students',
        {
          'id': _numericRecordId(id),
          'created_at': _date(DateTime(2025, 9, 1)),
          'full_name': seed.fullName,
          'class_name': seed.className,
        },
        'create student ${seed.fullName}',
      );
      result[seed.fullName] = id;
    }

    return result;
  }

  Future<Map<String, int>> _ensureBooks(Map<String, int> categoryIds) async {
    final books = await _recordsByNumericId('books');
    final byIsbn = <String, RecordModel>{};
    final byTitle = <String, RecordModel>{};
    for (final record in books.values) {
      final isbn = _textValue(record, 'isbn');
      if (isbn != null && isbn.isNotEmpty) byIsbn[isbn] = record;
      final title = _textValue(record, 'title');
      if (title != null) byTitle[title] = record;
    }

    final result = <String, int>{};
    for (final seed in _bookSeeds) {
      final existing = byIsbn[seed.isbn] ?? byTitle[seed.title];
      if (existing != null) {
        final id = _numericId(existing.id)!;
        result[seed.key] = id;
        await _patchBookMissingFields(existing, seed, categoryIds);
        continue;
      }

      final id = books.containsKey(seed.preferredId)
          ? await _nextNumericId('books')
          : seed.preferredId;
      await _create(
        'books',
        {
          'id': _numericRecordId(id),
          'created_at': _date(DateTime(2025, 9, 1)),
          'title': seed.title,
          'author': seed.author,
          'publisher': seed.publisher,
          'isbn': seed.isbn,
          'location': seed.location,
          'cover_image_url': seed.coverImageUrl,
          'status': 'available',
          'last_updated_by': null,
          'total_quantity': seed.totalQuantity,
          'available_quantity': seed.totalQuantity,
          'category_id': categoryIds[seed.categoryName],
          'tags': seed.tags,
          'rating': seed.rating,
        },
        'create book ${seed.title}',
      );
      result[seed.key] = id;
    }

    return result;
  }

  Future<void> _patchBookMissingFields(
    RecordModel record,
    BookSeed seed,
    Map<String, int> categoryIds,
  ) async {
    final updates = <String, Object?>{};
    void fillText(String field, String value) {
      final current = _textValue(record, field);
      if (current == null || current.isEmpty) updates[field] = value;
    }

    fillText('publisher', seed.publisher);
    fillText('isbn', seed.isbn);
    fillText('location', seed.location);
    fillText('cover_image_url', seed.coverImageUrl);

    final tags = record.get<List?>('tags')?.map((item) => '$item').toList();
    if (tags == null || tags.isEmpty) updates['tags'] = seed.tags;

    final rating = record.get<num?>('rating');
    if (rating == null || rating == 0) updates['rating'] = seed.rating;

    final category = _intValue(record.get('category_id'));
    if (category == null) {
      updates['category_id'] = categoryIds[seed.categoryName];
    }

    if (updates.isNotEmpty) {
      await _update(
        'books',
        record.id,
        updates,
        'patch missing metadata for ${seed.title}',
      );
    }
  }

  Future<void> _normalizeLegacyBookCategories({
    required int categoryId,
  }) async {
    final books = await _recordsByNumericId('books');
    for (final record in books.values) {
      final title = _textValue(record, 'title');
      if (!_legacyTeacherBookTitles.contains(title)) continue;
      final currentCategory = _intValue(record.get('category_id'));
      if (currentCategory == categoryId) continue;
      if (currentCategory != null &&
          !_placeholderCategoryIds.contains(currentCategory)) {
        continue;
      }
      await _update(
        'books',
        record.id,
        {'category_id': categoryId},
        'move legacy teacher book $title to 教师用书',
      );
    }
  }

  Future<void> _ensureReminderSettings() async {
    final existing = await _firstSetting('borrow_reminder_settings');
    final defaultValue = {
      'due_soon_days': 3,
      'student_reminder_days': 3,
      'teacher_reminder_days': 5,
    };

    if (existing == null) {
      await _create(
        'app_settings',
        {
          'key': 'borrow_reminder_settings',
          'value': defaultValue,
          'updated_at': _date(DateTime.now()),
        },
        'create borrow reminder settings',
      );
      return;
    }

    final value = existing.get<Map?>('value');
    final merged = Map<String, Object?>.from(defaultValue);
    if (value != null) {
      for (final entry in value.entries) {
        if (entry.value != null) merged['${entry.key}'] = entry.value;
      }
    }

    if (!_mapsEqual(value, merged)) {
      await _update(
        'app_settings',
        existing.id,
        {'value': merged, 'updated_at': _date(DateTime.now())},
        'fill missing reminder settings',
      );
    }
  }

  Future<void> _ensureBorrowSamples({
    required String handlerId,
    required Map<String, int> studentIds,
    required Map<String, int> bookIds,
  }) async {
    final records = await _recordsByNumericId('borrow_records');
    for (final seed in _borrowSeeds) {
      if (records.containsKey(seed.preferredId)) {
        stdout.writeln('skip borrow sample ${seed.preferredId}: id exists');
        continue;
      }
      final bookId = bookIds[seed.bookKey];
      final studentId = studentIds[seed.studentName];
      if (bookId == null || studentId == null) {
        throw StateError(
          'Borrow sample ${seed.preferredId} has unresolved book/student.',
        );
      }
      await _create(
        'borrow_records',
        {
          'id': _numericRecordId(seed.preferredId),
          'created_at': _date(seed.borrowDate),
          'book_id': bookId,
          'student_id': studentId,
          'profile_id': null,
          'borrow_date': _date(seed.borrowDate),
          'due_date': _date(seed.dueDate),
          'return_date':
              seed.returnDate == null ? null : _date(seed.returnDate!),
          'borrowed_by_user_id': handlerId,
          'quantity': seed.quantity,
          'reminder_days_before': seed.reminderDaysBefore,
        },
        'create borrow sample ${seed.preferredId}',
      );
    }
  }

  Future<void> _syncSeededBookInventory(Set<int> seededBookIds) async {
    final books = await _recordsByNumericId('books');
    final borrowRecords = await _recordsByNumericId('borrow_records');
    for (final bookId in seededBookIds) {
      final book = books[bookId];
      if (book == null) continue;
      final activeQuantity = borrowRecords.values
          .where((record) =>
              _intValue(record.get('book_id')) == bookId &&
              _emptyDate(record.get('return_date')))
          .fold<int>(0,
              (sum, record) => sum + (_intValue(record.get('quantity')) ?? 1));
      final total = _intValue(book.get('total_quantity')) ?? 1;
      final nextAvailable = (total - activeQuantity).clamp(0, total).toInt();
      final nextStatus = nextAvailable > 0 ? 'available' : 'borrowed';
      if (_intValue(book.get('available_quantity')) != nextAvailable ||
          _textValue(book, 'status') != nextStatus) {
        await _update(
          'books',
          book.id,
          {
            'available_quantity': nextAvailable,
            'status': nextStatus,
          },
          'sync inventory for ${_textValue(book, 'title')}',
        );
      }
    }
  }

  Future<void> _syncBookStatuses() async {
    final books = await _recordsByNumericId('books');
    for (final book in books.values) {
      final available = _intValue(book.get('available_quantity')) ?? 0;
      final expectedStatus = available > 0 ? 'available' : 'borrowed';
      if (_textValue(book, 'status') == expectedStatus) continue;
      await _update(
        'books',
        book.id,
        {'status': expectedStatus},
        'sync status for ${_textValue(book, 'title')}',
      );
    }
  }

  Future<RecordModel?> _firstSetting(String key) async {
    final records = await _pb.collection('app_settings').getFullList();
    for (final record in records) {
      if (_textValue(record, 'key') == key) return record;
    }
    return null;
  }

  Future<Map<int, RecordModel>> _recordsByNumericId(String collection) async {
    final records = await _pb.collection(collection).getFullList();
    return {
      for (final record in records)
        if (_numericId(record.id) != null) _numericId(record.id)!: record,
    };
  }

  Map<String, RecordModel> _recordsByName(
    Iterable<RecordModel> records,
    String field,
  ) {
    return {
      for (final record in records)
        if (_textValue(record, field) != null)
          _textValue(record, field)!: record,
    };
  }

  Future<int> _nextNumericId(String collection) async {
    final records = await _recordsByNumericId(collection);
    var id = records.keys.isEmpty
        ? 1
        : records.keys.reduce((a, b) => a > b ? a : b) + 1;
    while (records.containsKey(id)) {
      id++;
    }
    return id;
  }

  Future<void> _create(
    String collection,
    Map<String, Object?> body,
    String description,
  ) async {
    _plannedWrites++;
    stdout.writeln('${_dryRun ? 'plan' : 'write'}: $description');
    if (_dryRun) return;
    await _pb.collection(collection).create(body: body);
  }

  Future<void> _update(
    String collection,
    String id,
    Map<String, Object?> body,
    String description,
  ) async {
    _plannedWrites++;
    stdout.writeln('${_dryRun ? 'plan' : 'write'}: $description');
    if (_dryRun) return;
    await _pb.collection(collection).update(id, body: body);
  }
}

const _categorySeeds = [
  CategorySeed(3, '故事绘本', ['卧龙']),
  CategorySeed(4, '童谣语言', ['凤雏']),
  CategorySeed(5, '认知启蒙', ['幼麟']),
  CategorySeed(6, '科学自然', ['冢虎']),
  CategorySeed(7, '情绪社交', []),
  CategorySeed(8, '生活习惯与安全', []),
  CategorySeed(9, '传统文化与节日', []),
  CategorySeed(10, '教师用书', []),
];

const _studentSeeds = [
  StudentSeed(1, '许子祺', '小一班'),
  StudentSeed(2, '任小粟', '中一班'),
  StudentSeed(3, '赵灵儿', '中一班'),
  StudentSeed(4, '李神坛', '大一班'),
];

const _bookSeeds = [
  BookSeed(
    preferredId: 21,
    key: 'caterpillar',
    title: '好饿的毛毛虫',
    author: '[美] 艾瑞·卡尔 / 郑明进',
    publisher: '明天出版社',
    isbn: '9787533256739',
    categoryName: '科学自然',
    tags: ['绘本', '生命成长', '食物', '星期', '数数', '亲子共读'],
    rating: 4.8,
    totalQuantity: 4,
    location: '绘本区A架1层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-01/900/1300',
  ),
  BookSeed(
    preferredId: 22,
    key: 'press_here',
    title: '点点点',
    author: '[法] 埃尔维·杜莱 / 蒲蒲兰',
    publisher: '二十一世纪出版社',
    isbn: '9787539175546',
    categoryName: '认知启蒙',
    tags: ['互动绘本', '颜色', '动作', '观察', '小班'],
    rating: 4.6,
    totalQuantity: 3,
    location: '绘本区A架2层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-02/900/1300',
  ),
  BookSeed(
    preferredId: 23,
    key: 'who_hides',
    title: '谁藏起来了',
    author: '[日] 大西悟 / 蒲蒲兰',
    publisher: '二十一世纪出版社',
    isbn: '9787539130507',
    categoryName: '认知启蒙',
    tags: ['动物', '记忆', '找不同', '观察', '中班'],
    rating: 4.5,
    totalQuantity: 3,
    location: '绘本区A架2层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-03/900/1300',
  ),
  BookSeed(
    preferredId: 24,
    key: 'bear_baby',
    title: '小熊宝宝绘本·第一辑',
    author: '[日] 佐佐木洋子 / 蒲蒲兰',
    publisher: '新星出版社',
    isbn: '9787513352192',
    categoryName: '生活习惯与安全',
    tags: ['生活习惯', '问好', '如厕', '吃饭', '入园适应'],
    rating: 4.7,
    totalQuantity: 4,
    location: '绘本区B架1层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-04/900/1300',
  ),
  BookSeed(
    preferredId: 25,
    key: 'rainbow_flower',
    title: '彩虹色的花',
    author: '麦克·格雷涅茨、细野绫子 / 蒲蒲兰',
    publisher: '二十一世纪出版社',
    isbn: '9787539130460',
    categoryName: '情绪社交',
    tags: ['分享', '助人', '善良', '生命循环', '情绪社交'],
    rating: 4.6,
    totalQuantity: 3,
    location: '绘本区B架2层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-05/900/1300',
  ),
  BookSeed(
    preferredId: 26,
    key: 'moon_taste',
    title: '月亮的味道',
    author: '麦克·格雷涅茨 / 漪然、彭懿',
    publisher: '二十一世纪出版社',
    isbn: '9787539135892',
    categoryName: '故事绘本',
    tags: ['合作', '动物', '想象', '故事绘本', '表达'],
    rating: 4.7,
    totalQuantity: 4,
    location: '绘本区C架1层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-06/900/1300',
  ),
  BookSeed(
    preferredId: 27,
    key: 'rosie_walk',
    title: '母鸡萝丝去散步',
    author: '佩特·哈群斯 / 上谊出版部',
    publisher: '少年儿童出版社',
    isbn: '9787532467396',
    categoryName: '故事绘本',
    tags: ['农场', '空间方位', '看图讲述', '幽默', '无字书'],
    rating: 4.5,
    totalQuantity: 3,
    location: '绘本区C架1层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-07/900/1300',
  ),
  BookSeed(
    preferredId: 28,
    key: 'my_dad',
    title: '我爸爸',
    author: '[英] 安东尼·布朗 / 余治莹',
    publisher: '河北教育出版社',
    isbn: '9787543464582',
    categoryName: '情绪社交',
    tags: ['家庭', '父亲', '表达', '亲子共读', '自信'],
    rating: 4.7,
    totalQuantity: 3,
    location: '绘本区B架2层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-08/900/1300',
  ),
  BookSeed(
    preferredId: 29,
    key: 'no_david',
    title: '大卫，不可以',
    author: '[美] 大卫·香农 / 余治莹',
    publisher: '河北教育出版社',
    isbn: '9787543464636',
    categoryName: '生活习惯与安全',
    tags: ['规则', '边界', '情绪', '行为习惯', '安全'],
    rating: 4.6,
    totalQuantity: 4,
    location: '绘本区B架1层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-09/900/1300',
  ),
  BookSeed(
    preferredId: 30,
    key: 'vegetables',
    title: '一园青菜成了精',
    author: '周翔 图，编自北方童谣',
    publisher: '明天出版社',
    isbn: '9787533257545',
    categoryName: '童谣语言',
    tags: ['童谣', '蔬菜', '中国原创', '水墨', '语言韵律'],
    rating: 4.5,
    totalQuantity: 3,
    location: '绘本区D架1层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-10/900/1300',
  ),
  BookSeed(
    preferredId: 31,
    key: 'reunion',
    title: '团圆',
    author: '余丽琼 文 / 朱成梁 图',
    publisher: '明天出版社',
    isbn: '9787533255879',
    categoryName: '传统文化与节日',
    tags: ['春节', '家庭', '亲情', '中国原创', '传统节日'],
    rating: 4.8,
    totalQuantity: 3,
    location: '绘本区D架2层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-11/900/1300',
  ),
  BookSeed(
    preferredId: 32,
    key: 'always_love_you',
    title: '永远永远爱你',
    author: '宫西达也 / 蒲蒲兰',
    publisher: '二十一世纪出版社',
    isbn: '9787539141930',
    categoryName: '情绪社交',
    tags: ['亲情', '接纳', '恐龙', '同理心', '情感故事'],
    rating: 4.6,
    totalQuantity: 3,
    location: '绘本区B架3层',
    coverImageUrl:
        'https://picsum.photos/seed/kindergarten-library-12/900/1300',
  ),
];

final _borrowSeeds = [
  BorrowSeed(101, 'caterpillar', '许子祺', DateTime.utc(2025, 9, 8),
      DateTime.utc(2025, 9, 22), DateTime.utc(2025, 9, 20)),
  BorrowSeed(102, 'bear_baby', '许子祺', DateTime.utc(2025, 9, 18),
      DateTime.utc(2025, 10, 2), DateTime.utc(2025, 9, 29)),
  BorrowSeed(103, 'who_hides', '任小粟', DateTime.utc(2025, 10, 9),
      DateTime.utc(2025, 10, 23), DateTime.utc(2025, 10, 22)),
  BorrowSeed(104, 'moon_taste', '赵灵儿', DateTime.utc(2025, 10, 16),
      DateTime.utc(2025, 10, 30), DateTime.utc(2025, 10, 30)),
  BorrowSeed(105, 'no_david', '许子祺', DateTime.utc(2025, 11, 5),
      DateTime.utc(2025, 11, 19), DateTime.utc(2025, 11, 18)),
  BorrowSeed(106, 'rainbow_flower', '赵灵儿', DateTime.utc(2025, 11, 12),
      DateTime.utc(2025, 11, 26), DateTime.utc(2025, 11, 25)),
  BorrowSeed(107, 'my_dad', '李神坛', DateTime.utc(2025, 12, 3),
      DateTime.utc(2025, 12, 17), DateTime.utc(2025, 12, 18)),
  BorrowSeed(108, 'vegetables', '李神坛', DateTime.utc(2025, 12, 19),
      DateTime.utc(2026, 1, 2), DateTime.utc(2025, 12, 31)),
  BorrowSeed(109, 'reunion', '李神坛', DateTime.utc(2026, 1, 12),
      DateTime.utc(2026, 1, 26), DateTime.utc(2026, 1, 25)),
  BorrowSeed(110, 'press_here', '任小粟', DateTime.utc(2026, 3, 4),
      DateTime.utc(2026, 3, 18), DateTime.utc(2026, 3, 17)),
  BorrowSeed(111, 'rosie_walk', '赵灵儿', DateTime.utc(2026, 3, 21),
      DateTime.utc(2026, 4, 4), DateTime.utc(2026, 4, 3)),
  BorrowSeed(112, 'always_love_you', '任小粟', DateTime.utc(2026, 4, 8),
      DateTime.utc(2026, 4, 22), DateTime.utc(2026, 4, 21)),
  BorrowSeed(113, 'caterpillar', '任小粟', DateTime.utc(2026, 4, 20),
      DateTime.utc(2026, 5, 4), DateTime.utc(2026, 5, 3)),
  BorrowSeed(114, 'rainbow_flower', '许子祺', DateTime.utc(2026, 5, 18),
      DateTime.utc(2026, 6, 1), null),
  BorrowSeed(115, 'no_david', '赵灵儿', DateTime.utc(2026, 5, 30),
      DateTime.utc(2026, 6, 11), null),
  BorrowSeed(116, 'moon_taste', '李神坛', DateTime.utc(2026, 6, 3),
      DateTime.utc(2026, 6, 25), null),
  BorrowSeed(117, 'bear_baby', '许子祺', DateTime.utc(2026, 6, 5),
      DateTime.utc(2026, 6, 12), null),
];

final _legacyTeacherBookTitles = {
  'Java Web 应用与开发',
  '工程经济学',
  '软件工程',
  '编译原理',
  '形势与政策',
  '行测',
};

final _placeholderCategoryIds = {3, 4, 5, 6};

class CategorySeed {
  const CategorySeed(this.preferredId, this.name, this.placeholderNames);

  final int preferredId;
  final String name;
  final List<String> placeholderNames;
}

class StudentSeed {
  const StudentSeed(this.preferredId, this.fullName, this.className);

  final int preferredId;
  final String fullName;
  final String className;
}

class BookSeed {
  const BookSeed({
    required this.preferredId,
    required this.key,
    required this.title,
    required this.author,
    required this.publisher,
    required this.isbn,
    required this.categoryName,
    required this.tags,
    required this.rating,
    required this.totalQuantity,
    required this.location,
    required this.coverImageUrl,
  });

  final int preferredId;
  final String key;
  final String title;
  final String author;
  final String publisher;
  final String isbn;
  final String categoryName;
  final List<String> tags;
  final double rating;
  final int totalQuantity;
  final String location;
  final String coverImageUrl;
}

class BorrowSeed {
  const BorrowSeed(
    this.preferredId,
    this.bookKey,
    this.studentName,
    this.borrowDate,
    this.dueDate,
    this.returnDate, {
    this.quantity = 1,
    this.reminderDaysBefore = 3,
  });

  final int preferredId;
  final String bookKey;
  final String studentName;
  final DateTime borrowDate;
  final DateTime dueDate;
  final DateTime? returnDate;
  final int quantity;
  final int reminderDaysBefore;
}

String _date(DateTime date) => date.toUtc().toIso8601String();

String _numericRecordId(int id) => id.toString().padLeft(15, '0');

int? _numericId(String id) {
  if (!RegExp(r'^\d{15}$').hasMatch(id)) return null;
  return int.tryParse(id);
}

int? _intValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String && value.isNotEmpty) return int.tryParse(value);
  return null;
}

String? _textValue(RecordModel record, String field) {
  final value = record.get<dynamic>(field);
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _emptyDate(dynamic value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  return false;
}

bool _mapsEqual(Map<dynamic, dynamic>? a, Map<String, Object?> b) {
  if (a == null) return false;
  if (a.length != b.length) return false;
  for (final entry in b.entries) {
    if (a[entry.key] != entry.value) return false;
  }
  return true;
}

bool _shouldPatchGenericClass(String? currentClass, String targetClass) {
  if (currentClass == null || currentClass.isEmpty) return true;
  if (currentClass == targetClass) return false;
  return const {'小班', '中班', '大班'}.contains(currentClass);
}
