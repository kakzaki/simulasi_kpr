import 'package:flutter_test/flutter_test.dart';
import 'package:simulasi_kpr/models/interest_rate_period.dart';
import 'package:simulasi_kpr/services/loan_calculator.dart';

void main() {
  group('LoanCalculator.calculatePMT', () {
    test('should calculate PMT correctly for standard case', () {
      // PMT(500000000, 8%, 240 months)
      final pmt = LoanCalculator.calculatePMT(500000000, 0.08, 240);
      // Expected: ~4,182,200 (standard annuity formula)
      expect(pmt, closeTo(4182200, 1000));
    });

    test('should return principal/totalMonths when rate is 0', () {
      final pmt = LoanCalculator.calculatePMT(1200000, 0, 12);
      expect(pmt, equals(100000));
    });

    test('should return 0 when totalMonths is 0', () {
      final pmt = LoanCalculator.calculatePMT(500000000, 0.08, 0);
      expect(pmt, equals(0));
    });

    test('should handle very small principal', () {
      final pmt = LoanCalculator.calculatePMT(1000, 0.1, 12);
      expect(pmt, greaterThan(0));
      expect(pmt, lessThan(100));
    });

    test('should handle high interest rate', () {
      final pmt = LoanCalculator.calculatePMT(100000000, 0.24, 60);
      expect(pmt, greaterThan(0));
    });
  });

  group('LoanCalculator.getYearlyRate', () {
    test('should return correct fixed rate for year 1-3', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
      ];
      expect(LoanCalculator.getYearlyRate(1, periods), closeTo(0.0395, 0.001));
      expect(LoanCalculator.getYearlyRate(12, periods), closeTo(0.0395, 0.001));
      expect(LoanCalculator.getYearlyRate(36, periods), closeTo(0.0395, 0.001));
      expect(LoanCalculator.getYearlyRate(37, periods), equals(0.0));
    });

    test('should return correct graduated fixed rates', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
        InterestRatePeriod('7-20', rate: 10.25, type: RateType.fixed),
      ];

      expect(LoanCalculator.getYearlyRate(1, periods), closeTo(0.0395, 0.001));
      expect(LoanCalculator.getYearlyRate(36, periods), closeTo(0.0395, 0.001));
      expect(LoanCalculator.getYearlyRate(37, periods), closeTo(0.08, 0.001));
      expect(LoanCalculator.getYearlyRate(72, periods), closeTo(0.08, 0.001));
      expect(LoanCalculator.getYearlyRate(73, periods), closeTo(0.1025, 0.001));
      expect(LoanCalculator.getYearlyRate(240, periods), closeTo(0.1025, 0.001));
    });

    test('should handle floating rate', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-20', rate: 13.0, type: RateType.floating),
      ];

      expect(LoanCalculator.getYearlyRate(1, periods), closeTo(0.0395, 0.001));
      expect(LoanCalculator.getYearlyRate(37, periods), closeTo(0.13, 0.001));
      expect(LoanCalculator.getYearlyRate(72, periods), closeTo(0.13, 0.001));
    });

    test('should handle combination: fixed berjenjang + floating', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
        InterestRatePeriod('7-10', rate: 10.25, type: RateType.fixed),
        InterestRatePeriod('11-20', rate: 13.0, type: RateType.floating),
      ];

      expect(LoanCalculator.getYearlyRate(1, periods), closeTo(0.0395, 0.001));
      expect(LoanCalculator.getYearlyRate(49, periods), closeTo(0.08, 0.001));
      expect(LoanCalculator.getYearlyRate(85, periods), closeTo(0.1025, 0.001));
      expect(LoanCalculator.getYearlyRate(133, periods), closeTo(0.13, 0.001));
      expect(LoanCalculator.getYearlyRate(240, periods), closeTo(0.13, 0.001));
    });
  });

  group('LoanCalculator.validatePeriods', () {
    test('should return valid for correct periods', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
        InterestRatePeriod('7-20', rate: 10.25, type: RateType.fixed),
      ];
      final result = LoanCalculator.validatePeriods(periods, 240);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('should fail when periods is empty', () {
      final result = LoanCalculator.validatePeriods([], 240);
      expect(result.isValid, isFalse);
      expect(result.errors.length, equals(1));
    });

    test('should fail when period does not start from year 1', () {
      final periods = [
        InterestRatePeriod('2-5', rate: 8.0, type: RateType.fixed),
      ];
      final result = LoanCalculator.validatePeriods(periods, 240);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('tahun 1')), isTrue);
    });

    test('should detect overlap', () {
      final periods = [
        InterestRatePeriod('1-5', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-10', rate: 8.0, type: RateType.fixed),
      ];
      final result = LoanCalculator.validatePeriods(periods, 240);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Overlap')), isTrue);
    });

    test('should detect gap', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('5-20', rate: 10.25, type: RateType.fixed),
      ];
      final result = LoanCalculator.validatePeriods(periods, 240);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Gap')), isTrue);
    });

    test('should detect incomplete coverage', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
      ];
      final result = LoanCalculator.validatePeriods(periods, 240);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('mencakup')), isTrue);
    });

    test('should pass for combination fixed + floating covering full tenor', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
        InterestRatePeriod('7-20', rate: 13.0, type: RateType.floating),
      ];
      final result = LoanCalculator.validatePeriods(periods, 240);
      expect(result.isValid, isTrue);
    });

    test('should fail when start >= end', () {
      final periods = [
        InterestRatePeriod('5-3', rate: 3.95, type: RateType.fixed),
      ];
      final result = LoanCalculator.validatePeriods(periods, 240);
      expect(result.isValid, isFalse);
    });
  });

  group('LoanCalculator.calculate', () {
    test('should calculate standard graduated fixed correctly', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
        InterestRatePeriod('7-20', rate: 10.25, type: RateType.fixed),
      ];

      final result = LoanCalculator.calculate(
        principal: 500000000,
        tenorMonths: 240,
        periods: periods,
        useFixedPmtPerPeriod: true,
      );

      expect(result.totalPokok, closeTo(500000000, 100));
      expect(result.totalBunga, greaterThan(0));
      expect(result.totalPembayaran,
          closeTo(result.totalPokok + result.totalBunga, 1));
      expect(result.entries.last.sisaPinjaman, closeTo(0, 1));
      expect(result.entries.length, equals(240));
    });

    test('should handle floating rate calculation', () {
      final periods = [
        InterestRatePeriod('1-20', rate: 13.0, type: RateType.floating),
      ];

      final result = LoanCalculator.calculate(
        principal: 100000000,
        tenorMonths: 240,
        periods: periods,
        useFixedPmtPerPeriod: true,
      );

      for (final entry in result.entries) {
        expect(entry.rate, closeTo(0.13, 0.001));
      }
      expect(result.totalPokok, closeTo(100000000, 100));
    });

    test('should handle combination fixed + floating', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-20', rate: 13.0, type: RateType.floating),
      ];

      final result = LoanCalculator.calculate(
        principal: 300000000,
        tenorMonths: 240,
        periods: periods,
        useFixedPmtPerPeriod: true,
      );

      for (int i = 0; i < 36; i++) {
        expect(result.entries[i].rate, closeTo(0.0395, 0.001));
      }
      for (int i = 36; i < 240; i++) {
        expect(result.entries[i].rate, closeTo(0.13, 0.001));
      }
      expect(result.totalPokok, closeTo(300000000, 100));
    });

    test('should handle fixed PMT per period correctly', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
      ];

      final result = LoanCalculator.calculate(
        principal: 200000000,
        tenorMonths: 72,
        periods: periods,
        useFixedPmtPerPeriod: true,
      );

      final firstPeriodPmt = result.entries[0].angsuran;
      for (int i = 0; i < 36; i++) {
        expect(result.entries[i].angsuran, closeTo(firstPeriodPmt, 1));
      }

      final secondPeriodPmt = result.entries[36].angsuran;
      for (int i = 36; i < 72; i++) {
        expect(result.entries[i].angsuran, closeTo(secondPeriodPmt, 1));
      }

      expect(secondPeriodPmt, isNot(closeTo(firstPeriodPmt, 1)));
    });

    test('should handle prepayments', () {
      final periods = [
        InterestRatePeriod('1-20', rate: 8.0, type: RateType.fixed),
      ];

      final result = LoanCalculator.calculate(
        principal: 100000000,
        tenorMonths: 240,
        periods: periods,
        prepayments: [
          {'bulan': 12, 'nominal': 10000000.0},
        ],
        penaltyRate: 10,
        useFixedPmtPerPeriod: true,
      );

      expect(result.entries[11].pelunasanMaju, closeTo(10000000, 1));
      expect(result.entries[11].penalty, closeTo(1000000, 1));
      expect(result.totalPelunasanMaju, closeTo(10000000, 1));
      expect(result.totalPenalti, closeTo(1000000, 1));
      // With prepayments, total pokok + prepayments = principal
      expect(result.totalPokok + result.totalPelunasanMaju, closeTo(100000000, 500000));
    });

    test('should handle zero interest rate', () {
      final periods = [
        InterestRatePeriod('1-20', rate: 0, type: RateType.fixed),
      ];

      final result = LoanCalculator.calculate(
        principal: 1200000,
        tenorMonths: 12,
        periods: periods,
        useFixedPmtPerPeriod: true,
      );

      for (final entry in result.entries) {
        expect(entry.angsuran, closeTo(100000, 1));
        expect(entry.bunga, equals(0));
      }
    });

    test('should handle very short tenor (1 month)', () {
      final periods = [
        InterestRatePeriod('1-1', rate: 10.0, type: RateType.fixed),
      ];

      final result = LoanCalculator.calculate(
        principal: 100000000,
        tenorMonths: 1,
        periods: periods,
        useFixedPmtPerPeriod: true,
      );

      expect(result.entries.length, equals(1));
      expect(result.entries[0].sisaPinjaman, closeTo(0, 1));
      expect(result.totalPokok, closeTo(100000000, 100));
    });

    test('should handle graduated fixed with 20 year tenor', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
        InterestRatePeriod('7-20', rate: 10.25, type: RateType.fixed),
      ];

      final result = LoanCalculator.calculate(
        principal: 500000000,
        tenorMonths: 240,
        periods: periods,
        useFixedPmtPerPeriod: true,
      );

      expect(result.entries[35].rate, closeTo(0.0395, 0.001));
      expect(result.entries[36].rate, closeTo(0.08, 0.001));
      expect(result.entries[71].rate, closeTo(0.08, 0.001));
      expect(result.entries[72].rate, closeTo(0.1025, 0.001));
      expect(result.entries[239].rate, closeTo(0.1025, 0.001));
    });

    test('should handle 20 year tenor: 10 year fixed berjenjang + 10 year floating', () {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
        InterestRatePeriod('7-10', rate: 10.25, type: RateType.fixed),
        InterestRatePeriod('11-20', rate: 13.0, type: RateType.floating),
      ];

      final validation = LoanCalculator.validatePeriods(periods, 240);
      expect(validation.isValid, isTrue, reason: validation.errors.join(', '));

      final result = LoanCalculator.calculate(
        principal: 500000000,
        tenorMonths: 240,
        periods: periods,
        useFixedPmtPerPeriod: true,
      );

      for (int i = 0; i < 36; i++) {
        expect(result.entries[i].rate, closeTo(0.0395, 0.001),
            reason: 'Month ${i + 1} should be 3.95%');
      }
      for (int i = 36; i < 72; i++) {
        expect(result.entries[i].rate, closeTo(0.08, 0.001),
            reason: 'Month ${i + 1} should be 8.0%');
      }
      for (int i = 72; i < 120; i++) {
        expect(result.entries[i].rate, closeTo(0.1025, 0.001),
            reason: 'Month ${i + 1} should be 10.25%');
      }
      for (int i = 120; i < 240; i++) {
        expect(result.entries[i].rate, closeTo(0.13, 0.001),
            reason: 'Month ${i + 1} should be 13.0% (floating)');
      }

      expect(result.totalPokok, closeTo(500000000, 100));
      expect(result.entries.last.sisaPinjaman, closeTo(0, 1));
    });
  });

  group('InterestRatePeriod model', () {
    test('should calculate effectiveRate correctly for fixed', () {
      final p = InterestRatePeriod('1-3', rate: 8.0, type: RateType.fixed);
      expect(p.effectiveRate, closeTo(0.08, 0.001));
      expect(p.effectiveRatePercent, closeTo(8.0, 0.01));
    });

    test('should calculate effectiveRate correctly for floating', () {
      final p = InterestRatePeriod(
        '4-20',
        rate: 13.0,
        type: RateType.floating,
      );
      expect(p.effectiveRate, closeTo(0.13, 0.001));
      expect(p.effectiveRatePercent, closeTo(13.0, 0.01));
    });

    test('should parse startYear and endYear correctly', () {
      final p = InterestRatePeriod('7-20', rate: 10.25, type: RateType.fixed);
      expect(p.startYear, equals(7));
      expect(p.endYear, equals(20));
    });

    test('should generate correct rateDescription for fixed', () {
      final p = InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed);
      expect(p.rateDescription, contains('3.95'));
      expect(p.rateDescription, contains('Fixed'));
    });

    test('should generate correct rateDescription for floating', () {
      final p = InterestRatePeriod(
        '4-20',
        rate: 13.0,
        type: RateType.floating,
      );
      expect(p.rateDescription, contains('13.00'));
      expect(p.rateDescription, contains('Floating'));
    });

    test('should copyWith correctly', () {
      final original = InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed);
      final modified = original.copyWith(rate: 5.0);
      expect(modified.rate, equals(5.0));
      expect(modified.period, equals('1-3'));
      expect(modified.type, equals(RateType.fixed));
    });
  });
}
