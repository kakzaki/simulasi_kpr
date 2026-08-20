import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/simulation_config.dart';

/// Service untuk menyimpan/meload konfigurasi simulasi ke local storage
class StorageService {
  static const String _keyPrefix = 'kpr_sim_';
  static const String _listKey = '${_keyPrefix}config_list';
  static const int _maxConfigs = 20;

  /// Simpan konfigurasi baru
  ///
  /// Returns: true jika berhasil, false jika gagal atau sudah mencapai limit
  static Future<bool> saveConfig(SimulationConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getConfigNames();

      // Cek apakah sudah ada dengan nama yang sama → update
      final existingIndex = list.indexWhere((c) => c.name == config.name);
      if (existingIndex >= 0) {
        // Update existing
        await prefs.setString(
          '$_listKey${existingIndex}_data',
          jsonEncode(config.toJson()),
        );
        return true;
      }

      // Cek limit
      if (list.length >= _maxConfigs) {
        return false;
      }

      // Simpan data
      final index = list.length;
      await prefs.setString(
        '$_listKey${index}_data',
        jsonEncode(config.toJson()),
      );

      // Update index list
      final names = list.map((c) => c.name).toList();
      names.add(config.name);
      await prefs.setStringList(_listKey, names);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load semua konfigurasi yang tersimpan
  static Future<List<SimulationConfig>> loadAllConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final names = prefs.getStringList(_listKey) ?? [];

      final configs = <SimulationConfig>[];
      for (int i = 0; i < names.length; i++) {
        final data = prefs.getString('$_listKey${i}_data');
        if (data != null) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            configs.add(SimulationConfig.fromJson(json));
          } catch (_) {
            // Skip corrupted config
          }
        }
      }

      return configs;
    } catch (e) {
      return [];
    }
  }

  /// Load daftar nama konfigurasi (tanpa data lengkap)
  static Future<List<SimulationConfig>> getConfigNames() async {
    return loadAllConfigs();
  }

  /// Hapus konfigurasi berdasarkan nama
  static Future<bool> deleteConfig(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configs = await loadAllConfigs();

      final index = configs.indexWhere((c) => c.name == name);
      if (index < 0) return false;

      // Hapus data
      await prefs.remove('$_listKey${index}_data');

      // Shift data setelah index
      for (int i = index + 1; i < configs.length; i++) {
        final data = prefs.getString('$_listKey${i}_data');
        if (data != null) {
          await prefs.setString('$_listKey${i - 1}_data', data);
          await prefs.remove('$_listKey${i}_data');
        }
      }

      // Update nama list
      final names = configs.map((c) => c.name).toList();
      names.removeAt(index);
      await prefs.setStringList(_listKey, names);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cek apakah ada config dengan nama tertentu
  static Future<bool> configExists(String name) async {
    final configs = await loadAllConfigs();
    return configs.any((c) => c.name == name);
  }

  /// Dapatkan jumlah config tersimpan
  static Future<int> getConfigCount() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(_listKey) ?? [];
    return names.length;
  }

  /// Clear semua data
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(_listKey) ?? [];
    for (int i = 0; i < names.length; i++) {
      await prefs.remove('$_listKey${i}_data');
    }
    await prefs.remove(_listKey);
  }
}
