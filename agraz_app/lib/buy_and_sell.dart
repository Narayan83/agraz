import 'package:flutter/material.dart';

import 'buy_sell_service.dart';
import 'config.dart';
import 'l10n/app_l10n.dart';

void main() {
  runApp(const BuySellApp());
}

class BuySellApp extends StatelessWidget {
  const BuySellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: tr('Buy & Sell'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black), // Color of back arrow
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              // Handle back button press
              // If this is the first screen, you might want to exit the app
              // or handle it differently
              Navigator.of(context).pop();
            },
          ),
          title: Text(tr('Buy & Sell')),
        ),
        body: const BuySellPage(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BuySellPage extends StatefulWidget {
  const BuySellPage({super.key});

  @override
  State<BuySellPage> createState() => _BuySellPageState();
}

class _BuySellPageState extends State<BuySellPage> {
  int _currentIndex = 0;
  List<Item> _items = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final raw = await fetchBuySellListingsRaw();
      final parsed = raw.map(Item.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _items = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Buy & Sell')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: ItemSearch(List.of(_items)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddItemPage()),
              ).then((value) {
                if (value != null) {
                  setState(() {
                    _items.add(value);
                  });
                }
              });
            },
          ),
        ],
      ),
      body:
          _currentIndex == 0
              ? RefreshIndicator(
                onRefresh: _loadItems,
                child: _buildBrowseBody(context),
              )
              : const MyItemsPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Browse',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'My Items'),
        ],
      ),
    );
  }

  Widget _buildBrowseBody(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 16),
          Center(child: Text(tr('Loading listings…'))),
        ],
      );
    }
    if (_loadError != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade600),
          SizedBox(height: 12),
          Text(
            'Could not load listings',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _loadItems,
              icon: const Icon(Icons.refresh),
              label: Text(tr('Retry')),
            ),
          ),
        ],
      );
    }
    return ItemsList(items: _items);
  }
}

class ItemsList extends StatelessWidget {
  final List<Item> items;

  ItemsList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return items.isEmpty
        ? Center(child: Text(tr('No items available')))
        : ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            return ItemCard(item: items[index]);
          },
        );
  }
}

class ItemCard extends StatelessWidget {
  final Item item;

  const ItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ItemDetailPage(item: item)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ItemImage(imageRef: item.imagePath, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '₹${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.category, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        item.category,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        item.seller,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        item.date,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ItemDetailPage extends StatelessWidget {
  final Item item;

  const ItemDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ItemImage(imageRef: item.imagePath, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '₹${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(item.description, style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.category),
                      SizedBox(width: 8),
                      Text('Category: ${item.category}'),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person),
                      SizedBox(width: 8),
                      Text('Seller: ${item.seller}'),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time),
                      SizedBox(width: 8),
                      Text('Posted: ${item.date}'),
                    ],
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        // Implement buy functionality
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text(tr('Confirm Purchase')),
                                content: Text(
                                  'Are you sure you want to buy ${item.title} for ₹${item.price.toStringAsFixed(2)}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(tr('Cancel')),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Purchase confirmed for ${item.title}!',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(tr('Confirm')),
                                  ),
                                ],
                              ),
                        );
                      },
                      child: Text(
                        'Buy Now',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        // Implement message seller functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr('Message sent to seller')),
                          ),
                        );
                      },
                      child: Text(
                        'Message Seller',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyItemsPage extends StatelessWidget {
  const MyItemsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.list_alt, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Your listed items will appear here',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddItemPage()),
              );
            },
            child: Text(tr('Add New Item')),
          ),
        ],
      ),
    );
  }
}

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  String _imagePath = 'assets/images/placeholder.jpg';

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Add New Item')),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final newItem = Item(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleController.text,
                  price: double.parse(_priceController.text),
                  description: _descriptionController.text,
                  imagePath: _imagePath,
                  category: _categoryController.text,
                  seller: 'You',
                  date: 'Just now',
                );
                Navigator.pop(context, newItem);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  // In a real app, you would implement image picking here
                  // For this example, we'll just cycle through some placeholder images
                  setState(() {
                    _imagePath =
                        [
                          'assets/images/camera.jpg',
                          'assets/images/jacket.jpg',
                          'assets/images/phone.jpg',
                          'assets/images/table.jpg',
                        ][DateTime.now().millisecond % 4];
                  });
                },
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: AssetImage(_imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child:
                      _imagePath == 'assets/images/placeholder.jpg'
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 48),
                                Text(tr('Add Photo')),
                              ],
                            ),
                          )
                          : null,
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: tr('Title'),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: tr('Price'),
                  border: OutlineInputBorder(),
                  prefixText: '₹',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: tr('Category'),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: tr('Description'),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class ItemSearch extends SearchDelegate<String> {
  final List<Item> items;

  ItemSearch(this.items);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results =
        items
            .where(
              (item) =>
                  item.title.toLowerCase().contains(query.toLowerCase()) ||
                  item.description.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  item.category.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();

    return ItemsList(items: results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions =
        query.isEmpty
            ? items
            : items
                .where(
                  (item) =>
                      item.title.toLowerCase().contains(query.toLowerCase()) ||
                      item.description.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      item.category.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();

    return ItemsList(items: suggestions);
  }
}

/// Uses [Image.network] for `http`/`https` URLs, otherwise [Image.asset].
class ItemImage extends StatelessWidget {
  final String imageRef;
  final BoxFit fit;

  const ItemImage({super.key, required this.imageRef, this.fit = BoxFit.cover});

  bool get _isNetwork {
    final u = Uri.tryParse(imageRef.trim());
    return u != null &&
        u.hasScheme &&
        (u.scheme == 'http' || u.scheme == 'https');
  }

  @override
  Widget build(BuildContext context) {
    final ref = imageRef.trim();
    if (ref.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported),
      );
    }
    if (_isNetwork) {
      return Image.network(
        ref,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final total = loadingProgress.expectedTotalBytes;
          final loaded = loadingProgress.cumulativeBytesLoaded;
          return Center(
            child: CircularProgressIndicator(
              value: total != null ? loaded / total : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
    }
    return Image.asset(
      ref,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported),
      ),
    );
  }
}

class Item {
  final String id;
  final String title;
  final double price;
  final String description;
  final String imagePath;
  final String category;
  final String seller;
  final String date;
  /// First variant id for `POST /api/store/cart/items` (`variant_id` + `quantity`).
  final String? storeVariantId;

  Item({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.imagePath,
    required this.category,
    required this.seller,
    required this.date,
    this.storeVariantId,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    final hasVariants = json['variants'] is List && (json['variants'] as List).isNotEmpty;
    if (hasVariants) {
      return Item.fromStoreProduct(json);
    }

    String pick(Map<String, dynamic> m, List<String> keys, [String fallback = '']) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return fallback;
    }

    double priceVal = 0;
    final p = json['price'] ?? json['amount'] ?? json['cost'];
    if (p is num) {
      priceVal = p.toDouble();
    } else if (p != null) {
      priceVal = double.tryParse(p.toString()) ?? 0;
    }

    final rawImage = pick(json, [
      'image_url',
      'imageUrl',
      'image',
      'photo',
      'thumbnail_url',
      'thumbnailUrl',
      'image_path',
      'imagePath',
    ]);
    final image = resolveStoreMediaUrl(rawImage);

    return Item(
      id: pick(json, ['id', '_id'], DateTime.now().millisecondsSinceEpoch.toString()),
      title: pick(json, ['title', 'name', 'product_name'], 'Untitled'),
      price: priceVal,
      description: pick(json, ['description', 'desc', 'details', 'detail'], ''),
      imagePath: image,
      category: pick(json, ['category', 'type', 'tags'], ''),
      seller: pick(json, ['seller', 'seller_name', 'user', 'posted_by', 'owner'], ''),
      date: pick(json, [
        'date',
        'posted',
        'posted_at',
        'created_at',
        'updated_at',
      ], ''),
    );
  }

  /// Dashboard `GET /api/store/products` row (product + `variants[]` + `images[]`).
  factory Item.fromStoreProduct(Map<String, dynamic> json) {
    String pick(Map<String, dynamic> m, List<String> keys, [String fallback = '']) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return fallback;
    }

    Map<String, dynamic>? firstVariant;
    final variants = json['variants'];
    if (variants is List && variants.isNotEmpty) {
      final v0 = variants.first;
      if (v0 is Map) firstVariant = Map<String, dynamic>.from(v0);
    }

    double priceVal = 0;
    if (firstVariant != null) {
      final vp = firstVariant['price'] ?? firstVariant['amount'] ?? firstVariant['unit_price'];
      if (vp is num) {
        priceVal = vp.toDouble();
      } else if (vp != null) {
        priceVal = double.tryParse(vp.toString()) ?? 0;
      }
    }
    if (priceVal == 0) {
      final pp = json['price'] ?? json['amount'] ?? json['base_price'];
      if (pp is num) {
        priceVal = pp.toDouble();
      } else if (pp != null) {
        priceVal = double.tryParse(pp.toString()) ?? 0;
      }
    }

    String rawImage = '';
    if (firstVariant != null) {
      rawImage = pick(firstVariant, ['image_url', 'imageUrl', 'thumbnail_url', 'thumbnailUrl']);
    }
    if (rawImage.isEmpty) {
      final images = json['images'];
      if (images is List && images.isNotEmpty) {
        final im0 = images.first;
        if (im0 is Map) {
          rawImage = pick(Map<String, dynamic>.from(im0), [
            'image_url',
            'imageUrl',
            'url',
            'thumbnail_url',
          ]);
        }
      }
    }
    if (rawImage.isEmpty) {
      rawImage = pick(json, ['image_url', 'imageUrl', 'thumbnail_url', 'cover_image']);
    }

    final imagePath = resolveStoreMediaUrl(rawImage);

    String? variantIdStr;
    if (firstVariant != null && firstVariant['id'] != null) {
      variantIdStr = firstVariant['id'].toString();
    }

    final seller = pick(json, [
      'seller',
      'seller_name',
      'vendor_name',
      'shop_name',
      'owner',
      'brand',
    ], '');

    return Item(
      id: pick(json, ['id', '_id', 'product_id'], DateTime.now().millisecondsSinceEpoch.toString()),
      title: pick(json, ['title', 'name', 'product_name', 'slug'], 'Untitled'),
      price: priceVal,
      description: pick(json, ['description', 'desc', 'summary', 'details'], ''),
      imagePath: imagePath,
      category: pick(json, ['category', 'type', 'sku', 'department'], ''),
      seller: seller,
      date: pick(json, ['updated_at', 'created_at', 'posted_at', 'date'], ''),
      storeVariantId: variantIdStr,
    );
  }
}
