import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headup_loading/headup_loading.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const CreditSimulationApp());

/* ----------  ENUM & MODEL ---------- */
enum RateType { fixed, floating }

class InterestRatePeriod {
  final String period; // "1-3"
  final double rate; // dipakai kalau fixed
  final double? margin; // dipakai kalau floating
  final RateType type;

  InterestRatePeriod(
    this.period,
    this.rate, {
    this.margin,
    required this.type,
  });
}

/* ----------  MAIN APP ---------- */
class CreditSimulationApp extends StatelessWidget {
  const CreditSimulationApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KPR Simulasi Plus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      home: const CreditSimulationScreen(),
    );
  }
}

/* ----------  SCREEN ---------- */
class CreditSimulationScreen extends StatefulWidget {
  const CreditSimulationScreen({Key? key}) : super(key: key);
  @override
  State<CreditSimulationScreen> createState() => _CreditSimulationScreenState();
}

class _CreditSimulationScreenState extends State<CreditSimulationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _currencyFormat = NumberFormat("#,##0", "id_ID");

  /* controller lama */
  final _jumlahKreditController = TextEditingController(text: '500.000.000');
  final _tenorController = TextEditingController(text: '240');
  final _penaltyRateController = TextEditingController(text: '10');
  final _pelunasanMajuNominalController = TextEditingController();
  final _pelunasanMajuBulanController = TextEditingController();
  final _ratePeriodStartController = TextEditingController();
  final _ratePeriodEndController = TextEditingController();
  final _rateController = TextEditingController();

  /* controller baru */
  final _floatingMarginController = TextEditingController(text: '2.5');
  final _floatingRefController = TextEditingController(text: '6.0');

  /* data */
  final List<InterestRatePeriod> _periods = [
    InterestRatePeriod('1-3', 3.95, type: RateType.fixed),
    InterestRatePeriod('4-6', 8.0, type: RateType.fixed),
    InterestRatePeriod('7-20', 0, margin: 2.5, type: RateType.floating),
  ];

  final List<Map<String, dynamic>> _angsuranTable = [];
  final List<Map<String, dynamic>> _pelunasanMaju = [];
  double _penaltyRate = 10;
  bool _isPelunasanMajuActive = false;
  bool _isCalculating = false;

  /* helper UI */
  RateType _currentType = RateType.fixed;

  @override
  void dispose() {
    _jumlahKreditController.dispose();
    _tenorController.dispose();
    _penaltyRateController.dispose();
    _pelunasanMajuNominalController.dispose();
    _pelunasanMajuBulanController.dispose();
    _ratePeriodStartController.dispose();
    _ratePeriodEndController.dispose();
    _rateController.dispose();
    _scrollController.dispose();
    _floatingMarginController.dispose();
    _floatingRefController.dispose();
    super.dispose();
  }

  String _formatCurrency(double value) => 'Rp ${_currencyFormat.format(value)}';

  /* ----------  LOGIKA RATE ---------- */
  double _getBunga(int bulan) {
    int tahun = ((bulan - 1) ~/ 12) + 1;
    for (var p in _periods) {
      final years = p.period.split('-').map(int.parse).toList();
      if (tahun >= years[0] && tahun <= years[1]) {
        if (p.type == RateType.fixed) return p.rate / 100;
        // floating
        final ref = double.tryParse(_floatingRefController.text) ?? 6.0;
        final margin =
            p.margin ?? double.tryParse(_floatingMarginController.text) ?? 2.5;
        return (ref + margin) / 100;
      }
    }
    return 0.0;
  }

  /* ----------  TAMBAH PERIODE ---------- */
  void _addInterestRatePeriod() {
    if (_ratePeriodStartController.text.isEmpty ||
        _ratePeriodEndController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi tahun mulai & akhir')),
      );
      return;
    }
    int start = int.parse(_ratePeriodStartController.text);
    int end = int.parse(_ratePeriodEndController.text);
    if (start >= end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tahun mulai < tahun akhir')),
      );
      return;
    }

    double? rate;
    double? margin;
    if (_currentType == RateType.fixed) {
      rate = double.tryParse(_rateController.text);
      if (rate == null || rate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate fixed tidak valid')),
        );
        return;
      }
    } else {
      margin = double.tryParse(_floatingMarginController.text) ?? 2.5;
    }

    setState(() {
      _periods.add(InterestRatePeriod('$start-$end', rate ?? 0,
          margin: margin, type: _currentType));
      _periods.sort((a, b) => int.parse(a.period.split('-')[0])
          .compareTo(int.parse(b.period.split('-')[0])));
    });

    _ratePeriodStartController.clear();
    _ratePeriodEndController.clear();
    _rateController.clear();
  }

  /* ----------  TAMBAH PELUNASAN MAJU ---------- */
  void _addPelunasanMaju() {
    if (_pelunasanMajuNominalController.text.isEmpty ||
        _pelunasanMajuBulanController.text.isEmpty) return;
    double nominal = double.parse(
        _pelunasanMajuNominalController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    int bulan = int.parse(_pelunasanMajuBulanController.text);
    if (bulan > int.parse(_tenorController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bulan pelunasan melebihi tenor')),
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

  /* ----------  HITUNG KREDIT ---------- */
  Future<void> _calculateLoan() async {
    if (!_formKey.currentState!.validate()) return;
    HeadUpLoading.show(context);
    setState(() => _isCalculating = true);
    try {
      final clean =
          _jumlahKreditController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final jumlahKredit = double.parse(clean);
      final jangkaWaktu = int.parse(_tenorController.text);
      _penaltyRate = double.parse(_penaltyRateController.text);

      _angsuranTable.clear();
      double sisa = jumlahKredit;

      for (int i = 1; i <= jangkaWaktu; i++) {
        final yearlyRate = _getBunga(i);
        final monthlyRate = yearlyRate / 12;

        final angsuranTetap =
            calculatePMT(sisa, yearlyRate, jangkaWaktu - i + 1);
        final bunga = sisa * monthlyRate;
        final pokok = angsuranTetap - bunga;

        double pelunasan = 0, penalty = 0;
        if (_isPelunasanMajuActive) {
          final pm = _pelunasanMaju.where((p) => p['bulan'] == i).toList();
          if (pm.isNotEmpty) {
            pelunasan = pm[0]['nominal'];
            if (pelunasan > sisa) pelunasan = sisa;
            penalty = pelunasan * _penaltyRate / 100;
          }
        }

        sisa = sisa - pokok - pelunasan;
        if (sisa < 0) sisa = 0;

        _angsuranTable.add({
          'bulan': i,
          'rate': yearlyRate,
          'pokok': pokok,
          'bunga': bunga,
          'angsuran': angsuranTetap,
          'pelunasanMaju': pelunasan,
          'penalty': penalty,
          'sisaPinjaman': sisa,
        });
      }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 300));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isCalculating = false);
      HeadUpLoading.hide();
    }
  }

  /* ----------  PMT HELPER ---------- */
  double calculatePMT(double principal, double yearlyRate, int totalMonths) {
    final monthly = yearlyRate / 12;
    if (monthly == 0) return principal / totalMonths;
    final pvif = pow(1 + monthly, totalMonths);
    return (principal * monthly * pvif / (pvif - 1)).toDouble();
  }

  /* ----------  EXPORT EXCEL (SAMA) ---------- */
  Future<void> _exportToExcel() async {
    HeadUpLoading.show(context);
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Simulasi KPR'];

      /* header merge & title */
      final titleStyle = CellStyle(
          bold: true, horizontalAlign: HorizontalAlign.Center, fontSize: 14);
      final dateStyle =
          CellStyle(horizontalAlign: HorizontalAlign.Center, fontSize: 11);
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('SIMULASI KREDIT PEMILIKAN RUMAH (KPR)')
        ..cellStyle = titleStyle;

      final now = DateTime.now();
      final dateFormat = DateFormat('dd MMMM yyyy HH:mm');
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 1));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        ..value = TextCellValue('Tanggal: ${dateFormat.format(now)}')
        ..cellStyle = dateStyle;

      /* loan details */
      final cleanVal =
          _jumlahKreditController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final jumlahKredit = double.parse(cleanVal);
      final loanDetailsStyle = CellStyle(fontSize: 11);
      final loanAmountStyle = CellStyle(
          fontSize: 11,
          numberFormat: NumFormat.custom(formatCode: 'Rp#,##0'),
          horizontalAlign: HorizontalAlign.Left);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
        ..value = TextCellValue('Plafon Kredit')
        ..cellStyle = loanDetailsStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3))
        ..value = DoubleCellValue(jumlahKredit)
        ..cellStyle = loanAmountStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4))
        ..value = TextCellValue('Tenor')
        ..cellStyle = loanDetailsStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4))
        ..value = TextCellValue('${_tenorController.text} bulan')
        ..cellStyle = loanDetailsStyle;

      /* table headers */
      const headers = [
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
      final headerStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          backgroundColorHex: ExcelColor.fromHexString('#CCCCCC'),
          verticalAlign: VerticalAlign.Center,
          textWrapping: TextWrapping.WrapText);

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 6))
          ..value = TextCellValue(headers[i])
          ..cellStyle = headerStyle;
      }

      /* data rows */
      final numberStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
      final rateStyle = CellStyle(
          numberFormat: NumFormat.custom(formatCode: '0.00"%"'),
          horizontalAlign: HorizontalAlign.Center);
      final currencyStyle = CellStyle(
          numberFormat: NumFormat.custom(formatCode: 'Rp#,##0'),
          horizontalAlign: HorizontalAlign.Right);

      for (int i = 0; i < _angsuranTable.length; i++) {
        final data = _angsuranTable[i];
        final pm = _isPelunasanMajuActive
            ? _pelunasanMaju.firstWhere((p) => p['bulan'] == data['bulan'],
                orElse: () => {'nominal': 0.0, 'penalty': 0.0})
            : {'nominal': 0.0, 'penalty': 0.0};
        final totalBayar = data['angsuran'] + pm['nominal'] + pm['penalty'];

        final rowData = [
          data['bulan'],
          (_getBunga(data['bulan']) * 100),
          data['pokok'],
          data['bunga'],
          data['angsuran'],
          pm['nominal'],
          pm['penalty'],
          totalBayar,
          data['sisaPinjaman']
        ];

        for (int j = 0; j < rowData.length; j++) {
          final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 7));
          if (j == 0) {
            cell.value = IntCellValue(rowData[j]);
            cell.cellStyle = numberStyle;
          } else if (j == 1) {
            cell.value = DoubleCellValue(rowData[j].toDouble());
            cell.cellStyle = rateStyle;
          } else {
            cell.value = DoubleCellValue(rowData[j].toDouble());
            cell.cellStyle = currencyStyle;
          }
        }
      }

      /* summary */
      final lastRow = _angsuranTable.length + 9;
      final summaryHeaderStyle = CellStyle(
          bold: true,
          fontSize: 12,
          backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'));
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: lastRow),
          CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: lastRow));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: lastRow))
        ..value = TextCellValue('RINGKASAN')
        ..cellStyle = summaryHeaderStyle;

      final totalPokok =
          _angsuranTable.fold(0.0, (sum, item) => sum + item['pokok']);
      final totalBunga =
          _angsuranTable.fold(0.0, (sum, item) => sum + item['bunga']);
      final totalPelunasan = _isPelunasanMajuActive
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

      final summaryData = [
        ['Total Pokok', totalPokok],
        ['Total Bunga', totalBunga],
        if (_isPelunasanMajuActive) ...[
          ['Total Pelunasan Maju', totalPelunasan],
          ['Total Penalti', totalPenalti],
        ],
        ['Total Pembayaran', totalPembayaran],
      ];

      final summaryLabelStyle = CellStyle(bold: true, fontSize: 11);
      final summaryValueStyle = CellStyle(
          numberFormat: NumFormat.custom(formatCode: 'Rp#,##0'),
          horizontalAlign: HorizontalAlign.Left,
          fontSize: 11);

      for (int i = 0; i < summaryData.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 0, rowIndex: lastRow + i + 1))
          ..value = TextCellValue(summaryData[i][0].toString())
          ..cellStyle = summaryLabelStyle;
        sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 1, rowIndex: lastRow + i + 1))
          ..value = DoubleCellValue((summaryData[i][1] as num).toDouble())
          ..cellStyle = summaryValueStyle;
      }

      /* column widths */
      sheet.setColumnWidth(0, 8);
      sheet.setColumnWidth(1, 10);
      for (int i = 2; i < 9; i++) sheet.setColumnWidth(i, 20);

      /* hapus sheet default */
      if (excel.sheets.length > 1) excel.delete('Sheet1');

      /* export */
      final excelBytes = excel.encode()!;
      final fileName =
          'KPR_Simulasi_${DateFormat('yyyyMMdd_HHmm').format(now)}.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([
          excelBytes
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..style.display = 'none';
        html.document.body?.children.add(anchor);
        anchor.click();
        Future.delayed(const Duration(seconds: 1), () {
          html.document.body?.children.remove(anchor);
          html.Url.revokeObjectUrl(url);
        });
      } else {
        final dir = await getDownloadsDirectory();
        final filePath = '${dir?.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(excelBytes);
        if (Platform.isAndroid || Platform.isIOS) {
          await Share.shareXFiles([XFile(file.path)], text: 'Simulasi KPR');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File tersimpan di: $filePath'),
              action: SnackBarAction(
                label: 'Buka',
                onPressed: () => OpenFile.open(filePath),
              ),
            ),
          );
        }
      }
      HeadUpLoading.hide();
    } catch (e, s) {
      HeadUpLoading.hide();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export: $e')),
      );
      debugPrint(s.toString());
    }
  }

  /* ----------  WIDGET INPUT ---------- */
  Widget _buildInputSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Input Data Kredit',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _jumlahKreditController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Plafon Kredit (Rp)',
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
              validator: (value) {
                if (value == null || value.isEmpty) return 'Wajib diisi';
                final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                if (clean.isEmpty) return 'Tidak valid';
                final amount = double.tryParse(clean);
                if (amount == null || amount <= 0) return 'Tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tenorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tenor (bulan)'),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Wajib diisi';
                final tenor = int.tryParse(value);
                if (tenor == null || tenor <= 0) return 'Tidak valid';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  /* ----------  WIDGET RATE ---------- */
  Widget _buildInterestRateSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate Bunga', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Tipe Periode')),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<RateType>(
                    value: _currentType,
                    items: const [
                      DropdownMenuItem(
                          value: RateType.fixed, child: Text('Fixed')),
                      DropdownMenuItem(
                          value: RateType.floating, child: Text('Floating')),
                    ],
                    onChanged: (v) => setState(() => _currentType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ratePeriodStartController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tahun Mulai'),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ratePeriodEndController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tahun Akhir'),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            if (_currentType == RateType.fixed)
              TextFormField(
                controller: _rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Rate (%)', suffixText: '%'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              )
            else
              TextFormField(
                controller: _floatingMarginController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Margin Floating (%)', suffixText: '%'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addInterestRatePeriod,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Rate'),
              ),
            ),
            if (_periods.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _periods.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _periods[i];
                    return ListTile(
                      title: Text('Tahun ${p.period}'),
                      subtitle: Text(p.type == RateType.fixed
                          ? '${p.rate}% (Fixed)'
                          : 'Margin ${p.margin ?? _floatingMarginController.text}% (Floating)'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _periods.removeAt(i)),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text('Referensi Floating (%)'),
            TextFormField(
              controller: _floatingRefController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Mis. 6-mo JIBOR',
                suffixText: '%',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /* ----------  WIDGET PELUNASAN MAJU ---------- */
  Widget _buildPrepaymentSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Pelunasan Extra',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Switch(
                  value: _isPelunasanMajuActive,
                  onChanged: (v) => setState(() => _isPelunasanMajuActive = v),
                ),
              ],
            ),
            if (_isPelunasanMajuActive) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _penaltyRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Penalti (%)', suffixText: '%'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (v) {
                  if (v.isNotEmpty) {
                    setState(() => _penaltyRate = double.parse(v));
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pelunasanMajuNominalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _pelunasanMajuBulanController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Bulan Pelunasan', suffixText: 'bulan'),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _addPelunasanMaju,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Pelunasan'),
                ),
              ),
              if (_pelunasanMaju.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pelunasanMaju.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final pm = _pelunasanMaju[i];
                      return ListTile(
                        title: Text('Bulan ke-${pm['bulan']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nominal: ${_formatCurrency(pm['nominal'])}'),
                            Text('Penalti: ${_formatCurrency(pm['penalty'])}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              setState(() => _pelunasanMaju.removeAt(i)),
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

  /* ----------  WIDGET HASIL ---------- */
  Widget _buildResultsSection() {
    if (_angsuranTable.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil Perhitungan',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
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
                  final pm = _isPelunasanMajuActive
                      ? _pelunasanMaju.firstWhere(
                          (p) => p['bulan'] == data['bulan'],
                          orElse: () => {'nominal': 0.0, 'penalty': 0.0})
                      : {'nominal': 0.0, 'penalty': 0.0};
                  final totalBayar =
                      data['angsuran'] + pm['nominal'] + pm['penalty'];
                  return DataRow(
                    cells: [
                      DataCell(Text(data['bulan'].toString())),
                      DataCell(Text(
                          (_getBunga(data['bulan']) * 100).toStringAsFixed(2))),
                      DataCell(Text(_formatCurrency(data['pokok']))),
                      DataCell(Text(_formatCurrency(data['bunga']))),
                      DataCell(Text(_formatCurrency(data['angsuran']))),
                      DataCell(Text(_formatCurrency(pm['nominal']))),
                      DataCell(Text(_formatCurrency(pm['penalty']))),
                      DataCell(Text(
                        _formatCurrency(totalBayar),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              totalBayar > data['angsuran'] ? Colors.red : null,
                        ),
                      )),
                      DataCell(Text(_formatCurrency(data['sisaPinjaman']))),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ringkasan',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
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
                    const Divider(),
                    Text(
                      'Total Pembayaran: ${_formatCurrency(_angsuranTable.fold(0.0, (sum, item) => sum + item['angsuran']) + (_isPelunasanMajuActive ? _pelunasanMaju.fold(0.0, (sum, item) => sum + item['nominal'] + item['penalty']) : 0.0))}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _exportToExcel,
              icon: const Icon(Icons.file_download, color: Colors.white),
              label: const Text('Export Excel'),
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

  /* ----------  BUILD ---------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPR Simulasi Plus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _angsuranTable.clear();
                _pelunasanMaju.clear();
                _isPelunasanMajuActive = false;
                _periods
                  ..clear()
                  ..addAll([
                    InterestRatePeriod('1-3', 3.95, type: RateType.fixed),
                    InterestRatePeriod('4-6', 8.0, type: RateType.fixed),
                    InterestRatePeriod('7-20', 0,
                        margin: 2.5, type: RateType.floating),
                  ]);
                _jumlahKreditController.text = '500.000.000';
                _tenorController.text = '240';
                _penaltyRateController.text = '10';
                _floatingMarginController.text = '2.5';
                _floatingRefController.text = '6.0';
              });
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            _buildInputSection(),
            const SizedBox(height: 16),
            _buildInterestRateSection(),
            const SizedBox(height: 16),
            _buildPrepaymentSection(),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isCalculating ? null : _calculateLoan,
                icon: _isCalculating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.calculate),
                label: Text(_isCalculating ? 'Menghitung...' : 'Hitung'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildResultsSection(),
            const SizedBox(height: 16),
            _buildDeveloperFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: InkWell(
        onTap: () async {
          const url = 'https://kakzaki.dev';
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Powered by ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              'kakzaki.dev',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
            const Icon(Icons.open_in_new, size: 14, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
