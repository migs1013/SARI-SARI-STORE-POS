import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SariSariApp());
}

class SariSariApp extends StatelessWidget {
  const SariSariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sari-Sari Store',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Trebuchet MS',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF166534),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF14532D),
          secondary: const Color(0xFFD97706),
          surface: const Color(0xFFFFFBF3),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class Product {
  final String name;
  final int priceCentavos;
  final int initialStockQty;
  final String category;

  const Product(
    this.name,
    this.priceCentavos,
    this.initialStockQty,
    this.category,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'priceCentavos': priceCentavos,
      'initialStockQty': initialStockQty,
      'category': category,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      json['name'] as String? ?? 'Unnamed',
      json['priceCentavos'] as int? ?? 0,
      json['initialStockQty'] as int? ?? 0,
      json['category'] as String? ?? 'Others',
    );
  }
}

class SaleRecord {
  final DateTime soldAt;
  final int itemCount;
  final int totalCentavos;
  final int paymentCentavos;
  final int changeCentavos;
  final int discountCentavos;
  final int costCentavos;
  final int grossProfitCentavos;
  final String note;
  final Map<String, int> itemsByProduct;

  const SaleRecord({
    required this.soldAt,
    required this.itemCount,
    required this.totalCentavos,
    required this.paymentCentavos,
    required this.changeCentavos,
    required this.discountCentavos,
    required this.costCentavos,
    required this.grossProfitCentavos,
    required this.note,
    required this.itemsByProduct,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'soldAt': soldAt.toIso8601String(),
      'itemCount': itemCount,
      'totalCentavos': totalCentavos,
      'paymentCentavos': paymentCentavos,
      'changeCentavos': changeCentavos,
      'discountCentavos': discountCentavos,
      'costCentavos': costCentavos,
      'grossProfitCentavos': grossProfitCentavos,
      'note': note,
      'itemsByProduct': itemsByProduct,
    };
  }

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawItems =
        json['itemsByProduct'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return SaleRecord(
      soldAt: DateTime.tryParse(json['soldAt'] as String? ?? '') ?? DateTime.now(),
      itemCount: json['itemCount'] as int? ?? 0,
      totalCentavos: json['totalCentavos'] as int? ?? 0,
      paymentCentavos: json['paymentCentavos'] as int? ?? 0,
      changeCentavos: json['changeCentavos'] as int? ?? 0,
      discountCentavos: json['discountCentavos'] as int? ?? 0,
      costCentavos: json['costCentavos'] as int? ?? 0,
      grossProfitCentavos: json['grossProfitCentavos'] as int? ?? 0,
      note: json['note'] as String? ?? '',
      itemsByProduct: rawItems.map(
        (String key, dynamic value) => MapEntry<String, int>(key, value as int? ?? 0),
      ),
    );
  }
}

class CheckoutData {
  final int paymentCentavos;
  final int discountCentavos;
  final String note;

  const CheckoutData({
    required this.paymentCentavos,
    required this.discountCentavos,
    required this.note,
  });
}

class ExpenseRecord {
  final String title;
  final int amountCentavos;
  final DateTime spentAt;

  const ExpenseRecord({
    required this.title,
    required this.amountCentavos,
    required this.spentAt,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'amountCentavos': amountCentavos,
      'spentAt': spentAt.toIso8601String(),
    };
  }

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ExpenseRecord(
      title: json['title'] as String? ?? 'Expense',
      amountCentavos: json['amountCentavos'] as int? ?? 0,
      spentAt: DateTime.tryParse(json['spentAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class LedgerEntry {
  final String customerName;
  final String type;
  final int amountCentavos;
  final String note;
  final DateTime createdAt;

  const LedgerEntry({
    required this.customerName,
    required this.type,
    required this.amountCentavos,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'customerName': customerName,
      'type': type,
      'amountCentavos': amountCentavos,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      customerName: json['customerName'] as String? ?? 'Customer',
      type: json['type'] as String? ?? 'utang',
      amountCentavos: json['amountCentavos'] as int? ?? 0,
      note: json['note'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _forest = Color(0xFF14532D);
  static const Color _moss = Color(0xFF2E7D32);
  static const Color _sunset = Color(0xFFD97706);
  static const Color _cream = Color(0xFFFFFBF3);
  static const String _storageKey = 'sari_pos_state_v1';

  final List<Product> products = <Product>[
    Product('Coke 290ml', 2000, 20, 'Beverages'),
    Product('3-in-1 Coffee', 1200, 25, 'Beverages'),
    Product('Instant Noodles', 1500, 30, 'Food'),
    Product('Sardines Can', 2500, 16, 'Food'),
    Product('Rice (1kg)', 5000, 18, 'Rice'),
    Product('Bath Soap', 1800, 14, 'Personal Care'),
    Product('Shampoo Sachet', 700, 40, 'Personal Care'),
    Product('Biscuits Pack', 1000, 22, 'Snacks'),
  ];

  int totalSalesCentavos = 0;
  final Map<String, int> _stockByName = <String, int>{};
  final Map<String, int> _cartByName = <String, int>{};
  final Map<String, int> _priceByName = <String, int>{};
  final Map<String, int> _costByName = <String, int>{};
  final List<SaleRecord> _sales = <SaleRecord>[];
  final List<ExpenseRecord> _expenses = <ExpenseRecord>[];
  final List<LedgerEntry> _ledger = <LedgerEntry>[];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _highContrastMode = false;

  @override
  void initState() {
    super.initState();
    for (final Product product in products) {
      _stockByName[product.name] = product.initialStockQty;
      _priceByName[product.name] = product.priceCentavos;
      _costByName[product.name] = (product.priceCentavos * 70 ~/ 100);
    }
    unawaited(_loadSavedState());
  }

  List<String> get categories {
    final Set<String> set = <String>{};
    for (final Product product in products) {
      set.add(product.category);
    }
    final List<String> list = set.toList()..sort();
    return <String>['All', ...list];
  }

  List<Product> get visibleProducts {
    final String query = _searchQuery.toLowerCase().trim();
    final List<Product> filtered = products.where((Product p) {
      final bool categoryMatch = _selectedCategory == 'All' || p.category == _selectedCategory;
      final bool searchMatch = query.isEmpty || p.name.toLowerCase().contains(query);
      return categoryMatch && searchMatch;
    }).toList();

    filtered.sort((Product a, Product b) {
      if (_selectedCategory == 'All') {
        final int categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare != 0) {
          return categoryCompare;
        }
      }
      return a.name.compareTo(b.name);
    });

    return filtered;
  }

  List<Object> get visibleListEntries {
    final List<Product> items = visibleProducts;
    if (_selectedCategory != 'All') {
      return items;
    }

    final List<Object> entries = <Object>[];
    String? currentCategory;
    for (final Product product in items) {
      if (product.category != currentCategory) {
        currentCategory = product.category;
        entries.add(currentCategory);
      }
      entries.add(product);
    }
    return entries;
  }

  Future<void> _loadSavedState() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      final Map<String, dynamic> data =
          jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, dynamic> stockData =
          data['stockByName'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final Map<String, dynamic> cartData =
          data['cartByName'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final Map<String, dynamic> priceData =
          data['priceByName'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final Map<String, dynamic> costData =
          data['costByName'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final List<dynamic> salesData = data['sales'] as List<dynamic>? ?? <dynamic>[];
        final List<dynamic> expensesData = data['expenses'] as List<dynamic>? ?? <dynamic>[];
        final List<dynamic> ledgerData = data['ledger'] as List<dynamic>? ?? <dynamic>[];

      if (!mounted) {
        return;
      }

      setState(() {
        totalSalesCentavos = data['totalSalesCentavos'] as int? ?? 0;

        for (final Product product in products) {
          _stockByName[product.name] =
              stockData[product.name] as int? ?? product.initialStockQty;
        }

        _cartByName
          ..clear()
          ..addEntries(
            cartData.entries
                .where((MapEntry<String, dynamic> e) => (e.value as int? ?? 0) > 0)
                .map(
                  (MapEntry<String, dynamic> e) =>
                      MapEntry<String, int>(e.key, e.value as int? ?? 0),
                ),
          );

        for (final Product product in products) {
          _priceByName[product.name] =
              priceData[product.name] as int? ?? product.priceCentavos;
          _costByName[product.name] =
              costData[product.name] as int? ?? (product.priceCentavos * 70 ~/ 100);
        }

        _selectedCategory = data['selectedCategory'] as String? ?? 'All';
        if (!categories.contains(_selectedCategory)) {
          _selectedCategory = 'All';
        }
        _highContrastMode = data['highContrastMode'] as bool? ?? false;

        _sales
          ..clear()
          ..addAll(
            salesData
                .whereType<Map<String, dynamic>>()
                .map(SaleRecord.fromJson)
                .toList(),
          );

        _expenses
          ..clear()
          ..addAll(
            expensesData
                .whereType<Map<String, dynamic>>()
                .map(ExpenseRecord.fromJson)
                .toList(),
          );

        _ledger
          ..clear()
          ..addAll(
            ledgerData
                .whereType<Map<String, dynamic>>()
                .map(LedgerEntry.fromJson)
                .toList(),
          );
      });
    } on MissingPluginException {
      // shared_preferences may not be registered in a stale hot-reload session.
    } catch (_) {
      // Ignore corrupted local state and continue with defaults.
    }
  }

  Future<void> _saveState() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = <String, dynamic>{
        'totalSalesCentavos': totalSalesCentavos,
        'stockByName': _stockByName,
        'cartByName': _cartByName,
        'priceByName': _priceByName,
        'costByName': _costByName,
        'selectedCategory': _selectedCategory,
        'highContrastMode': _highContrastMode,
        'sales': _sales.map((SaleRecord s) => s.toJson()).toList(),
        'expenses': _expenses.map((ExpenseRecord e) => e.toJson()).toList(),
        'ledger': _ledger.map((LedgerEntry entry) => entry.toJson()).toList(),
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } on MissingPluginException {
      // Skip persistence if the plugin is temporarily unavailable.
    }
  }

  void persistState() {
    unawaited(_saveState());
  }

  void addToCart(Product product) {
    addQuantityToCart(product, 1);
  }

  void addQuantityToCart(Product product, int quantity, {bool showMessage = false}) {
    final int available = remainingStock(product);
    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} is out of stock.')),
      );
      return;
    }

    final int qtyToAdd = quantity > available ? available : quantity;

    setState(() {
      final int currentQty = _cartByName[product.name] ?? 0;
      _cartByName[product.name] = currentQty + qtyToAdd;
    });
    persistState();

    if (showMessage) {
      final String message = qtyToAdd == quantity
          ? 'Added $qtyToAdd ${product.name} to cart.'
          : 'Only $qtyToAdd ${product.name} added. Remaining stock limit reached.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void removeFromCart(Product product) {
    setState(() {
      final int currentQty = _cartByName[product.name] ?? 0;
      if (currentQty <= 1) {
        _cartByName.remove(product.name);
      } else {
        _cartByName[product.name] = currentQty - 1;
      }
    });
    persistState();
  }

  int stockFor(Product product) {
    return _stockByName[product.name] ?? 0;
  }

  int priceFor(Product product) {
    return _priceByName[product.name] ?? product.priceCentavos;
  }

  int costFor(Product product) {
    return _costByName[product.name] ?? (product.priceCentavos * 70 ~/ 100);
  }

  int cartQty(Product product) {
    return _cartByName[product.name] ?? 0;
  }

  int remainingStock(Product product) {
    return stockFor(product) - cartQty(product);
  }

  int get cartTotalCentavos {
    int total = 0;
    for (final Product product in products) {
      total += cartQty(product) * priceFor(product);
    }
    return total;
  }

  Future<void> openInventoryManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded, color: _forest),
                    const SizedBox(width: 8),
                    const Text(
                      'Inventory manager',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: addNewProduct,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Product'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: products.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Product product = products[index];
                      final int stock = stockFor(product);
                      final bool low = stock <= 3;
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEAF5EC),
                            child: Text(
                              product.name.characters.first,
                              style: const TextStyle(
                                color: _forest,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.category} | Price: ${formatPeso(priceFor(product))} | Cost: ${formatPeso(costFor(product))}',
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              Chip(
                                label: Text(
                                  low ? 'Low: $stock' : 'Stock: $stock',
                                  style: TextStyle(
                                    color: low
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF374151),
                                  ),
                                ),
                                backgroundColor: low
                                    ? const Color(0xFFFFE4E6)
                                    : const Color(0xFFF3F4F6),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _stockByName[product.name] = stockFor(product) + 1;
                                  });
                                  persistState();
                                },
                                tooltip: 'Restock +1',
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                              IconButton(
                                onPressed: () => editProductPrice(product),
                                tooltip: 'Edit price',
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => editProductCost(product),
                                tooltip: 'Edit cost',
                                icon: const Icon(Icons.price_change_outlined),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> editProductPrice(Product product) async {
    final TextEditingController controller = TextEditingController(
      text: (priceFor(product) / 100).toStringAsFixed(2),
    );

    final int? newPrice = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit price: ${product.name}'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (peso)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final int parsed = parsePesoToCentavos(controller.text);
                if (parsed <= 0) {
                  return;
                }
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newPrice == null) {
      return;
    }

    setState(() {
      _priceByName[product.name] = newPrice;
    });
    persistState();
  }

  Future<void> editProductCost(Product product) async {
    final TextEditingController controller = TextEditingController(
      text: (costFor(product) / 100).toStringAsFixed(2),
    );

    final int? newCost = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit cost: ${product.name}'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cost (peso)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final int parsed = parsePesoToCentavos(controller.text);
                if (parsed <= 0) {
                  return;
                }
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newCost == null) {
      return;
    }

    setState(() {
      _costByName[product.name] = newCost;
    });
    persistState();
  }

  Future<void> addNewProduct() async {
    final TextEditingController nameController = TextEditingController();
    final List<String> selectableCategories =
      categories.where((String c) => c != 'All').toList();
    final TextEditingController newCategoryController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    final TextEditingController costController = TextEditingController();
    final TextEditingController stockController = TextEditingController(text: '1');
    String selectedCategory = selectableCategories.isNotEmpty
      ? selectableCategories.first
      : 'Others';
    bool useNewCategory = false;
    String error = '';

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Add Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: useNewCategory ? '__new__' : selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: <DropdownMenuItem<String>>[
                        ...selectableCategories.map(
                          (String category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        ),
                        const DropdownMenuItem<String>(
                          value: '__new__',
                          child: Text('Add new category'),
                        ),
                      ],
                      onChanged: (String? value) {
                        setDialogState(() {
                          useNewCategory = value == '__new__';
                          if (!useNewCategory && value != null) {
                            selectedCategory = value;
                          }
                        });
                      },
                    ),
                    if (useNewCategory) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: newCategoryController,
                        decoration: const InputDecoration(
                          labelText: 'New category name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Price (peso)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Initial stock',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: costController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cost (peso)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String name = nameController.text.trim();
                    final String category = useNewCategory
                        ? newCategoryController.text.trim()
                        : selectedCategory;
                    final int price = parsePesoToCentavos(priceController.text);
                    final int cost = parsePesoToCentavos(costController.text);
                    final int stock = int.tryParse(stockController.text.trim()) ?? 0;

                    if (name.isEmpty || category.isEmpty) {
                      setDialogState(() {
                        error = 'Name and category are required.';
                      });
                      return;
                    }
                    if (price <= 0) {
                      setDialogState(() {
                        error = 'Price must be greater than 0.';
                      });
                      return;
                    }
                    if (stock <= 0) {
                      setDialogState(() {
                        error = 'Stock must be at least 1.';
                      });
                      return;
                    }
                    if (cost <= 0) {
                      setDialogState(() {
                        error = 'Cost must be greater than 0.';
                      });
                      return;
                    }
                    final bool exists = products.any(
                      (Product p) => p.name.toLowerCase() == name.toLowerCase(),
                    );
                    if (exists) {
                      setDialogState(() {
                        error = 'Product name already exists.';
                      });
                      return;
                    }

                    Navigator.of(context).pop(<String, dynamic>{
                      'product': Product(name, price, stock, category),
                      'cost': cost,
                    });
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    final Product? newProduct = result?['product'] as Product?;
    final int newCost = result?['cost'] as int? ?? 0;

    if (newProduct == null) {
      return;
    }

    setState(() {
      products.add(newProduct);
      _stockByName[newProduct.name] = newProduct.initialStockQty;
      _priceByName[newProduct.name] = newProduct.priceCentavos;
      _costByName[newProduct.name] = newCost;
      if (_selectedCategory != 'All' && _selectedCategory != newProduct.category) {
        _selectedCategory = 'All';
      }
    });
    persistState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newProduct.name} added to inventory.')),
      );
    }
  }

  int get cartItemCount {
    int count = 0;
    for (final int qty in _cartByName.values) {
      count += qty;
    }
    return count;
  }

  int get todaySalesCentavos {
    final DateTime now = DateTime.now();
    int total = 0;
    for (final SaleRecord sale in _sales) {
      if (isSameDay(sale.soldAt, now)) {
        total += sale.totalCentavos;
      }
    }
    return total;
  }

  int get todayCostCentavos {
    final DateTime now = DateTime.now();
    int total = 0;
    for (final SaleRecord sale in _sales) {
      if (isSameDay(sale.soldAt, now)) {
        total += sale.costCentavos;
      }
    }
    return total;
  }

  int get todayGrossProfitCentavos {
    return todaySalesCentavos - todayCostCentavos;
  }

  int get todayExpensesCentavos {
    final DateTime now = DateTime.now();
    int total = 0;
    for (final ExpenseRecord expense in _expenses) {
      if (isSameDay(expense.spentAt, now)) {
        total += expense.amountCentavos;
      }
    }
    return total;
  }

  int get todayNetCentavos {
    return todayGrossProfitCentavos - todayExpensesCentavos;
  }

  Map<String, int> get customerBalances {
    final Map<String, int> balances = <String, int>{};
    for (final LedgerEntry entry in _ledger) {
      final int current = balances[entry.customerName] ?? 0;
      if (entry.type == 'utang') {
        balances[entry.customerName] = current + entry.amountCentavos;
      } else {
        final int next = current - entry.amountCentavos;
        balances[entry.customerName] = next < 0 ? 0 : next;
      }
    }
    return balances;
  }

  bool isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String formatDate(DateTime dateTime) {
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String dateKey(DateTime dateTime) {
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  List<DateTime> get saleDates {
    final Map<String, DateTime> uniqueDates = <String, DateTime>{};
    for (final SaleRecord sale in _sales) {
      uniqueDates[dateKey(sale.soldAt)] = DateTime(
        sale.soldAt.year,
        sale.soldAt.month,
        sale.soldAt.day,
      );
    }

    final List<DateTime> dates = uniqueDates.values.toList();
    dates.sort((DateTime a, DateTime b) => b.compareTo(a));
    return dates;
  }

  List<DateTime> get expenseDates {
    final Map<String, DateTime> uniqueDates = <String, DateTime>{};
    for (final ExpenseRecord expense in _expenses) {
      uniqueDates[dateKey(expense.spentAt)] = DateTime(
        expense.spentAt.year,
        expense.spentAt.month,
        expense.spentAt.day,
      );
    }

    final List<DateTime> dates = uniqueDates.values.toList();
    dates.sort((DateTime a, DateTime b) => b.compareTo(a));
    return dates;
  }

  List<SaleRecord> salesForDate(DateTime date) {
    return _sales.where((SaleRecord sale) => isSameDay(sale.soldAt, date)).toList()
      ..sort((SaleRecord a, SaleRecord b) => b.soldAt.compareTo(a.soldAt));
  }

  int totalForDate(DateTime date) {
    int total = 0;
    for (final SaleRecord sale in salesForDate(date)) {
      total += sale.totalCentavos;
    }
    return total;
  }

  List<ExpenseRecord> expensesForDate(DateTime date) {
    return _expenses
        .where((ExpenseRecord expense) => isSameDay(expense.spentAt, date))
        .toList()
      ..sort((ExpenseRecord a, ExpenseRecord b) => b.spentAt.compareTo(a.spentAt));
  }

  int totalExpensesForDate(DateTime date) {
    int total = 0;
    for (final ExpenseRecord expense in expensesForDate(date)) {
      total += expense.amountCentavos;
    }
    return total;
  }

  Future<void> addExpense() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    String error = '';

    final ExpenseRecord? newExpense = await showDialog<ExpenseRecord>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Add Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Expense name',
                        hintText: 'e.g. Load, Delivery, Electricity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (peso)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String title = titleController.text.trim();
                    final int amount = parsePesoToCentavos(amountController.text);

                    if (title.isEmpty) {
                      setDialogState(() {
                        error = 'Expense name is required.';
                      });
                      return;
                    }
                    if (amount <= 0) {
                      setDialogState(() {
                        error = 'Amount must be greater than 0.';
                      });
                      return;
                    }

                    Navigator.of(context).pop(
                      ExpenseRecord(
                        title: title,
                        amountCentavos: amount,
                        spentAt: DateTime.now(),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newExpense == null) {
      return;
    }

    setState(() {
      _expenses.insert(0, newExpense);
    });
    persistState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Expense saved: ${newExpense.title}')),
      );
    }
  }

  Future<void> openExpensesForDate(DateTime date) async {
    final List<ExpenseRecord> expenses = expensesForDate(date);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_rounded, color: _sunset),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Expenses • ${formatDate(date)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'Entries: ${expenses.length} | Total: ${formatPeso(totalExpensesForDate(date))}',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (expenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No expenses found for this date.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: expenses.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final ExpenseRecord expense = expenses[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(
                              expense.title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(formatTime(expense.spentAt)),
                            trailing: Text(
                              formatPeso(expense.amountCentavos),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _sunset,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> openExpensesTracker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wallet_rounded, color: _sunset),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Expenses Tracker',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: addExpense,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today: ${formatDate(DateTime.now())}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('Expenses: ${formatPeso(todayExpensesCentavos)}'),
                      Text('Net after expenses: ${formatPeso(todayNetCentavos)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (expenseDates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No saved expenses yet.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: expenseDates.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final DateTime date = expenseDates[index];
                        final List<ExpenseRecord> expenses = expensesForDate(date);
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            onTap: () => openExpensesForDate(date),
                            title: Text(
                              formatDate(date),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${expenses.length} entries | Total: ${formatPeso(totalExpensesForDate(date))}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> addLedgerEntry(String type) async {
    final List<String> borrowerNames = customerBalances.entries
        .where((MapEntry<String, int> entry) => entry.value > 0)
        .map((MapEntry<String, int> entry) => entry.key)
        .toList()
      ..sort();
    final TextEditingController customerController = TextEditingController(
      text: type == 'payment' && borrowerNames.isNotEmpty ? borrowerNames.first : '',
    );
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    String selectedBorrower = borrowerNames.isNotEmpty ? borrowerNames.first : '';
    String error = '';

    final LedgerEntry? entry = await showDialog<LedgerEntry>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(type == 'utang' ? 'Add Utang' : 'Record Payment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (type == 'payment' && borrowerNames.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedBorrower,
                        decoration: const InputDecoration(
                          labelText: 'Payment name',
                          border: OutlineInputBorder(),
                        ),
                        items: borrowerNames
                            .map(
                              (String name) => DropdownMenuItem<String>(
                                value: name,
                                child: Text(name),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          setDialogState(() {
                            selectedBorrower = value ?? selectedBorrower;
                            customerController.text = selectedBorrower;
                          });
                        },
                      )
                    else
                      TextField(
                        controller: customerController,
                        decoration: InputDecoration(
                          labelText: type == 'payment' ? 'Payment name' : 'Customer name',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (peso)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String customer = customerController.text.trim();
                    final int amount = parsePesoToCentavos(amountController.text);
                    if (customer.isEmpty) {
                      setDialogState(() {
                        error = 'Customer name is required.';
                      });
                      return;
                    }
                    if (amount <= 0) {
                      setDialogState(() {
                        error = 'Amount must be greater than 0.';
                      });
                      return;
                    }

                    Navigator.of(context).pop(
                      LedgerEntry(
                        customerName: customer,
                        type: type,
                        amountCentavos: amount,
                        note: noteController.text.trim(),
                        createdAt: DateTime.now(),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (entry == null) {
      return;
    }

    setState(() {
      _ledger.insert(0, entry);
    });
    persistState();
  }

  Future<void> openUtangLedger() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final Map<String, int> balances = customerBalances;
        final List<String> customers = balances.keys.toList()..sort();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: _forest),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Utang Ledger',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => addLedgerEntry('utang'),
                      child: const Text('Add Utang'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () => addLedgerEntry('payment'),
                      child: const Text('Payment'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (customers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No ledger entries yet.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: customers.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final String customer = customers[index];
                        final int balance = balances[customer] ?? 0;
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            onTap: () => openCustomerLedgerDetails(customer),
                            title: Text(
                              customer,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(balance > 0 ? 'Outstanding utang' : 'Paid / no balance'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatPeso(balance),
                                  style: TextStyle(
                                    color: balance > 0 ? const Color(0xFFB91C1C) : const Color(0xFF166534),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<LedgerEntry> ledgerEntriesForCustomer(String customerName) {
    return _ledger
        .where((LedgerEntry entry) => entry.customerName == customerName)
        .toList()
      ..sort((LedgerEntry a, LedgerEntry b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> openCustomerLedgerDetails(String customerName) async {
    final List<LedgerEntry> entries = ledgerEntriesForCustomer(customerName);
    int runningBalance = 0;
    for (final LedgerEntry entry in entries.reversed) {
      if (entry.type == 'utang') {
        runningBalance += entry.amountCentavos;
      } else {
        runningBalance -= entry.amountCentavos;
        if (runningBalance < 0) {
          runningBalance = 0;
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_box_rounded, color: _forest),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        customerName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'Outstanding balance: ${formatPeso(runningBalance)}',
                  style: TextStyle(
                    color: runningBalance > 0 ? const Color(0xFFB91C1C) : const Color(0xFF166534),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No ledger history yet.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final LedgerEntry entry = entries[index];
                        final bool isUtang = entry.type == 'utang';
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(
                              isUtang ? 'Utang added' : 'Payment made',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${formatDate(entry.createdAt)} ${formatTime(entry.createdAt)}${entry.note.isNotEmpty ? '\n${entry.note}' : ''}',
                            ),
                            isThreeLine: entry.note.isNotEmpty,
                            trailing: Text(
                              '${isUtang ? '+' : '-'}${formatPeso(entry.amountCentavos)}',
                              style: TextStyle(
                                color: isUtang ? const Color(0xFFB91C1C) : const Color(0xFF166534),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<SaleRecord> salesForPeriod(String period) {
    final DateTime now = DateTime.now();
    if (period == 'day') {
      return _sales.where((SaleRecord sale) => isSameDay(sale.soldAt, now)).toList();
    }
    if (period == 'week') {
      final DateTime start = now.subtract(const Duration(days: 6));
      return _sales
          .where((SaleRecord sale) =>
              sale.soldAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
              sale.soldAt.isBefore(now.add(const Duration(days: 1))))
          .toList();
    }
    final DateTime startOfMonth = DateTime(now.year, now.month, 1);
    return _sales.where((SaleRecord sale) => sale.soldAt.isAfter(startOfMonth.subtract(const Duration(seconds: 1)))).toList();
  }

  int expensesForPeriod(String period) {
    final DateTime now = DateTime.now();
    if (period == 'day') {
      return _expenses
          .where((ExpenseRecord expense) => isSameDay(expense.spentAt, now))
          .fold<int>(0, (int sum, ExpenseRecord e) => sum + e.amountCentavos);
    }
    if (period == 'week') {
      final DateTime start = now.subtract(const Duration(days: 6));
      return _expenses
          .where((ExpenseRecord expense) =>
              expense.spentAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
              expense.spentAt.isBefore(now.add(const Duration(days: 1))))
          .fold<int>(0, (int sum, ExpenseRecord e) => sum + e.amountCentavos);
    }
    final DateTime startOfMonth = DateTime(now.year, now.month, 1);
    return _expenses
        .where((ExpenseRecord expense) =>
            expense.spentAt.isAfter(startOfMonth.subtract(const Duration(seconds: 1))))
        .fold<int>(0, (int sum, ExpenseRecord e) => sum + e.amountCentavos);
  }

  List<LedgerEntry> ledgerForPeriod(String period) {
    final DateTime now = DateTime.now();
    if (period == 'day') {
      return _ledger.where((LedgerEntry entry) => isSameDay(entry.createdAt, now)).toList();
    }
    if (period == 'week') {
      final DateTime start = now.subtract(const Duration(days: 6));
      return _ledger
          .where((LedgerEntry entry) =>
              entry.createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
              entry.createdAt.isBefore(now.add(const Duration(days: 1))))
          .toList();
    }
    final DateTime startOfMonth = DateTime(now.year, now.month, 1);
    return _ledger
        .where((LedgerEntry entry) =>
            entry.createdAt.isAfter(startOfMonth.subtract(const Duration(seconds: 1))))
        .toList();
  }

  Future<void> openAnalyticsDashboard() async {
    String period = 'day';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final List<SaleRecord> periodSales = salesForPeriod(period);
            final List<LedgerEntry> periodLedger = ledgerForPeriod(period);
            final int salesTotal = periodSales.fold<int>(
              0,
              (int sum, SaleRecord sale) => sum + sale.totalCentavos,
            );
            final int profitTotal = periodSales.fold<int>(
              0,
              (int sum, SaleRecord sale) => sum + sale.grossProfitCentavos,
            );
            final int expenseTotal = expensesForPeriod(period);
            final int netTotal = profitTotal - expenseTotal;
            final int utangIssued = periodLedger
                .where((LedgerEntry entry) => entry.type == 'utang')
                .fold<int>(0, (int sum, LedgerEntry entry) => sum + entry.amountCentavos);
            final int paymentsCollected = periodLedger
                .where((LedgerEntry entry) => entry.type == 'payment')
                .fold<int>(0, (int sum, LedgerEntry entry) => sum + entry.amountCentavos);
            final int outstandingTotal = customerBalances.values.fold<int>(
              0,
              (int sum, int value) => sum + value,
            );

            final Map<String, int> topProducts = <String, int>{};
            final Map<int, int> hourlySales = <int, int>{};
            for (final SaleRecord sale in periodSales) {
              hourlySales[sale.soldAt.hour] = (hourlySales[sale.soldAt.hour] ?? 0) + sale.totalCentavos;
              sale.itemsByProduct.forEach((String name, int qty) {
                topProducts[name] = (topProducts[name] ?? 0) + qty;
              });
            }

            final List<MapEntry<String, int>> topList = topProducts.entries.toList()
              ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
            final List<MapEntry<int, int>> hourList = hourlySales.entries.toList()
              ..sort((MapEntry<int, int> a, MapEntry<int, int> b) => a.key.compareTo(b.key));

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bar_chart_rounded, color: _forest),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Analytics',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Day'),
                          selected: period == 'day',
                          onSelected: (_) => setSheetState(() => period = 'day'),
                        ),
                        ChoiceChip(
                          label: const Text('Week'),
                          selected: period == 'week',
                          onSelected: (_) => setSheetState(() => period = 'week'),
                        ),
                        ChoiceChip(
                          label: const Text('Month'),
                          selected: period == 'month',
                          onSelected: (_) => setSheetState(() => period = 'month'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sales: ${formatPeso(salesTotal)}'),
                          Text('Gross profit: ${formatPeso(profitTotal)}'),
                          Text('Expenses: ${formatPeso(expenseTotal)}'),
                          Text('Net: ${formatPeso(netTotal)}'),
                          const SizedBox(height: 6),
                          Text('Utang issued (${period.toUpperCase()}): ${formatPeso(utangIssued)}'),
                          Text('Payments collected (${period.toUpperCase()}): ${formatPeso(paymentsCollected)}'),
                          Text('Outstanding utang (all): ${formatPeso(outstandingTotal)}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Top products', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (topList.isEmpty)
                      const Text('No product sales in this period.')
                    else
                      ...topList.take(5).map(
                        (MapEntry<String, int> entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('${entry.key}: ${entry.value} pcs'),
                        ),
                      ),
                    const SizedBox(height: 10),
                    const Text('Sales by hour', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (hourList.isEmpty)
                      const Text('No transactions in this period.')
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: hourList.length,
                          itemBuilder: (BuildContext context, int index) {
                            final MapEntry<int, int> row = hourList[index];
                            return Text('${row.key.toString().padLeft(2, '0')}:00 - ${formatPeso(row.value)}');
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> openSalesForDate(DateTime date) async {
    final List<SaleRecord> sales = salesForDate(date);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: _forest),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formatDate(date),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'Transactions: ${sales.length} | Total: ${formatPeso(totalForDate(date))}',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (sales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No sales found for this date.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sales.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final SaleRecord sale = sales[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(
                              '${formatTime(sale.soldAt)} • ${formatPeso(sale.totalCentavos)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              'Items: ${sale.itemCount} | Paid: ${formatPeso(sale.paymentCentavos)} | Discount: ${formatPeso(sale.discountCentavos)}\nProfit: ${formatPeso(sale.grossProfitCentavos)} | Change: ${formatPeso(sale.changeCentavos)}${sale.note.isNotEmpty ? '\nNote: ${sale.note}' : ''}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> openSalesHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, color: _forest),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sales History by Date',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final DateTime now = DateTime.now();
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: saleDates.isNotEmpty ? saleDates.first : now,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(now.year + 5),
                        );
                        if (pickedDate == null || !context.mounted) {
                          return;
                        }
                        await openSalesForDate(pickedDate);
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      tooltip: 'Pick date',
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (saleDates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No saved sales yet.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: saleDates.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final DateTime date = saleDates[index];
                        final List<SaleRecord> sales = salesForDate(date);
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            onTap: () => openSalesForDate(date),
                            title: Text(
                              formatDate(date),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${sales.length} transactions | Total: ${formatPeso(totalForDate(date))}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<CheckoutData?> showCheckoutDialog() async {
    int paymentCentavos = 0;
    int discountCentavos = 0;
    final TextEditingController noteController = TextEditingController();

    return showDialog<CheckoutData>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final int maxDiscount = cartTotalCentavos;
            if (discountCentavos > maxDiscount) {
              discountCentavos = maxDiscount;
            }
            final int totalAfterDiscount = cartTotalCentavos - discountCentavos;
            final int changeCentavos = paymentCentavos - totalAfterDiscount;

            return AlertDialog(
              title: const Text('Complete sale'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items: $cartItemCount'),
                  Text('Total: ${formatPeso(cartTotalCentavos)}'),
                  const SizedBox(height: 6),
                  Text('After discount: ${formatPeso(totalAfterDiscount)}'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('₱50'),
                        onPressed: () {
                          setDialogState(() {
                            paymentCentavos = 5000;
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('₱100'),
                        onPressed: () {
                          setDialogState(() {
                            paymentCentavos = 10000;
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('₱200'),
                        onPressed: () {
                          setDialogState(() {
                            paymentCentavos = 20000;
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('₱500'),
                        onPressed: () {
                          setDialogState(() {
                            paymentCentavos = 50000;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Payment (peso)',
                      hintText: 'e.g. 100',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String value) {
                      setDialogState(() {
                        paymentCentavos = parsePesoToCentavos(value);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Discount (peso)',
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String value) {
                      setDialogState(() {
                        discountCentavos = parsePesoToCentavos(value);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'Optional note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    changeCentavos >= 0
                        ? 'Change: ${formatPeso(changeCentavos)}'
                        : 'Insufficient payment',
                    style: TextStyle(
                      color: changeCentavos >= 0
                          ? const Color(0xFF166534)
                          : const Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: paymentCentavos >= totalAfterDiscount && totalAfterDiscount > 0
                      ? () => Navigator.of(context).pop(
                            CheckoutData(
                              paymentCentavos: paymentCentavos,
                              discountCentavos: discountCentavos,
                              note: noteController.text.trim(),
                            ),
                          )
                      : null,
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> completeSale() async {
    if (_cartByName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.')),
      );
      return;
    }

    final CheckoutData? checkoutData = await showCheckoutDialog();
    if (checkoutData == null) {
      return;
    }

    final Map<String, int> soldItems = <String, int>{};
    int saleCost = 0;
    for (final Product product in products) {
      final int qty = cartQty(product);
      if (qty > 0) {
        soldItems[product.name] = qty;
        saleCost += qty * costFor(product);
      }
    }

    final int grossSale = cartTotalCentavos;
    final int discount = checkoutData.discountCentavos > grossSale
        ? grossSale
        : checkoutData.discountCentavos;
    final int saleTotal = grossSale - discount;
    final int changeCentavos = checkoutData.paymentCentavos - saleTotal;
    final int grossProfit = saleTotal - saleCost;

    setState(() {
      for (final Product product in products) {
        final int qty = cartQty(product);
        if (qty > 0) {
          _stockByName[product.name] = stockFor(product) - qty;
        }
      }

      totalSalesCentavos += saleTotal;
      _sales.insert(
        0,
        SaleRecord(
          soldAt: DateTime.now(),
          itemCount: cartItemCount,
          totalCentavos: saleTotal,
          paymentCentavos: checkoutData.paymentCentavos,
          changeCentavos: changeCentavos,
          discountCentavos: discount,
          costCentavos: saleCost,
          grossProfitCentavos: grossProfit,
          note: checkoutData.note,
          itemsByProduct: soldItems,
        ),
      );
      _cartByName.clear();
    });
    persistState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sale saved. Change: ${formatPeso(changeCentavos)}')),
    );
  }

  void resetSales() {
    setState(() {
      totalSalesCentavos = 0;
      _sales.clear();
      _cartByName.clear();
      for (final Product product in products) {
        _stockByName[product.name] = product.initialStockQty;
      }
    });
    persistState();
  }

  int parsePesoToCentavos(String rawValue) {
    final String clean = rawValue.replaceAll(',', '').trim();
    final double? amount = double.tryParse(clean);
    if (amount == null || amount < 0) {
      return 0;
    }
    return (amount * 100).round();
  }

  String formatPeso(int centavos) {
    return '₱${(centavos / 100).toStringAsFixed(2)}';
  }

  String formatTime(DateTime dateTime) {
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> confirmResetSales() async {
    final bool shouldReset = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Reset sales?'),
              content: const Text('This will clear the total sales amount.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldReset) {
      resetSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompact = screenWidth < 430;
    final bool isVeryCompact = screenWidth < 380;
    final bool isTablet = screenWidth >= 700;
    final bool highContrast = _highContrastMode;
    final Color pageTop = highContrast ? const Color(0xFFF3F4F6) : const Color(0xFFEAF5EC);
    final Color pageBottom = highContrast ? const Color(0xFFFFFFFF) : const Color(0xFFFFF5E9);
    final Color bodyTextColor = highContrast ? const Color(0xFF111827) : const Color(0xFF4B5563);
    final Color panelBorderColor = highContrast ? const Color(0x33000000) : const Color(0x1A000000);
    final Color searchFillColor = highContrast
      ? const Color(0xFFFFFFFF)
      : Colors.white.withValues(alpha: 0.95);
    final Color chipBackgroundColor = highContrast
      ? const Color(0xFFF3F4F6)
      : Colors.white.withValues(alpha: 0.88);
    final Color productCardColor = highContrast
      ? const Color(0xFFFFFFFF)
      : Colors.white.withValues(alpha: 0.94);
    final Color cartGradientBottom = highContrast
      ? const Color(0xFFF3F4F6)
      : const Color(0xFFF6FAF7);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Sari-Sari POS',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
        actions: [
          if (isCompact) ...[
            IconButton(
              icon: Icon(
                highContrast ? Icons.contrast_rounded : Icons.contrast_outlined,
              ),
              onPressed: () {
                setState(() {
                  _highContrastMode = !_highContrastMode;
                });
                persistState();
              },
              tooltip: highContrast ? 'Standard mode' : 'Cashier contrast',
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              onPressed: openAnalyticsDashboard,
              tooltip: 'Analytics',
            ),
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: openSalesHistory,
              tooltip: 'Sales history',
            ),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              onSelected: (String action) {
                switch (action) {
                  case 'utang':
                    openUtangLedger();
                    break;
                  case 'expenses':
                    openExpensesTracker();
                    break;
                  case 'inventory':
                    openInventoryManager();
                    break;
                  case 'contrast':
                    setState(() {
                      _highContrastMode = !_highContrastMode;
                    });
                    persistState();
                    break;
                  case 'reset':
                    confirmResetSales();
                    break;
                }
              },
              itemBuilder: (BuildContext context) {
                return const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'utang',
                    child: ListTile(
                      leading: Icon(Icons.people_alt_rounded),
                      title: Text('Utang ledger'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'expenses',
                    child: ListTile(
                      leading: Icon(Icons.wallet_rounded),
                      title: Text('Expenses'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'inventory',
                    child: ListTile(
                      leading: Icon(Icons.inventory_2_outlined),
                      title: Text('Inventory'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'contrast',
                    child: ListTile(
                      leading: Icon(Icons.contrast_rounded),
                      title: Text('Toggle contrast mode'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'reset',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Reset today sales'),
                    ),
                  ),
                ];
              },
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                highContrast ? Icons.contrast_rounded : Icons.contrast_outlined,
              ),
              onPressed: () {
                setState(() {
                  _highContrastMode = !_highContrastMode;
                });
                persistState();
              },
              tooltip: highContrast ? 'Standard mode' : 'Cashier contrast',
            ),
            IconButton(
              icon: const Icon(Icons.people_alt_rounded),
              onPressed: openUtangLedger,
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              onPressed: openAnalyticsDashboard,
            ),
            IconButton(
              icon: const Icon(Icons.wallet_rounded),
              onPressed: openExpensesTracker,
            ),
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: openSalesHistory,
            ),
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: openInventoryManager,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: confirmResetSales,
            )
          ],
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[pageTop, pageBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isVeryCompact ? 10 : 14,
              10,
              isVeryCompact ? 10 : 14,
              14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isVeryCompact ? 14 : 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: <Color>[_forest, _moss],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x22FFFFFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Live Snapshot',
                              style: TextStyle(
                                color: Color(0xFFE9FDEB),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.schedule_rounded,
                            color: Color(0xFFDFF7E4),
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'TODAY\'S SALES',
                        style: TextStyle(
                          color: Color(0xFFDFF7E4),
                          fontSize: 13,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDate(DateTime.now()),
                        style: const TextStyle(
                          color: Color(0xFFDFF7E4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOut,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.18),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(opacity: animation, child: child),
                          );
                        },
                        child: Text(
                          formatPeso(todaySalesCentavos),
                          key: ValueKey<int>(todaySalesCentavos),
                          style: const TextStyle(
                            color: _cream,
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All-time saved sales: ${formatPeso(totalSalesCentavos)}',
                        style: const TextStyle(
                          color: Color(0xFFDFF7E4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Gross today: ${formatPeso(todayGrossProfitCentavos)}',
                              style: const TextStyle(
                                color: Color(0xFFDFF7E4),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Expenses today: ${formatPeso(todayExpensesCentavos)}',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: Color(0xFFFFE7C2),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Net today: ${formatPeso(todayNetCentavos)}',
                              style: const TextStyle(
                                color: Color(0xFFDFF7E4),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.point_of_sale_rounded, size: 18, color: _sunset),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap for 1 item, or use quick quantity for packs/dozen',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: bodyTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Clear search',
                          ),
                    hintText: 'Search item name...',
                    filled: true,
                    fillColor: searchFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0x22000000)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0x22000000)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _forest, width: 1.5),
                    ),
                    isDense: true,
                  ),
                  onChanged: (String value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: isCompact ? 42 : 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (BuildContext context, int index) {
                      return const SizedBox(width: 8);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final String category = categories[index];
                      final bool selected = category == _selectedCategory;
                      return ChoiceChip(
                        showCheckmark: false,
                        side: const BorderSide(color: Color(0x1A000000)),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : const Color(0xFF374151),
                        ),
                        selectedColor: _forest,
                        backgroundColor: chipBackgroundColor,
                        label: Text(category),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category;
                          });
                          persistState();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Product List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 4),
                    itemCount: visibleListEntries.length,
                    separatorBuilder: (BuildContext context, int index) {
                      return const SizedBox(height: 8);
                    },
                    itemBuilder: (context, index) {
                      final Object entry = visibleListEntries[index];
                      if (entry is String) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: Text(
                            entry,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _forest,
                              letterSpacing: 0.3,
                            ),
                          ),
                        );
                      }

                      final Product product = entry as Product;
                      final int availableStock = remainingStock(product);
                      final bool outOfStock = availableStock <= 0;
                      final bool lowStock = availableStock > 0 && availableStock <= 3;
                      final String? subtitle = outOfStock
                          ? 'Out of stock'
                          : lowStock
                              ? 'Low stock: $availableStock left'
                              : null;

                      return Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: productCardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: panelBorderColor.withValues(alpha: 0.8)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          dense: isCompact,
                          onTap: outOfStock ? null : () => addToCart(product),
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: outOfStock
                                ? const Color(0xFFFFE8E8)
                                : const Color(0xFFE8F4EA),
                            child: Text(
                              product.name.isEmpty
                                  ? '?'
                                  : product.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: outOfStock ? const Color(0xFFB91C1C) : _forest,
                              ),
                            ),
                          ),
                          title: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: subtitle == null
                              ? null
                              : Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: outOfStock
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF9A6700),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                          isThreeLine: isTablet && subtitle != null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: isCompact ? 70 : 92,
                                child: Text(
                                  formatPeso(priceFor(product)),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _sunset,
                                  ),
                                ),
                              ),
                              SizedBox(width: isCompact ? 2 : 8),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 34,
                                  height: 34,
                                ),
                                onPressed: outOfStock ? null : () => addToCart(product),
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: 'Add to cart',
                              ),
                              PopupMenuButton<int>(
                                enabled: !outOfStock,
                                tooltip: 'Quick quantity',
                                onSelected: (int quantity) {
                                  addQuantityToCart(
                                    product,
                                    quantity,
                                    showMessage: true,
                                  );
                                },
                                itemBuilder: (BuildContext context) {
                                  return <PopupMenuEntry<int>>[
                                    const PopupMenuItem<int>(
                                      value: 3,
                                      child: Text('Add 3 pcs'),
                                    ),
                                    const PopupMenuItem<int>(
                                      value: 6,
                                      child: Text('Add 6 pcs'),
                                    ),
                                    const PopupMenuItem<int>(
                                      value: 12,
                                      child: Text('Add 1 dozen (12 pcs)'),
                                    ),
                                  ];
                                },
                                icon: Icon(
                                  Icons.arrow_drop_down_circle_outlined,
                                  size: isCompact ? 22 : 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isVeryCompact ? 10 : 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[const Color(0xFFFFFFFF), cartGradientBottom],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: panelBorderColor),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F4EA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.shopping_cart_checkout_rounded,
                              color: _forest,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cart ($cartItemCount)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatPeso(cartTotalCentavos),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _sunset,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_cartByName.isEmpty)
                        const Text(
                          'No items yet. Add products above.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        )
                      else
                        SizedBox(
                          height: isCompact ? 104 : 120,
                          child: ListView(
                            children: products
                                .where((Product p) => cartQty(p) > 0)
                                .map((Product product) {
                                  final int qty = cartQty(product);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${product.name} x$qty',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints.tightFor(
                                            width: 34,
                                            height: 34,
                                          ),
                                          onPressed: () => removeFromCart(product),
                                          icon: const Icon(Icons.remove_circle_outline),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints.tightFor(
                                            width: 34,
                                            height: 34,
                                          ),
                                          onPressed: remainingStock(product) > 0
                                              ? () => addToCart(product)
                                              : null,
                                          icon: const Icon(Icons.add_circle_outline),
                                        ),
                                        Text(
                                          formatPeso(priceFor(product) * qty),
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (isCompact) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _cartByName.isEmpty ? null : completeSale,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Complete Sale'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _cartByName.isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _cartByName.clear();
                                    });
                                    persistState();
                                  },
                            child: const Text('Clear cart'),
                          ),
                        ),
                      ] else
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: _cartByName.isEmpty
                                  ? null
                                  : () {
                                      setState(() {
                                        _cartByName.clear();
                                      });
                                      persistState();
                                    },
                              child: const Text('Clear cart'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _cartByName.isEmpty ? null : completeSale,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Complete Sale'),
                              ),
                            ),
                          ],
                        ),
                      if (_sales.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last sale ${formatTime(_sales.first.soldAt)} - '
                          '${formatPeso(_sales.first.totalCentavos)} '
                          '(Paid ${formatPeso(_sales.first.paymentCentavos)}, '
                          'Discount ${formatPeso(_sales.first.discountCentavos)}, '
                          'Profit ${formatPeso(_sales.first.grossProfitCentavos)})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4B5563),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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