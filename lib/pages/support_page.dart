import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';

class SupportPage extends HookWidget {
  const SupportPage({super.key, required this.tables});

  final TablesDB tables;

  @override
  Widget build(BuildContext context) {
    final items = useState<List<models.Row>?>(null);
    final error = useState<String?>(null);
    final isLoading = useState(false);
    final selectedRequest = useState<models.Row?>(null);
    final replyController = useTextEditingController();
    final statusVal = useState<String>('open');

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        final res = await tables.listRows(
          databaseId: kDatabaseId,
          tableId: kSupportRequestsCollectionId,
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

    Future<void> updateRequest() async {
      if (selectedRequest.value == null) return;
      isLoading.value = true;
      try {
        final data = <String, dynamic>{
          'status': statusVal.value,
          'adminReply': replyController.text.trim(),
        };
        if (replyController.text.trim().isNotEmpty) {
          data['repliedAt'] = DateTime.now().toIso8601String();
          if (statusVal.value == 'open') {
            data['status'] = 'answered';
            statusVal.value = 'answered';
          }
        }
        await tables.updateRow(
          databaseId: kDatabaseId,
          tableId: kSupportRequestsCollectionId,
          rowId: selectedRequest.value!.$id,
          data: data,
        );
        selectedRequest.value = null;
        replyController.clear();
        await load();
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
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
              Text('Support Requests', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton.filledTonal(onPressed: load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          if (error.value != null) ...[
            Text(error.value!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Subject')),
                          DataColumn(label: Text('Sender')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Created At')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: list.map((doc) {
                          final status = doc.data['status'] ?? 'open';
                          final email = doc.data['email'] ?? doc.data['username'] ?? '';
                          return DataRow(
                            cells: [
                              DataCell(Text(doc.data['subject'] ?? '')),
                              DataCell(Text(email)),
                              DataCell(Text(doc.data['category'] ?? '')),
                              DataCell(Chip(
                                label: Text(status.toString().toUpperCase()),
                                backgroundColor: status == 'resolved' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                              )),
                              DataCell(Text(doc.$createdAt)),
                              DataCell(TextButton(
                                onPressed: () {
                                  selectedRequest.value = doc;
                                  replyController.text = (doc.data['adminReply'] ?? '').toString();
                                  statusVal.value = (doc.data['status'] ?? 'open').toString();
                                },
                                child: const Text('Review'),
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                if (selectedRequest.value != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Review Support Request', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const Divider(),
                            Text('From: ${selectedRequest.value!.data['displayName'] ?? ''} (${selectedRequest.value!.data['email'] ?? ''})'),
                            const SizedBox(height: 8),
                            Text('Subject: ${selectedRequest.value!.data['subject'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(selectedRequest.value!.data['message'] ?? ''),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: statusVal.value,
                              decoration: const InputDecoration(labelText: 'Status'),
                              items: const [
                                DropdownMenuItem(value: 'open', child: Text('Open')),
                                DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                                DropdownMenuItem(value: 'answered', child: Text('Answered')),
                                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                              ],
                              onChanged: (val) {
                                if (val != null) statusVal.value = val;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: replyController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Admin Reply',
                                border: OutlineInputBorder(),
                                hintText: 'Enter your response...',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => selectedRequest.value = null,
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isLoading.value ? null : updateRequest,
                                  child: const Text('Save & Reply'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
