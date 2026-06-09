import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/models/book.dart';
import 'package:kindergarten_library/utils/search_matcher.dart';

void main() {
  test('matches Chinese book title by pinyin initials', () {
    final book = Book(id: 1, title: '软件工程');

    expect(SearchMatcher.matchesBook(book, 'rjg'), isTrue);
    expect(
      SearchMatcher.matchText(book.title, 'rjg').kind,
      SearchMatchKind.initials,
    );
  });

  test('matches Chinese book title by full pinyin', () {
    final book = Book(id: 1, title: '软件工程');

    expect(SearchMatcher.matchesBook(book, 'ruanjian'), isTrue);
    expect(
      SearchMatcher.matchText(book.title, 'ruanjian').kind,
      SearchMatchKind.pinyin,
    );
  });

  test('matches nearby typo in pinyin query', () {
    final book = Book(id: 1, title: '软件工程');

    expect(SearchMatcher.matchesBook(book, 'ruanjiangongchng'), isTrue);
    expect(
      SearchMatcher.matchText(book.title, 'ruanjiangongchng').kind,
      SearchMatchKind.fuzzy,
    );
  });

  test('returns highlight range for direct text contains', () {
    final match = SearchMatcher.matchText('童心出版社', '出版社');

    expect(match.kind, SearchMatchKind.contains);
    expect(match.hasRange, isTrue);
    expect(match.start, 2);
    expect(match.end, 5);
  });
}
