import 'interest_rate_period.dart';

/// Konfigurasi simulasi KPR yang bisa disimpan/di-load
class SimulationConfig {
  final String name;
  final DateTime createdAt;
  final double jumlahKredit;
  final int tenorBulan;
  final List<InterestRatePeriod> periods;
  final bool isPelunasanMajuActive;
  final double penaltyRate;
  final List<Map<String, double>> pelunasanMaju;
  final bool useFixedPmtPerPeriod;

  SimulationConfig({
    required this.name,
    required this.createdAt,
    required this.jumlahKredit,
    required this.tenorBulan,
    required this.periods,
    this.isPelunasanMajuActive = false,
    this.penaltyRate = 10,
    this.pelunasanMaju = const [],
    this.useFixedPmtPerPeriod = true,
  });

  /// Konversi ke Map untuk disimpan ke JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'jumlahKredit': jumlahKredit,
      'tenorBulan': tenorBulan,
      'periods': periods.map((p) => _periodToJson(p)).toList(),
      'isPelunasanMajuActive': isPelunasanMajuActive,
      'penaltyRate': penaltyRate,
      'pelunasanMaju': pelunasanMaju,
      'useFixedPmtPerPeriod': useFixedPmtPerPeriod,
    };
  }

  /// Buat dari Map (JSON)
  factory SimulationConfig.fromJson(Map<String, dynamic> json) {
    return SimulationConfig(
      name: json['name'] as String? ?? 'Untitled',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      jumlahKredit: (json['jumlahKredit'] as num?)?.toDouble() ?? 0,
      tenorBulan: json['tenorBulan'] as int? ?? 240,
      periods: (json['periods'] as List<dynamic>?)
              ?.map((e) => _periodFromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isPelunasanMajuActive: json['isPelunasanMajuActive'] as bool? ?? false,
      penaltyRate: (json['penaltyRate'] as num?)?.toDouble() ?? 10,
      pelunasanMaju: (json['pelunasanMaju'] as List<dynamic>?)
              ?.map((e) => (e as Map<String, dynamic>).map(
                    (k, v) => MapEntry(k, (v as num).toDouble()),
                  ))
              .toList() ??
          [],
      useFixedPmtPerPeriod: json['useFixedPmtPerPeriod'] as bool? ?? true,
    );
  }

  static Map<String, dynamic> _periodToJson(InterestRatePeriod p) {
    return {
      'period': p.period,
      'rate': p.rate,
      'type': p.type.name,
    };
  }

  static InterestRatePeriod _periodFromJson(Map<String, dynamic> json) {
    // Backward compat: old format had referenceRate + margin for floating
    // New format just uses rate for both fixed and floating
    final type = RateType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => RateType.fixed,
    );

    if (type == RateType.floating && json['rate'] == 0) {
      // Old format: compute rate from referenceRate + margin
      final refRate = (json['referenceRate'] as num?)?.toDouble() ?? 0;
      final m = (json['margin'] as num?)?.toDouble() ?? 0;
      return InterestRatePeriod(
        json['period'] as String,
        rate: refRate + m,
        type: type,
      );
    }

    return InterestRatePeriod(
      json['period'] as String,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      type: type,
    );
  }

  /// Salin dengan perubahan
  SimulationConfig copyWith({
    String? name,
    DateTime? createdAt,
    double? jumlahKredit,
    int? tenorBulan,
    List<InterestRatePeriod>? periods,
    bool? isPelunasanMajuActive,
    double? penaltyRate,
    List<Map<String, double>>? pelunasanMaju,
    bool? useFixedPmtPerPeriod,
  }) {
    return SimulationConfig(
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      jumlahKredit: jumlahKredit ?? this.jumlahKredit,
      tenorBulan: tenorBulan ?? this.tenorBulan,
      periods: periods ?? this.periods,
      isPelunasanMajuActive: isPelunasanMajuActive ?? this.isPelunasanMajuActive,
      penaltyRate: penaltyRate ?? this.penaltyRate,
      pelunasanMaju: pelunasanMaju ?? this.pelunasanMaju,
      useFixedPmtPerPeriod: useFixedPmtPerPeriod ?? this.useFixedPmtPerPeriod,
    );
  }

  @override
  String toString() =>
      'SimulationConfig($name, kredit=$jumlahKredit, tenor=$tenorBulan bulan, '
      '${periods.length} periode)';
}
