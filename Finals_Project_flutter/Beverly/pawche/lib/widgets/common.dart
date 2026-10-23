import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PawcheLogo extends StatelessWidget {
  final double size;
  const PawcheLogo({super.key, this.size = 30});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.favorite, size: size, color: PawcheColors.pink),
              Icon(Icons.pets, size: size * .42, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Text('Pawché',
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: size * .78,
                fontWeight: FontWeight.w900,
                color: PawcheColors.darkPink))
      ]);
}

class PetPhoto extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const PetPhoto({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: borderRadius,
        child: Image.asset(
          'assets/images/pet-pair.png',
          width: width,
          height: height,
          fit: BoxFit.cover,
          semanticLabel: 'A golden retriever and a cat',
        ),
      );
}

class PetAvatar extends StatelessWidget {
  final String type;
  final double size;

  const PetAvatar({super.key, required this.type, this.size = 72});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          type.toLowerCase() == 'cat'
              ? 'assets/images/cat.png'
              : 'assets/images/dog.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: type.toLowerCase() == 'cat' ? 'Pet cat' : 'Pet dog',
        ),
      );
}

class ProductArtwork extends StatelessWidget {
  final String emoji;
  final String? imageAsset;
  final String? imageUrl;
  final double size;

  const ProductArtwork({
    super.key,
    required this.emoji,
    required this.imageAsset,
    this.imageUrl,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = this.imageUrl;
    final uri = imageUrl == null ? null : Uri.tryParse(imageUrl);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      return Image.network(
        uri.toString(),
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Product image',
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final imageAsset = this.imageAsset;
    if (imageAsset == null) {
      if (emoji.isEmpty) {
        return Icon(
          Icons.inventory_2_outlined,
          size: size * .6,
          color: PawcheColors.muted,
        );
      }
      return Text(emoji, style: TextStyle(fontSize: size));
    }
    return Image.asset(
      imageAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Product image',
      errorBuilder: (_, __, ___) => Icon(
        Icons.inventory_2_outlined,
        size: size * .6,
        color: PawcheColors.muted,
      ),
    );
  }
}

class PinkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PinkButton({super.key, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)));
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

void showDemoLimitation(BuildContext context, String message) =>
    showMessage(context, 'Demo mode: $message');

String formatPeso(int amount) =>
    '₱${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

class PawchePageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PawchePageTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: PawcheColors.navy,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: const TextStyle(color: PawcheColors.muted, fontSize: 13),
              ),
            ],
          ],
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PawcheColors.navy,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}
