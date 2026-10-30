import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';

class BalancesPage extends HookWidget {
  const BalancesPage({super.key, required this.tables});

  final TablesDB tables;

  @override
  Widget build(BuildContext context) {
    final items = useState<List<models.Row>?>(null);
    final error = useState<String?>(null);
    final isLoading = useState(false);
    final balanceController = useTextEditingController();

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        final res = await tables.listRows(
          databaseId: kDatabaseId,
          tableId: kBalancesCollectionId,
          queries: [
            Query.orderDesc('updatedAt'),
            Query.limit(100),
          ],
        );
        items.value = res.rows;
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    Future<void> adjustBalance(models.Row doc) async {
      final adjustment = double.tryParse(balanceController.text) ?? 0.0;
      if (adjustment == 0.0) return;
      isLoading.value = true;
      try {
        final currentBal = (doc.data['balance'] ?? 0.0) as num;
        final newBal = currentBal.toDouble() + adjustment;
        await tables.updateRow(
          databaseId: kDatabaseId,
          tableId: kBalancesCollectionId,
          rowId: doc.$id,
          data: <String, dynamic>{
            'balance': newBal,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
        balanceController.clear();
        await load();
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> showAdjustDialog(models.Row doc) async {
      balanceController.clear();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Adjust Balance for ${doc.$id}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Balance: \$${(doc.data['balance'] ?? 0.0).toString()}'),
              const SizedBox(height: 12),
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (e.g. +50.0 or -20.0)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                adjustBalance(doc);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final list = items.value ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Creator Balances', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton.filledTonal(onPressed: load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          if (error.value != null) ...[
            Text(error.value!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Creator User ID')),
                    DataColumn(label: Text('Current Balance (USD)')),
                    DataColumn(label: Text('Total Earned (USD)')),
                    DataColumn(label: Text('Last Updated')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: list.map((doc) {
                    final bal = (doc.data['balance'] ?? 0.0) as num;
                    final total = (doc.data['totalEarned'] ?? 0.0) as num;
                    return DataRow(
                      cells: [
                        DataCell(Text(doc.$id)),
                        DataCell(Text(bal.toStringAsFixed(2))),
                        DataCell(Text(total.toStringAsFixed(2))),
                        DataCell(Text(doc.data['updatedAt'] ?? doc.$updatedAt)),
                        DataCell(ElevatedButton(
                          onPressed: () => showAdjustDialog(doc),
                          child: const Text('Adjust'),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
