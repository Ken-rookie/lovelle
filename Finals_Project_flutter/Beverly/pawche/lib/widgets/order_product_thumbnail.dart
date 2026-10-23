import 'package:flutter/material.dart';

import '../models/checkout.dart';
import '../theme/app_theme.dart';

class OrderProductThumbnail extends StatelessWidget {
  final OrderHistoryItem? item;
  final double size;

  const OrderProductThumbnail({super.key, required this.item, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item?.imageUrl;
    final uri = imageUrl == null ? null : Uri.tryParse(imageUrl);
    final asset = _assetFor(item?.productSlug);
    Widget image;
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      image = Image.network(
        uri.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(asset),
      );
    } else if (asset != null) {
      image = Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(null),
      );
    } else {
      image = _fallback(null);
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: PawcheColors.pale,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image,
      ),
    );
  }

  Widget _fallback(String? asset) {
    if (asset != null) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _iconFallback(),
      );
    }
    return _iconFallback();
  }

  Widget _iconFallback() => const ColoredBox(
        color: PawcheColors.blush,
        child: Icon(Icons.pets_rounded, color: PawcheColors.darkPink),
      );

  String? _assetFor(String? slug) => switch (slug) {
        'p1' => 'assets/images/royal-canin.png',
        'p2' => 'assets/images/cat-food.png',
        'p3' => 'assets/images/toy-ball.png',
        'p4' => 'assets/images/grooming.png',
        'p5' => 'assets/images/cat-tree.png',
        'p6' => 'assets/images/dog-bed.png',
        'p7' => 'assets/images/pet-carrier.png',
        _ => null,
      };
}
