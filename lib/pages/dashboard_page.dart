import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../constants.dart';

class DashboardPage extends HookWidget {
  const DashboardPage({super.key, required this.tables});

  final TablesDB tables;

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(false);
    final error = useState<String?>(null);

    final totalUsers = useState<int>(0);
    final dailyNewUsers = useState<int>(0);
    final activeUsers = useState<int>(0);
    final totalPosts = useState<int>(0);
    final activeBoosts = useState<int>(0);
    final totalBoosts = useState<int>(0);
    final openReports = useState<int>(0);

    final totalRevenue = useState<double>(0.0);
    final totalPaidOut = useState<double>(0.0);
    final dailyEarnings = useState<double>(0.0);
    final monthlyEarnings = useState<double>(0.0);

    final momentumPosts = useState<List<models.Row>>([]);
    final countries = useState<Map<String, int>>({});

    Future<models.RowList> safeList(String tableId, List<String> queries) async {
      try {
        return await tables.listRows(
          databaseId: kDatabaseId,
          tableId: tableId,
          queries: queries,
        );
      } catch (_) {
        return models.RowList(total: 0, rows: []);
      }
    }

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        final now = DateTime.now();
        final oneDayAgo = now.subtract(const Duration(days: 1)).toIso8601String();
        final thirtyDaysAgo = now.subtract(const Duration(days: 30)).toIso8601String();

        final results = await Future.wait([
          // 0. Total Users
          safeList(kProfilesCollectionId, [Query.limit(1)]),
          // 1. Daily New Users (created last 24h)
          safeList(kProfilesCollectionId, [Query.greaterThan('\$createdAt', oneDayAgo), Query.limit(1)]),
          // 2. Active Users (updated last 24h)
          safeList(kProfilesCollectionId, [Query.greaterThan('\$updatedAt', oneDayAgo), Query.limit(1)]),
          // 3. Total Posts
          safeList(kPostsCollectionId, [Query.limit(1)]),
          // 4. Active Running Boosts
          safeList(kBoostsCollectionId, [Query.equal('status', 'running'), Query.limit(1)]),
          // 5. Total Boosts
          safeList(kBoostsCollectionId, [Query.limit(1)]),
          // 6. Open Reports
          safeList(kReportsCollectionId, [Query.limit(1)]),
          // 7. Momentum Posts (Impression leaders)
          safeList(kPostsCollectionId, [Query.orderDesc('impressions'), Query.limit(5)]),
          // 8. Payouts (Paid)
          safeList(kPayoutsCollectionId, [Query.equal('status', 'paid'), Query.limit(500)]),
          // 9. All Boosts
          safeList(kBoostsCollectionId, [Query.limit(500)]),
          // 10. Recent Ad Revenue events
          safeList(kAdRevenueCollectionId, [Query.greaterThan('timestamp', thirtyDaysAgo), Query.limit(1000)]),
          // 11. Geographic sample
          safeList(kProfilesCollectionId, [Query.limit(200)]),
        ]);

        totalUsers.value = results[0].total;
        dailyNewUsers.value = results[1].total;
        activeUsers.value = results[2].total;
        totalPosts.value = results[3].total;
        activeBoosts.value = results[4].total;
        totalBoosts.value = results[5].total;
        openReports.value = results[6].total;
        momentumPosts.value = results[7].rows;

        // Aggregate Financial Metrics
        double totalRevVal = 0.0;
        double totalPaidVal = 0.0;
        double dailyEarningVal = 0.0;
        double monthlyEarningVal = 0.0;

        // Process Creator Payouts
        for (final row in results[8].rows) {
          final amt = (row.data['amount'] ?? 0) as num;
          totalPaidVal += amt.toDouble();
        }

        // Process Boosts Payments (Revenue)
        for (final row in results[9].rows) {
          final amt = (row.data['amountUsd'] ?? row.data['amount'] ?? 0.0) as num;
          final amtDouble = amt.toDouble();
          totalRevVal += amtDouble;

          final cAtStr = row.$createdAt;
          final cAt = DateTime.tryParse(cAtStr.toString());
          if (cAt != null) {
            final diff = now.difference(cAt);
            if (diff.inHours <= 24) {
              dailyEarningVal += amtDouble;
            }
            if (diff.inDays <= 30) {
              monthlyEarningVal += amtDouble;
            }
          }
        }

        // Process Ad Revenue events
        for (final row in results[10].rows) {
          final valMicros = (row.data['valueMicros'] ?? row.data['value_micros'] ?? 0) as num;
          final adAmt = valMicros.toDouble() / 1e6;
          totalRevVal += adAmt;

          final tsStr = row.data['timestamp'] ?? row.$createdAt;
          final ts = DateTime.tryParse(tsStr.toString());
          if (ts != null) {
            final diff = now.difference(ts);
            if (diff.inHours <= 24) {
              dailyEarningVal += adAmt;
            }
            if (diff.inDays <= 30) {
              monthlyEarningVal += adAmt;
            }
          }
        }

        totalRevenue.value = totalRevVal;
        totalPaidOut.value = totalPaidVal;
        dailyEarnings.value = dailyEarningVal;
        monthlyEarnings.value = monthlyEarningVal;

        // Process country demographics
        final byCountry = <String, int>{};
        for (final row in results[11].rows) {
          final raw = (row.data['country'] as String?) ?? 'Unknown';
          final code = raw.isEmpty ? 'Unknown' : raw;
          byCountry[code] = (byCountry[code] ?? 0) + 1;
        }
        countries.value = byCountry;

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

    if (isLoading.value && totalUsers.value == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget metricGroupTitle(String title) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 8),
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    Widget metricCard(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: isDark
                    ? [theme.colorScheme.surface, theme.colorScheme.surface.withOpacity(0.85)]
                    : [Colors.white, Colors.white.withOpacity(0.9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    List<Widget> countryWidgets() {
      if (countries.value.isEmpty) {
        return [
          Text(
            'No geographic data yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ];
      }
      final entries = countries.value.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return entries.take(5).map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${e.value} users', style: TextStyle(color: theme.colorScheme.primary)),
            ],
          ),
        );
      }).toList();
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Admin Hub',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Real-time overview of the XapZap platform'),
                  ],
                ),
                IconButton.filledTonal(
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (error.value != null) ...[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          error.value!,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // FINANCIAL ANALYTICS
            metricGroupTitle('FINANCIAL ANALYTICS (USD)'),
            Row(
              children: [
                metricCard(
                  'Total Platform Revenue',
                  '\$${totalRevenue.value.toStringAsFixed(2)}',
                  Icons.monetization_on,
                  Colors.green,
                ),
                const SizedBox(width: 12),
                metricCard(
                  'Daily Earnings (24h)',
                  '\$${dailyEarnings.value.toStringAsFixed(2)}',
                  Icons.trending_up,
                  Colors.teal,
                ),
                const SizedBox(width: 12),
                metricCard(
                  'Monthly Earnings (30d)',
                  '\$${monthlyEarnings.value.toStringAsFixed(2)}',
                  Icons.calendar_month,
                  Colors.orange,
                ),
                const SizedBox(width: 12),
                metricCard(
                  'Paid to Creators',
                  '\$${totalPaidOut.value.toStringAsFixed(2)}',
                  Icons.account_balance,
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // USER ANALYTICS
            metricGroupTitle('USER GROWTH & TRAFFIC'),
            Row(
              children: [
                metricCard(
                  'All Registered Users',
                  totalUsers.value.toString(),
                  Icons.people,
                  Colors.indigo,
                ),
                const SizedBox(width: 12),
                metricCard(
                  'Daily New Users (24h)',
                  dailyNewUsers.value.toString(),
                  Icons.person_add,
                  Colors.deepPurple,
                ),
                const SizedBox(width: 12),
                metricCard(
                  'Active Users (24h)',
                  activeUsers.value.toString(),
                  Icons.bolt,
                  Colors.amber,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // CONTENT & MODERATION
            metricGroupTitle('PLATFORM HEALTH'),
            Row(
              children: [
                metricCard(
                  'Total Posts Shared',
                  totalPosts.value.toString(),
                  Icons.article,
                  Colors.blueGrey,
                ),
                const SizedBox(width: 12),
                metricCard(
                  'Active Ad Campaigns',
                  activeBoosts.value.toString(),
                  Icons.campaign,
                  Colors.purple,
                ),
                const SizedBox(width: 12),
                metricCard(
                  'Open Reports',
                  openReports.value.toString(),
                  Icons.report,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MOMENTUM CONTENT (TRENDING)
                Expanded(
                  flex: 3,
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.insights, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Momentum Content (Trending)',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          if (momentumPosts.value.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: Text('No momentum content detected yet.')),
                            )
                          else
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(1),
                                2: FlexColumnWidth(1),
                                3: FlexColumnWidth(1),
                                4: FlexColumnWidth(1.2),
                              },
                              children: [
                                TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Text('Post ID', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                                    ),
                                    Text('Kind', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                                    Text('Likes', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                                    Text('Comments', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                                    Text('Impressions', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                ...momentumPosts.value.map((post) {
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text(post.$id, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                                      ),
                                      Text(post.data['kind'] ?? '', style: const TextStyle(fontSize: 13)),
                                      Text('${post.data['likes'] ?? 0}', style: const TextStyle(fontSize: 13)),
                                      Text('${post.data['comments'] ?? 0}', style: const TextStyle(fontSize: 13)),
                                      Text(
                                        '${post.data['impressions'] ?? 0}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // COUNTRIES DEMOGRAPHICS
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.public, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Geo Distribution (Sample)',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          ...countryWidgets(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
