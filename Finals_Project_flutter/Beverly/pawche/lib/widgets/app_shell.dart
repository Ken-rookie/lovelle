import 'package:flutter/material.dart';

import '../data/cart_store.dart';
import '../screens/cart_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/shop_screen.dart';
import '../screens/wishlist_screen.dart';
import '../theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final _cartKey = GlobalKey<CartScreenState>();
  final _wishlistKey = GlobalKey<WishlistScreenState>();

  late final pages = [
    HomeScreen(),
    ShopScreen(),
    CartScreen(key: _cartKey),
    WishlistScreen(key: _wishlistKey),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) {
            if (value == 2) _cartKey.currentState?.refreshLiveData();
            if (value == 3) _wishlistKey.currentState?.refresh();
            setState(() => index = value);
          },
          backgroundColor: Colors.white,
          indicatorColor: PawcheColors.blush,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              label: 'Shop',
            ),
            NavigationDestination(
              icon: AnimatedBuilder(
                animation: CartStore.instance,
                builder: (context, _) => Badge(
                  isLabelVisible: CartStore.instance.itemCount > 0,
                  label: Text(
                    CartStore.instance.itemCount > 99
                        ? '99+'
                        : '${CartStore.instance.itemCount}',
                  ),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              ),
              label: 'Cart',
            ),
            const NavigationDestination(
              icon: Icon(Icons.favorite_border),
              label: 'Wishlist',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      );
}
