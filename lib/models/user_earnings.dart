class UserEarnings {
  UserEarnings({
    required this.userId,
    required this.currency,
  });

  final String userId;
  final String currency;
  int totalMicros = 0;
  int eventCount = 0;
  DateTime? lastEventAt;
  final Set<String> countries = <String>{};
}
