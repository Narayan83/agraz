class IncomeExpenseData {
  String? receiptPaymentType;
  String? category;
  String? subCategory;
  /// Multi-select subcategories. When 2+, API receives [subCategories] and splits amount.
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

  // Category to SubCategory mapping
  final Map<String, Map<String, String>> categorySubCategoryMap = {
    'Farming Income': {
      'Agriculture Production': '🌱',
      'By-products': '📦',
      'Livestock & Dairy': '🐄',
      'Rental / Service': '🏠',
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
    return map;
  }
}
