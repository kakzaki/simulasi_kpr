/// Satu baris dalam tabel amortization
class AmortizationEntry {
  final int bulan; // bulan ke-berapa (1-indexed)
  final double rate; // yearly rate (desimal)
  final double pokok; // pembayaran pokok
  final double bunga; // pembayaran bunga
  final double angsuran; // angsuran total (pokok + bunga)
  final double pelunasanMaju; // pelunasan dipercepat
  final double penalty; // penalti pelunasan dipercepat
  final double sisaPinjaman; // sisa pinjaman setelah pembayaran

  const AmortizationEntry({
    required this.bulan,
    required this.rate,
    required this.pokok,
    required this.bunga,
    required this.angsuran,
    this.pelunasanMaju = 0,
    this.penalty = 0,
    required this.sisaPinjaman,
  });

  /// Total bayar dalam bulan ini (angsuran + pelunasan maju + penalty)
  double get totalBayar => angsuran + pelunasanMaju + penalty;

  /// Rate dalam persen
  double get ratePercent => rate * 100;

  /// Apakah ada pelunasan dipercepat di bulan ini
  bool get hasPrepayment => pelunasanMaju > 0;

  @override
  String toString() =>
      'AmortEntry(bulan=$bulan, rate=${ratePercent.toStringAsFixed(2)}%, '
      'pokok=$pokok, bunga=$bunga, angsuran=$angsuran, sisa=$sisaPinjaman)';
}
