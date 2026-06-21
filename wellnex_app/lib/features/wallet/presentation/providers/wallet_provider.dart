import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/api_service.dart';

/// Transaction type constants — avoids scattered magic strings
abstract class TransactionType {
  static const steps = 'STEPS';
  static const streakBonus = 'STREAK_BONUS';
  static const milestone = 'MILESTONE';
  static const adReward = 'AD_REWARD';
  static const referral = 'REFERRAL';
  static const redemption = 'REDEMPTION';
}

/// Filter constants
abstract class TransactionFilter {
  static const all = 'ALL';
  static const earned = 'EARNED';
  static const redeemed = 'REDEEMED';
}

/// Transaction Model
class WalletTransaction {
  final String id;
  final String type;
  final int points;
  final String? description;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.points,
    this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    // Null-safe date parsing with fallback
    DateTime createdAt;
    final rawDate = json['createdAt'];
    if (rawDate is String && rawDate.isNotEmpty) {
      createdAt = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return WalletTransaction(
      id: json['id'] as String? ??
          json['_id'] as String? ?? '',
      type: json['type'] as String? ?? TransactionType.steps,
      points: json['points'] as int? ?? 0,
      description: json['description'] as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'points': points,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
      };

  WalletTransaction copyWith({
    String? id,
    String? type,
    int? points,
    String? description,
    DateTime? createdAt,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      points: points ?? this.points,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isEarning => points > 0;
  bool get isRedemption => points < 0 || type == TransactionType.redemption;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WalletTransaction(id: $id, type: $type, points: $points)';
}

/// Wallet State
class WalletState {
  final bool isLoading;
  final int balance;
  final int lifetimePoints;
  final List<WalletTransaction> transactions;
  final String selectedFilter;
  final String? error;

  const WalletState({
    this.isLoading = false,
    this.balance = 0,
    this.lifetimePoints = 0,
    this.transactions = const [],
    this.selectedFilter = TransactionFilter.all,
    this.error,
  });

  /// Returns a copy, with [clearError] explicitly resetting error to null.
  WalletState copyWith({
    bool? isLoading,
    int? balance,
    int? lifetimePoints,
    List<WalletTransaction>? transactions,
    String? selectedFilter,
    String? error,
    bool clearError = false,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      balance: balance ?? this.balance,
      lifetimePoints: lifetimePoints ?? this.lifetimePoints,
      transactions: transactions ?? this.transactions,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<WalletTransaction> get filteredTransactions {
    switch (selectedFilter) {
      case TransactionFilter.earned:
        return transactions.where((t) => t.isEarning).toList();
      case TransactionFilter.redeemed:
        return transactions.where((t) => t.isRedemption).toList();
      default:
        return transactions;
    }
  }

  /// Total earned points from all earning transactions
  int get totalEarned => transactions
      .where((t) => t.isEarning)
      .fold<int>(0, (sum, t) => sum + t.points);

  /// Total spent (absolute value) from all redemption transactions
  int get totalSpent => transactions
      .where((t) => t.isRedemption)
      .fold<int>(0, (sum, t) => sum + t.points.abs());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          balance == other.balance &&
          lifetimePoints == other.lifetimePoints &&
          selectedFilter == other.selectedFilter &&
          error == other.error;

  @override
  int get hashCode =>
      isLoading.hashCode ^
      balance.hashCode ^
      lifetimePoints.hashCode ^
      selectedFilter.hashCode ^
      error.hashCode;
}

/// Wallet Provider
final walletProvider =
    StateNotifierProvider.autoDispose<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.watch(apiServiceProvider));
});

class WalletNotifier extends StateNotifier<WalletState> {
  final ApiService _apiService;

  WalletNotifier(this._apiService) : super(const WalletState());

  /// Clear any current error from state
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Fetch wallet balance + transaction history
  Future<void> fetchWalletData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        _apiService.get('/rewards/wallet'),
        _apiService.get('/rewards/transactions'),
      ]);

      final walletData = results[0].data as Map<String, dynamic>? ?? {};
      final txData = results[1].data;

      // Backend may return { data: [...] } or directly a List
      List<dynamic> rawTxList;
      if (txData is Map<String, dynamic>) {
        rawTxList = txData['data'] as List<dynamic>? ??
            txData['transactions'] as List<dynamic>? ??
            [];
      } else if (txData is List<dynamic>) {
        rawTxList = txData;
      } else {
        rawTxList = [];
      }

      final transactions = rawTxList
          .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        isLoading: false,
        balance: walletData['balance'] as int? ?? 0,
        lifetimePoints: walletData['lifetimePoints'] as int? ?? 0,
        transactions: transactions,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiError.from(e).message,
      );
    }
  }

  /// Set transaction filter
  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }
}
