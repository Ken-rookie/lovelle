import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

const giftlyPink = LovelleColors.rose;
const giftlyInk = LovelleColors.plum;
final peso =
    NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

void showOperationError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(friendlyErrorMessage(error)),
      action: SnackBarAction(
        label: 'Details',
        onPressed: () {
          if (!context.mounted) return;
          showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('More information'),
              content: SingleChildScrollView(
                child: SelectableText(error.toString()),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

String friendlyErrorMessage(Object error) {
  final details = error.toString().toLowerCase();
  if (details.contains('functionsfetchexception') ||
      details.contains('failed to fetch') ||
      details.contains('reasonphrase: null') ||
      (details.contains('/functions/v1/') && details.contains('fetch'))) {
    return 'The checkout service is temporarily unavailable. Check that the Supabase Edge Function is deployed and your project URL and keys are valid.';
  }
  if (details.contains('42501') || details.contains('permission denied')) {
    return 'Lovelle does not have access to this information yet. Apply the customer-access policies in Supabase, then try again.';
  }
  if (details.contains('socketexception') ||
      details.contains('failed host lookup') ||
      details.contains('network is unreachable')) {
    return 'Check your internet connection and try again.';
  }
  return 'We could not load this right now. Please try again.';
}

class LoadErrorState extends StatelessWidget {
  const LoadErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final message = friendlyErrorMessage(error);
    if (compact) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LovelleColors.mauve,
                fontSize: 12,
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: LovelleColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    color: LovelleColors.palePink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    color: LovelleColors.roseDark,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'We hit a small snag',
                  style: TextStyle(
                    color: LovelleColors.plum,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: LovelleColors.mauve,
                    height: 1.4,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
                const SizedBox(height: 8),
                Material(
                  type: MaterialType.transparency,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Technical details',
                      style: TextStyle(
                        color: LovelleColors.mauve,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      SelectableText(
                        error.toString(),
                        style: const TextStyle(
                          color: LovelleColors.mauve,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.label = 'A little patience, please…',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
        child: compact
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      label,
                      style: const TextStyle(
                        color: LovelleColors.mauve,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
      );
}

class LovelleLogo extends StatelessWidget {
  const LovelleLogo({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Lovelle',
            style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: compact ? 30 : 46,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                color: giftlyPink)),
        const Text("More than gifts, it's a feeling.",
            style:
                TextStyle(fontSize: 11, color: giftlyInk, letterSpacing: .35)),
      ]);
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: giftlyInk,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.action});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                    color: giftlyPink.withValues(alpha: .10),
                    shape: BoxShape.circle),
                child: Icon(icon, color: giftlyPink, size: 40)),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: giftlyInk)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ])));
}

class NetworkProductImage extends StatelessWidget {
  const NetworkProductImage({super.key, required this.url, this.height = 140});
  final String url;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [LovelleColors.palePink, LovelleColors.cream],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: url.isEmpty
            ? const _ProductImageFallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _ProductImageFallback(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _ProductImageFallback(showSpinner: true);
                },
              ),
      );
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback({this.showSpinner = false});

  final bool showSpinner;

  @override
  Widget build(BuildContext context) => Center(
        child: showSpinner
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.card_giftcard_rounded,
                size: 48,
                color: giftlyPink,
              ),
      );
}
