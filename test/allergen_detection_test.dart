import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_eat_japan/services/allergen_detector.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('extractAllergenKey', () {
    test('辞書キーと完全一致する場合にそのキーを返す', () {
      expect(extractAllergenKey('小麦'), equals('小麦'));
      expect(extractAllergenKey('卵'), equals('卵'));
      expect(extractAllergenKey('乳成分'), equals('乳成分'));
      expect(extractAllergenKey('えび'), equals('えび'));
      expect(extractAllergenKey('落花生'), equals('落花生'));
    });

    test('成分文字列にアレルゲンキーが含まれる場合に検出する', () {
      expect(extractAllergenKey('小麦粉'), equals('小麦'));
      expect(extractAllergenKey('小麦粉（小麦）'), equals('小麦'));
      expect(extractAllergenKey('乳化剤（大豆）'), equals('大豆'));
      expect(extractAllergenKey('卵白'), equals('卵'));
      expect(extractAllergenKey('小麦でん粉'), equals('小麦'));
    });

    test('アレルゲンを含まない成分はnullを返す', () {
      expect(extractAllergenKey('砂糖'), isNull);
      expect(extractAllergenKey('食塩'), isNull);
      expect(extractAllergenKey('水'), isNull);
      expect(extractAllergenKey('植物油'), isNull);
    });

    test('空文字列はnullを返す', () {
      expect(extractAllergenKey(''), isNull);
    });
  });

  group('extractAllergenKeys', () {
    test('成分リストから複数のアレルゲンキーを抽出する', () {
      final keys = extractAllergenKeys(['小麦粉', '砂糖', '卵白', '食塩']);
      expect(keys, containsAll(['小麦', '卵']));
      expect(keys, isNot(contains('砂糖')));
      expect(keys, isNot(contains('食塩')));
    });

    test('同じアレルゲンが複数の成分に含まれていても重複しない', () {
      final keys = extractAllergenKeys(['小麦粉', '小麦でん粉', '小麦グルテン']);
      expect(keys.length, equals(1));
      expect(keys.first, equals('小麦'));
    });

    test('複数種のアレルゲンを同時に検出できる', () {
      final keys = extractAllergenKeys([
        '小麦粉（小麦）',
        '乳化剤（大豆）',
        '砂糖',
        '卵黄',
        '食塩',
      ]);
      expect(keys, containsAll(['小麦', '大豆', '卵']));
      expect(keys, isNot(contains('砂糖')));
      expect(keys, isNot(contains('食塩')));
    });

    test('空リストは空Setを返す', () {
      expect(extractAllergenKeys([]), isEmpty);
    });

    test('アレルゲン非含有成分のみのリストは空Setを返す', () {
      expect(extractAllergenKeys(['砂糖', '食塩', '水', '香料']), isEmpty);
    });
  });
}
