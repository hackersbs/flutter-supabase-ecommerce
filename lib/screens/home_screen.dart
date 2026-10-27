import 'package:e_comerce_appliction/provider/productprovider.dart';
import 'package:e_comerce_appliction/provider/orderditiyalce.dart';
import 'package:e_comerce_appliction/screens/account_screen.dart';
import 'package:e_comerce_appliction/screens/cart_screen.dart';
import 'package:e_comerce_appliction/screens/filter_screen.dart';
import 'package:e_comerce_appliction/screens/notifications_screen.dart';
import 'package:e_comerce_appliction/screens/message_screen.dart';
import 'package:e_comerce_appliction/screens/order_tracking_screen.dart';
import 'package:e_comerce_appliction/widgets/home_widgets.dart';
import 'package:e_comerce_appliction/data/catalog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:e_comerce_appliction/widgets/error_state.dart';
import 'package:speech_to_text/speech_to_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = context.read<OrderDitiyalce>();
      orderProvider.loadNotifications();
      orderProvider.subscribeToRealtimeNotifications();
    });
  }

  final List<Widget> _screens = const [
    HomePageContent(),
    FilterScreen(),
    CartScreen(),
    MessageScreen(),
    OrderTrackingScreen(),
    AccountScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.filter_list),
            label: 'Filter',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: 'Message',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Person'),
        ],
      ),
    );
  }
}

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final TextEditingController _searchController = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();
  String _selectedCategory = 'All';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Productprovider>().getProduct();
    });
  }

  Future<void> _toggleVoiceSearch() async {
    try {
      final available = await _speechToText.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _isListening = status == 'listening');
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voice search error: ${error.errorMsg}')),
          );
        },
      );

      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice search is not available on this device.'),
          ),
        );
        return;
      }

      if (_isListening) {
        await _speechToText.stop();
        setState(() => _isListening = false);
        return;
      }

      await _speechToText.listen(
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          setState(() {
            _searchController.text = words;
            _searchController.selection = TextSelection.collapsed(
              offset: words.length,
            );
          });
        },
      );
      setState(() => _isListening = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Voice search failed: $error')));
    }
  }

  @override
  void dispose() {
    _speechToText.stop();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? theme.colorScheme.surface
            : theme.colorScheme.primary,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'E-Commerce',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isDark ? theme.colorScheme.onSurface : Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // can be used to navigate to notifications screen if needed
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<Productprovider>().getProduct();
        },
        child: Consumer<Productprovider>(
          builder: (context, provider, child) {
            if (!provider.isLoading &&
                provider.errorMessage != null &&
                provider.products.isEmpty) {
              return ErrorState(
                message: provider.errorMessage!,
                onRetry: provider.getProduct,
              );
            }
            final query = _searchController.text.trim().toLowerCase();
            final searchTerms = smartSearchTerms(query);
            final filteredProducts = provider.products.where((product) {
              final name = (product['name'] ?? '').toString().toLowerCase();
              final productCategory = (product['category'] ?? 'General')
                  .toString()
                  .toLowerCase();
              final productSubcategory = (product['subcategory'] ?? '')
                  .toString()
                  .toLowerCase();
              final searchableText =
                  '$name $productCategory $productSubcategory';
              final matchesQuery =
                  query.isEmpty || searchTerms.any(searchableText.contains);
              final selectedCategory = _selectedCategory.toLowerCase();
              final matchesCategory =
                  selectedCategory == 'all' ||
                  productCategory == selectedCategory ||
                  productSubcategory == selectedCategory ||
                  (selectedCategory == 'footwear' &&
                      productCategory == 'fashion') ||
                  (selectedCategory == 'shoes' &&
                      productSubcategory.contains('shoe')) ||
                  (selectedCategory == 'boots' &&
                      productSubcategory.contains('boot'));

              return matchesQuery && matchesCategory;
            }).toList();
            final foodProducts = provider.products.where((product) {
              final category = (product['category'] ?? '')
                  .toString()
                  .toLowerCase();
              final subcategory = (product['subcategory'] ?? '')
                  .toString()
                  .toLowerCase();
              return category == 'food' ||
                  subcategory == 'food' ||
                  subcategory == 'snacks' ||
                  subcategory == 'beverages' ||
                  subcategory == 'bakery' ||
                  subcategory == 'grocery' ||
                  subcategory == 'organic';
            }).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SearchBarWidget(
                    controller: _searchController,
                    isListening: _isListening,
                    onMicPressed: _toggleVoiceSearch,
                    onChanged: (_) {
                      setState(() {});
                    },
                  ).animate().fade(delay: 100.ms).slideY(begin: 0.1),
                ),
                SliverToBoxAdapter(
                  child: CategoryWidget(
                    selectedCategory: _selectedCategory,
                    onCategorySelected: (category) {
                      setState(() {
                        _selectedCategory = category == _selectedCategory
                            ? 'All'
                            : category;
                      });
                    },
                  ).animate().fade(delay: 200.ms).slideX(begin: 0.05),
                ),
                SliverToBoxAdapter(
                  child: const HeroSectionWidget()
                      .animate()
                      .fade(delay: 300.ms)
                      .scale(begin: const Offset(0.95, 0.95)),
                ),
                if (provider.popularProducts.isNotEmpty &&
                    _searchController.text.trim().isEmpty &&
                    _selectedCategory == 'All')
                  SliverToBoxAdapter(
                    child: _HorizontalProductSection(
                      title: 'Most searched items',
                      products: provider.popularProducts,
                    ).animate().fade(delay: 350.ms).slideY(begin: 0.05),
                  ),
                if (_searchController.text.trim().isEmpty &&
                    _selectedCategory == 'All' &&
                    foodProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalProductSection(
                      title: 'Food picks',
                      products: foodProducts,
                    ).animate().fade(delay: 400.ms).slideY(begin: 0.05),
                  ),
                if (provider.likedProducts.isNotEmpty &&
                    _searchController.text.trim().isEmpty &&
                    _selectedCategory == 'All')
                  SliverToBoxAdapter(
                    child: _HorizontalProductSection(
                      title: 'Your favorites',
                      products: provider.likedProducts,
                    ).animate().fade(delay: 450.ms).slideY(begin: 0.05),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Recommended for You',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).animate().fade(delay: 400.ms),
                ),
                if (provider.isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filteredProducts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('No products found.')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.sizeOf(context).width >= 600
                            ? 4
                            : 2,
                        childAspectRatio: MediaQuery.sizeOf(context).width < 360
                            ? 0.68
                            : 0.75,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = filteredProducts[index];
                        return FlipkartCardWidget(product: product);
                      }, childCount: filteredProducts.length),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HorizontalProductSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> products;

  const _HorizontalProductSection({
    required this.title,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 275,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) => SizedBox(
                width: 180,
                child: FlipkartCardWidget(product: products[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
