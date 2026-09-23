import 'package:e_comerce_appliction/provider/productprovider.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Productprovider>().getProduct();
    });
  }

  @override
  void dispose() {
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
        title: Text(
          'E-Commerce',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
            color: isDark ? theme.colorScheme.onSurface : Colors.white,
          ),
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

            return CustomScrollView(
              slivers: [
                if (provider.likedProducts.isNotEmpty &&
                    _searchController.text.trim().isEmpty &&
                    _selectedCategory == 'All')
                  SliverToBoxAdapter(
                    child: _HorizontalProductSection(
                      title: 'Your favorites',
                      products: provider.likedProducts,
                    ),
                  ),
                if (provider.popularProducts.isNotEmpty &&
                    _searchController.text.trim().isEmpty &&
                    _selectedCategory == 'All')
                  SliverToBoxAdapter(
                    child: _HorizontalProductSection(
                      title: 'Popular with buyers',
                      products: provider.popularProducts,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SearchBarWidget(
                    controller: _searchController,
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
