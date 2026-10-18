/// Monthly AI receipt-scan usage of the current user.
///
/// [scanLimit] comes from `memberships/{membershipId}.receiptScanQuota`;
/// `null` means the plan has no limit.
class ReceiptScanQuota {
  final int scansUsed;
  final int? scanLimit;

  const ReceiptScanQuota({required this.scansUsed, required this.scanLimit});

  bool get isUnlimited => scanLimit == null;

  bool get isQuotaExceeded => !isUnlimited && scansUsed >= scanLimit!;

  /// Remaining scans this period, or `null` when the plan is unlimited.
  int? get scansRemaining {
    final limit = scanLimit;
    if (limit == null) return null;
    final remaining = limit - scansUsed;
    return remaining < 0 ? 0 : remaining;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceiptScanQuota &&
        other.scansUsed == scansUsed &&
        other.scanLimit == scanLimit;
  }

  @override
  int get hashCode => Object.hash(scansUsed, scanLimit);
}
