import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';

class BoostsPage extends HookWidget {
  const BoostsPage({super.key, required this.tables});

  final TablesDB tables;

  @override
  Widget build(BuildContext context) {
    final items = useState<List<models.Row>?>(null);
    final error = useState<String?>(null);
    final isLoading = useState(false);

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        final res = await tables.listRows(
          databaseId: kDatabaseId,
          tableId: kBoostsCollectionId,
          queries: <String>[
            Query.orderDesc('\$createdAt'),
            Query.limit(200),
          ],
        );
        items.value = res.rows;
      } on AppwriteException catch (e) {
        error.value = e.message ?? 'Failed to load boosts';
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    if (isLoading.value && items.value == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error.value != null) {
      return Center(child: Text(error.value!));
    }

    final list = items.value ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Boosted posts / ads',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Boost ID')),
                  DataColumn(label: Text('Post ID')),
                  DataColumn(label: Text('User ID')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Amount (USD)')),
                  DataColumn(label: Text('Days')),
                  DataColumn(label: Text('Target reach')),
                  DataColumn(label: Text('Delivered')),
                  DataColumn(label: Text('Provider')),
                  DataColumn(label: Text('Payment ref')),
                ],
                rows: list
                    .map(
                      (doc) => DataRow(
                        cells: [
                          DataCell(Text(doc.$id)),
                          DataCell(Text('${doc.data['postId'] ?? ''}')),
                          DataCell(Text('${doc.data['userId'] ?? ''}')),
                          DataCell(Text('${doc.data['status'] ?? ''}')),
                          DataCell(
                            Text(
                              (doc.data['amountUsd'] as num? ?? 0)
                                  .toStringAsFixed(2),
                            ),
                          ),
                          DataCell(
                            Text('${doc.data['days'] ?? ''}'),
                          ),
                          DataCell(
                            Text('${doc.data['targetReach'] ?? 0}'),
                          ),
                          DataCell(
                            Text('${doc.data['deliveredImpressions'] ?? 0}'),
                          ),
                          DataCell(
                            Text('${doc.data['paymentProvider'] ?? ''}'),
                          ),
                          DataCell(
                            Text('${doc.data['paymentRef'] ?? ''}'),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
