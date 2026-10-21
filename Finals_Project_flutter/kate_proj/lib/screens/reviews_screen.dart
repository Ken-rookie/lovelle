import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getReviews();
  }

  void _reload() {
    setState(() => _future = SupabaseService.getReviews());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Reviews')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const AppLoadingState(label: 'Loading your reviews…');
            }
            if (snap.hasError) {
              return LoadErrorState(error: snap.error!, onRetry: _reload);
            }
            final rows = snap.data ?? [];
            if (rows.isEmpty) {
              return const EmptyState(
                icon: Icons.rate_review_outlined,
                title: 'No reviews yet',
                subtitle:
                    'After your order is delivered, you can share your feedback.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final review = rows[i];
                final product = review['products'] as Map?;
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(Icons.star, color: Color(0xFFE3AD44)),
                  title: Text(product?['name']?.toString() ?? 'Product'),
                  subtitle: Text(
                    review['comment']?.toString() ?? 'No written comment',
                  ),
                  trailing: Text('${review['rating']} ★'),
                );
              },
            );
          },
        ),
      );
}
