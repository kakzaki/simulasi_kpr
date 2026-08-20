import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/amortization_entry.dart';

/// Chart visualisasi amortization timeline
///
/// Menampilkan:
/// 1. Pie chart: Proporsi Total Pokok vs Bunga
/// 2. Line chart: Sisa Pinjaman (turun dari principal ke 0)
/// 3. Bar chart: Pokok vs Bunga per tahun
class AmortizationChart extends StatelessWidget {
  final List<AmortizationEntry> entries;

  const AmortizationChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        _buildPieChart(),
        const SizedBox(height: 20),
        _buildBalanceLineChart(),
        const SizedBox(height: 20),
        _buildYearlyBarChart(),
      ],
    );
  }

  /// Pie chart: Proporsi Total Pokok vs Bunga
  Widget _buildPieChart() {
    double totalPokok = 0;
    double totalBunga = 0;
    double totalPelunasan = 0;
    double totalPenalti = 0;

    for (final e in entries) {
      totalPokok += e.pokok;
      totalBunga += e.bunga;
      totalPelunasan += e.pelunasanMaju;
      totalPenalti += e.penalty;
    }

    final total = totalPokok + totalBunga + totalPelunasan + totalPenalti;
    if (total == 0) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];

    // Pokok (hijau)
    final pokokPct = (totalPokok / total * 100);
    sections.add(PieChartSectionData(
      value: totalPokok,
      title: '${pokokPct.toStringAsFixed(1)}%',
      color: const Color(0xFF43A047),
      radius: 80,
      titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white),
    ));

    // Bunga (oranye)
    final bungaPct = (totalBunga / total * 100);
    sections.add(PieChartSectionData(
      value: totalBunga,
      title: '${bungaPct.toStringAsFixed(1)}%',
      color: const Color(0xFFFB8C00),
      radius: 80,
      titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white),
    ));

    // Pelunasan (ungu) - hanya jika ada
    if (totalPelunasan > 0) {
      final pelunasanPct = (totalPelunasan / total * 100);
      sections.add(PieChartSectionData(
        value: totalPelunasan,
        title: '${pelunasanPct.toStringAsFixed(1)}%',
        color: const Color(0xFF7B1FA2),
        radius: 80,
        titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      ));
    }

    // Penalti (merah) - hanya jika ada
    if (totalPenalti > 0) {
      final penaltiPct = (totalPenalti / total * 100);
      sections.add(PieChartSectionData(
        value: totalPenalti,
        title: '${penaltiPct.toStringAsFixed(1)}%',
        color: const Color(0xFFE53935),
        radius: 80,
        titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Proporsi Pembayaran',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF212121))),
          const SizedBox(height: 4),
          Text('Total: ${_formatRp(total)}',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF757575))),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pieLegend('Pokok', const Color(0xFF43A047),
                        _formatRp(totalPokok), '${pokokPct.toStringAsFixed(1)}%'),
                    const SizedBox(height: 8),
                    _pieLegend('Bunga', const Color(0xFFFB8C00),
                        _formatRp(totalBunga), '${bungaPct.toStringAsFixed(1)}%'),
                    if (totalPelunasan > 0) ...[
                      const SizedBox(height: 8),
                      _pieLegend('Pelunasan', const Color(0xFF7B1FA2),
                          _formatRp(totalPelunasan), '${(totalPelunasan / total * 100).toStringAsFixed(1)}%'),
                    ],
                    if (totalPenalti > 0) ...[
                      const SizedBox(height: 8),
                      _pieLegend('Penalti', const Color(0xFFE53935),
                          _formatRp(totalPenalti), '${(totalPenalti / total * 100).toStringAsFixed(1)}%'),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pieLegend(String label, Color color, String value, String pct) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF212121))),
            Text('$value ($pct)',
                style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
          ],
        ),
      ],
    );
  }

  /// Line chart: Sisa Pinjaman dari awal sampai 0
  Widget _buildBalanceLineChart() {
    // Sample setiap N bulan agar chart tidak terlalu padat
    final step = entries.length > 120 ? 6 : (entries.length > 60 ? 3 : 1);
    final spots = <FlSpot>[];

    for (int i = 0; i < entries.length; i += step) {
      spots.add(FlSpot(
        entries[i].bulan.toDouble(),
        entries[i].sisaPinjaman,
      ));
    }
    // Pastikan titik terakhir (sisa = 0) ada
    if (spots.last.x != entries.last.bulan.toDouble()) {
      spots.add(FlSpot(
        entries.last.bulan.toDouble(),
        entries.last.sisaPinjaman,
      ));
    }

    final maxY = entries.first.sisaPinjaman;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sisa Pinjaman',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF212121))),
          const SizedBox(height: 4),
          Text(
              'Dari ${_formatRp(maxY)} sampai lunas',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF757575))),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 0.8,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('0');
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
                      reservedSize: 24,
                      interval: _getBottomInterval(entries.length),
                      getTitlesWidget: (value, meta) {
                        final tahun = (value / 12).ceil();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('T$tahun',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF757575))),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: const Color(0xFF1565C0),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1565C0).withValues(alpha: 0.2),
                          const Color(0xFF1565C0).withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final bulan = spot.x.toInt();
                        final tahun = (bulan / 12).ceil();
                        return LineTooltipItem(
                          'T$tahun (${bulan}bln)\n${_formatRp(spot.y)}',
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bar chart: Pokok vs Bunga per tahun
  Widget _buildYearlyBarChart() {
    // Group by year
    final yearlyData = <int, _YearlySum>{};
    for (final e in entries) {
      final tahun = ((e.bulan - 1) ~/ 12) + 1;
      yearlyData.putIfAbsent(tahun, () => _YearlySum());
      yearlyData[tahun]!.pokok += e.pokok;
      yearlyData[tahun]!.bunga += e.bunga;
    }

    final years = yearlyData.keys.toList()..sort();
    final maxY = years
        .map((y) => yearlyData[y]!.pokok + yearlyData[y]!.bunga)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Pokok vs Bunga per Tahun',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF212121))),
              ),
              _legend('Pokok', const Color(0xFF43A047)),
              const SizedBox(width: 12),
              _legend('Bunga', const Color(0xFFFB8C00)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.1,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final year = years[group.x];
                      final label = rodIndex == 0 ? 'Pokok' : 'Bunga';
                      return BarTooltipItem(
                        'T$year: $label\n${_formatRp(rod.toY)}',
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
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= years.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('T${years[idx]}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF757575))),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
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
                barGroups: List.generate(years.length, (i) {
                  final y = yearlyData[years[i]]!;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: y.pokok,
                        color: const Color(0xFF43A047),
                        width: _barWidth(years.length),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                      BarChartRodData(
                        toY: y.bunga,
                        color: const Color(0xFFFB8C00),
                        width: _barWidth(years.length),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF757575))),
      ],
    );
  }

  double _barWidth(int yearCount) {
    if (yearCount <= 5) return 16;
    if (yearCount <= 10) return 10;
    return 6;
  }

  double _getBottomInterval(int totalMonths) {
    if (totalMonths <= 60) return 12;
    if (totalMonths <= 120) return 24;
    if (totalMonths <= 240) return 36;
    return 60;
  }

  String _formatRp(double value) {
    if (value >= 1000000000) {
      return 'Rp ${(value / 1000000000).toStringAsFixed(1)} M';
    }
    if (value >= 1000000) {
      return 'Rp ${(value / 1000000).toStringAsFixed(0)} jt';
    }
    return 'Rp ${value.toStringAsFixed(0)}';
  }
}

class _YearlySum {
  double pokok = 0;
  double bunga = 0;
}
