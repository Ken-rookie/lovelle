import 'package:flutter/foundation.dart';

import '../models/product.dart';

class CartLine {
  final Product product;
  final int quantity;

  const CartLine({required this.product, required this.quantity});

  int get lineTotal => productPriceAmount(product) * quantity;
}

class CartStore extends ChangeNotifier {
  CartStore._();

  static final instance = CartStore._();

  final Map<String, CartLine> _lines = {};

  List<CartLine> get lines => List.unmodifiable(_lines.values);

  int get itemCount =>
      _lines.values.fold(0, (count, line) => count + line.quantity);

  int get subtotal =>
      _lines.values.fold(0, (total, line) => total + line.lineTotal);

  bool add(Product product, {int quantity = 1}) {
    if (quantity < 1 ||
        product.stockQuantity == null ||
        product.stockQuantity! < 1) {
      return false;
    }
    final current = _lines[product.id];
    final nextQuantity = (current?.quantity ?? 0) + quantity;
    if (nextQuantity > product.stockQuantity!) {
      return false;
    }
    _lines[product.id] = CartLine(
      product: product,
      quantity: nextQuantity,
    );
    notifyListeners();
    return true;
  }

  bool increase(String productId) {
    final current = _lines[productId];
    if (current == null) return false;
    if (current.product.stockQuantity == null ||
        current.quantity >= current.product.stockQuantity!) {
      return false;
    }
    _lines[productId] =
        CartLine(product: current.product, quantity: current.quantity + 1);
    notifyListeners();
    return true;
  }

  void decrease(String productId) {
    final current = _lines[productId];
    if (current == null) return;
    if (current.quantity <= 1) {
      _lines.remove(productId);
    } else {
      _lines[productId] =
          CartLine(product: current.product, quantity: current.quantity - 1);
    }
    notifyListeners();
  }

  void remove(String productId) {
    if (_lines.remove(productId) != null) notifyListeners();
  }

  void updateProduct(Product product) {
    final current = _lines[product.id];
    if (current == null) return;
    _lines[product.id] = CartLine(
      product: product,
      quantity: current.quantity,
    );
    notifyListeners();
  }

  void consume(Map<String, int> quantities) {
    var changed = false;
    for (final entry in quantities.entries) {
      final current = _lines[entry.key];
      if (current == null) continue;
      final remaining = current.quantity - entry.value;
      if (remaining <= 0) {
        _lines.remove(entry.key);
      } else {
        _lines[entry.key] =
            CartLine(product: current.product, quantity: remaining);
      }
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    notifyListeners();
  }
}

int productPriceAmount(Product product) =>
    int.parse(product.price.replaceAll(RegExp(r'[^0-9]'), ''));
