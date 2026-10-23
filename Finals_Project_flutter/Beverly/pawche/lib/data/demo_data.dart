import '../models/product.dart';
import '../models/pet.dart';

const demoProducts = <Product>[
  Product(
      id: 'p1',
      name: 'Royal Canin Dog Food',
      category: 'Dog Food',
      price: '₱1',
      emoji: '🥫',
      description:
          'Complete nutrition for adult dogs. Supports healthy skin, coat, and digestion.'),
  Product(
      id: 'p2',
      name: 'Cat Food',
      category: 'Cat Food',
      price: '₱1',
      emoji: '🐱',
      description: 'Balanced everyday nutrition for happy, healthy cats.'),
  Product(
      id: 'p3',
      name: 'Pet Toy Ball',
      category: 'Pet Toys',
      price: '₱1',
      emoji: '🎾',
      description: 'Colorful playtime toy for curious pets.'),
  Product(
      id: 'p4',
      name: 'Grooming Supplies',
      category: 'Grooming',
      price: '₱1',
      emoji: '🧴',
      description: 'Gentle grooming essentials for your furry friend.'),
  Product(
      id: 'p5',
      name: 'Cat Tree',
      category: 'Furniture',
      price: '₱1',
      emoji: '🪵',
      description: 'A cozy climbing and scratching space for cats.'),
  Product(
      id: 'p6',
      name: 'Dog Bed',
      category: 'Beds',
      price: '₱1',
      emoji: '🛏️',
      description: 'A soft, supportive resting spot for your dog.'),
  Product(
      id: 'p7',
      name: 'Pet Carrier',
      category: 'Accessories',
      price: '₱1',
      emoji: '🧳',
      description: 'Comfortable travel carrier for everyday adventures.'),
  Product(
      id: 'p8',
      name: 'Cat Litter',
      category: 'Cat Supplies',
      price: '₱1',
      emoji: '📦',
      description: 'Everyday litter essentials for a tidy home.'),
];
const demoPets = <Pet>[
  Pet(
      name: 'Luna',
      type: 'Dog',
      breed: 'Golden Retriever',
      age: '2 years old',
      emoji: '🐕'),
  Pet(
      name: 'Mochi',
      type: 'Cat',
      breed: 'Persian Cat',
      age: '1 year old',
      emoji: '🐈')
];
