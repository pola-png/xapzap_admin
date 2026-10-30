import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';

class PayoutsPage extends HookWidget {
  const PayoutsPage({super.key, required this.tables});

  final TablesDB tables;

  @override
  Widget build(BuildContext context) {
    final items = useState<List<models.Row>?>(null);
    final error = useState<String?>(null);
    final isLoading = useState(false);
    final noteController = useTextEditingController();

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        final res = await tables.listRows(
          databaseId: kDatabaseId,
          tableId: kPayoutsCollectionId,
          queries: [
            Query.orderDesc('\$createdAt'),
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

    Future<void> updatePayoutStatus(models.Row row, String status) async {
      isLoading.value = true;
      try {
        final data = <String, dynamic>{
          'status': status,
        };
        if (status == 'paid') {
          data['paidAt'] = DateTime.now().toIso8601String();
          data['notes'] = noteController.text.trim();
          data['reference'] = noteController.text.trim();
        }
        await tables.updateRow(
          databaseId: kDatabaseId,
          tableId: kPayoutsCollectionId,
          rowId: row.$id,
          data: data,
        );
        noteController.clear();
        await load();
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> showApprovalDialog(models.Row row) async {
      noteController.clear();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approve & Pay Creator'),
          content: TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Approval/Reference Notes',
              hintText: 'Enter transaction ref or notes...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                updatePayoutStatus(row, 'paid');
              },
              child: const Text('Confirm Pay'),
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
              Text('Creator Payout Requests', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                    DataColumn(label: Text('Payout ID')),
                    DataColumn(label: Text('User ID')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Currency')),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Created At')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: list.map((doc) {
                    final status = (doc.data['status'] ?? 'requested').toString();
                    final amt = (doc.data['amount'] ?? 0) as num;
                    return DataRow(
                      cells: [
                        DataCell(Text(doc.$id)),
                        DataCell(Text(doc.data['userId'] ?? '')),
                        DataCell(Text(amt.toStringAsFixed(2))),
                        DataCell(Text(doc.data['currency'] ?? 'USD')),
                        DataCell(Text(doc.data['method'] ?? 'bank')),
                        DataCell(Chip(
                          label: Text(status.toUpperCase()),
                          backgroundColor: status == 'paid' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                        )),
                        DataCell(Text(doc.$createdAt)),
                        DataCell(
                          status == 'paid'
                              ? const Text('Paid & Closed', style: TextStyle(color: Colors.grey))
                              : Wrap(
                                  spacing: 8,
                                  children: [
                                    if (status != 'processing')
                                      TextButton(
                                        onPressed: () => updatePayoutStatus(doc, 'processing'),
                                        child: const Text('Process'),
                                      ),
                                    ElevatedButton(
                                      onPressed: () => showApprovalDialog(doc),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Pay'),
                                    ),
                                    TextButton(
                                      onPressed: () => updatePayoutStatus(doc, 'rejected'),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Reject'),
                                    ),
                                  ],
                                ),
                        ),
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
