import 'dart:math';

import '../models/amortization_entry.dart';
import '../models/interest_rate_period.dart';

/// Hasil validasi periode
class PeriodValidation {
  final bool isValid;
  final List<String> errors;

  const PeriodValidation({required this.isValid, required this.errors});

  static const valid = PeriodValidation(isValid: true, errors: []);
}

/// Hasil perhitungan kredit
class LoanCalculationResult {
  final List<AmortizationEntry> entries;
  final double totalPokok;
  final double totalBunga;
  final double totalAngsuran;
  final double totalPelunasanMaju;
  final double totalPenalti;
  final double totalPembayaran;

  const LoanCalculationResult({
    required this.entries,
    required this.totalPokok,
    required this.totalBunga,
    required this.totalAngsuran,
    required this.totalPelunasanMaju,
    required this.totalPenalti,
    required this.totalPembayaran,
  });
}

/// Service untuk perhitungan simulasi KPR
class LoanCalculator {
  /// Menghitung PMT (Payment) menggunakan formula annuity
  ///
  /// [principal] - jumlah pinjaman
  /// [yearlyRate] - suku bunga tahunan (desimal, misal 0.08 untuk 8%)
  /// [totalMonths] - sisa tenor dalam bulan
  ///
  /// Returns: angsuran per bulan
  static double calculatePMT(
      double principal, double yearlyRate, int totalMonths) {
    if (totalMonths <= 0) return 0;
    final monthlyRate = yearlyRate / 12;
    if (monthlyRate == 0) return principal / totalMonths;
    final pvif = pow(1 + monthlyRate, totalMonths);
    return (principal * monthlyRate * pvif / (pvif - 1)).toDouble();
  }

  /// Mendapatkan rate tahunan berdasarkan bulan keberapa
  ///
  /// Menggunakan periode-periode yang sudah diatur.
  /// Bulan 1-12 = tahun 1, bulan 13-24 = tahun 2, dst.
  static double getYearlyRate(int bulan, List<InterestRatePeriod> periods) {
    int tahun = ((bulan - 1) ~/ 12) + 1;
    for (var p in periods) {
      if (tahun >= p.startYear && tahun <= p.endYear) {
        return p.effectiveRate;
      }
    }
    // Jika tidak ada periode yang match, return 0
    return 0.0;
  }

  /// Mendapatkan periode yang berlaku untuk bulan tertentu
  static InterestRatePeriod? getPeriodForMonth(
      int bulan, List<InterestRatePeriod> periods) {
    int tahun = ((bulan - 1) ~/ 12) + 1;
    for (var p in periods) {
      if (tahun >= p.startYear && tahun <= p.endYear) {
        return p;
      }
    }
    return null;
  }

  /// Validasi periode-periode yang diberikan
  ///
  /// Memeriksa:
  /// - Tidak ada overlap
  /// - Tidak ada gap
  /// - Coverage sesuai tenor
  static PeriodValidation validatePeriods(
      List<InterestRatePeriod> periods, int tenorMonths) {
    final errors = <String>[];

    if (periods.isEmpty) {
      errors.add('Minimal harus ada satu periode rate');
      return PeriodValidation(isValid: false, errors: errors);
    }

    // Sort by start year
    final sorted = List<InterestRatePeriod>.from(periods)
      ..sort((a, b) => a.startYear.compareTo(b.startYear));

    final totalYears = (tenorMonths / 12).ceil();

    // Check mulai dari tahun 1
    if (sorted.first.startYear != 1) {
      errors.add('Periode harus dimulai dari tahun 1');
    }

    // Check overlap dan gap
    for (int i = 0; i < sorted.length; i++) {
      final current = sorted[i];

      // Validasi range tahun
      if (current.startYear >= current.endYear) {
        errors.add(
            'Tahun mulai (${current.startYear}) harus kurang dari tahun akhir (${current.endYear})');
      }

      // Check overlap dengan period berikutnya
      if (i < sorted.length - 1) {
        final next = sorted[i + 1];
        if (current.endYear >= next.startYear) {
          errors.add(
              'Overlap: Tahun ${current.period} dan ${next.period}');
        }

        // Check gap
        if (current.endYear + 1 < next.startYear) {
          errors.add(
              'Gap: Tidak ada rate untuk tahun ${current.endYear + 1} sampai ${next.startYear - 1}');
        }
      }
    }

    // Check coverage sampai tenor
    if (sorted.last.endYear < totalYears) {
      errors.add(
          'Periode rate tidak mencakup sampai tahun $totalYears. '
          'Periode terakhir hanya sampai tahun ${sorted.last.endYear}');
    }

    return PeriodValidation(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Menghitung simulasi amortization
  ///
  /// [principal] - jumlah pinjaman
  /// [tenorMonths] - tenor dalam bulan
  /// [periods] - list periode rate
  /// [prepayments] - list pelunasan dipercepat {bulan, nominal}
  /// [penaltyRate] - rate penalti (persen, misal 10 untuk 10%)
  /// [useFixedPmtPerPeriod] - jika true, PMT tetap dalam satu periode rate
  static LoanCalculationResult calculate({
    required double principal,
    required int tenorMonths,
    required List<InterestRatePeriod> periods,
    List<Map<String, double>>? prepayments,
    double penaltyRate = 0,
    bool useFixedPmtPerPeriod = true,
  }) {
    final entries = <AmortizationEntry>[];
    double sisa = principal;
    double? currentPmt;
    int currentPeriodStart = 0;

    for (int i = 1; i <= tenorMonths; i++) {
      final yearlyRate = getYearlyRate(i, periods);
      final monthlyRate = yearlyRate / 12;

      // Tentukan PMT
      if (useFixedPmtPerPeriod) {
        // PMT dihitung sekali di awal setiap periode rate
        final sisaBulan = tenorMonths - i + 1;
        if (currentPmt == null || _isNewPeriod(i, periods, currentPeriodStart)) {
          currentPmt = calculatePMT(sisa, yearlyRate, sisaBulan);
          currentPeriodStart = i;
        }
      } else {
        // PMT dihitung ulang setiap bulan (approach lama)
        currentPmt = calculatePMT(sisa, yearlyRate, tenorMonths - i + 1);
      }

      // Jika sisa sudah 0, tidak ada pembayaran lagi
      if (sisa <= 0) {
        entries.add(AmortizationEntry(
          bulan: i,
          rate: yearlyRate,
          pokok: 0,
          bunga: 0,
          angsuran: 0,
          sisaPinjaman: 0,
        ));
        continue;
      }

      final bunga = sisa * monthlyRate;
      final pokok = currentPmt - bunga;

      // Pelunasan dipercepat
      double pelunasan = 0, penalty = 0;
      if (prepayments != null) {
        final pm = prepayments.where((p) => p['bulan'] == i.toDouble());
        if (pm.isNotEmpty) {
          pelunasan = pm.first['nominal']!;
          if (pelunasan > sisa) pelunasan = sisa;
          penalty = pelunasan * penaltyRate / 100;
        }
      }

      sisa = sisa - pokok - pelunasan;
      if (sisa < 0) sisa = 0;

      entries.add(AmortizationEntry(
        bulan: i,
        rate: yearlyRate,
        pokok: pokok,
        bunga: bunga,
        angsuran: currentPmt,
        pelunasanMaju: pelunasan,
        penalty: penalty,
        sisaPinjaman: sisa,
      ));
    }

    // Hitung total
    double totalPokok = 0, totalBunga = 0, totalAngsuran = 0;
    double totalPelunasan = 0, totalPenalti = 0;

    for (final e in entries) {
      totalPokok += e.pokok;
      totalBunga += e.bunga;
      totalAngsuran += e.angsuran;
      totalPelunasan += e.pelunasanMaju;
      totalPenalti += e.penalty;
    }

    return LoanCalculationResult(
      entries: entries,
      totalPokok: totalPokok,
      totalBunga: totalBunga,
      totalAngsuran: totalAngsuran,
      totalPelunasanMaju: totalPelunasan,
      totalPenalti: totalPenalti,
      totalPembayaran: totalAngsuran + totalPelunasan + totalPenalti,
    );
  }

  /// Cek apakah bulan ini adalah awal periode rate baru
  static bool _isNewPeriod(
      int bulan, List<InterestRatePeriod> periods, int currentStart) {
    int tahun = ((bulan - 1) ~/ 12) + 1;
    for (var p in periods) {
      if (tahun == p.startYear && bulan != currentStart) {
        return true;
      }
    }
    return false;
  }
}
