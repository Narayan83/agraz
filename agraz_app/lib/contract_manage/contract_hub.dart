import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../feedback_fab.dart';
import '../l10n/app_l10n.dart';
import 'cm_assets_page.dart';
import 'cm_customer_summary_page.dart';
import 'cm_entity_page.dart';
import 'cm_payments_page.dart';
import 'cm_project_list.dart';
import 'cm_purchases_page.dart';
import 'cm_stock_report_page.dart';

class ContractManageHubPage extends StatelessWidget {
  const ContractManageHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workflow = <_HubItem>[
      _HubItem('Projects', 'Map customer → project, then open workspace for labour, money & stock', Icons.apartment_rounded, AppColors.primary, () => const CmProjectListPage()),
      _HubItem('Customers', 'Create customers before projects', Icons.people_alt_rounded, AppColors.info, () => const CmCustomersPage()),
      _HubItem('Labour Suppliers', 'Labour leads who send gangs to site', Icons.groups_rounded, AppColors.primaryLight, () => const CmLabourSuppliersPage()),
      _HubItem('Labours', 'Workers under each lead', Icons.engineering_rounded, AppColors.expense, () => const CmLaboursPage()),
      _HubItem('Dealers', 'Sand / cement suppliers', Icons.store_mall_directory_rounded, AppColors.warning, () => const CmDealersPage()),
      _HubItem('Materials', 'Material master', Icons.inventory_2_rounded, AppColors.primaryDark, () => const CmMaterialsPage()),
    ];
    final reports = <_HubItem>[
      _HubItem('Payments (all)', 'All advances, receipts, dealer & labour pays', Icons.account_balance_wallet_rounded, AppColors.accent, () => const CmPaymentsPage()),
      _HubItem('Purchases / Stock', 'All material purchases', Icons.shopping_cart_rounded, AppColors.income, () => const CmPurchasesPage()),
      _HubItem('Stock Report', 'Own yard vs customer site stock', Icons.bar_chart_rounded, AppColors.info, () => const CmStockReportPage()),
      _HubItem('Customer Summary', 'Cross-project customer view', Icons.summarize_rounded, AppColors.accent, () => const CmCustomerSummaryPage()),
      _HubItem('Assets', 'JCB and equipment', Icons.agriculture_rounded, AppColors.warning, () => const CmAssetsPage()),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr('Contract Manage')),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: withFeedbackAction(context, menu: 'contract_manage'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              tr('Start here: 1) Add Customer  2) Create Project (map customer, start/end/status)  3) Open project → Send labour, record advances, buy/issue stock, pay leads/dealers. Overview answers how many men/women, rates, days, advances and balances.'),
              style: const TextStyle(height: 1.4, fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(tr('Workflow'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          ...workflow.map((i) => _tile(context, i)),
          const SizedBox(height: 16),
          Text(tr('Masters & reports'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          ...reports.map((i) => _tile(context, i)),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, _HubItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page())),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                TintedIcon(icon: item.icon, color: item.color, boxSize: 44, size: 22, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(item.title), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      const SizedBox(height: 2),
                      Text(tr(item.subtitle), style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() page;
  const _HubItem(this.title, this.subtitle, this.icon, this.color, this.page);
}
