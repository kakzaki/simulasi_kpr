import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulasi_kpr/main.dart';
import 'package:simulasi_kpr/models/interest_rate_period.dart';
import 'package:simulasi_kpr/services/loan_calculator.dart';

void main() {
  group('CreditSimulationApp', () {
    testWidgets('should render main app with title', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      expect(find.text('KPR Simulasi Plus'), findsOneWidget);
    });

    testWidgets('should render input section', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      expect(find.textContaining('Input Data Kredit'), findsOneWidget);
      expect(find.text('Plafon Kredit'), findsOneWidget);
      expect(find.textContaining('Tenor'), findsOneWidget);
    });

    testWidgets('should render interest rate section', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      expect(find.textContaining('Suku Bunga'), findsWidgets);
      expect(find.textContaining('Tambah Periode'), findsWidgets);
    });

    testWidgets('should show default periods', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      expect(find.text('Tahun 1-3'), findsOneWidget);
      expect(find.text('Tahun 4-6'), findsOneWidget);
      expect(find.text('Tahun 7-20'), findsOneWidget);
    });

    testWidgets('should have info and refresh buttons', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('should show PMT mode toggle', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      expect(find.text('PMT Tetap per Periode'), findsOneWidget);
    });

    testWidgets('should show validation feedback for periods', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      expect(find.textContaining('Konfigurasi rate valid'), findsOneWidget);
    });

    testWidgets('should show info dialog', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.text('Tentang Aplikasi'), findsOneWidget);
    });

    testWidgets('should render all major sections', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      expect(find.textContaining('Input Data Kredit'), findsOneWidget);
      expect(find.textContaining('Suku Bunga'), findsWidgets);
      expect(find.textContaining('3.95'), findsWidgets);
      expect(find.textContaining('10.25'), findsOneWidget);
    });

    testWidgets('should have ElevatedButton for calculate', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      final elevatedButtons = find.byType(ElevatedButton);
      expect(elevatedButtons, findsWidgets);
    });

    testWidgets('should have at least 2 Cards for sections', (tester) async {
      await tester.pumpWidget(const CreditSimulationApp());
      final cards = find.byType(Card);
      expect(cards, findsAtLeast(2));
    });

    testWidgets('should validate rate period overlap detection', (tester) async {
      final periods = [
        InterestRatePeriod('1-5', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('4-10', rate: 8.0, type: RateType.fixed),
      ];
      final result = LoanCalculator.validatePeriods(periods, 240);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Overlap')), isTrue);
    });

    testWidgets('should validate gap detection', (tester) async {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        InterestRatePeriod('5-20', rate: 10.25, type: RateType.fixed),
      ];
      final result = LoanCalculator.validatePeriods(periods, 240);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Gap')), isTrue);
    });

    testWidgets('should validate incomplete coverage', (tester) async {
      final periods = [
        InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
      ];
      final result = LoanCalculator.validatePeriods(periods, 240);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('mencakup')), isTrue);
    });
  });
}
