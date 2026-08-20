import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simulasi_kpr/models/interest_rate_period.dart';
import 'package:simulasi_kpr/models/simulation_config.dart';
import 'package:simulasi_kpr/services/storage_service.dart';

void main() {
  group('SimulationConfig serialization', () {
    test('should serialize and deserialize correctly', () {
      final config = SimulationConfig(
        name: 'KPR Test',
        createdAt: DateTime(2025, 1, 15, 10, 30),
        jumlahKredit: 500000000,
        tenorBulan: 240,
        periods: [
          InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
          InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
          InterestRatePeriod('7-20', rate: 10.25, type: RateType.fixed),
        ],
        useFixedPmtPerPeriod: true,
        floatingRefRate: 4.0,
        floatingMargin: 2.5,
      );

      final json = config.toJson();
      final restored = SimulationConfig.fromJson(json);

      expect(restored.name, equals('KPR Test'));
      expect(restored.jumlahKredit, closeTo(500000000, 1));
      expect(restored.tenorBulan, equals(240));
      expect(restored.periods.length, equals(3));
      expect(restored.periods[0].rate, closeTo(3.95, 0.01));
      expect(restored.periods[1].rate, closeTo(8.0, 0.01));
      expect(restored.periods[2].rate, closeTo(10.25, 0.01));
      expect(restored.useFixedPmtPerPeriod, isTrue);
    });

    test('should serialize floating rate period correctly', () {
      final config = SimulationConfig(
        name: 'Floating Test',
        createdAt: DateTime.now(),
        jumlahKredit: 300000000,
        tenorBulan: 240,
        periods: [
          InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
          InterestRatePeriod('4-20', referenceRate: 5.0, margin: 3.0, type: RateType.floating),
        ],
        floatingRefRate: 5.0,
        floatingMargin: 3.0,
      );

      final json = config.toJson();
      final restored = SimulationConfig.fromJson(json);

      expect(restored.periods[1].type, equals(RateType.floating));
      expect(restored.periods[1].referenceRate, closeTo(5.0, 0.01));
      expect(restored.periods[1].margin, closeTo(3.0, 0.01));
    });

    test('should serialize prepayments correctly', () {
      final config = SimulationConfig(
        name: 'Prepayment Test',
        createdAt: DateTime.now(),
        jumlahKredit: 200000000,
        tenorBulan: 120,
        periods: [
          InterestRatePeriod('1-10', rate: 8.0, type: RateType.fixed),
        ],
        isPelunasanMajuActive: true,
        penaltyRate: 5,
        pelunasanMaju: [
          {'bulan': 12, 'nominal': 10000000, 'penalty': 500000},
          {'bulan': 24, 'nominal': 20000000, 'penalty': 1000000},
        ],
      );

      final json = config.toJson();
      final restored = SimulationConfig.fromJson(json);

      expect(restored.isPelunasanMajuActive, isTrue);
      expect(restored.penaltyRate, closeTo(5, 0.01));
      expect(restored.pelunasanMaju.length, equals(2));
      expect(restored.pelunasanMaju[0]['bulan'], closeTo(12, 0.01));
      expect(restored.pelunasanMaju[0]['nominal'], closeTo(10000000, 1));
    });

    test('should handle missing fields gracefully', () {
      final json = <String, dynamic>{
        'name': 'Minimal',
        'jumlahKredit': 100000000,
      };
      final config = SimulationConfig.fromJson(json);
      expect(config.name, equals('Minimal'));
      expect(config.tenorBulan, equals(240));
      expect(config.periods, isEmpty);
      expect(config.useFixedPmtPerPeriod, isTrue);
    });

    test('should copyWith correctly', () {
      final original = SimulationConfig(
        name: 'Original',
        createdAt: DateTime.now(),
        jumlahKredit: 500000000,
        tenorBulan: 240,
        periods: [],
      );

      final modified = original.copyWith(name: 'Modified', jumlahKredit: 600000000);
      expect(modified.name, equals('Modified'));
      expect(modified.jumlahKredit, closeTo(600000000, 1));
      expect(modified.tenorBulan, equals(240));
    });
  });

  group('StorageService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should save and load config', () async {
      final config = SimulationConfig(
        name: 'Test Config',
        createdAt: DateTime(2025, 6, 15),
        jumlahKredit: 500000000,
        tenorBulan: 240,
        periods: [
          InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
        ],
      );

      final saved = await StorageService.saveConfig(config);
      expect(saved, isTrue);

      final loaded = await StorageService.loadAllConfigs();
      expect(loaded.length, equals(1));
      expect(loaded[0].name, equals('Test Config'));
      expect(loaded[0].jumlahKredit, closeTo(500000000, 1));
    });

    test('should update existing config with same name', () async {
      final config1 = SimulationConfig(
        name: 'My Config',
        createdAt: DateTime(2025, 1, 1),
        jumlahKredit: 500000000,
        tenorBulan: 240,
        periods: [],
      );
      await StorageService.saveConfig(config1);

      final config2 = SimulationConfig(
        name: 'My Config',
        createdAt: DateTime(2025, 6, 15),
        jumlahKredit: 750000000,
        tenorBulan: 180,
        periods: [],
      );
      await StorageService.saveConfig(config2);

      final loaded = await StorageService.loadAllConfigs();
      expect(loaded.length, equals(1));
      expect(loaded[0].jumlahKredit, closeTo(750000000, 1));
      expect(loaded[0].tenorBulan, equals(180));
    });

    test('should delete config', () async {
      final config = SimulationConfig(
        name: 'To Delete',
        createdAt: DateTime.now(),
        jumlahKredit: 100000000,
        tenorBulan: 120,
        periods: [],
      );
      await StorageService.saveConfig(config);

      final deleted = await StorageService.deleteConfig('To Delete');
      expect(deleted, isTrue);

      final loaded = await StorageService.loadAllConfigs();
      expect(loaded, isEmpty);
    });

    test('should return false when deleting non-existent config', () async {
      final deleted = await StorageService.deleteConfig('Non Existent');
      expect(deleted, isFalse);
    });

    test('should check config exists', () async {
      final config = SimulationConfig(
        name: 'Exists',
        createdAt: DateTime.now(),
        jumlahKredit: 100000000,
        tenorBulan: 60,
        periods: [],
      );
      await StorageService.saveConfig(config);

      expect(await StorageService.configExists('Exists'), isTrue);
      expect(await StorageService.configExists('Not Exists'), isFalse);
    });

    test('should get config count', () async {
      expect(await StorageService.getConfigCount(), equals(0));

      await StorageService.saveConfig(SimulationConfig(
        name: 'A',
        createdAt: DateTime.now(),
        jumlahKredit: 100,
        tenorBulan: 12,
        periods: [],
      ));
      await StorageService.saveConfig(SimulationConfig(
        name: 'B',
        createdAt: DateTime.now(),
        jumlahKredit: 200,
        tenorBulan: 24,
        periods: [],
      ));

      expect(await StorageService.getConfigCount(), equals(2));
    });

    test('should clear all data', () async {
      await StorageService.saveConfig(SimulationConfig(
        name: 'A',
        createdAt: DateTime.now(),
        jumlahKredit: 100,
        tenorBulan: 12,
        periods: [],
      ));
      await StorageService.saveConfig(SimulationConfig(
        name: 'B',
        createdAt: DateTime.now(),
        jumlahKredit: 200,
        tenorBulan: 24,
        periods: [],
      ));

      await StorageService.clearAll();

      final loaded = await StorageService.loadAllConfigs();
      expect(loaded, isEmpty);
    });

    test('should handle multiple configs', () async {
      for (int i = 0; i < 5; i++) {
        await StorageService.saveConfig(SimulationConfig(
          name: 'Config $i',
          createdAt: DateTime.now(),
          jumlahKredit: (i + 1) * 100000000.0,
          tenorBulan: (i + 1) * 60,
          periods: [],
        ));
      }

      final loaded = await StorageService.loadAllConfigs();
      expect(loaded.length, equals(5));
      expect(loaded[0].name, equals('Config 0'));
      expect(loaded[4].name, equals('Config 4'));
    });

    test('should handle delete middle config correctly', () async {
      for (int i = 0; i < 3; i++) {
        await StorageService.saveConfig(SimulationConfig(
          name: 'Config $i',
          createdAt: DateTime.now(),
          jumlahKredit: (i + 1) * 100000000.0,
          tenorBulan: 240,
          periods: [],
        ));
      }

      await StorageService.deleteConfig('Config 1');

      final loaded = await StorageService.loadAllConfigs();
      expect(loaded.length, equals(2));
      expect(loaded[0].name, equals('Config 0'));
      expect(loaded[1].name, equals('Config 2'));
    });
  });
}
