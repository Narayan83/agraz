class FarmIncomeProductLine {
  String product;
  double quantity;
  String unit;
  double unitPrice;
  double lineTotal;

  FarmIncomeProductLine({
    this.product = '',
    this.quantity = 0,
    this.unit = 'kg',
    this.unitPrice = 0,
    this.lineTotal = 0,
  });

  double get total {
    if (lineTotal > 0) {
      return double.parse(lineTotal.toStringAsFixed(2));
    }
    final t = quantity * unitPrice;
    return double.parse(t.toStringAsFixed(2));
  }

  Map<String, dynamic> toJson() => {
        'product': product,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'unitPrice': unitPrice,
        'price': unitPrice,
        'total': total,
      };

  factory FarmIncomeProductLine.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    final qty = asDouble(json['quantity']);
    final price = asDouble(
      json['unit_price'] ?? json['unitPrice'] ?? json['price'],
    );
    final tot = asDouble(json['total']);
    final synced = FarmIncomeLineCalc.sync(
      quantity: qty,
      unitPrice: price,
      total: tot,
      fromTotal: tot > 0 && price <= 0,
    );
    return FarmIncomeProductLine(
      product: (json['product'] ?? '').toString(),
      quantity: qty,
      unit: (json['unit'] ?? 'kg').toString(),
      unitPrice: tot > 0 && price > 0 ? price : synced.unitPrice,
      lineTotal: tot > 0 && price > 0 ? tot : synced.total,
    );
  }
}

/// Qty is always user-entered. Price and total fill each other.
class FarmIncomeLineCalc {
  static double roundMoney(double v) => double.parse(v.toStringAsFixed(2));

  /// [fromTotal] true when total (or qty after a total) should drive price.
  static ({double unitPrice, double total}) sync({
    required double quantity,
    required double unitPrice,
    required double total,
    required bool fromTotal,
  }) {
    if (quantity <= 0) {
      return (unitPrice: unitPrice, total: total);
    }
    if (fromTotal) {
      if (total <= 0) {
        return (unitPrice: unitPrice, total: total);
      }
      return (
        unitPrice: roundMoney(total / quantity),
        total: roundMoney(total),
      );
    }
    return (
      unitPrice: unitPrice,
      total: roundMoney(quantity * unitPrice),
    );
  }
}

class IncomeExpenseData {
  String? receiptPaymentType;
  String? category;
  String? subCategory;
  /// Selected subcategory (kept as a list of 0–1 for existing save/API mapping).
  List<String> subCategories = [];
  String? narration;
  String? mobile;
  double? amount;
  DateTime? transactionDate;

  /// Cash | Transfer
  String transactionMode = 'Cash';
  int? organizationId;

  // Address fields
  String? name;
  String? village;
  String? post;
  String? taluk;
  String? district;
  String? extraAddress;
  String? pincode;

  /// Farm income product detail lines (arecanut varieties, etc.).
  List<FarmIncomeProductLine> productLines = [];

  static const List<String> productUnits = ['kg', 'bag', 'ltr', 'pc', 'load'];

  /// Crops under Farming Income that support product-detail lines.
  static const List<String> farmCropSubCategories = [
    'Arecanut',
    'Banana',
    'Coconut',
    'Cardamom',
    'Pepper',
    'Coffee',
    'Cocoa',
    'Vanilla',
    'Other Crop',
  ];

  /// Variety / product options per crop (from farm income sheet).
  static const Map<String, List<String>> farmProductCatalog = {
    'Arecanut': [
      'rashi',
      'bette',
      'gotu',
      'churu',
      'kole',
      'hasi adike',
      'ketakalu',
      'kallabette',
      's. bette',
      'chali',
      'ck',
      'bg',
      'koka',
      'chakra',
      'laddu',
      'gorabalu',
      'sippe',
      'togaru',
    ],
    'Banana': [
      'mitaga',
      'karibale',
      'boodu',
      'g9',
      'other',
    ],
    'Coconut': [
      'coconut',
      'sippe',
      'sippe kayi',
      'bale patte leaf',
      'hillu',
    ],
  };

  static bool supportsProductDetails(String? category, List<String> selected) {
    if (category != 'Farming Income') return false;
    if (selected.length != 1) return false;
    return farmCropSubCategories.contains(selected.first);
  }

  static List<String> productsForCrop(String crop) {
    return farmProductCatalog[crop] ?? const <String>[];
  }

  // Category to SubCategory mapping
  final Map<String, Map<String, String>> categorySubCategoryMap = {
    'Farming Income': {
      'Arecanut': '🟤',
      'Banana': '🍌',
      'Coconut': '🥥',
      'Cardamom': '🌿',
      'Pepper': '⚫',
      'Coffee': '☕',
      'Cocoa': '🍫',
      'Vanilla': '🌸',
      'Other Crop': '🌾',
      'By-products': '📦',
      'Livestock & Dairy': '🐄',
      'Rental / Service': '🏠',
      // Kept for older records / edit dropdowns
      'Agriculture Production': '🌱',
    },
    'Non-Farming Income': {
      'Government / Subsidy': '🏛️',
      'Asset & Miscellaneous': '💰',
    },
    'Farming Expense': {
      'Labour': '👩‍🌾',
      'Manure': '🌱',
      'Chemicals': '🧪',
      'Machinery Rent': '🚜',
      'Vehicle Rent': '🚛',
      'Implements': '🔧',
      'Irrigation': '💧',
      'Machinery Purchase': '🛒',
      'Special Works': '🏗️',
      'Cattle Feed': '🐄',
      'Fodder': '🌾',
      'Vet Medicines and Care': '💊',
      'Live Stock Purchase': '🐮',
      'Others': '📊',
    },
    'Living Expense': {
      'Grocery': '🛒',
      'Fruits & Veg': '🍎',
      'Milk & Ghee': '🥛',
      'Medicine': '💊',
      'Vehicle Maintenance': '🛠️',
      'Pooja': '🕯️',
      'Donation': '🤝',
      'Gift': '🎁',
      'Mobile & Currency': '📱',
      'Lifestyle': '👗',
      'Misc': '🧺',
      'Vehicle Rent': '🚗',
      'Refreshing': '☕',
      'Gas': '🔥',
      'Education': '📚',
      'Electricity': '💡',
      'Repair': '🔧',
      'Transportation Expense': '🚕',
      'Entertainment': '🎬',
      'Tour & Travel': '✈️',
      'Newspapers & Books': '📰',
      'Lifestyle Others': '🌟',
    },
  };

  /// Whole-rupee split: base = floor(amount/n), remainder to first.
  static List<int> splitAmountsWholeRupees(double amount, int n) {
    if (n <= 0) return [];
    final total = amount.floor();
    if (n == 1) return [total];
    final base = total ~/ n;
    final rem = total % n;
    return List.generate(n, (i) => i == 0 ? base + rem : base);
  }

  List<({String name, int amount})> splitPreview() {
    final selected = effectiveSubCategories;
    final amt = amount ?? 0;
    if (selected.isEmpty || amt <= 0) return [];
    final parts = splitAmountsWholeRupees(amt, selected.length);
    return [
      for (var i = 0; i < selected.length; i++)
        (name: selected[i], amount: parts[i]),
    ];
  }

  List<String> get effectiveSubCategories {
    if (subCategories.isNotEmpty) return List<String>.from(subCategories);
    if (subCategory != null && subCategory!.trim().isNotEmpty) {
      return [subCategory!.trim()];
    }
    return [];
  }

  bool get canAddProductDetails =>
      supportsProductDetails(category, effectiveSubCategories);

  double get productLinesTotal =>
      productLines.fold<double>(0, (s, e) => s + e.total);

  void syncAmountFromProductLines() {
    if (productLines.isEmpty) return;
    amount = double.parse(productLinesTotal.toStringAsFixed(2));
  }

  // Convert to map for API submission
  Map<String, dynamic> toJson() {
    String? dateStr;
    if (transactionDate != null) {
      final d = transactionDate!;
      dateStr =
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }
    final selected = effectiveSubCategories;
    if (productLines.isNotEmpty) {
      syncAmountFromProductLines();
    }
    final map = <String, dynamic>{
      'type': receiptPaymentType,
      'category': category,
      'amount': amount,
      'narration': narration ?? '',
      'mobile': mobile ?? '',
      'date': dateStr,
      'name': name ?? '',
      'village': village ?? '',
      'post': post ?? '',
      'taluk': taluk ?? '',
      'district': district ?? '',
      'extraAddress': extraAddress ?? '',
      'pincode': pincode ?? '',
      'transaction_mode': transactionMode,
      'transactionMode': transactionMode,
    };
    if (organizationId != null) {
      map['organization_id'] = organizationId;
      map['organizationId'] = organizationId;
    }
    if (selected.length >= 2) {
      map['subCategories'] = selected;
      map['sub_categories'] = selected;
      map['subCategory'] = selected.first;
      map['sub_category'] = selected.first;
    } else if (selected.length == 1) {
      map['subCategory'] = selected.first;
      map['sub_category'] = selected.first;
    } else {
      map['subCategory'] = subCategory;
    }
    if (selected.length <= 1) {
      final lines = productLines.map((e) => e.toJson()).toList();
      map['product_lines'] = lines;
      map['productLines'] = lines;
    }
    return map;
  }
}
