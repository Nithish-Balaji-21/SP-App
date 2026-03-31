import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import 'daily_summary_screen.dart';
import 'new_bill_screen.dart';
import 'past_bills_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _todayBillCount = 0;
  int _todayRevenuePaise = 0;
  int _lowStockCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final stats = await DatabaseHelper.instance.getDailyStats(DateTime.now());
    final lowStockCount = await DatabaseHelper.instance.getLowStockCount();
    if (!mounted) {
      return;
    }

    setState(() {
      _todayBillCount = stats['count'] ?? 0;
      _todayRevenuePaise = stats['revenue_paise'] ?? 0;
      _lowStockCount = lowStockCount;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('STATE PHARMACY'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Today: $dateText',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _summaryCard(
                title: 'Total Bills Today',
                value: '$_todayBillCount',
                icon: Icons.receipt_long,
              ),
              const SizedBox(height: 12),
              _summaryCard(
                title: 'Total Revenue Today',
                value: _formatMoney(_todayRevenuePaise),
                icon: Icons.currency_rupee,
              ),
              const SizedBox(height: 12),
              _summaryCard(
                title: 'Low Stock Medicines',
                value: '$_lowStockCount',
                icon: Icons.warning_amber_rounded,
              ),
            ],
            const SizedBox(height: 24),
            _navButton(
              context,
              icon: Icons.add_circle_outline,
              label: 'New Bill',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewBillScreen()),
                );
                _loadDashboard();
              },
            ),
            const SizedBox(height: 12),
            _navButton(
              context,
              icon: Icons.list_alt_outlined,
              label: 'Past Bills',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PastBillsScreen()),
                );
                _loadDashboard();
              },
            ),
            const SizedBox(height: 12),
            _navButton(
              context,
              icon: Icons.summarize_outlined,
              label: 'Daily Summary',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailySummaryScreen()),
                );
                _loadDashboard();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
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

  Widget _navButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 58,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 28),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  String _formatMoney(int paise) {
    final rs = paise / 100;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rs);
  }
}
