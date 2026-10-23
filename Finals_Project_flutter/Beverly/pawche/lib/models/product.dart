class Product {
  final String id;
  final String name;
  final String category;
  final String price;
  final String emoji;
  final String description;
  final int? stockQuantity;
  final String? imageUrl;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.emoji,
    required this.description,
    this.stockQuantity,
    this.imageUrl,
  });

  String? get imageAsset => switch (id) {
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
