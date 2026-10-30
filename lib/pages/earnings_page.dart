import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';
import '../models/user_earnings.dart';

class EarningsPage extends HookWidget {
  const EarningsPage({super.key, required this.tables});

  final TablesDB tables;

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(false);
    final error = useState<String?>(null);
    final events = useState<List<models.Row>>(<models.Row>[]);
    final payouts = useState<List<models.Row>>(<models.Row>[]);

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        final ev = await tables.listRows(
          databaseId: kDatabaseId,
          tableId: kAdRevenueCollectionId,
          queries: <String>[
            Query.orderDesc('timestamp'),
            Query.limit(1000),
          ],
        );
        final pay = await tables.listRows(
          databaseId: kDatabaseId,
          tableId: kPayoutsCollectionId,
          queries: <String>[
            Query.orderDesc('\$createdAt'),
            Query.limit(200),
          ],
        );
        events.value = ev.rows;
        payouts.value = pay.rows;
      } on AppwriteException catch (e) {
        error.value = e.message ?? 'Failed to load earnings data';
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    if (isLoading.value && events.value.isEmpty && payouts.value.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    // Aggregate earnings by userId from ILRD events.
    final perUser = <String, UserEarnings>{};
    for (final row in events.value) {
      final data = row.data;
      final userId = (data['userId'] as String?) ?? 'unknown';
      final microsRaw = data['valueMicros'] ?? data['value_micros'] ?? 0;
      final micros = microsRaw is int
          ? microsRaw
          : int.tryParse(microsRaw.toString()) ?? 0;
      final currency = (data['currency'] as String?) ?? 'USD';
      final country = (data['country'] as String?) ?? '';
      final tsStr = (data['timestamp'] as String?) ?? row.$createdAt;
      final ts = DateTime.tryParse(tsStr);
      final entry = perUser.putIfAbsent(
        userId,
        () => UserEarnings(
          userId: userId,
          currency: currency,
        ),
      );
      entry.totalMicros += micros;
      entry.eventCount += 1;
      if (country.isNotEmpty) {
        entry.countries.add(country);
      }
      if (ts != null &&
          (entry.lastEventAt == null || ts.isAfter(entry.lastEventAt!))) {
        entry.lastEventAt = ts;
      }
    }

    Widget earningsTable() {
      if (perUser.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: const Text(
            'No ad revenue events yet. Once the app records ILRD events into the '
            '`ad_revenue_events` table, creator earnings will appear here.',
          ),
        );
      }
      final rows = perUser.values.toList()
        ..sort((a, b) => b.totalMicros.compareTo(a.totalMicros));
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('User ID')),
            DataColumn(label: Text('Gross revenue')),
            DataColumn(label: Text('Creator share (40%)')),
            DataColumn(label: Text('Events')),
            DataColumn(label: Text('Countries')),
            DataColumn(label: Text('Last event')),
          ],
          rows: rows.map((e) {
            final gross = e.totalMicros / 1e6;
            final share = gross * 0.40;
            return DataRow(
              cells: [
                DataCell(Text(e.userId)),
                DataCell(Text('${e.currency} ${gross.toStringAsFixed(2)}')),
                DataCell(Text('${e.currency} ${share.toStringAsFixed(2)}')),
                DataCell(Text(e.eventCount.toString())),
                DataCell(Text(e.countries.take(3).join(', '))),
                DataCell(
                  Text(
                    e.lastEventAt?.toIso8601String() ?? '-',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      );
    }

    Widget payoutsTable() {
      if (payouts.value.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: const Text(
            'No payouts recorded yet. Use a dedicated payouts table in Appwrite to '
            'track payments made to creators (userId, amount, currency, method, status).',
          ),
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Payout ID')),
            DataColumn(label: Text('User ID')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Currency')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Method')),
            DataColumn(label: Text('Created at')),
          ],
          rows: payouts.value.map((p) {
            final data = p.data;
            final amountRaw = data['amount'] ?? 0;
            final amount = amountRaw is num
                ? amountRaw.toDouble()
                : double.tryParse(amountRaw.toString()) ?? 0.0;
            final currency = (data['currency'] as String?) ?? 'USD';
            return DataRow(
              cells: [
                DataCell(Text(p.$id)),
                DataCell(Text('${data['userId'] ?? ''}')),
                DataCell(Text(amount.toStringAsFixed(2))),
                DataCell(Text(currency)),
                DataCell(Text('${data['status'] ?? ''}')),
                DataCell(Text('${data['method'] ?? ''}')),
                DataCell(Text(p.$createdAt)),
              ],
            );
          }).toList(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Earnings & payouts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (error.value != null) ...[
            Text(
              error.value!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: ListView(
              children: [
                Text(
                  'Creator earnings (from ad_revenue_events)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                earningsTable(),
                const SizedBox(height: 24),
                Text(
                  'Recorded payouts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                payoutsTable(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
