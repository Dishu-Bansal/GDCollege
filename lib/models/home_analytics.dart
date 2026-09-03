/// One logged-in account's share of an activity during the day.
///
/// [account] is the email of the logged-in user who performed the activity
/// (the `changedBy` value on the underlying audit/stock logs). An empty
/// account string means the actor was not recorded for those entries (for
/// example unattributed historical activity) and is rendered as
/// "Unknown account". [amount] is that account's contribution.
typedef AccountAmount = ({String account, int amount});

/// Converts an account → amount tally into a [List] of [AccountAmount]s,
/// sorted descending by amount (ties broken alphabetically by account).
List<AccountAmount> accountSharesFromTally(Map<String, int> tally) {
  final shares =
      <AccountAmount>[
        for (final e in tally.entries)
          if (e.value > 0) (account: e.key, amount: e.value),
      ]..sort((a, b) {
        final byAmount = b.amount.compareTo(a.amount);
        return byAmount != 0 ? byAmount : a.account.compareTo(b.account);
      });
  return shares;
}

/// Aggregated activity counts for a single calendar day.
///
/// Each activity total has a matching account-wise breakdown
/// ([AccountAmount] list) whose entries sum to that total.
class HomeAnalytics {
  /// Start of the analytics day (00:00 IST).
  final DateTime day;

  // Students
  final int studentsCreated;
  final int studentsUpdated;
  final int studentsDeleted;

  // Staff
  final int staffCreated;
  final int staffUpdated;
  final int staffDeleted;

  // Stock
  final int inspectionsDone;
  final int itemsAdded;
  final int itemsRemoved;
  final int assignmentsDone;

  // Account-wise breakdowns (per-account share of each total above).
  final List<AccountAmount> studentsCreatedAccounts;
  final List<AccountAmount> studentsUpdatedAccounts;
  final List<AccountAmount> studentsDeletedAccounts;
  final List<AccountAmount> staffCreatedAccounts;
  final List<AccountAmount> staffUpdatedAccounts;
  final List<AccountAmount> staffDeletedAccounts;
  final List<AccountAmount> inspectionsAccounts;
  final List<AccountAmount> itemsAddedAccounts;
  final List<AccountAmount> itemsRemovedAccounts;
  final List<AccountAmount> assignmentsAccounts;

  const HomeAnalytics({
    required this.day,
    this.studentsCreated = 0,
    this.studentsUpdated = 0,
    this.studentsDeleted = 0,
    this.staffCreated = 0,
    this.staffUpdated = 0,
    this.staffDeleted = 0,
    this.inspectionsDone = 0,
    this.itemsAdded = 0,
    this.itemsRemoved = 0,
    this.assignmentsDone = 0,
    this.studentsCreatedAccounts = const [],
    this.studentsUpdatedAccounts = const [],
    this.studentsDeletedAccounts = const [],
    this.staffCreatedAccounts = const [],
    this.staffUpdatedAccounts = const [],
    this.staffDeletedAccounts = const [],
    this.inspectionsAccounts = const [],
    this.itemsAddedAccounts = const [],
    this.itemsRemovedAccounts = const [],
    this.assignmentsAccounts = const [],
  });

  int get studentEvents => studentsCreated + studentsUpdated + studentsDeleted;

  int get staffEvents => staffCreated + staffUpdated + staffDeleted;

  bool get hasAnyActivity =>
      studentEvents > 0 ||
      staffEvents > 0 ||
      inspectionsDone > 0 ||
      itemsAdded > 0 ||
      itemsRemoved > 0 ||
      assignmentsDone > 0;
}
