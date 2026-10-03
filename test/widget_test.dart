import 'package:flutter_test/flutter_test.dart';
import 'package:um_campus_marketplace/models/product.dart';
import 'package:um_campus_marketplace/utils/price_validator.dart';

void main() {
  Map<String, dynamic> row() => {
    'id': 'product-1',
    'seller_id': 'seller-1',
    'title': 'Book',
    'price': 100,
    'created_at': '2026-09-25T00:00:00Z',
    'image_urls': ['https://example.com/a,b.jpg', null, '', 42],
  };

  test('parses numeric prices and preserves commas in image URLs', () {
    final product = Product.fromMap(row());
    expect(product.price, 100.0);
    expect(product.imageUrls, ['https://example.com/a,b.jpg']);
    expect(product.createdAt, DateTime.utc(2026, 9, 25));
    expect(product.toMap()['image_urls'], product.imageUrls);
  });

  test('image list cannot be mutated through input or output', () {
    final data = row();
    final product = Product.fromMap(data);
    (data['image_urls'] as List).clear();
    expect(product.imageUrls, hasLength(1));
    expect(() => product.imageUrls.clear(), throwsUnsupportedError);
  });

  test('rejects malformed dates and array strings', () {
    for (final date in [null, 'invalid']) {
      expect(
        () => Product.fromMap(row()..['created_at'] = date),
        throwsFormatException,
      );
    }
    expect(
      () => Product.fromMap(row()..['image_urls'] = '{a,b}'),
      throwsFormatException,
    );
  });

  test('rejects malformed and non-finite stored prices', () {
    for (final price in [null, '100', double.nan, double.infinity, -1]) {
      expect(
        () => Product.fromMap(row()..['price'] = price),
        throwsFormatException,
      );
    }
  });

  test('validates listing prices including non-finite input', () {
    for (final value in [
      null,
      '',
      'abc',
      'NaN',
      'Infinity',
      '-Infinity',
      '0',
      '-1',
      '1000001',
    ]) {
      expect(validatePrice(value), isNotNull, reason: 'Input: $value');
    }
    for (final value in ['0.01', ' 100.50 ', '1000000']) {
      expect(validatePrice(value), isNull);
    }
  });
}
