import '../models/book.dart';

enum SearchMatchKind {
  none,
  exact,
  contains,
  pinyin,
  initials,
  fuzzy,
}

class SearchMatch {
  const SearchMatch(this.kind, {this.start = -1, this.end = -1});

  final SearchMatchKind kind;
  final int start;
  final int end;

  bool get isMatch => kind != SearchMatchKind.none;
  bool get hasRange => start >= 0 && end > start;
}

class SearchMatcher {
  const SearchMatcher._();

  static bool matchesBook(Book book, String query) {
    if (_normalizedQuery(query).isEmpty) return true;
    return [
      book.title,
      book.author,
      book.publisher,
      book.isbn,
      book.location,
      book.categoryName,
      ...book.tags,
    ].any((field) => matchText(field, query).isMatch);
  }

  static SearchMatch matchText(String? text, String query) {
    final normalizedQuery = _normalizedQuery(query);
    if (text == null || normalizedQuery.isEmpty) {
      return const SearchMatch(SearchMatchKind.none);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.trim().toLowerCase();
    if (lowerText == lowerQuery) {
      return SearchMatch(SearchMatchKind.exact, start: 0, end: text.length);
    }
    final directIndex = lowerText.indexOf(lowerQuery);
    if (directIndex >= 0) {
      return SearchMatch(
        SearchMatchKind.contains,
        start: directIndex,
        end: directIndex + lowerQuery.length,
      );
    }

    final compactText = _compact(text);
    if (compactText.contains(normalizedQuery)) {
      return const SearchMatch(SearchMatchKind.contains);
    }

    final pinyin = _toPinyin(text);
    if (pinyin.contains(normalizedQuery)) {
      return const SearchMatch(SearchMatchKind.pinyin);
    }

    final initials = _toInitials(text);
    if (initials.contains(normalizedQuery)) {
      return const SearchMatch(SearchMatchKind.initials);
    }

    if (_isCloseMatch(compactText, normalizedQuery) ||
        _isCloseMatch(pinyin, normalizedQuery) ||
        _isCloseMatch(initials, normalizedQuery)) {
      return const SearchMatch(SearchMatchKind.fuzzy);
    }

    return const SearchMatch(SearchMatchKind.none);
  }

  static String searchAssistLabel(SearchMatchKind kind) {
    switch (kind) {
      case SearchMatchKind.pinyin:
        return '拼音命中';
      case SearchMatchKind.initials:
        return '缩略词命中';
      case SearchMatchKind.fuzzy:
        return '近似命中';
      case SearchMatchKind.exact:
      case SearchMatchKind.contains:
      case SearchMatchKind.none:
        return '';
    }
  }

  static String _normalizedQuery(String query) {
    return _compact(query);
  }

  static String _compact(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[\s\-_:：,，.。/\\]+'), '');
  }

  static String _toInitials(String text) {
    return text.runes.map((rune) {
      final char = String.fromCharCode(rune);
      final pinyin = _pinyinMap[char];
      if (pinyin != null && pinyin.isNotEmpty) return pinyin[0];
      if (RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
        return char.toLowerCase();
      }
      return '';
    }).join();
  }

  static String _toPinyin(String text) {
    return text.runes.map((rune) {
      final char = String.fromCharCode(rune);
      final pinyin = _pinyinMap[char];
      if (pinyin != null) return pinyin;
      if (RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
        return char.toLowerCase();
      }
      return '';
    }).join();
  }

  static bool _isCloseMatch(String candidate, String query) {
    if (candidate.isEmpty || query.length < 3) return false;
    if (_isSubsequence(query, candidate)) return true;

    final maxDistance = query.length <= 5 ? 1 : 2;
    if (candidate.length <= 48 &&
        _levenshtein(candidate, query, maxDistance) <= maxDistance) {
      return true;
    }

    for (var i = 0; i < candidate.length; i++) {
      final end = (i + query.length + maxDistance).clamp(0, candidate.length);
      if (end <= i) continue;
      final window = candidate.substring(i, end);
      if (_levenshtein(window, query, maxDistance) <= maxDistance) {
        return true;
      }
    }
    return false;
  }

  static bool _isSubsequence(String query, String candidate) {
    var queryIndex = 0;
    for (var i = 0; i < candidate.length && queryIndex < query.length; i++) {
      if (candidate[i] == query[queryIndex]) queryIndex++;
    }
    return queryIndex == query.length;
  }

  static int _levenshtein(String a, String b, int cutoff) {
    if ((a.length - b.length).abs() > cutoff) return cutoff + 1;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;
      var rowMin = current[0];
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((value, element) => value < element ? value : element);
        if (current[j + 1] < rowMin) rowMin = current[j + 1];
      }
      if (rowMin > cutoff) return cutoff + 1;
      previous = current;
    }
    return previous.last;
  }
}

const _pinyinMap = <String, String>{
  '软': 'ruan',
  '件': 'jian',
  '工': 'gong',
  '程': 'cheng',
  '编': 'bian',
  '译': 'yi',
  '原': 'yuan',
  '理': 'li',
  '形': 'xing',
  '势': 'shi',
  '与': 'yu',
  '政': 'zheng',
  '策': 'ce',
  '行': 'xing',
  '测': 'ce',
  '图': 'tu',
  '书': 'shu',
  '管': 'guan',
  '馆': 'guan',
  '借': 'jie',
  '阅': 'yue',
  '还': 'huan',
  '学': 'xue',
  '生': 'sheng',
  '老': 'lao',
  '师': 'shi',
  '幼': 'you',
  '儿': 'er',
  '园': 'yuan',
  '分': 'fen',
  '类': 'lei',
  '标': 'biao',
  '注': 'zhu',
  '评': 'ping',
  '出': 'chu',
  '版': 'ban',
  '社': 'she',
  '作': 'zuo',
  '者': 'zhe',
  '位': 'wei',
  '置': 'zhi',
  '库': 'ku',
  '存': 'cun',
  '开': 'kai',
  '阳': 'yang',
  '楼': 'lou',
  '架': 'jia',
  '层': 'ceng',
  '南': 'nan',
  '京': 'jing',
  '大': 'da',
  '经': 'jing',
  '济': 'ji',
  '计': 'ji',
  '算': 'suan',
  '机': 'ji',
  '后': 'hou',
  '端': 'duan',
  '设': 'she',
  '目': 'mu',
  '项': 'xiang',
  '职': 'zhi',
  '业': 'ye',
  '能': 'neng',
  '力': 'li',
  '练': 'lian',
  '习': 'xi',
  '资': 'zi',
  '料': 'liao',
  '思': 'si',
  '时': 'shi',
  '秋': 'qiu',
  '季': 'ji',
  '教': 'jiao',
  '材': 'cai',
  '庄': 'zhuang',
  '国': 'guo',
  '强': 'qiang',
  '李': 'li',
  '代': 'dai',
  '平': 'ping',
  '陈': 'chen',
  '火': 'huo',
  '旺': 'wang',
  '小': 'xiao',
};
