import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'shop_screen.dart';
import 'wishlist_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'product_details_screen.dart';
import 'notifications_screen.dart';
import '../models/product.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _NavIconBadge extends StatelessWidget {
  const _NavIconBadge({
    required this.icon,
    required this.count,
  });

  final Widget icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -5,
          top: -5,
          child: Container(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppShellState extends State<AppShell> {
  final _cartScreenKey = GlobalKey<CartScreenState>();
  final _wishlistScreenKey = GlobalKey<WishlistScreenState>();
  int _index = 0;
  int _cartCount = 0;
  int _wishlistCount = 0;
  String _shopSearch = '';
  String? _shopCategory;

  @override
  void initState() {
    super.initState();
    _refreshNavCounts();
  }

  Future<void> _refreshNavCounts() async {
    if (!SupabaseService.ready) return;
    try {
      final cartCount = await SupabaseService.getCartCount();
      final wishlistCount = await SupabaseService.getWishlistCount();
      if (!mounted) return;
      setState(() {
        _cartCount = cartCount;
        _wishlistCount = wishlistCount;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _cartCount = 0;
          _wishlistCount = 0;
        });
      }
    }
  }

  void _setTab(int index) {
    if (index == 3) {
      _cartScreenKey.currentState?.reloadCart();
      _refreshNavCounts();
    }
    if (index == 2) {
      _wishlistScreenKey.currentState?.reloadWishlist();
      _refreshNavCounts();
    }
    setState(() => _index = index);
  }

  void _openShop(String query) {
    setState(() {
      _shopSearch = query;
      _shopCategory = null;
      _index = 1;
    });
  }

  void _openCategory(String categoryId) {
    setState(() {
      _shopSearch = '';
      _shopCategory = categoryId;
      _index = 1;
    });
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  LovelleLogo(),
                  SizedBox(height: 22),
                  Text(
                    'Connect your Supabase project',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Open lib/config/app_config.dart and add your Supabase project URL and anon/publishable key. Then run the app again.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 18),
                  SelectableText(
                    'lib/config/app_config.dart',
                    style: TextStyle(
                        color: giftlyPink, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!SupabaseService.ready) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  LovelleLogo(),
                  SizedBox(height: 22),
                  Text(
                    'Restart the app to connect',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Supabase settings changed after the app started. Stop and run the app again to initialize the connection.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (SupabaseService.userId == null) {
      return AuthScreen(onSignedIn: () => setState(() {}));
    }

    final pages = [
      HeroMode(
        enabled: _index == 0,
        child: HomeScreen(
          onShop: () => _openShop(''),
          onSearch: _openShop,
          onCategory: _openCategory,
          onNotifications: _openNotifications,
          onProduct: (Product product) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailsScreen(product: product),
            ),
          ),
        ),
      ),
      HeroMode(
        enabled: _index == 1,
        child: ShopScreen(
          key: ValueKey('$_shopSearch:$_shopCategory'),
          initialSearch: _shopSearch,
          initialCategoryId: _shopCategory,
          onProduct: (Product product) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailsScreen(product: product),
            ),
          ),
        ),
      ),
      HeroMode(
        enabled: _index == 2,
        child: WishlistScreen(
          key: _wishlistScreenKey,
          onShop: () => _openShop(''),
          onProduct: (Product product) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailsScreen(product: product),
            ),
          ),
        ),
      ),
      HeroMode(
        enabled: _index == 3,
        child: CartScreen(
          key: _cartScreenKey,
          onShop: () => _openShop(''),
        ),
      ),
      HeroMode(
        enabled: _index == 4,
        child: ProfileScreen(
          onSignOut: () => setState(() {}),
          onWishlist: () => _setTab(2),
        ),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _setTab,
        backgroundColor: Colors.white,
        indicatorColor: giftlyPink.withValues(alpha: 0.13),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Shop'),
          NavigationDestination(
              icon: _NavIconBadge(
                count: _wishlistCount,
                icon: const Icon(Icons.favorite_border),
              ),
              selectedIcon: _NavIconBadge(
                count: _wishlistCount,
                icon: const Icon(Icons.favorite),
              ),
              label: 'Wishlist'),
          NavigationDestination(
              icon: _NavIconBadge(
                count: _cartCount,
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
              selectedIcon: _NavIconBadge(
                count: _cartCount,
                icon: const Icon(Icons.shopping_bag),
              ),
              label: 'Cart'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
