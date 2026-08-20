import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/simulation_config.dart';
import '../services/loan_calculator.dart';
import '../services/storage_service.dart';

/// Layar perbandingan 2 skenario KPR side-by-side
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _currencyFormat = NumberFormat("#,##0", "id_ID");

  LoanCalculationResult? _resultA;
  LoanCalculationResult? _resultB;
  SimulationConfig? _configA;
  SimulationConfig? _configB;
  String _labelA = 'Skenario A';
  String _labelB = 'Skenario B';

  bool _isLoadingA = false;
  bool _isLoadingB = false;

  String _formatRp(double v) => 'Rp ${_currencyFormat.format(v.toInt())}';

  /* ----------  LOAD FROM SAVED CONFIG ---------- */
  Future<void> _pickConfig(bool isA) async {
    final configs = await StorageService.loadAllConfigs();
    if (!mounted) return;

    if (configs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada konfigurasi tersimpan. Simpan dulu dari menu utama.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picked = await showDialog<SimulationConfig>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Pilih ${isA ? "Skenario A" : "Skenario B"}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: configs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = configs[i];
              final dateStr = DateFormat('dd MMM yyyy').format(c.createdAt);
              return ListTile(
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${_formatRp(c.jumlahKredit)} • ${(c.tenorBulan / 12).toInt()} thn • $dateStr'),
                onTap: () => Navigator.pop(ctx, c),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ],
      ),
    );

    if (picked == null) return;

    setState(() {
      if (isA) {
        _configA = picked;
        _labelA = picked.name;
        _isLoadingA = true;
      } else {
        _configB = picked;
        _labelB = picked.name;
        _isLoadingB = true;
      }
    });

    final result = LoanCalculator.calculate(
      principal: picked.jumlahKredit,
      tenorMonths: picked.tenorBulan,
      periods: picked.periods,
      prepayments: picked.isPelunasanMajuActive ? picked.pelunasanMaju : null,
      penaltyRate: picked.penaltyRate,
      useFixedPmtPerPeriod: picked.useFixedPmtPerPeriod,
    );

    setState(() {
      if (isA) {
        _resultA = result;
        _isLoadingA = false;
      } else {
        _resultB = result;
        _isLoadingB = false;
      }
    });
  }

  /* ----------  BUILD ---------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perbandingan Skenario'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (_resultA != null && _resultB != null)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: () {
                setState(() {
                  final tmpR = _resultA;
                  final tmpC = _configA;
                  final tmpL = _labelA;
                  _resultA = _resultB;
                  _configA = _configB;
                  _labelA = _labelB;
                  _resultB = tmpR;
                  _configB = tmpC;
                  _labelB = tmpL;
                });
              },
              tooltip: 'Tukar Skenario',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /* --- scenario pickers --- */
          Row(
            children: [
              Expanded(child: _buildPickerCard(true)),
              const SizedBox(width: 12),
              Expanded(child: _buildPickerCard(false)),
            ],
          ),
          const SizedBox(height: 20),

          /* --- comparison content --- */
          if (_resultA != null && _resultB != null) ...[
            _buildMetricsComparison(),
            const SizedBox(height: 16),
            _buildChartComparison(),
          ] else if (_resultA != null || _resultB != null) ...[
            _buildPartialResult(),
          ] else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildPickerCard(bool isA) {
    final label = isA ? _labelA : _labelB;
    final config = isA ? _configA : _configB;
    final isLoading = isA ? _isLoadingA : _isLoadingB;
    final color = isA ? const Color(0xFF1565C0) : const Color(0xFFFB8C00);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isLoading ? null : () => _pickConfig(isA),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isLoading
              ? const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        config != null ? Icons.check_circle : Icons.add_circle_outline,
                        color: color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: color),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    if (config != null)
                      Text(
                        '${_formatRp(config.jumlahKredit)}\n${(config.tenorBulan / 12).toInt()} tahun',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF757575)),
                      )
                    else
                      const Text('Tap untuk pilih',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFFBDBDBD))),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPartialResult() {
    final hasA = _resultA != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.compare_arrows, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                hasA ? 'Pilih Skenario B' : 'Pilih Skenario A',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap kartu di atas untuk memilih konfigurasi',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.compare_arrows, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Pilih 2 Skenario',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              Text(
                'Pilih konfigurasi tersimpan dari kedua kartu\nuntuk melihat perbandingan',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ----------  METRICS COMPARISON TABLE ---------- */
  Widget _buildMetricsComparison() {
    final a = _resultA!;
    final b = _resultB!;

    final rows = [
      _MetricRow('Total Pokok', a.totalPokok, b.totalPokok),
      _MetricRow('Total Bunga', a.totalBunga, b.totalBunga),
      _MetricRow('Total Pembayaran', a.totalPembayaran, b.totalPembayaran),
      _MetricRow('Total Angsuran', a.totalAngsuran, b.totalAngsuran),
      _MetricRow('Angsuran/Bulan (awal)', a.entries.first.angsuran, b.entries.first.angsuran),
    ];

    if (a.totalPelunasanMaju > 0 || b.totalPelunasanMaju > 0) {
      rows.add(_MetricRow('Pelunasan Dipercepat', a.totalPelunasanMaju, b.totalPelunasanMaju));
    }
    if (a.totalPenalti > 0 || b.totalPenalti > 0) {
      rows.add(_MetricRow('Total Penalti', a.totalPenalti, b.totalPenalti));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart, size: 20, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                const Text('Perbandingan Metrik',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF212121))),
              ],
            ),
            const SizedBox(height: 16),
            /* --- header --- */
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                      flex: 3,
                      child: Text('Metrik',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Color(0xFF757575)))),
                  Expanded(
                      flex: 2,
                      child: Text(_labelA,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFF1565C0)))),
                  const SizedBox(width: 12),
                  Expanded(
                      flex: 2,
                      child: Text(_labelB,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFFFB8C00)))),
                  const SizedBox(width: 8),
                  const Expanded(
                      flex: 2,
                      child: Text('Selisih',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Color(0xFF757575)))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            /* --- rows --- */
            ...rows.map((row) => _buildMetricRow(row)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(_MetricRow row) {
    final diff = row.valueB - row.valueA;
    final diffAbs = diff.abs();
    final isLowerBetter = row.label.contains('Bunga') ||
        row.label.contains('Pembayaran') ||
        row.label.contains('Penalti') ||
        row.label.contains('Angsuran');

    Color? diffColor;
    if (diffAbs > 0) {
      if (isLowerBetter) {
        diffColor = diff < 0 ? const Color(0xFF43A047) : const Color(0xFFE53935);
      } else {
        diffColor = diff > 0 ? const Color(0xFF43A047) : const Color(0xFFE53935);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(row.label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(
              flex: 2,
              child: Text(_formatRp(row.valueA),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Expanded(
              flex: 2,
              child: Text(_formatRp(row.valueB),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: Text(
                diffAbs > 0
                    ? '${diff > 0 ? '+' : '-'}${_formatRp(diffAbs)}'
                    : '-',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: diffColor ?? const Color(0xFF757575)),
              )),
        ],
      ),
    );
  }

  /* ----------  CHART COMPARISON ---------- */
  Widget _buildChartComparison() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, size: 20, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                const Text('Perbandingan Grafik',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF212121))),
              ],
            ),
            const SizedBox(height: 16),
            _buildComparisonBarChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonBarChart() {
    final a = _resultA!;
    final b = _resultB!;

    final categories = ['Pokok', 'Bunga', 'Total'];
    final valuesA = [a.totalPokok, a.totalBunga, a.totalPembayaran];
    final valuesB = [b.totalPokok, b.totalBunga, b.totalPembayaran];
    final maxY = [valuesA, valuesB].expand((v) => v).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.15,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = rodIndex == 0 ? _labelA : _labelB;
                return BarTooltipItem(
                  '$label\n${_formatRp(rod.toY)}',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  if (value >= 1000000000) {
                    return Text('${(value / 1000000000).toStringAsFixed(1)}M',
                        style: const TextStyle(fontSize: 10));
                  }
                  return Text('${(value / 1000000).toStringAsFixed(0)}jt',
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= categories.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(categories[idx],
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212121))),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 0.8,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(categories.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: valuesA[i],
                  color: const Color(0xFF1565C0),
                  width: 16,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: valuesB[i],
                  color: const Color(0xFFFB8C00),
                  width: 16,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _MetricRow {
  final String label;
  final double valueA;
  final double valueB;
  _MetricRow(this.label, this.valueA, this.valueB);
}
