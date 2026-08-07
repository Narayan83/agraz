class IncomeExpenseData {
  String? receiptPaymentType;
  String? category;
  String? subCategory;
  String? narration;
  String? mobile;
  double? amount;
  DateTime? transactionDate;

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

  // Convert to map for API submission
  Map<String, dynamic> toJson() {
    return {
      'type': receiptPaymentType,
      'category': category,
      'subCategory': subCategory,
      'amount': amount,
      'narration': narration ?? '',
      'mobile': mobile ?? '',
      'date': transactionDate?.toIso8601String(),
      'name': name ?? '',
      'village': village ?? '',
      'post': post ?? '',
      'taluk': taluk ?? '',
      'district': district ?? '',
      'extraAddress': extraAddress ?? '',
      'pincode': pincode ?? '',
    };
  }
}
