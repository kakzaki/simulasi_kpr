import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headup_loading/headup_loading.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const CreditSimulationApp());
}

class InterestRatePeriod {
  final String period;
  final double rate;

  InterestRatePeriod(this.period, this.rate);
}

class CreditSimulationApp extends StatelessWidget {
  const CreditSimulationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simulasi Kredit',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      home: const CreditSimulationScreen(),
    );
  }
}

class CreditSimulationScreen extends StatefulWidget {
  const CreditSimulationScreen({Key? key}) : super(key: key);

  @override
  _CreditSimulationScreenState createState() => _CreditSimulationScreenState();
}

class _CreditSimulationScreenState extends State<CreditSimulationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _currencyFormat = NumberFormat("#,##0", "id_ID");

  final _jumlahKreditController = TextEditingController(text: '500.000.000');
  final _jangkaWaktuController = TextEditingController(text: '240');
  final _penaltyRateController = TextEditingController(text: '10');
  final _pelunasanMajuNominalController = TextEditingController();
  final _pelunasanMajuBulanController = TextEditingController();
  final _ratePeriodStartController = TextEditingController();
  final _ratePeriodEndController = TextEditingController();
  final _rateController = TextEditingController();

  List<InterestRatePeriod> _periods = [
    InterestRatePeriod('1-3', 3.95),
    InterestRatePeriod('4-6', 8.0),
    InterestRatePeriod('7-20', 10.25),
  ];

  List<Map<String, dynamic>> _angsuranTable = [];
  List<Map<String, dynamic>> _pelunasanMaju = [];
  double _penaltyRate = 10;
  bool _isPelunasanMajuActive = false;
  bool _isCalculating = false;

  @override
  void dispose() {
    _jumlahKreditController.dispose();
    _jangkaWaktuController.dispose();
    _penaltyRateController.dispose();
    _pelunasanMajuNominalController.dispose();
    _pelunasanMajuBulanController.dispose();
    _ratePeriodStartController.dispose();
    _ratePeriodEndController.dispose();
    _rateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatCurrency(double value) {
    return 'Rp ${_currencyFormat.format(value)}';
  }

  void _addInterestRatePeriod() {
    if (_ratePeriodStartController.text.isEmpty ||
        _ratePeriodEndController.text.isEmpty ||
        _rateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mohon lengkapi semua field rate bunga')),
      );
      return;
    }

    int startYear = int.parse(_ratePeriodStartController.text);
    int endYear = int.parse(_ratePeriodEndController.text);
    double rate = double.parse(_rateController.text);

    if (startYear >= endYear) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Tahun mulai harus lebih kecil dari tahun akhir')),
      );
      return;
    }

    setState(() {
      _periods.add(InterestRatePeriod('$startYear-$endYear', rate));
      _periods.sort((a, b) => int.parse(a.period.split('-')[0])
          .compareTo(int.parse(b.period.split('-')[0])));
    });

    _ratePeriodStartController.clear();
    _ratePeriodEndController.clear();
    _rateController.clear();
  }

  void _addPelunasanMaju() {
    if (_pelunasanMajuNominalController.text.isEmpty ||
        _pelunasanMajuBulanController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mohon lengkapi nominal dan bulan pelunasan')),
      );
      return;
    }

    double nominal = double.parse(
        _pelunasanMajuNominalController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    int bulan = int.parse(_pelunasanMajuBulanController.text);

    if (bulan > int.parse(_jangkaWaktuController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulan pelunasan melebihi jangka waktu kredit')),
      );
      return;
    }

    setState(() {
      _pelunasanMaju.add({
        'bulan': bulan,
        'nominal': nominal,
        'penalty': nominal * (_penaltyRate / 100),
      });
      _pelunasanMaju.sort((a, b) => a['bulan'].compareTo(b['bulan']));
    });

    _pelunasanMajuNominalController.clear();
    _pelunasanMajuBulanController.clear();
  }

  Future<void> _exportToExcel() async {
    HeadUpLoading.show(context);
    try {
      // Buat instance Excel
      var excel = Excel.createExcel();
      var sheet = excel['Simulasi KPR'];

      // Buat header
      final headers = [
        'Bulan',
        'Rate (%)',
        'Pokok',
        'Bunga',
        'Angsuran',
        'Pelunasan Maju',
        'Penalti',
        'Total Bayar',
        'Sisa Pinjaman'
      ];

      // Tambahkan style untuk header
      var headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#CCCCCC'),
      );

      // Tulis header
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue("${headers[i]}")
          ..cellStyle = headerStyle;
      }

      // Tulis data
      for (var i = 0; i < _angsuranTable.length; i++) {
        var data = _angsuranTable[i];
        var pelunasanMaju = _isPelunasanMajuActive
            ? _pelunasanMaju.firstWhere((p) => p['bulan'] == data['bulan'],
                orElse: () => {'nominal': 0.0, 'penalty': 0.0})
            : {'nominal': 0.0, 'penalty': 0.0};

        double totalBayar = data['angsuran'] +
            pelunasanMaju['nominal'] +
            pelunasanMaju['penalty'];

        final rowData = [
          data['bulan'],
          (_getBunga(data['bulan']) * 100).toStringAsFixed(2),
          data['pokok'],
          data['bunga'],
          data['angsuran'],
          pelunasanMaju['nominal'],
          pelunasanMaju['penalty'],
          totalBayar,
          data['sisaPinjaman']
        ];

        for (var j = 0; j < rowData.length; j++) {
          var cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
          cell.value = TextCellValue("${rowData[j]}");

          // Format angka untuk kolom yang berisi nilai uang
          if (j >= 2) {
            // Kolom mulai dari 'Pokok'
            cell.cellStyle = CellStyle(
              numberFormat: NumFormat.standard_3,
            );
          }
        }
      }

      // Tambahkan ringkasan di bawah tabel
      var lastRow = _angsuranTable.length + 2; // Beri jarak 1 baris

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: lastRow))
        ..value = TextCellValue('Ringkasan')
        ..cellStyle = CellStyle(bold: true);

      final totalPokok =
          _angsuranTable.fold(0.0, (sum, item) => sum + item['pokok']);
      final totalBunga =
          _angsuranTable.fold(0.0, (sum, item) => sum + item['bunga']);
      final totalPelunasanMaju = _isPelunasanMajuActive
          ? _pelunasanMaju.fold(0.0, (sum, item) => sum + item['nominal'])
          : 0.0;
      final totalPenalti = _isPelunasanMajuActive
          ? _pelunasanMaju.fold(0.0, (sum, item) => sum + item['penalty'])
          : 0.0;
      final totalPembayaran = _angsuranTable.fold(
              0.0, (sum, item) => sum + item['angsuran']) +
          (_isPelunasanMajuActive
              ? _pelunasanMaju.fold(
                  0.0, (sum, item) => sum + item['nominal'] + item['penalty'])
              : 0.0);

      // Tulis ringkasan
      final summaryData = [
        ['Total Pokok', totalPokok],
        ['Total Bunga', totalBunga],
        if (_isPelunasanMajuActive) ...[
          ['Total Pelunasan Maju', totalPelunasanMaju],
          ['Total Penalti', totalPenalti],
        ],
        ['Total Pembayaran', totalPembayaran],
      ];

      for (var i = 0; i < summaryData.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 0, rowIndex: lastRow + i + 1))
          ..value = TextCellValue("${summaryData[i][0]}")
          ..cellStyle = CellStyle(bold: true);

        sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 1, rowIndex: lastRow + i + 1))
          ..value = DoubleCellValue(double.parse(summaryData[i][1].toString()))
          ..cellStyle = CellStyle(
            numberFormat: NumFormat.standard_3,
            bold: i == summaryData.length - 1, // Bold untuk Total Pembayaran
          );
      }

      // Auto-fit columns
      for (var i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15.0);
      }

      // Simpan file
      final directory = await getApplicationCacheDirectory();
      final now = DateTime.now();
      final fileName =
          'simulasi_kpr_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.xlsx';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(excel.encode()!);

      if (mounted) {
        HeadUpLoading.hide();
        debugPrint('File Excel berhasil disimpan di ${file.path}');
        await Share.shareXFiles([XFile(file.path)], text: 'Bagikan file ini');
      }
    } catch (e, stack) {
      HeadUpLoading.hide();
      if (mounted) {
        debugPrint(stack.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor ke Excel: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// Tambahkan fungsi helper untuk menghitung PMT
  double calculatePMT(double principal, double yearlyRate, int totalMonths) {
    double monthlyRate = yearlyRate / 12;
    if (monthlyRate == 0) return principal / totalMonths;

    num pvif = pow(1 + monthlyRate, totalMonths);
    return (principal * monthlyRate * pvif / (pvif - 1));
  }

// Fungsi untuk menghitung tabel amortisasi
  Future<void> _calculateLoan() async {
    FocusNode focusNode = FocusNode();
    focusNode.unfocus();
    if (!_formKey.currentState!.validate()) return;
    HeadUpLoading.show(context);

    setState(() => _isCalculating = true);

    try {
      String cleanValue =
          _jumlahKreditController.text.replaceAll(RegExp(r'[^0-9]'), '');
      double jumlahKredit = double.parse(cleanValue);
      int jangkaWaktu = int.parse(_jangkaWaktuController.text);
      _penaltyRate = double.parse(_penaltyRateController.text);

      await Future.delayed(Duration(milliseconds: 500));

      _angsuranTable.clear();
      double sisaPinjaman = jumlahKredit;

      for (int i = 1; i <= jangkaWaktu; i++) {
        double yearlyRate = _getBunga(i);
        double monthlyRate = yearlyRate / 12;

        // Hitung angsuran tetap dengan PMT
        double angsuranTetap =
            calculatePMT(sisaPinjaman, yearlyRate, jangkaWaktu - i + 1);

        // Hitung bunga bulan ini
        double bunga = sisaPinjaman * monthlyRate;

        // Hitung pokok dari angsuran tetap
        double pokok = angsuranTetap - bunga;

        // Handle pelunasan maju jika ada
        double pelunasanMaju = 0.0;
        double penalty = 0.0;

        if (_isPelunasanMajuActive) {
          var pelunasanBulanIni =
              _pelunasanMaju.where((p) => p['bulan'] == i).toList();
          if (pelunasanBulanIni.isNotEmpty) {
            pelunasanMaju = pelunasanBulanIni[0]['nominal'];
            if (pelunasanMaju > sisaPinjaman) {
              pelunasanMaju = sisaPinjaman;
            }
            penalty = pelunasanMaju * _penaltyRate;
          }
        }

        // Update sisa pinjaman
        sisaPinjaman = sisaPinjaman - pokok - pelunasanMaju;
        if (sisaPinjaman < 0) sisaPinjaman = 0;

        _angsuranTable.add({
          'bulan': i,
          'rate': yearlyRate,
          'pokok': pokok,
          'bunga': bunga,
          'angsuran': angsuranTetap,
          'pelunasanMaju': pelunasanMaju,
          'penalty': penalty,
          'sisaPinjaman': sisaPinjaman,
        });

        // Jika ada pelunasan maju, recalculate angsuran untuk bulan berikutnya
        if (pelunasanMaju > 0) {
          // Reset perhitungan untuk sisa periode dengan sisa pinjaman yang baru
          jangkaWaktu = jangkaWaktu;
        }
      }

      setState(() {});

      await Future.delayed(Duration(milliseconds: 300));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      HeadUpLoading.hide();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Terjadi kesalahan dalam perhitungan: ${e.toString()}')),
      );
    } finally {
      setState(() => _isCalculating = false);
      HeadUpLoading.hide();
    }
  }

  double _getBunga(int bulan) {
    int tahun = ((bulan - 1) ~/ 12) + 1;
    double rate = 0;

    for (var period in _periods) {
      var years = period.period.split('-');
      int startYear = int.parse(years[0]);
      int endYear = int.parse(years[1]);

      if (tahun >= startYear && tahun <= endYear) {
        rate = period.rate;
        break;
      }
    }

    return rate / 100;
  }

  Widget _buildInputSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Input Data Kredit',
                style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            TextFormField(
              controller: _jumlahKreditController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Plavon Kredit (Rp)',
                prefixText: 'Rp ',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue;
                  final number = int.tryParse(newValue.text);
                  if (number == null) return oldValue;
                  final result = _currencyFormat.format(number);
                  return TextEditingValue(
                    text: result,
                    selection: TextSelection.collapsed(offset: result.length),
                  );
                }),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Jumlah kredit wajib diisi';
                }

                // Hapus semua karakter selain angka
                String cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');

                if (cleanValue.isEmpty) {
                  return 'Jumlah kredit tidak valid';
                }

                double? amount = double.tryParse(cleanValue);
                if (amount == null || amount <= 0) {
                  return 'Jumlah kredit tidak valid';
                }

                return null;
              },
            ),
            // ... (kode lainnya tetap sama)
          ],
        ),
      ),
    );
  }

  Widget _buildInterestRateSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate Bunga', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            TextFormField(
              controller: _ratePeriodStartController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Tahun Mulai'),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _ratePeriodEndController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Tahun Akhir'),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _rateController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Rate (%)',
                suffixText: '%',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addInterestRatePeriod,
                icon: Icon(Icons.add),
                label: Text('Tambah Rate'),
              ),
            ),
            if (_periods.isNotEmpty) ...[
              SizedBox(height: 16),
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _periods.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final period = _periods[index];
                    return ListTile(
                      title: Text('Tahun ${period.period}'),
                      subtitle: Text('${period.rate}%'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _periods.removeAt(index));
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrepaymentSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Pelunasan Extra',
                    style: Theme.of(context).textTheme.titleLarge),
                Spacer(),
                Switch(
                  value: _isPelunasanMajuActive,
                  onChanged: (value) =>
                      setState(() => _isPelunasanMajuActive = value),
                ),
              ],
            ),
            if (_isPelunasanMajuActive) ...[
              SizedBox(height: 16),
              // Tambahkan input penalti di sini
              TextFormField(
                controller: _penaltyRateController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Penalti (%)',
                  suffixText: '%',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (value) {
                  // Update nilai penalti saat input berubah
                  if (value.isNotEmpty) {
                    setState(() {
                      _penaltyRate = double.parse(value) / 100;
                    });
                  }
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _pelunasanMajuNominalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nominal Pelunasan',
                  prefixText: 'Rp ',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.isEmpty) return newValue;
                    final number = int.parse(newValue.text);
                    final result = _currencyFormat.format(number);
                    return TextEditingValue(
                      text: result,
                      selection: TextSelection.collapsed(offset: result.length),
                    );
                  }),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _pelunasanMajuBulanController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Bulan Pelunasan',
                  suffixText: 'bulan',
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _addPelunasanMaju,
                  icon: Icon(Icons.add),
                  label: Text('Tambah Pelunasan'),
                ),
              ),
              if (_pelunasanMaju.isNotEmpty) ...[
                SizedBox(height: 16),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _pelunasanMaju.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final pelunasan = _pelunasanMaju[index];
                      return ListTile(
                        title: Text('Bulan ke-${pelunasan['bulan']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Nominal: ${_formatCurrency(pelunasan['nominal'])}'),
                            Text(
                                'Penalti: ${_formatCurrency(pelunasan['penalty'])}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() => _pelunasanMaju.removeAt(index));
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_angsuranTable.isEmpty) return SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil Perhitungan',
                style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('Bulan')),
                  DataColumn(label: Text('Rate (%)')),
                  DataColumn(label: Text('Pokok')),
                  DataColumn(label: Text('Bunga')),
                  DataColumn(label: Text('Angsuran')),
                  DataColumn(label: Text('Pelunasan\nMaju')),
                  DataColumn(label: Text('Penalti')),
                  DataColumn(label: Text('Total\nBayar')),
                  DataColumn(label: Text('Sisa\nPinjaman')),
                ],
                rows: _angsuranTable.map((data) {
                  // Cek apakah ada pelunasan maju pada bulan ini
                  var pelunasanMaju = _isPelunasanMajuActive
                      ? _pelunasanMaju.firstWhere(
                          (p) => p['bulan'] == data['bulan'],
                          orElse: () => {'nominal': 0.0, 'penalty': 0.0})
                      : {'nominal': 0.0, 'penalty': 0.0};

                  double totalBayar = data['angsuran'] +
                      pelunasanMaju['nominal'] +
                      pelunasanMaju['penalty'];

                  return DataRow(
                    cells: [
                      DataCell(Text(data['bulan'].toString())),
                      DataCell(Text(
                          '${(_getBunga(data['bulan']) * 100).toStringAsFixed(2)}')),
                      DataCell(Text(_formatCurrency(data['pokok']))),
                      DataCell(Text(_formatCurrency(data['bunga']))),
                      DataCell(Text(_formatCurrency(data['angsuran']))),
                      DataCell(Text(_formatCurrency(pelunasanMaju['nominal']))),
                      DataCell(Text(_formatCurrency(pelunasanMaju['penalty']))),
                      DataCell(
                        Text(
                          _formatCurrency(totalBayar),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: totalBayar > data['angsuran']
                                ? Colors.red
                                : null,
                          ),
                        ),
                      ),
                      DataCell(Text(_formatCurrency(data['sisaPinjaman']))),
                    ],
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ringkasan',
                        style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: 8),
                    Text(
                        'Total Pokok: ${_formatCurrency(_angsuranTable.fold(0.0, (sum, item) => sum + item['pokok']))}'),
                    Text(
                        'Total Bunga: ${_formatCurrency(_angsuranTable.fold(0.0, (sum, item) => sum + item['bunga']))}'),
                    if (_isPelunasanMajuActive) ...[
                      Text(
                          'Total Pelunasan Maju: ${_formatCurrency(_pelunasanMaju.fold(0.0, (sum, item) => sum + item['nominal']))}'),
                      Text(
                          'Total Penalti: ${_formatCurrency(_pelunasanMaju.fold(0.0, (sum, item) => sum + item['penalty']))}'),
                    ],
                    Divider(),
                    Text(
                      'Total Pembayaran: ${_formatCurrency(_angsuranTable.fold(0.0, (sum, item) => sum + item['angsuran']) + (_isPelunasanMajuActive ? _pelunasanMaju.fold(0.0, (sum, item) => sum + item['nominal'] + item['penalty']) : 0.0))}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _exportToExcel,
              icon: Icon(Icons.file_download, color: Colors.white),
              label: Text('Export Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Simulasi KPR'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _angsuranTable.clear();
                _pelunasanMaju.clear();
                _isPelunasanMajuActive = false;
                _periods = [
                  InterestRatePeriod('1-3', 3.95),
                  InterestRatePeriod('4-6', 8.0),
                  InterestRatePeriod('7-20', 10.25),
                ];
                _jumlahKreditController.text = '500.000.000';
                _jangkaWaktuController.text = '240';
                _penaltyRateController.text = '10';
              });
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.all(16),
          children: [
            _buildInputSection(),
            SizedBox(height: 16),
            _buildInterestRateSection(),
            SizedBox(height: 16),
            _buildPrepaymentSection(),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isCalculating ? null : _calculateLoan,
                icon: _isCalculating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.calculate),
                label: Text(_isCalculating ? 'Menghitung...' : 'Hitung'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildResultsSection(),
          ],
        ),
      ),
    );
  }
}
