import 'package:appwrite/appwrite.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final appwriteClientProvider = Provider<Client>((ref) {
  final client = Client()
      .setEndpoint('https://api.xapzap.com/v1')
      .setProject('690641ad0029b51eefe0');
  return client;
});

final accountProvider = Provider<Account>((ref) {
  final client = ref.watch(appwriteClientProvider);
  return Account(client);
});

final tablesProvider = Provider<TablesDB>((ref) {
  final client = ref.watch(appwriteClientProvider);
  return TablesDB(client);
});
