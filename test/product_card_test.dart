import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:um_campus_marketplace/models/product.dart';
import 'package:um_campus_marketplace/widgets/product_card.dart';

void main() {
  group('ProductCard', () {
    late Product product;

    setUp(() {
      product = Product(
        id: 'product-test-001',
        sellerId: 'seller-test-001',
        sellerName: 'Test Seller',
        title: 'Test Laptop',
        description: 'A test marketplace product.',
        price: 25000.00,
        category: 'Electronics',

        // Required by your updated Product model
        itemCondition: 'Good',

        imageUrls: const [],
        createdAt: DateTime(2026, 9, 30),
        isSold: false,
      );
    });

    testWidgets('displays product information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductCard(product: product)),
        ),
      );

      await tester.pump();

      expect(find.text('Test Laptop'), findsOneWidget);

      expect(find.text('ELECTRONICS'), findsOneWidget);

      expect(find.text('₱25,000.00'), findsOneWidget);

      expect(find.text('Test Seller'), findsOneWidget);
    });

    testWidgets('shows SOLD when product is sold', (WidgetTester tester) async {
      final soldProduct = Product(
        id: 'product-test-002',
        sellerId: 'seller-test-001',
        sellerName: 'Test Seller',
        title: 'Sold Laptop',
        description: 'Already sold product.',
        price: 15000.00,
        category: 'Electronics',

        // Required field
        itemCondition: 'Good',

        imageUrls: const [],
        createdAt: DateTime(2026, 9, 30),
        isSold: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductCard(product: soldProduct)),
        ),
      );

      await tester.pump();

      expect(find.text('Sold Laptop'), findsOneWidget);

      expect(find.text('SOLD'), findsOneWidget);
    });
  });
}
