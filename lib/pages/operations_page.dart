import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';

class OperationsPage extends HookWidget {
  const OperationsPage({super.key, required this.tables});

  final TablesDB tables;

  @override
  Widget build(BuildContext context) {
    final selectedCollection = useState<String>(kProfilesCollectionId);
    final items = useState<List<models.Row>?>(null);
    final isLoading = useState(false);
    final error = useState<String?>(null);

    final collections = {
      'Profiles': kProfilesCollectionId,
      'Posts': kPostsCollectionId,
      'Reports': kReportsCollectionId,
      'Boosts': kBoostsCollectionId,
      'Support Requests': kSupportRequestsCollectionId,
      'Payouts': kPayoutsCollectionId,
      'Creator Balances': kBalancesCollectionId,
    };

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        final res = await tables.listRows(
          databaseId: kDatabaseId,
          tableId: selectedCollection.value,
          queries: [
            Query.limit(50),
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
    }, [selectedCollection.value]);

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
              Text('System & Database Operations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton.filledTonal(onPressed: load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Select Table to Inspect: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: selectedCollection.value,
                items: collections.entries.map((e) {
                  return DropdownMenuItem(value: e.value, child: Text(e.key));
                }).toList(),
                onChanged: (val) {
                  if (val != null) selectedCollection.value = val;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (error.value != null) ...[
            Text(error.value!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: Card(
              child: isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? const Center(child: Text('No records found in this table.'))
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, idx) {
                            final row = list[idx];
                            return ExpansionTile(
                              title: Text('Row ID: ${row.$id}'),
                              subtitle: Text('Created At: ${row.$createdAt}'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                                    ),
                                    child: SelectableText(
                                      const JsonEncoder.withIndent('  ').convert(row.data),
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
