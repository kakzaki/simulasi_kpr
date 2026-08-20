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
  final double floatingRefRate;
  final double floatingMargin;

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
    this.floatingRefRate = 4.0,
    this.floatingMargin = 2.5,
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
      'floatingRefRate': floatingRefRate,
      'floatingMargin': floatingMargin,
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
      floatingRefRate: (json['floatingRefRate'] as num?)?.toDouble() ?? 4.0,
      floatingMargin: (json['floatingMargin'] as num?)?.toDouble() ?? 2.5,
    );
  }

  static Map<String, dynamic> _periodToJson(InterestRatePeriod p) {
    return {
      'period': p.period,
      'rate': p.rate,
      'referenceRate': p.referenceRate,
      'margin': p.margin,
      'type': p.type.name,
    };
  }

  static InterestRatePeriod _periodFromJson(Map<String, dynamic> json) {
    return InterestRatePeriod(
      json['period'] as String,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      referenceRate: (json['referenceRate'] as num?)?.toDouble(),
      margin: (json['margin'] as num?)?.toDouble(),
      type: RateType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RateType.fixed,
      ),
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
    double? floatingRefRate,
    double? floatingMargin,
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
      floatingRefRate: floatingRefRate ?? this.floatingRefRate,
      floatingMargin: floatingMargin ?? this.floatingMargin,
    );
  }

  @override
  String toString() =>
      'SimulationConfig($name, kredit=$jumlahKredit, tenor=$tenorBulan bulan, '
      '${periods.length} periode)';
}
