import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';

class PostsPage extends HookWidget {
  const PostsPage({super.key, required this.tables});

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
          tableId: kPostsCollectionId,
          queries: <String>[
            Query.orderDesc('\$createdAt'),
            Query.limit(100),
          ],
        );
        items.value = res.rows;
      } on AppwriteException catch (e) {
        error.value = e.message ?? 'Failed to load posts';
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
                'Posts',
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
                DataColumn(label: Text('Post ID')),
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Kind')),
                DataColumn(label: Text('Likes')),
                DataColumn(label: Text('Comments')),
                DataColumn(label: Text('Impressions')),
                DataColumn(label: Text('Actions')),
              ],
              rows: list
                  .map(
                    (doc) => DataRow(
                      cells: [
                        DataCell(Text(doc.$id)),
                        DataCell(Text('${doc.data['username'] ?? ''}')),
                        DataCell(Text('${doc.data['kind'] ?? ''}')),
                        DataCell(
                          Text('${doc.data['likes'] ?? 0}'),
                        ),
                        DataCell(
                          Text('${doc.data['comments'] ?? 0}'),
                        ),
                        DataCell(
                          Text('${doc.data['impressions'] ?? 0}'),
                        ),
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
                                        tableId: kPostsCollectionId,
                                        rowId: doc.$id,
                                      );
                                      try {
                                        final reports = await tables.listRows(
                                          databaseId: kDatabaseId,
                                          tableId: kReportsCollectionId,
                                          queries: <String>[
                                            Query.equal('targetId', doc.$id),
                                            Query.limit(1000),
                                          ],
                                        );
                                        for (final r in reports.rows) {
                                          await tables.deleteRow(
                                            databaseId: kDatabaseId,
                                            tableId: kReportsCollectionId,
                                            rowId: r.$id,
                                          );
                                        }
                                      } catch (_) {}
                                      await load();
                                    } on AppwriteException catch (e) {
                                      error.value =
                                          e.message ?? 'Failed to delete post';
                                    } finally {
                                      isLoading.value = false;
                                    }
                                  },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
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
