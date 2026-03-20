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

  const SaleRecord({
    required this.soldAt,
    required this.itemCount,
    required this.totalCentavos,
    required this.paymentCentavos,
    required this.changeCentavos,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'soldAt': soldAt.toIso8601String(),
      'itemCount': itemCount,
      'totalCentavos': totalCentavos,
      'paymentCentavos': paymentCentavos,
      'changeCentavos': changeCentavos,
    };
  }

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    return SaleRecord(
      soldAt: DateTime.tryParse(json['soldAt'] as String? ?? '') ?? DateTime.now(),
      itemCount: json['itemCount'] as int? ?? 0,
      totalCentavos: json['totalCentavos'] as int? ?? 0,
      paymentCentavos: json['paymentCentavos'] as int? ?? 0,
      changeCentavos: json['changeCentavos'] as int? ?? 0,
    );
  }
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
  final List<SaleRecord> _sales = <SaleRecord>[];
  final List<ExpenseRecord> _expenses = <ExpenseRecord>[];
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    for (final Product product in products) {
      _stockByName[product.name] = product.initialStockQty;
      _priceByName[product.name] = product.priceCentavos;
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
      final List<dynamic> salesData = data['sales'] as List<dynamic>? ?? <dynamic>[];
        final List<dynamic> expensesData = data['expenses'] as List<dynamic>? ?? <dynamic>[];

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
        }

        _selectedCategory = data['selectedCategory'] as String? ?? 'All';
        if (!categories.contains(_selectedCategory)) {
          _selectedCategory = 'All';
        }

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
        'selectedCategory': _selectedCategory,
        'sales': _sales.map((SaleRecord s) => s.toJson()).toList(),
        'expenses': _expenses.map((ExpenseRecord e) => e.toJson()).toList(),
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
                            '${product.category} | Price: ${formatPeso(priceFor(product))}',
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

  Future<void> addNewProduct() async {
    final TextEditingController nameController = TextEditingController();
    final List<String> selectableCategories =
      categories.where((String c) => c != 'All').toList();
    final TextEditingController newCategoryController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    final TextEditingController stockController = TextEditingController(text: '1');
    String selectedCategory = selectableCategories.isNotEmpty
      ? selectableCategories.first
      : 'Others';
    bool useNewCategory = false;
    String error = '';

    final Product? newProduct = await showDialog<Product>(
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
                    final bool exists = products.any(
                      (Product p) => p.name.toLowerCase() == name.toLowerCase(),
                    );
                    if (exists) {
                      setDialogState(() {
                        error = 'Product name already exists.';
                      });
                      return;
                    }

                    Navigator.of(context).pop(
                      Product(
                        name,
                        price,
                        stock,
                        category,
                      ),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newProduct == null) {
      return;
    }

    setState(() {
      products.add(newProduct);
      _stockByName[newProduct.name] = newProduct.initialStockQty;
      _priceByName[newProduct.name] = newProduct.priceCentavos;
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
    return todaySalesCentavos - todayExpensesCentavos;
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
                              'Items: ${sale.itemCount} | Paid: ${formatPeso(sale.paymentCentavos)} | Change: ${formatPeso(sale.changeCentavos)}',
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

  Future<int?> showCheckoutDialog() async {
    int paymentCentavos = 0;

    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final int changeCentavos = paymentCentavos - cartTotalCentavos;

            return AlertDialog(
              title: const Text('Complete sale'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items: $cartItemCount'),
                  Text('Total: ${formatPeso(cartTotalCentavos)}'),
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
                  onPressed: paymentCentavos >= cartTotalCentavos && cartTotalCentavos > 0
                      ? () => Navigator.of(context).pop(paymentCentavos)
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

    final int? paymentCentavos = await showCheckoutDialog();
    if (paymentCentavos == null) {
      return;
    }

    final int saleTotal = cartTotalCentavos;
    final int changeCentavos = paymentCentavos - saleTotal;

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
          paymentCentavos: paymentCentavos,
          changeCentavos: changeCentavos,
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
    final bool isTablet = screenWidth >= 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Sari-Sari POS'),
        actions: [
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
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFEAF5EC), Color(0xFFFFF5E9)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
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
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              'Expenses today: ${formatPeso(todayExpensesCentavos)}',
                              style: const TextStyle(
                                color: Color(0xFFFFE7C2),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Net today: ${formatPeso(todayNetCentavos)}',
                              textAlign: TextAlign.end,
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
                  children: const [
                    Icon(Icons.point_of_sale_rounded, size: 18, color: _sunset),
                    SizedBox(width: 8),
                    Text(
                      'Tap for 1 item, or use quick quantity for packs/dozen',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search item name...',
                    border: OutlineInputBorder(),
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
                  height: 40,
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
                        child: ListTile(
                          onTap: outOfStock ? null : () => addToCart(product),
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
                                visualDensity: isCompact
                                    ? VisualDensity.compact
                                    : VisualDensity.standard,
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_cart_checkout_rounded, color: _forest),
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
                          height: 120,
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
                                          onPressed: () => removeFromCart(product),
                                          icon: const Icon(Icons.remove_circle_outline),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
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
                          '(Paid ${formatPeso(_sales.first.paymentCentavos)})',
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