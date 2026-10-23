import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawche_customer/config/supabase_service.dart';
import 'package:pawche_customer/data/bohol_address_repository.dart';
import 'package:pawche_customer/data/cart_store.dart';
import 'package:pawche_customer/data/demo_data.dart';
import 'package:pawche_customer/main.dart';
import 'package:pawche_customer/models/checkout.dart';
import 'package:pawche_customer/models/product.dart';
import 'package:pawche_customer/models/product_review.dart';
import 'package:pawche_customer/screens/cart_screen.dart';
import 'package:pawche_customer/screens/checkout_screen.dart';
import 'package:pawche_customer/screens/forgot_password_screen.dart';
import 'package:pawche_customer/screens/home_screen.dart';
import 'package:pawche_customer/screens/login_screen.dart';
import 'package:pawche_customer/screens/my_pets_screen.dart';
import 'package:pawche_customer/screens/order_history_screen.dart';
import 'package:pawche_customer/screens/payment_screen.dart';
import 'package:pawche_customer/screens/product_details_screen.dart';
import 'package:pawche_customer/screens/profile_screen.dart';
import 'package:pawche_customer/screens/register_screen.dart';
import 'package:pawche_customer/screens/shop_screen.dart';
import 'package:pawche_customer/screens/splash_screen.dart';
import 'package:pawche_customer/screens/wishlist_screen.dart';
import 'package:pawche_customer/widgets/common.dart';
import 'package:pawche_customer/widgets/product_card.dart';

Product _withLiveStock(
  Product product, {
  int stock = 5,
  String? price,
}) =>
    Product(
      id: product.id,
      name: product.name,
      category: product.category,
      price: price ?? product.price,
      emoji: product.emoji,
      description: product.description,
      stockQuantity: stock,
      imageUrl: product.imageUrl,
    );

ProductDetailsData _offlineProductDetails(Product product) =>
    ProductDetailsData(
      product: _withLiveStock(product),
      rating: const ProductRatingSummary.empty(),
      reviews: const [],
      stockQuantity: 5,
      userReviewStatus: null,
      isLive: false,
    );

void main() {
  testWidgets('order history loads live data instead of sample orders', (
    WidgetTester tester,
  ) async {
    if (SupabaseService.initializedClient?.auth.currentUser != null) return;

    await tester.pumpWidget(
      const MaterialApp(home: OrderHistoryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('PCH-2025-0421'), findsNothing);
    expect(find.text('PCH-2025-0415'), findsNothing);
    expect(find.text('Orders are temporarily unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'order history details explain status, items, delivery, and total', (
    WidgetTester tester,
  ) async {
    final entry = OrderHistoryEntry(
      order: const CheckoutOrder(
        id: 'order-id',
        referenceNumber: 'PCH-TEST-001',
        status: 'confirmed',
        paymentStatus: 'unpaid',
        paymentMethod: 'cod',
        totalAmount: 1,
      ),
      createdAt: DateTime.utc(2026, 10, 22, 8),
      items: const [
        OrderHistoryItem(
          productSlug: 'p3',
          productName: 'Pet Toy Ball',
          quantity: 1,
          unitPrice: 1,
        ),
      ],
      subtotal: 1,
      deliveryFee: 0,
      shippingAddress: {
        'full_name': 'Pet Parent',
        'address_line1': '12 Paw Street',
        'barangay': 'Poblacion',
        'municipality': 'Tagbilaran City',
        'province': 'Bohol',
        'phone': '09123456789',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [OrderHistoryCard(entry: entry, onTap: () {})],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order and payment status'), findsOneWidget);
    expect(find.text('Order confirmed'), findsOneWidget);
    expect(find.text('Due on delivery'), findsOneWidget);
    expect(find.text('Pay ₱1 in cash to the courier.'), findsOneWidget);
    expect(find.text('Items ordered'), findsOneWidget);
    expect(find.text('Pet Toy Ball'), findsOneWidget);
    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('Items subtotal'), findsOneWidget);
    expect(find.text('Delivery fee'), findsOneWidget);
    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('Cash due on delivery'), findsOneWidget);
    expect(find.textContaining('12 Paw Street'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pawche app shows the login screen after its loading splash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PawcheApp());
    expect(find.text('Loading Pawché…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Pawché'), findsOneWidget);
    expect(find.text('Welcome to Pawché!'), findsNothing);
  });

  testWidgets('splash screen fits a short viewport without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen()),
    );
    await tester.pump();

    expect(find.text('Loading Pawché…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(PetPhoto), findsNothing);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Get Started'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to Pawché'), findsOneWidget);
  });

  testWidgets('login is branded and usable on a narrow screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(
      find.text(
        'Welcome back, pet parent. Sign in to manage your orders and pet essentials.',
      ),
      findsOneWidget,
    );
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Continue in demo mode'), findsNothing);
    expect(find.text('Sign in to Pawché'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign in to my account'));
    await tester.tap(find.text('Sign in to my account'));
    await tester.pump();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('login screen provides a working create-account link', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    final createAccount = find.text("New to Pawché?  Create an account");
    await tester.ensureVisible(createAccount);
    await tester.tap(createAccount);
    await tester.pump();

    expect(find.text('Create your Pawché account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Phone number (optional)'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create my account'), findsOneWidget);
    expect(find.text('Create Your Account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup checks that both password entries match', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );
    await tester.tap(find.text("New to Pawché?  Create an account"));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'Pet Parent');
    await tester.enterText(find.byType(TextFormField).at(1), 'pet@example.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(4), 'different123');
    await tester.ensureVisible(find.text('Create my account'));
    await tester.tap(find.text('Create my account'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password visibility control has an accessible label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('unconfigured sign-in shows inline guidance without a snackbar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    if (SupabaseService.isConfigured) {
      expect(
        find.text('Supabase is not configured yet.'),
        findsNothing,
      );
      return;
    }

    await tester.enterText(find.byType(TextFormField).at(0), 'pet@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.ensureVisible(find.text('Sign in to my account'));
    await tester.tap(find.text('Sign in to my account'));
    await tester.pump();

    expect(
      find.textContaining('Supabase is not configured yet.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login has no path to the app without authenticating', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.text('Continue in demo mode'), findsNothing);
    await tester.ensureVisible(find.text('Sign in to my account'));
    await tester.tap(find.text('Sign in to my account'));
    await tester.pump();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Shop'), findsNothing);
  });

  testWidgets('home renders the cropped pet artwork and shop CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );
    await tester.pump();

    expect(find.text('Happy Pets,\nHappy Lives'), findsOneWidget);
    expect(find.text('Shop Now'), findsOneWidget);
    expect(find.byType(PetPhoto), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shop shows no local sample products when Supabase is offline', (
    WidgetTester tester,
  ) async {
    if (SupabaseService.initializedClient != null) return;

    await tester.pumpWidget(
      const MaterialApp(home: ShopScreen(initialCategory: 'Dogs')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Royal Canin Dog Food'), findsNothing);
    expect(find.text('Live catalog unavailable'), findsOneWidget);
    expect(find.textContaining('No sample items are shown.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product card uses supplied customer rating summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 180,
            height: 280,
            child: ProductCard(
              product: demoProducts.first,
              ratingSummary: const ProductRatingSummary(
                averageRating: 4.6,
                reviewCount: 12,
                ratingCounts: {5: 8, 4: 2, 3: 1, 2: 1, 1: 0},
              ),
              onTap: () {},
              onFavorite: () {},
              onAdd: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('4.6 · 12 reviews'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product card shows live stock count', (
    WidgetTester tester,
  ) async {
    final product = Product(
      id: demoProducts.first.id,
      name: demoProducts.first.name,
      category: demoProducts.first.category,
      price: '₱1',
      emoji: demoProducts.first.emoji,
      description: demoProducts.first.description,
      stockQuantity: 5,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 180,
            height: 280,
            child: ProductCard(
              product: product,
              onTap: () {},
              onFavorite: () {},
              onAdd: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('In stock · 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shop search and category controls work when catalog is offline',
      (
    WidgetTester tester,
  ) async {
    if (SupabaseService.initializedClient != null) return;

    await tester.pumpWidget(
      const MaterialApp(home: ShopScreen(initialCategory: 'Dogs')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cat food');
    await tester.pump();

    expect(find.text('0 products found'), findsOneWidget);
    expect(
      find.text('Live catalog unavailable'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);

    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cats').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Cats'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart quantities update checkout totals', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CartStore.instance.clear();
    CartStore.instance
      ..add(_withLiveStock(demoProducts[0]))
      ..add(_withLiveStock(demoProducts[2]))
      ..add(_withLiveStock(demoProducts[7]));
    addTearDown(CartStore.instance.clear);

    await tester.pumpWidget(
      MaterialApp(
        home: CartScreen(
          productsLoader: (slugs) async => [
            for (final slug in slugs)
              _withLiveStock(
                demoProducts.firstWhere((product) => product.id == slug),
                price: slug == 'p1' ? '₱2' : null,
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      CartStore.instance.lines
          .firstWhere((line) => line.product.id == 'p1')
          .product
          .price,
      '₱2',
    );
    expect(find.text('₱2 each'), findsOneWidget);
    await tester.tap(find.byTooltip('Add one').first);
    await tester.pump();

    expect(CartStore.instance.subtotal, 6);
    expect(find.textContaining('4 items in your cart'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('₱6'), findsNWidgets(2));
    final checkoutCta = find.textContaining('Continue to checkout');
    await tester.ensureVisible(checkoutCta);
    await tester.pumpAndSettle();
    await tester.tap(checkoutCta);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Estimated subtotal'), findsOneWidget);
    expect(find.text('Royal Canin Dog Food × 2'), findsOneWidget);
    expect(find.text('₱6'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart blocks checkout when a product is no longer active', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CartStore.instance.clear();
    CartStore.instance.add(_withLiveStock(demoProducts.first));
    addTearDown(CartStore.instance.clear);

    await tester.pumpWidget(
      MaterialApp(
        home: CartScreen(productsLoader: (_) async => []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No longer in the live catalog'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final checkoutCta = find.textContaining('Continue to checkout');
    await tester.ensureVisible(checkoutCta);
    await tester.pumpAndSettle();
    final checkoutButton = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byType(PinkButton),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(checkoutButton.onPressed, isNull);
    expect(find.text('Checkout'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wishlist shows live products with price stock and cart action', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CartStore.instance.clear();
    final product = _withLiveStock(demoProducts.first, stock: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: WishlistScreen(productsLoader: () async => [product]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Royal Canin Dog Food'), findsOneWidget);
    expect(find.text('₱1'), findsOneWidget);
    expect(find.text('Only 2 left'), findsOneWidget);
    await tester.tap(find.text('Add to cart'));
    await tester.pump();
    expect(CartStore.instance.itemCount, 1);
    expect(
        find.text('Royal Canin Dog Food added to your cart.'), findsOneWidget);
    CartStore.instance.clear();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty wishlist guides the user to live products', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: WishlistScreen(productsLoader: () async => []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved products yet'), findsOneWidget);
    expect(find.text('Explore live products'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product details adds to cart and starts Buy Now checkout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CartStore.instance.clear();
    addTearDown(CartStore.instance.clear);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailsScreen(
          product: demoProducts.first,
          detailsLoader: (product) async => _offlineProductDetails(product),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buy now'), findsOneWidget);
    expect(find.text('Add to cart'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    await tester.tap(find.text('Add to cart'));
    await tester.pump();

    expect(CartStore.instance.itemCount, 2);
    expect(find.text('2 items added to your cart.'), findsOneWidget);

    await tester.tap(find.text('Buy now'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout'), findsOneWidget);
    expect(find.textContaining('We’ll save them securely with your order.'),
        findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Royal Canin Dog Food × 2'), findsOneWidget);
    expect(find.text('₱2'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout requires delivery details before payment', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CheckoutScreen(
          lineItems: [
            CheckoutLineItem(
              productSlug: 'p1',
              name: 'Royal Canin Dog Food',
              quantity: 1,
              unitPrice: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Continue to Payment'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Continue to Payment'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required.'), findsWidgets);
    expect(find.text('Choose how to pay'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bohol barangay options follow the selected municipality', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CheckoutScreen(
          lineItems: [
            CheckoutLineItem(
              productSlug: 'p1',
              name: 'Royal Canin Dog Food',
              quantity: 1,
              unitPrice: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    expect(dropdowns, findsNWidgets(2));
    await tester.ensureVisible(dropdowns.first);
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    final municipalityOptions = tester.widgetList<DropdownMenuItem<String>>(
      find.byType(DropdownMenuItem<String>),
    );
    expect(municipalityOptions, isNotEmpty);
    final municipality = municipalityOptions.first.value!;
    await tester.tap(find.text(municipality).first);
    await tester.pumpAndSettle();

    expect(dropdowns, findsNWidgets(2));
    final barangayField = find.byKey(
      ValueKey('barangay-$municipality-'),
    );
    final barangayButton = find.descendant(
      of: barangayField,
      matching: find.byType(DropdownButton<String>),
    );
    final barangayOptions =
        tester.widget<DropdownButton<String>>(barangayButton).items!;
    final knownBarangays =
        (await BoholAddressRepository.loadLocations())[municipality]!.toSet();
    expect(barangayOptions, isNotEmpty);
    expect(
      barangayOptions.every((option) => knownBarangays.contains(option.value)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('payment step offers live methods and blocks empty orders', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: PaymentScreen(total: 4)),
    );
    expect(tester.takeException(), isNull);

    expect(find.text('₱4'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('PayMongo QRPH'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
    expect(find.text('PayMongo QRPH'), findsOneWidget);
    await tester.tap(find.text('PayMongo QRPH'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Show PayMongo QR'));
    expect(find.text('Show PayMongo QR'), findsOneWidget);
    expect(
      find.textContaining('A unique QRPH code will appear here for 5 minutes'),
      findsOneWidget,
    );
    await tester.tap(find.text('Show PayMongo QR'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(
      find.textContaining('Return to checkout and enter delivery details'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile wishlist entry opens the wishlist screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProfileScreen()),
    );

    await tester.tap(find.text('Wishlist'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar).last,
        matching: find.text('My Wishlist'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration validates before attempting account creation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: RegisterScreen()),
    );
    await tester.ensureVisible(find.text('Create my account'));
    await tester.tap(find.text('Create my account'));
    await tester.pump();

    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forgot password validates the email address', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ForgotPasswordScreen()),
    );
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('pet cards and product detail use reference imagery', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MyPetsScreen()),
    );
    await tester.pump();

    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Mochi'), findsOneWidget);
    expect(find.byType(PetAvatar), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailsScreen(
          product: demoProducts.first,
          detailsLoader: (product) async => _offlineProductDetails(product),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Royal Canin Dog Food'), findsOneWidget);
    expect(find.text('4.8'), findsNothing);
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Live product information and customer reviews'),
      findsOneWidget,
    );
    expect(find.text('Quantity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
