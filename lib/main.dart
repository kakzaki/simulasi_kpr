import 'dart:io';

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

import 'models/interest_rate_period.dart';
import 'models/simulation_config.dart';
import 'services/loan_calculator.dart';
import 'services/storage_service.dart';
import 'screens/compare_screen.dart';
import 'widgets/amortization_chart.dart';

void main() => runApp(const CreditSimulationApp());

/* ----------  COLOR SCHEME ---------- */
class AppColors {
  static const primary = Color(0xFF1565C0);
  static const primaryLight = Color(0xFF42A5F5);
  static const primaryDark = Color(0xFF0D47A1);
  static const accent = Color(0xFF00BFA5);
  static const surface = Color(0xFFF8F9FA);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const border = Color(0xFFE0E0E0);
  static const success = Color(0xFF43A047);
  static const warning = Color(0xFFFB8C00);
  static const error = Color(0xFFE53935);
  static const fixedColor = Color(0xFF1565C0);
  static const floatingColor = Color(0xFFFB8C00);
}

/* ----------  MAIN APP ---------- */
class CreditSimulationApp extends StatelessWidget {
  const CreditSimulationApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KPR Simulasi Plus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          helperStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 0.5,
          space: 1,
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
  State<CreditSimulationScreen> createState() =>
      _CreditSimulationScreenState();
}

class _CreditSimulationScreenState extends State<CreditSimulationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _currencyFormat = NumberFormat("#,##0", "id_ID");
  final _focusNode = FocusScopeNode();

  /* controllers */
  final _jumlahKreditController = TextEditingController(text: '500.000.000');
  final _tenorController = TextEditingController(text: '240');
  final _penaltyRateController = TextEditingController(text: '10');
  final _pelunasanMajuNominalController = TextEditingController();
  final _pelunasanMajuBulanController = TextEditingController();
  final _ratePeriodStartController = TextEditingController();
  final _ratePeriodEndController = TextEditingController();
  final _rateController = TextEditingController();
  final _floatingRefRateController = TextEditingController(text: '4.0');
  final _floatingMarginController = TextEditingController(text: '2.5');

  /* data */
  final List<InterestRatePeriod> _periods = [
    InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
    InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
    InterestRatePeriod('7-20', rate: 10.25, type: RateType.fixed),
  ];

  LoanCalculationResult? _result;
  bool _isPelunasanMajuActive = false;
  bool _isCalculating = false;
  bool _useFixedPmtPerPeriod = true;
  late TabController _resultsTabController;

  /* helper UI */
  RateType _currentType = RateType.fixed;

  @override
  void initState() {
    super.initState();
    _resultsTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _resultsTabController.dispose();
    _jumlahKreditController.dispose();
    _tenorController.dispose();
    _penaltyRateController.dispose();
    _pelunasanMajuNominalController.dispose();
    _pelunasanMajuBulanController.dispose();
    _ratePeriodStartController.dispose();
    _ratePeriodEndController.dispose();
    _rateController.dispose();
    _floatingRefRateController.dispose();
    _floatingMarginController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatCurrency(double value) => 'Rp ${_currencyFormat.format(value)}';

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
        const SnackBar(
            content: Text('Tahun mulai harus kurang dari tahun akhir')),
      );
      return;
    }

    if (_currentType == RateType.fixed) {
      final rate = double.tryParse(_rateController.text);
      if (rate == null || rate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate fixed tidak valid')),
        );
        return;
      }
      setState(() {
        _periods.add(
            InterestRatePeriod('$start-$end', rate: rate, type: RateType.fixed));
        _sortPeriods();
      });
    } else {
      final refRate =
          double.tryParse(_floatingRefRateController.text) ?? 4.0;
      final margin =
          double.tryParse(_floatingMarginController.text) ?? 2.5;
      setState(() {
        _periods.add(InterestRatePeriod(
          '$start-$end',
          referenceRate: refRate,
          margin: margin,
          type: RateType.floating,
        ));
        _sortPeriods();
      });
    }

    _ratePeriodStartController.clear();
    _ratePeriodEndController.clear();
    _rateController.clear();
  }

  void _sortPeriods() {
    _periods.sort((a, b) => a.startYear.compareTo(b.startYear));
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
    final exists = _result?.entries.any((e) => e.bulan == bulan) ?? false;
    if (!exists && _result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bulan tidak valid untuk tenor ini')),
      );
      return;
    }
    setState(() {
      _pelunasanMajuController.add({
        'bulan': bulan.toDouble(),
        'nominal': nominal,
        'penalty': nominal * (_penaltyRate / 100),
      });
      _pelunasanMajuController
          .sort((a, b) => a['bulan']!.compareTo(b['bulan']!));
    });
    _pelunasanMajuNominalController.clear();
    _pelunasanMajuBulanController.clear();
  }

  final List<Map<String, double>> _pelunasanMajuController = [];
  double _penaltyRate = 10;

  /* ----------  HITUNG KREDIT ---------- */
  Future<void> _calculateLoan() async {
    _focusNode.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final tenor = int.parse(_tenorController.text);
    final periodValidation = LoanCalculator.validatePeriods(_periods, tenor);
    if (!periodValidation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(periodValidation.errors.first),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    HeadUpLoading.show(context);
    setState(() => _isCalculating = true);
    try {
      final clean =
          _jumlahKreditController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final jumlahKredit = double.parse(clean);
      _penaltyRate = double.tryParse(_penaltyRateController.text) ?? 10;

      final result = LoanCalculator.calculate(
        principal: jumlahKredit,
        tenorMonths: tenor,
        periods: _periods,
        prepayments: _isPelunasanMajuActive ? _pelunasanMajuController : null,
        penaltyRate: _penaltyRate,
        useFixedPmtPerPeriod: _useFixedPmtPerPeriod,
      );

      setState(() => _result = result);
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
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() => _isCalculating = false);
      HeadUpLoading.hide();
    }
  }

  /* ----------  EXPORT EXCEL ---------- */
  Future<void> _exportToExcel() async {
    if (_result == null) return;
    HeadUpLoading.show(context);
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Simulasi KPR'];

      final titleStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          fontSize: 14);
      final dateStyle =
          CellStyle(horizontalAlign: HorizontalAlign.Center, fontSize: 11);
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('SIMULASI KREDIT PEMILIKAN RUMAH (KPR)')
        ..cellStyle = titleStyle;

      final now = DateTime.now();
      final dateFormat = DateFormat('dd MMMM yyyy HH:mm');
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 1));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        ..value = TextCellValue('Tanggal: ${dateFormat.format(now)}')
        ..cellStyle = dateStyle;

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

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5))
        ..value = TextCellValue('Rate Info')
        ..cellStyle = loanDetailsStyle;
      final periodInfo = _periods
          .map((p) => 'Tahun ${p.period}: ${p.rateDescription}')
          .join('\n');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5))
        ..value = TextCellValue(periodInfo)
        ..cellStyle = loanDetailsStyle;

      const headers = [
        'Bulan',
        'Tahun',
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
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 7))
          ..value = TextCellValue(headers[i])
          ..cellStyle = headerStyle;
      }

      final numberStyle =
          CellStyle(horizontalAlign: HorizontalAlign.Center);
      final rateStyle = CellStyle(
          numberFormat: NumFormat.custom(formatCode: '0.00'),
          horizontalAlign: HorizontalAlign.Center);
      final currencyStyle = CellStyle(
          numberFormat: NumFormat.custom(formatCode: 'Rp#,##0'),
          horizontalAlign: HorizontalAlign.Right);

      for (int i = 0; i < _result!.entries.length; i++) {
        final data = _result!.entries[i];
        final rowData = [
          data.bulan,
          ((data.bulan - 1) ~/ 12) + 1,
          data.ratePercent,
          data.pokok,
          data.bunga,
          data.angsuran,
          data.pelunasanMaju,
          data.penalty,
          data.totalBayar,
          data.sisaPinjaman,
        ];

        for (int j = 0; j < rowData.length; j++) {
          final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 8));
          if (j <= 1) {
            cell.value = IntCellValue(rowData[j].toInt());
            cell.cellStyle = numberStyle;
          } else if (j == 2) {
            cell.value = DoubleCellValue(rowData[j].toDouble());
            cell.cellStyle = rateStyle;
          } else {
            cell.value = DoubleCellValue(rowData[j].toDouble());
            cell.cellStyle = currencyStyle;
          }
        }
      }

      final lastRow = _result!.entries.length + 10;
      final summaryHeaderStyle = CellStyle(
          bold: true,
          fontSize: 12,
          backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'));
      sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: lastRow),
          CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: lastRow));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: lastRow))
        ..value = TextCellValue('RINGKASAN')
        ..cellStyle = summaryHeaderStyle;

      final summaryData = [
        ['Total Pokok', _result!.totalPokok],
        ['Total Bunga', _result!.totalBunga],
        if (_isPelunasanMajuActive) ...[
          ['Total Pelunasan Maju', _result!.totalPelunasanMaju],
          ['Total Penalti', _result!.totalPenalti],
        ],
        ['Total Pembayaran', _result!.totalPembayaran],
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
          ..value =
              DoubleCellValue((summaryData[i][1] as num).toDouble())
          ..cellStyle = summaryValueStyle;
      }

      sheet.setColumnWidth(0, 8);
      sheet.setColumnWidth(1, 8);
      for (int i = 2; i < 10; i++) sheet.setColumnWidth(i, 18);

      if (excel.sheets.length > 1) excel.delete('Sheet1');

      final excelBytes = excel.encode()!;
      final fileName =
          'KPR_Simulasi_${DateFormat('yyyyMMdd_HHmm').format(now)}.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([
          excelBytes
        ],
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
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

  /* ----------  SECTION HEADER ---------- */
  Widget _sectionHeader(IconData icon, Color color, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ],
    );
  }

  /* ----------  WIDGET: INPUT SECTION ---------- */
  Widget _buildInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.account_balance, AppColors.primary,
                'Input Data Kredit'),
            const SizedBox(height: 20),
            TextFormField(
              controller: _jumlahKreditController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Plafon Kredit',
                prefixText: 'Rp ',
                helperText: 'Jumlah pinjaman yang diajukan',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue;
                  final number = int.parse(newValue.text);
                  final result = _currencyFormat.format(number);
                  return TextEditingValue(
                    text: result,
                    selection:
                        TextSelection.collapsed(offset: result.length),
                  );
                }),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Wajib diisi';
                final clean =
                    value.replaceAll(RegExp(r'[^0-9]'), '');
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
              decoration: const InputDecoration(
                labelText: 'Tenor',
                suffixText: 'bulan',
                helperText: 'Contoh: 240 = 20 tahun',
              ),
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

  /* ----------  WIDGET: INTEREST RATE SECTION ---------- */
  Widget _buildInterestRateSection() {
    final tenor = int.tryParse(_tenorController.text) ?? 240;
    final periodValidation =
        LoanCalculator.validatePeriods(_periods, tenor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
                Icons.percent, AppColors.success, 'Suku Bunga'),
            const SizedBox(height: 12),

            /* --- validation banner --- */
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: periodValidation.isValid
                    ? AppColors.success.withOpacity(0.08)
                    : AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: periodValidation.isValid
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.error.withOpacity(0.3)),
              ),
              child: periodValidation.isValid
                  ? Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 16, color: AppColors.success),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Konfigurasi rate valid',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: periodValidation.errors
                          .map((e) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                        Icons.error_outline,
                                        size: 16,
                                        color: AppColors.error),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(e,
                                          style: const TextStyle(
                                              color:
                                                  AppColors.error,
                                              fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),

            /* --- PMT mode --- */
            Material(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              child: SwitchListTile(
                title: const Text('PMT Tetap per Periode',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _useFixedPmtPerPeriod
                      ? 'Angsuran tetap selama periode rate (Standar KPR)'
                      : 'Angsuran dihitung ulang setiap bulan',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _useFixedPmtPerPeriod,
                onChanged: (v) =>
                    setState(() => _useFixedPmtPerPeriod = v),
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
              ),
            ),
            const Divider(height: 24),

            /* --- add period form --- */
            const Text('Tambah Periode Baru',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            DropdownButtonFormField<RateType>(
              value: _currentType,
              decoration: const InputDecoration(
                  labelText: 'Tipe Suku Bunga'),
              items: const [
                DropdownMenuItem(
                    value: RateType.fixed, child: Text('Fixed')),
                DropdownMenuItem(
                    value: RateType.floating,
                    child: Text('Floating')),
              ],
              onChanged: (v) => setState(() => _currentType = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ratePeriodStartController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Tahun Mulai', hintText: '1'),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward,
                      size: 18, color: AppColors.textSecondary),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _ratePeriodEndController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Tahun Akhir', hintText: '3'),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentType == RateType.fixed)
              TextFormField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Suku Bunga Fixed',
                    suffixText: '%',
                    helperText: 'Contoh: 3.95'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
              )
            else ...[
              TextFormField(
                controller: _floatingRefRateController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Reference Rate / BI Rate',
                    suffixText: '%',
                    helperText: 'Suku bunga acuan (SBI/BI Rate)'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _floatingMarginController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Margin Bank',
                    suffixText: '%',
                    helperText: 'Selisih yang ditambahkan bank'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addInterestRatePeriod,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Tambah Periode'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            /* --- period list --- */
            if (_periods.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Konfigurasi Rate Aktif',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ...List.generate(_periods.length, (i) {
                final p = _periods[i];
                final isFixed = p.type == RateType.fixed;
                final color = isFixed
                    ? AppColors.fixedColor
                    : AppColors.floatingColor;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('Tahun ${p.period}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(p.rateDescription,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(p.typeLabel,
                            style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.red.shade300, size: 18),
                        onPressed: () =>
                            setState(() => _periods.removeAt(i)),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  /* ----------  WIDGET: PELUNASAN MAJU SECTION ---------- */
  Widget _buildPrepaymentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.speed,
                      color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pelunasan Dipercepat',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text(
                        _isPelunasanMajuActive ? 'Aktif' : 'Nonaktif',
                        style: TextStyle(
                            fontSize: 12,
                            color: _isPelunasanMajuActive
                                ? AppColors.success
                                : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isPelunasanMajuActive,
                  activeColor: AppColors.primary,
                  onChanged: (v) =>
                      setState(() => _isPelunasanMajuActive = v),
                ),
              ],
            ),
            if (_isPelunasanMajuActive) ...[
              const SizedBox(height: 20),
              TextFormField(
                controller: _penaltyRateController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Penalti Pelunasan',
                    suffixText: '%',
                    helperText: 'Persentase penalti'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (v) {
                  if (v.isNotEmpty) {
                    _penaltyRate = double.tryParse(v) ?? 10;
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller:
                          _pelunasanMajuNominalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nominal',
                        prefixText: 'Rp ',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        TextInputFormatter.withFunction(
                            (oldValue, newValue) {
                          if (newValue.text.isEmpty) return newValue;
                          final number =
                              int.parse(newValue.text);
                          final result =
                              _currencyFormat.format(number);
                          return TextEditingValue(
                            text: result,
                            selection:
                                TextSelection.collapsed(
                                    offset: result.length),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller:
                          _pelunasanMajuBulanController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Bulan Ke-',
                          suffixText: 'bulan'),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _addPelunasanMaju,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: const BorderSide(color: Colors.purple),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (_pelunasanMajuController.isNotEmpty) ...[
                const SizedBox(height: 16),
                ..._pelunasanMajuController
                    .asMap()
                    .entries
                    .map((entry) {
                  final idx = entry.key;
                  final pm = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              Colors.purple.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payments,
                            color: Colors.purple.shade300,
                            size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Bulan ke-${pm['bulan']!.toInt()}',
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600)),
                              Text(
                                  'Pokok: ${_formatCurrency(pm['nominal']!)}',
                                  style: const TextStyle(
                                      fontSize: 12)),
                              Text(
                                  'Penalti: ${_formatCurrency(pm['penalty']!)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.red.shade300,
                              size: 18),
                          onPressed: () => setState(() =>
                              _pelunasanMajuController
                                  .removeAt(idx)),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /* ----------  WIDGET: HASIL SECTION ---------- */
  Widget _buildResultsSection() {
    if (_result == null) return _buildEmptyState();
    final result = _result!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
                Icons.analytics, AppColors.accent, 'Hasil Perhitungan'),
            const SizedBox(height: 20),
            _buildSummaryCards(result),
            const SizedBox(height: 20),

            /* --- tab bar --- */
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _resultsTabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Grafik'),
                  Tab(text: 'Tabel'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            /* --- tab bar view --- */
            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _resultsTabController,
                children: [
                  /* Tab 0: Grafik */
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        AmortizationChart(entries: result.entries),
                        const SizedBox(height: 16),
                        _buildRateBreakdown(result),
                      ],
                    ),
                  ),

                  /* Tab 1: Tabel */
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildDataTable(result),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            /* --- export button --- */
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exportToExcel,
                icon: const Icon(Icons.download_rounded,
                    color: Colors.white, size: 20),
                label: const Text('Export ke Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ----------  EMPTY STATE ---------- */
  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.calculate_outlined,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Belum ada hasil',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              Text(
                  'Masukkan data kredit dan tekan\n"Hitung Simulasi" untuk melihat hasil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400)),
            ],
          ),
        ),
      ),
    );
  }

  /* ----------  SUMMARY CARDS ---------- */
  Widget _buildSummaryCards(LoanCalculationResult result) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final cardWidth = isWide
            ? (constraints.maxWidth - 24) / 3
            : (constraints.maxWidth - 12) / 2;

        final items = [
          _SummaryItem(
              'Total Pokok', result.totalPokok, AppColors.primary, Icons.account_balance_wallet),
          _SummaryItem(
              'Total Bunga', result.totalBunga, AppColors.warning, Icons.percent),
          _SummaryItem(
              'Total Pembayaran', result.totalPembayaran, AppColors.accent, Icons.receipt_long),
        ];

        if (_isPelunasanMajuActive) {
          items.insert(2,
              _SummaryItem('Pelunasan Dipercepat', result.totalPelunasanMaju, Colors.purple, Icons.speed));
          items.insert(3,
              _SummaryItem('Total Penalti', result.totalPenalti, AppColors.error, Icons.gavel));
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(
                    width: cardWidth,
                    child: _summaryCard(item),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _summaryCard(_SummaryItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 14, color: item.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(item.title,
                    style: TextStyle(
                        fontSize: 11,
                        color: item.color,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_formatCurrency(item.value),
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: item.color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  /* ----------  DATA TABLE ---------- */
  Widget _buildDataTable(LoanCalculationResult result) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          dataRowColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary.withValues(alpha: 0.1);
              }
              return null;
            },
          ),
          columnSpacing: 16,
          horizontalMargin: 12,
          headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.textPrimary),
          dataTextStyle: const TextStyle(
              fontSize: 12, color: AppColors.textPrimary),
          columns: const [
            DataColumn(label: Text('Bulan')),
            DataColumn(label: Text('Rate')),
            DataColumn(label: Text('Pokok')),
            DataColumn(label: Text('Bunga')),
            DataColumn(label: Text('Angsuran')),
            DataColumn(label: Text('Pelunasan')),
            DataColumn(label: Text('Penalti')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Sisa')),
          ],
          rows: result.entries.asMap().entries.map((entry) {
            final idx = entry.key;
            final data = entry.value;
            final isEven = idx % 2 == 0;
            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) {
                  if (isEven) return Colors.grey.shade50;
                  return null;
                },
              ),
              cells: [
                DataCell(Text('${data.bulan}',
                    style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(Text(
                    '${data.ratePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                        color: data.hasPrepayment
                            ? AppColors.error
                            : AppColors.primary,
                        fontWeight: FontWeight.w500))),
                DataCell(Text(_formatCurrency(data.pokok))),
                DataCell(Text(_formatCurrency(data.bunga))),
                DataCell(Text(_formatCurrency(data.angsuran),
                    style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(Text(
                    data.pelunasanMaju > 0
                        ? _formatCurrency(data.pelunasanMaju)
                        : '-',
                    style: TextStyle(
                        color: data.pelunasanMaju > 0 ? AppColors.error : null))),
                DataCell(Text(
                    data.penalty > 0
                        ? _formatCurrency(data.penalty)
                        : '-',
                    style: TextStyle(
                        color: data.penalty > 0 ? AppColors.error : null))),
                DataCell(Text(
                  _formatCurrency(data.totalBayar),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: data.totalBayar > data.angsuran
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                )),
                DataCell(Text(_formatCurrency(data.sisaPinjaman))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /* ----------  RATE BREAKDOWN ---------- */
  Widget _buildRateBreakdown(LoanCalculationResult result) {
    final rateGroups = <double, int>{};
    for (final e in result.entries) {
      rateGroups[e.rate] = (rateGroups[e.rate] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Breakdown Rate per Periode',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          ...rateGroups.entries.map((entry) {
            final ratePercent = entry.key * 100;
            final months = entry.value;
            final years = (months / 12).toStringAsFixed(1);
            final isFloating =
                rateGroups.keys.toList().indexOf(entry.key) ==
                    rateGroups.length - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.circle,
                      size: 6,
                      color: isFloating
                          ? AppColors.floatingColor
                          : AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                      '$ratePercent% selama $months bulan (~$years tahun)',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /* ----------  BUILD ---------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPR Simulasi Plus'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CompareScreen()));
            },
            tooltip: 'Bandingkan Skenario',
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _showSaveDialog,
            tooltip: 'Simpan Konfigurasi',
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _showLoadDialog,
            tooltip: 'Muat Konfigurasi',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Tentang',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetForm,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: FocusScope(
        node: _focusNode,
        child: GestureDetector(
          onTap: () => _focusNode.unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Form(
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
                const SizedBox(height: 20),

                /* --- calculate button --- */
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isCalculating ? null : _calculateLoan,
                    icon: _isCalculating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.calculate,
                            color: Colors.white),
                    label: Text(
                        _isCalculating
                            ? 'Menghitung...'
                            : 'Hitung Simulasi',
                        style: const TextStyle(
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildResultsSection(),
                const SizedBox(height: 24),
                _buildDeveloperFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ----------  BUILD CONFIG FROM STATE ---------- */
  SimulationConfig _buildConfig(String name) {
    final clean = _jumlahKreditController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return SimulationConfig(
      name: name,
      createdAt: DateTime.now(),
      jumlahKredit: double.tryParse(clean) ?? 0,
      tenorBulan: int.tryParse(_tenorController.text) ?? 240,
      periods: List.from(_periods),
      isPelunasanMajuActive: _isPelunasanMajuActive,
      penaltyRate: _penaltyRate,
      pelunasanMaju: List.from(_pelunasanMajuController),
      useFixedPmtPerPeriod: _useFixedPmtPerPeriod,
      floatingRefRate: double.tryParse(_floatingRefRateController.text) ?? 4.0,
      floatingMargin: double.tryParse(_floatingMarginController.text) ?? 2.5,
    );
  }

  /* ----------  LOAD CONFIG TO STATE ---------- */
  void _loadConfig(SimulationConfig config) {
    setState(() {
      _result = null;
      _jumlahKreditController.text = _currencyFormat.format(config.jumlahKredit.toInt());
      _tenorController.text = config.tenorBulan.toString();
      _periods
        ..clear()
        ..addAll(config.periods);
      _isPelunasanMajuActive = config.isPelunasanMajuActive;
      _penaltyRate = config.penaltyRate;
      _penaltyRateController.text = config.penaltyRate.toString();
      _pelunasanMajuController
        ..clear()
        ..addAll(config.pelunasanMaju);
      _useFixedPmtPerPeriod = config.useFixedPmtPerPeriod;
      _floatingRefRateController.text = config.floatingRefRate.toString();
      _floatingMarginController.text = config.floatingMargin.toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Konfigurasi "${config.name}" berhasil dimuat'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /* ----------  SAVE DIALOG ---------- */
  void _showSaveDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Simpan Konfigurasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Berikan nama untuk konfigurasi ini:',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Contoh: KPR Rumah Depok',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (v) async {
                if (v.trim().isEmpty) return;
                Navigator.pop(context);
                await _doSave(v.trim());
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              await _doSave(name);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _doSave(String name) async {
    final config = _buildConfig(name);
    final success = await StorageService.saveConfig(config);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Konfigurasi "$name" berhasil disimpan'
            : 'Gagal menyimpan konfigurasi'),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /* ----------  LOAD DIALOG ---------- */
  void _showLoadDialog() async {
    final configs = await StorageService.loadAllConfigs();
    if (!mounted) return;
    if (configs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Belum ada konfigurasi tersimpan'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Muat Konfigurasi'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: configs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = configs[i];
              final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(c.createdAt);
              final kreditStr = _formatCurrency(c.jumlahKredit);
              final tenorThn = (c.tenorBulan / 12).toInt();
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(c.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '$kreditStr • $tenorThn tahun • ${dateStr}'),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Colors.red.shade300, size: 20),
                  onPressed: () async {
                    Navigator.pop(context);
                    await StorageService.deleteConfig(c.name);
                    _showLoadDialog(); // refresh list
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  _loadConfig(c);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Tentang Aplikasi'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KPR Simulasi Plus adalah alat simulasi '
                'kredit rumah yang mendukung:'),
            SizedBox(height: 12),
            Text('• Fixed rate berjenjang (graduated fixed)'),
            SizedBox(height: 4),
            Text('• Floating rate (reference rate + margin)'),
            SizedBox(height: 4),
            Text('• Kombinasi fixed & floating'),
            SizedBox(height: 4),
            Text('• Pelunasan dipercepat dengan penalti'),
            SizedBox(height: 4),
            Text('• Export ke Excel'),
            SizedBox(height: 12),
            Text('Formula: PMT (Annuity) dengan pembaharuan '
                'per periode rate.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _result = null;
      _pelunasanMajuController.clear();
      _isPelunasanMajuActive = false;
      _periods
        ..clear()
        ..addAll([
          InterestRatePeriod('1-3', rate: 3.95, type: RateType.fixed),
          InterestRatePeriod('4-6', rate: 8.0, type: RateType.fixed),
          InterestRatePeriod('7-20', rate: 10.25, type: RateType.fixed),
        ]);
      _jumlahKreditController.text = '500.000.000';
      _tenorController.text = '240';
      _penaltyRateController.text = '10';
      _floatingRefRateController.text = '4.0';
      _floatingMarginController.text = '2.5';
    });
  }

  Widget _buildDeveloperFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
            Text('Powered by ',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500)),
            Text('kakzaki.dev',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new,
                size: 12, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

/* ----------  SUMMARY ITEM MODEL ---------- */
class _SummaryItem {
  final String title;
  final double value;
  final Color color;
  final IconData icon;
  _SummaryItem(this.title, this.value, this.color, this.icon);
}
