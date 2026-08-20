/// Tipe suku bunga: fixed atau floating
enum RateType { fixed, floating }

/// Model periode suku bunga KPR
class InterestRatePeriod {
  final String period; // "1-3" (tahun)
  final double rate; // rate dalam %
  final double? referenceRate; // deprecated, kept for backward compat
  final double? margin; // deprecated, kept for backward compat
  final RateType type;

  InterestRatePeriod(
    this.period, {
    this.rate = 0,
    this.referenceRate,
    this.margin,
    required this.type,
  });

  /// Tahun mulai periode (1-indexed)
  int get startYear {
    final parts = period.split('-');
    return int.parse(parts[0]);
  }

  /// Tahun akhir periode (inclusive)
  int get endYear {
    final parts = period.split('-');
    return int.parse(parts[1]);
  }

  /// Effective rate dalam bentuk desimal (misal 0.08 untuk 8%)
  double get effectiveRate {
    // Always use rate field directly (both fixed & floating)
    // ReferenceRate + margin deprecated, kept for backward compat only
    return rate / 100;
  }

  /// Effective rate dalam bentuk persen
  double get effectiveRatePercent => effectiveRate * 100;

  /// Deskripsi tipe dalam bahasa Indonesia
  String get typeLabel {
    switch (type) {
      case RateType.fixed:
        return 'Fixed';
      case RateType.floating:
        return 'Floating';
    }
  }

  /// Deskripsi rate untuk ditampilkan
  String get rateDescription {
    switch (type) {
      case RateType.fixed:
        return '${rate.toStringAsFixed(2)}% (Fixed)';
      case RateType.floating:
        return '${rate.toStringAsFixed(2)}% (Floating)';
    }
  }

  InterestRatePeriod copyWith({
    String? period,
    double? rate,
    double? referenceRate,
    double? margin,
    RateType? type,
  }) {
    return InterestRatePeriod(
      period ?? this.period,
      rate: rate ?? this.rate,
      referenceRate: referenceRate ?? this.referenceRate,
      margin: margin ?? this.margin,
      type: type ?? this.type,
    );
  }

  @override
  String toString() =>
      'InterestRatePeriod($period, $type, rate=$rate)';
}
