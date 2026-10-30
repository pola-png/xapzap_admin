import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';

class ReportsPage extends HookWidget {
  const ReportsPage({super.key, required this.tables});

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
          tableId: kReportsCollectionId,
          queries: <String>[
            Query.orderDesc('\$createdAt'),
            Query.limit(100),
          ],
        );
        items.value = res.rows;
      } on AppwriteException catch (e) {
        error.value = e.message ?? 'Failed to load reports';
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
                'Reports',
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
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Report ID')),
                DataColumn(label: Text('Target ID')),
                DataColumn(label: Text('Target Type')),
                DataColumn(label: Text('User ID')),
                DataColumn(label: Text('Reason')),
                DataColumn(label: Text('Actions')),
              ],
              rows: list
                  .map(
                    (doc) => DataRow(
                      cells: [
                        DataCell(Text(doc.$id)),
                        DataCell(Text('${doc.data['targetId'] ?? ''}')),
                        DataCell(Text('${doc.data['targetType'] ?? ''}')),
                        DataCell(Text('${doc.data['userId'] ?? ''}')),
                        DataCell(Text('${doc.data['reason'] ?? ''}')),
                        DataCell(
                          TextButton(
                            onPressed: isLoading.value
                                ? null
                                : () async {
                                    isLoading.value = true;
                                    error.value = null;
                                    try {
                                      await tables.deleteRow(
                                        databaseId: kDatabaseId,
                                        tableId: kReportsCollectionId,
                                        rowId: doc.$id,
                                      );
                                      await load();
                                    } on AppwriteException catch (e) {
                                      error.value = e.message ??
                                          'Failed to resolve report';
                                    } finally {
                                      isLoading.value = false;
                                    }
                                  },
                            child: const Text('Resolve'),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
