import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';

class UsersPage extends HookWidget {
  const UsersPage({super.key, required this.tables});

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
          tableId: kProfilesCollectionId,
          queries: <String>[
            Query.orderAsc('displayName'),
            Query.limit(100),
          ],
        );
        items.value = res.rows;
      } on AppwriteException catch (e) {
        error.value = e.message ?? 'Failed to load profiles';
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

    Future<void> toggleAdmin(models.Row doc) async {
      isLoading.value = true;
      error.value = null;
      try {
        final current = doc.data['isAdmin'] as bool? ?? false;
        await tables.updateRow(
          databaseId: kDatabaseId,
          tableId: kProfilesCollectionId,
          rowId: doc.$id,
          data: <String, dynamic>{'isAdmin': !current},
        );
        await load();
      } on AppwriteException catch (e) {
        error.value = e.message ?? 'Failed to update admin flag';
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> toggleBan(models.Row doc) async {
      isLoading.value = true;
      error.value = null;
      try {
        final current = doc.data['isBanned'] as bool? ?? false;
        await tables.updateRow(
          databaseId: kDatabaseId,
          tableId: kProfilesCollectionId,
          rowId: doc.$id,
          data: <String, dynamic>{'isBanned': !current},
        );
        await load();
      } on AppwriteException catch (e) {
        error.value = e.message ?? 'Failed to update ban flag';
      } finally {
        isLoading.value = false;
      }
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
                'Users',
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
                DataColumn(label: Text('User ID')),
                DataColumn(label: Text('Username')),
                DataColumn(label: Text('Display name')),
                DataColumn(label: Text('Admin')),
                DataColumn(label: Text('Banned')),
                DataColumn(label: Text('Actions')),
              ],
              rows: list
                  .map(
                    (doc) {
                      final isAdmin =
                          (doc.data['isAdmin'] as bool? ?? false);
                      final isBanned =
                          (doc.data['isBanned'] as bool? ?? false);
                      return DataRow(
                        cells: [
                          DataCell(Text(doc.$id)),
                          DataCell(Text('${doc.data['username'] ?? ''}')),
                          DataCell(
                            Text('${doc.data['displayName'] ?? ''}'),
                          ),
                          DataCell(Text(isAdmin ? 'Yes' : 'No')),
                          DataCell(Text(isBanned ? 'Yes' : 'No')),
                          DataCell(
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: isLoading.value
                                      ? null
                                      : () => toggleAdmin(doc),
                                  child: Text(
                                    isAdmin ? 'Revoke admin' : 'Make admin',
                                  ),
                                ),
                                TextButton(
                                  onPressed: isLoading.value
                                      ? null
                                      : () => toggleBan(doc),
                                  style: TextButton.styleFrom(
                                    foregroundColor: isBanned
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                  child: Text(
                                    isBanned ? 'Unban user' : 'Ban user',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
