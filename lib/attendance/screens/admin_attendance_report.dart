import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:file_saver/file_saver.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONFIG
// ─────────────────────────────────────────────────────────────────────────────
const String _baseUrl = 'http://192.168.29.103:3000';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _red = Color(0xFFEF4444);
const Color _surface = Color(0xFFF0F4FF);
const Color _card = Colors.white;
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _border = Color(0xFFE2E8F0);

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────
class _Visit {
  final String locationName;
  final DateTime? inTime;
  final DateTime? outTime;
  final int workedMinutes;

  _Visit({
    required this.locationName,
    required this.inTime,
    required this.outTime,
    required this.workedMinutes,
  });

  String get workedFormatted {
    final h = workedMinutes ~/ 60;
    final m = workedMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String get inFmt => inTime == null ? '--:--' : _fmtTime(inTime!);
  String get outFmt => outTime == null ? '--:--' : _fmtTime(outTime!);

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _EmpDay {
  final int empId;
  final String empName;
  final DateTime date;
  final List<_Visit> visits;

  _EmpDay({
    required this.empId,
    required this.empName,
    required this.date,
    required this.visits,
  });

  int get totalMinutes => visits.fold(0, (s, v) => s + v.workedMinutes);

  String get totalFormatted {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class _ReportService {
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<List<_EmpDay>> fetchRange(DateTime from, DateTime to) async {
    final List<_EmpDay> result = [];

    for (
      DateTime d = from;
      !d.isAfter(to);
      d = d.add(const Duration(days: 1))
    ) {
      try {
        final url = Uri.parse(
          '$_baseUrl/attendance/by-date-detail?date=${_fmt(d)}',
        );
        final res = await http.get(url);
        if (res.statusCode != 200) continue;

        final body = jsonDecode(res.body);
        final List rows = (body is Map ? body['data'] : null) ?? [];

        for (final row in rows) {
          if (row is! Map) continue;

          final rawId = row['emp_id'];
          final empId = rawId == null
              ? 0
              : rawId is num
              ? rawId.toInt()
              : int.tryParse(rawId.toString()) ?? 0;

          final empName = row['name']?.toString().trim() ?? '';

          // ── New format: sessions[] → visits[] ─────────────────────────────
          // ── Old format: flat visits[] (TL endpoint) ───────────────────────
          // Both are handled below so the report works for any endpoint.
          List<_Visit> flatVisits = [];

          final rawSessions = row['sessions'];
          if (rawSessions is List && rawSessions.isNotEmpty) {
            // New backend: flatten all sessions → all visits
            for (final sess in rawSessions) {
              if (sess is! Map) continue;
              final sessionVisits = sess['visits'];
              if (sessionVisits is! List) continue;
              for (final v in sessionVisits) {
                final visit = _parseVisit(v, d);
                if (visit != null) flatVisits.add(visit);
              }
            }
          } else {
            // Legacy / TL endpoint: flat visits[]
            final rawVisits = row['visits'];
            if (rawVisits is List) {
              for (final v in rawVisits) {
                final visit = _parseVisit(v, d);
                if (visit != null) flatVisits.add(visit);
              }
            }
          }

          result.add(
            _EmpDay(
              empId: empId,
              empName: empName,
              date: d,
              visits: flatVisits,
            ),
          );
        }
      } catch (e) {
        debugPrint('fetchRange error for $d: $e');
        continue;
      }
    }
    return result;
  }

  /// Parses a single visit map into a [_Visit], or returns null if invalid.
  static _Visit? _parseVisit(dynamic v, DateTime date) {
    if (v is! Map) return null;

    // New backend uses 'site_name'; legacy uses 'location_name'
    final locationName =
        (v['site_name'] ?? v['location_name'])?.toString() ?? 'Unknown';

    final inRaw = v['in_time'];
    final outRaw = v['out_time'];

    final rawMins = v['worked_minutes'];
    int mins = 0;
    if (rawMins is num) {
      mins = rawMins.toInt();
    } else if (rawMins is String) {
      mins = int.tryParse(rawMins) ?? 0;
    }
    if (mins < 0) mins = 0;

    return _Visit(
      locationName: locationName,
      inTime: inRaw != null ? _parseTime(inRaw.toString(), date) : null,
      outTime: outRaw != null ? _parseTime(outRaw.toString(), date) : null,
      workedMinutes: mins,
    );
  }

  static DateTime _parseTime(String t, DateTime date) {
    try {
      if (t.contains('T') || t.contains('-')) return DateTime.parse(t);
      final parts = t.split(':');
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
        parts.length > 2 ? int.parse(parts[2]) : 0,
      );
    } catch (_) {
      return date;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXCEL BUILDER  (unchanged — operates on flat _Visit / _EmpDay models)
// ─────────────────────────────────────────────────────────────────────────────
class _ExcelBuilder {
  static xl.CellStyle _hdrStyle({String hex = 'FF1A56DB'}) => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString(hex),
    fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
    bold: true,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    fontSize: 10,
    fontFamily: 'Arial',
    textWrapping: xl.TextWrapping.WrapText,
  );

  static xl.CellStyle _subHdrStyle() => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString('FFD1E9FF'),
    bold: true,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    fontSize: 9,
    fontFamily: 'Arial',
  );

  static xl.CellStyle _cellStyle({bool bold = false, bool center = false}) =>
      xl.CellStyle(
        fontSize: 9,
        fontFamily: 'Arial',
        bold: bold,
        horizontalAlign: center
            ? xl.HorizontalAlign.Center
            : xl.HorizontalAlign.Left,
        verticalAlign: xl.VerticalAlign.Center,
      );

  static xl.CellStyle _totalStyle() => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString('FFECFDF5'),
    bold: true,
    fontSize: 9,
    fontFamily: 'Arial',
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
  );

  static void _setCell(
    xl.Sheet sheet,
    int row,
    int col,
    dynamic value, [
    xl.CellStyle? style,
  ]) {
    final cell = sheet.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value is int
        ? xl.IntCellValue(value)
        : value is double
        ? xl.DoubleCellValue(value)
        : xl.TextCellValue(value?.toString() ?? '');
    if (style != null) cell.cellStyle = style;
  }

  // ── DAY-WISE ───────────────────────────────────────────────────────────────
  static xl.Excel buildDayWise(List<_EmpDay> data, DateTime from, DateTime to) {
    final excel = xl.Excel.createExcel();
    const sheetName = 'Day-Wise Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0),
    );
    _setCell(
      sheet,
      0,
      0,
      'Attendance Day-Wise Report  |  ${_fmtDate(from)} to ${_fmtDate(to)}',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 12,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
      ),
    );
    sheet.setRowHeight(0, 28);

    final headers = [
      'S.No',
      'Emp ID',
      'Employee Name',
      'Site Name',
      'Check In',
      'Check Out',
      'Total Hrs',
    ];
    for (int c = 0; c < headers.length; c++)
      _setCell(sheet, 1, c, headers[c], _hdrStyle());
    sheet.setRowHeight(1, 22);

    final widths = [6.0, 9.0, 22.0, 22.0, 12.0, 12.0, 12.0];
    for (int c = 0; c < widths.length; c++) sheet.setColumnWidth(c, widths[c]);

    int sno = 1, row = 2;
    data.sort((a, b) {
      final dc = a.date.compareTo(b.date);
      return dc != 0 ? dc : a.empId.compareTo(b.empId);
    });

    for (final day in data) {
      if (day.visits.isEmpty) continue;
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
      );
      _setCell(
        sheet,
        row,
        0,
        '📅  ${_fmtDateLong(day.date)}  —  ${day.empName}  (ID: ${day.empId})',
        xl.CellStyle(
          backgroundColorHex: xl.ExcelColor.fromHexString('FFE8F0FE'),
          bold: true,
          fontSize: 9,
          fontFamily: 'Arial',
        ),
      );
      sheet.setRowHeight(row, 18);
      row++;

      for (int vi = 0; vi < day.visits.length; vi++) {
        final v = day.visits[vi];
        _setCell(sheet, row, 0, sno, _cellStyle(center: true));
        _setCell(sheet, row, 1, day.empId, _cellStyle(center: true));
        _setCell(sheet, row, 2, day.empName, _cellStyle());
        _setCell(sheet, row, 3, v.locationName, _cellStyle());
        _setCell(sheet, row, 4, v.inFmt, _cellStyle(center: true));
        _setCell(sheet, row, 5, v.outFmt, _cellStyle(center: true));
        _setCell(sheet, row, 6, v.workedFormatted, _cellStyle(center: true));

        if (vi == day.visits.length - 1 && day.visits.length > 1) {
          sheet.merge(
            xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1),
            xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row + 1),
          );
          _setCell(
            sheet,
            row + 1,
            0,
            'Total for ${day.empName} on ${_fmtDate(day.date)}',
            _totalStyle(),
          );
          _setCell(sheet, row + 1, 6, day.totalFormatted, _totalStyle());
          row++;
        }
        row++;
        sno++;
      }
    }
    return excel;
  }

  // ── MONTHLY ────────────────────────────────────────────────────────────────
  static xl.Excel buildMonthly(List<_EmpDay> data, DateTime from, DateTime to) {
    final excel = xl.Excel.createExcel();
    const sheetName = 'Monthly Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final List<DateTime> dates = [];
    for (DateTime d = from; !d.isAfter(to); d = d.add(const Duration(days: 1)))
      dates.add(d);

    final Map<int, String> empNames = {};
    final Map<int, Map<String, Map<String, int>>> empSiteDate = {};
    for (final day in data) {
      empNames[day.empId] = day.empName;
      empSiteDate.putIfAbsent(day.empId, () => {});
      for (final v in day.visits) {
        empSiteDate[day.empId]!.putIfAbsent(v.locationName, () => {});
        final dk = _fmtDate(day.date);
        empSiteDate[day.empId]![v.locationName]![dk] =
            (empSiteDate[day.empId]![v.locationName]![dk] ?? 0) +
            v.workedMinutes;
      }
    }

    final totalCols = 4 + dates.length + 1;
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 0),
    );
    _setCell(
      sheet,
      0,
      0,
      'Attendance Monthly Report  |  ${_fmtDate(from)} to ${_fmtDate(to)}',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 12,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
      ),
    );
    sheet.setRowHeight(0, 28);

    final fixedHeaders = ['S.No', 'Emp ID', 'Employee Name', 'Site Name'];
    for (int c = 0; c < fixedHeaders.length; c++)
      _setCell(sheet, 1, c, fixedHeaders[c], _hdrStyle());
    for (int di = 0; di < dates.length; di++) {
      _setCell(
        sheet,
        1,
        4 + di,
        '${dates[di].day}\n${_monthShort(dates[di].month)}',
        _subHdrStyle(),
      );
      sheet.setColumnWidth(4 + di, 8.0);
    }
    _setCell(
      sheet,
      1,
      4 + dates.length,
      'Total\nWorking Hrs',
      _hdrStyle(hex: 'FF0E9F6E'),
    );
    sheet.setRowHeight(1, 30);

    sheet.setColumnWidth(0, 6.0);
    sheet.setColumnWidth(1, 9.0);
    sheet.setColumnWidth(2, 22.0);
    sheet.setColumnWidth(3, 22.0);
    sheet.setColumnWidth(4 + dates.length, 14.0);

    int sno = 1, row = 2;
    final sortedEmpIds = empSiteDate.keys.toList()..sort();

    for (final empId in sortedEmpIds) {
      final name = empNames[empId] ?? '';
      final sites = empSiteDate[empId]!;
      final sortedSites = sites.keys.toList()..sort();
      int empTotalMins = 0;
      final empStartRow = row;

      for (final site in sortedSites) {
        final dateMap = sites[site]!;
        _setCell(sheet, row, 0, sno, _cellStyle(center: true));
        _setCell(sheet, row, 1, empId, _cellStyle(center: true));
        _setCell(sheet, row, 2, name, _cellStyle());
        _setCell(sheet, row, 3, site, _cellStyle());

        int siteTotalMins = 0;
        for (int di = 0; di < dates.length; di++) {
          final mins = dateMap[_fmtDate(dates[di])] ?? 0;
          siteTotalMins += mins;
          _setCell(
            sheet,
            row,
            4 + di,
            mins > 0 ? _minsToHrs(mins) : '',
            _cellStyle(center: true),
          );
        }
        empTotalMins += siteTotalMins;
        _setCell(
          sheet,
          row,
          4 + dates.length,
          _minsToHrs(siteTotalMins),
          _cellStyle(center: true, bold: true),
        );
        row++;
        sno++;
      }

      if (sortedSites.length > 1) {
        sheet.merge(
          xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
          xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
        );
        _setCell(sheet, row, 0, 'Total — $name (ID: $empId)', _totalStyle());
        for (int di = 0; di < dates.length; di++) {
          int dayTotal = 0;
          for (final site in sortedSites)
            dayTotal += empSiteDate[empId]![site]![_fmtDate(dates[di])] ?? 0;
          _setCell(
            sheet,
            row,
            4 + di,
            dayTotal > 0 ? _minsToHrs(dayTotal) : '',
            _totalStyle(),
          );
        }
        _setCell(
          sheet,
          row,
          4 + dates.length,
          _minsToHrs(empTotalMins),
          _totalStyle(),
        );
        row++;

        if (sortedSites.length > 1) {
          sheet.merge(
            xl.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: empStartRow,
            ),
            xl.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: empStartRow + sortedSites.length - 1,
            ),
          );
          sheet.merge(
            xl.CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: empStartRow,
            ),
            xl.CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: empStartRow + sortedSites.length - 1,
            ),
          );
        }
      }
    }
    return excel;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmtDateLong(DateTime d) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  static String _monthShort(int m) {
    const s = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return s[m];
  }

  static String _minsToHrs(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN  — Two-tab layout (Day-Wise / Monthly)
// ─────────────────────────────────────────────────────────────────────────────
class AdminAttendanceReportScreen extends StatefulWidget {
  const AdminAttendanceReportScreen({super.key});

  @override
  State<AdminAttendanceReportScreen> createState() =>
      _AdminAttendanceReportScreenState();
}

class _AdminAttendanceReportScreenState
    extends State<AdminAttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Day-wise: single date ──────────────────────────────────────────────────
  DateTime _dayDate = DateTime.now();
  bool _loading = false;
  bool _fetched = false;
  String? _error;
  List<_EmpDay> _data = [];
  String _searchQuery = '';
  String _filterSite = 'All';

  // ── Monthly date range (independent) ──────────────────────────────────────
  DateTime _mFromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _mToDate = DateTime.now();
  bool _mLoading = false;
  bool _mFetched = false;
  String? _mError;
  List<_EmpDay> _mData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDayDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dayDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dayDate = picked);
  }

  Future<void> _pickMonthlyDate(bool isFrom) async {
    final current = isFrom ? _mFromDate : _mToDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _mFromDate = picked;
        if (_mToDate.isBefore(_mFromDate)) _mToDate = _mFromDate;
      } else {
        _mToDate = picked;
        if (_mFromDate.isAfter(_mToDate)) _mFromDate = _mToDate;
      }
    });
  }

  Future<void> _fetchDayData() async {
    setState(() {
      _loading = true;
      _error = null;
      _fetched = false;
    });
    try {
      _data = await _ReportService.fetchRange(_dayDate, _dayDate);
      _data.sort((a, b) => a.empName.compareTo(b.empName));
      setState(() {
        _fetched = true;
        _searchQuery = '';
        _filterSite = 'All';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchMonthlyData() async {
    setState(() {
      _mLoading = true;
      _mError = null;
      _mFetched = false;
    });
    try {
      _mData = await _ReportService.fetchRange(_mFromDate, _mToDate);
      setState(() => _mFetched = true);
    } catch (e) {
      setState(() => _mError = e.toString());
    } finally {
      setState(() => _mLoading = false);
    }
  }

  Future<void> _downloadDayWise() async {
    if (_data.isEmpty) {
      _showSnack('No data to export', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final excel = _ExcelBuilder.buildDayWise(_data, _dayDate, _dayDate);
      await _saveAndOpen(excel, 'Attendance_DayWise_${_fmtKey(_dayDate)}.xlsx');
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _downloadMonthly() async {
    if (_mData.isEmpty) {
      _showSnack('No data to export', isError: true);
      return;
    }
    setState(() => _mLoading = true);
    try {
      final excel = _ExcelBuilder.buildMonthly(_mData, _mFromDate, _mToDate);
      await _saveAndOpen(
        excel,
        'Attendance_Monthly_${_fmtKey(_mFromDate)}_to_${_fmtKey(_mToDate)}.xlsx',
      );
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      setState(() => _mLoading = false);
    }
  }

  Future<void> _saveAndOpen(xl.Excel excel, String fileName) async {
    final bytes = excel.save();
    if (bytes == null) throw Exception('Failed to generate Excel');

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: fileName.replaceAll('.xlsx', ''),
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      _showSnack('Download started: $fileName');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
      _showSnack('Saved: $fileName');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _red : _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<String> get _allSites {
    final sites = <String>{};
    for (final d in _data) for (final v in d.visits) sites.add(v.locationName);
    return ['All', ...sites.toList()..sort()];
  }

  List<_EmpDay> get _filteredData => _data.where((d) {
    final matchName =
        _searchQuery.isEmpty ||
        d.empName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        d.empId.toString().contains(_searchQuery);
    final matchSite =
        _filterSite == 'All' ||
        d.visits.any((v) => v.locationName == _filterSite);
    return matchName && matchSite;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: Scaffold(
        backgroundColor: _surface,
        appBar: _buildAppBar(),
        body: TabBarView(
          controller: _tabController,
          children: [
            _DayWiseTab(
              selectedDate: _dayDate,
              loading: _loading,
              fetched: _fetched,
              error: _error,
              data: _filteredData,
              searchQuery: _searchQuery,
              filterSite: _filterSite,
              allSites: _allSites,
              fmt: _fmt,
              onPickDate: _pickDayDate,
              onFetch: _fetchDayData,
              onDownload: _downloadDayWise,
              onSearchChange: (v) => setState(() => _searchQuery = v),
              onSiteChange: (v) => setState(() => _filterSite = v ?? 'All'),
              onQuickDate: (d) => setState(() => _dayDate = d),
            ),
            _MonthlyTab(
              fromDate: _mFromDate,
              toDate: _mToDate,
              loading: _mLoading,
              fetched: _mFetched,
              error: _mError,
              data: _mData,
              fmt: _fmt,
              onPickFrom: () => _pickMonthlyDate(true),
              onPickTo: () => _pickMonthlyDate(false),
              onFetch: _fetchMonthlyData,
              onDownload: _downloadMonthly,
              onQuickRange: (from, to) => setState(() {
                _mFromDate = from;
                _mToDate = to;
              }),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => PreferredSize(
    preferredSize: const Size.fromHeight(150),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x401A56DB),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Export to Excel',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.calendar_today_rounded, size: 16),
                  text: 'Day Wise',
                ),
                Tab(
                  icon: Icon(Icons.calendar_month_rounded, size: 16),
                  text: 'Monthly',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — DAY WISE
// ─────────────────────────────────────────────────────────────────────────────
class _DayWiseTab extends StatelessWidget {
  final DateTime selectedDate;
  final bool loading, fetched;
  final String? error;
  final List<_EmpDay> data;
  final String searchQuery, filterSite;
  final List<String> allSites;
  final String Function(DateTime) fmt;
  final VoidCallback onPickDate, onFetch, onDownload;
  final ValueChanged<String> onSearchChange;
  final ValueChanged<String?> onSiteChange;
  final ValueChanged<DateTime> onQuickDate;

  const _DayWiseTab({
    required this.selectedDate,
    required this.loading,
    required this.fetched,
    required this.error,
    required this.data,
    required this.searchQuery,
    required this.filterSite,
    required this.allSites,
    required this.fmt,
    required this.onPickDate,
    required this.onFetch,
    required this.onDownload,
    required this.onSearchChange,
    required this.onSiteChange,
    required this.onQuickDate,
  });

  int get _totalEmployees => data.length;
  int get _totalVisits => data.fold(0, (s, e) => s + e.visits.length);
  String get _totalWorked {
    final mins = data.fold<int>(0, (s, e) => s + e.totalMinutes);
    return '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final pad = isWide ? 24.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Select Date'),
                    const SizedBox(height: 12),
                    isWide
                        ? Row(
                            children: [
                              SizedBox(
                                width: 220,
                                child: _DatePickerField(
                                  'Date',
                                  selectedDate,
                                  fmt,
                                  onPickDate,
                                ),
                              ),
                              const SizedBox(width: 16),
                              _QuickChip(
                                'Today',
                                () => onQuickDate(DateTime.now()),
                              ),
                              const SizedBox(width: 8),
                              _QuickChip(
                                'Yesterday',
                                () => onQuickDate(
                                  DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DatePickerField(
                                'Date',
                                selectedDate,
                                fmt,
                                onPickDate,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _QuickChip(
                                    'Today',
                                    () => onQuickDate(DateTime.now()),
                                  ),
                                  _QuickChip(
                                    'Yesterday',
                                    () => onQuickDate(
                                      DateTime.now().subtract(
                                        const Duration(days: 1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Button(
                      label: 'Fetch Data',
                      icon: Icons.refresh_rounded,
                      color: _primary,
                      loading: loading,
                      onTap: onFetch,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Button(
                      label: 'Download Excel',
                      icon: Icons.download_rounded,
                      color: _accent,
                      loading: false,
                      enabled: fetched && !loading,
                      onTap: onDownload,
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                _ErrorCard(error!),
              ],
              if (fetched && !loading) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.people_alt_rounded,
                      label: 'Employees',
                      value: _totalEmployees.toString(),
                      color: _primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.location_on_rounded,
                      label: 'Total Visits',
                      value: _totalVisits.toString(),
                      color: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: 'Total Hrs',
                      value: _totalWorked,
                      color: _accent,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Card(
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(
                              child: _SearchField(
                                query: searchQuery,
                                onChanged: onSearchChange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 200,
                              child: _DropdownField(
                                label: 'All Sites',
                                value: filterSite,
                                items: allSites,
                                onChanged: onSiteChange,
                                icon: Icons.location_on_rounded,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SearchField(
                              query: searchQuery,
                              onChanged: onSearchChange,
                            ),
                            const SizedBox(height: 10),
                            _DropdownField(
                              label: 'All Sites',
                              value: filterSite,
                              items: allSites,
                              onChanged: onSiteChange,
                              icon: Icons.location_on_rounded,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                _DayWiseList(data: data, isWide: isWide),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: _textDark),
      decoration: const InputDecoration(
        hintText: 'Search by name or Emp ID…',
        hintStyle: TextStyle(color: _textMid, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: _textMid, size: 18),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}

class _DayWiseList extends StatelessWidget {
  final List<_EmpDay> data;
  final bool isWide;
  const _DayWiseList({required this.data, required this.isWide});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 44,
                  color: _textMid.withOpacity(0.35),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No attendance data found.',
                  style: TextStyle(color: _textMid, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final emp in data) ...[
          _EmpExpandCard(emp: emp, isWide: isWide),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EmpExpandCard extends StatefulWidget {
  final _EmpDay emp;
  final bool isWide;
  const _EmpExpandCard({required this.emp, required this.isWide});

  @override
  State<_EmpExpandCard> createState() => _EmpExpandCardState();
}

class _EmpExpandCardState extends State<_EmpExpandCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _anim;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _rotate = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _anim.forward() : _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.emp;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primary.withOpacity(0.15),
                          _primary.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        emp.empName.isNotEmpty
                            ? emp.empName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.empName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ID: ${emp.empId}  ·  ${emp.visits.length} visit${emp.visits.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 11, color: _textMid),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accent.withOpacity(0.25)),
                    ),
                    child: Text(
                      emp.totalFormatted,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  RotationTransition(
                    turns: _rotate,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _textMid,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    children: [
                      Divider(height: 1, color: _border),
                      Container(
                        color: const Color(0xFFF1F5FF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: widget.isWide
                            ? _VisitTableHeaderWide()
                            : _VisitTableHeaderNarrow(),
                      ),
                      for (int i = 0; i < emp.visits.length; i++)
                        _VisitRowWidget(
                          visit: emp.visits[i],
                          isEven: i.isEven,
                          isWide: widget.isWide,
                        ),
                      if (emp.visits.length > 1)
                        Container(
                          color: const Color(0xFFECFDF5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.summarize_rounded,
                                size: 13,
                                color: _accent,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _accent,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                emp.totalFormatted,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _VisitTableHeaderWide extends StatelessWidget {
  const _VisitTableHeaderWide();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(flex: 3, child: _hdr('Site Name')),
      Expanded(flex: 2, child: _hdr('In Time', center: true)),
      Expanded(flex: 2, child: _hdr('Out Time', center: true)),
      Expanded(flex: 2, child: _hdr('Work Time', center: true)),
    ],
  );
  Widget _hdr(String t, {bool center = false}) => Text(
    t,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: _textMid,
    ),
    textAlign: center ? TextAlign.center : TextAlign.left,
  );
}

class _VisitTableHeaderNarrow extends StatelessWidget {
  const _VisitTableHeaderNarrow();
  @override
  Widget build(BuildContext context) => const Text(
    'Visit Details',
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: _textMid,
    ),
  );
}

class _VisitRowWidget extends StatelessWidget {
  final _Visit visit;
  final bool isEven, isWide;
  const _VisitRowWidget({
    required this.visit,
    required this.isEven,
    required this.isWide,
  });

  Widget _timeCell(String t, IconData icon, Color color) => Row(
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          t,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final bg = isEven ? Colors.white : const Color(0xFFF8FAFF);
    if (isWide) {
      return Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: _textMid,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      visit.locationName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textDark,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: _timeCell(
                visit.inFmt,
                Icons.login_rounded,
                const Color(0xFF16A34A),
              ),
            ),
            Expanded(
              flex: 2,
              child: _timeCell(
                visit.outFmt,
                Icons.logout_rounded,
                const Color(0xFFDC2626),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    visit.workedFormatted,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 13, color: _textMid),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  visit.locationName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  visit.workedFormatted,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _timeCell(
                  visit.inFmt,
                  Icons.login_rounded,
                  const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeCell(
                  visit.outFmt,
                  Icons.logout_rounded,
                  const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — MONTHLY
// ─────────────────────────────────────────────────────────────────────────────
class _MonthlyTab extends StatelessWidget {
  final DateTime fromDate, toDate;
  final bool loading, fetched;
  final String? error;
  final List<_EmpDay> data;
  final String Function(DateTime) fmt;
  final VoidCallback onPickFrom, onPickTo, onFetch, onDownload;
  final void Function(DateTime from, DateTime to) onQuickRange;

  const _MonthlyTab({
    required this.fromDate,
    required this.toDate,
    required this.loading,
    required this.fetched,
    required this.error,
    required this.data,
    required this.fmt,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onFetch,
    required this.onDownload,
    required this.onQuickRange,
  });

  String get _totalWorked {
    final mins = data.fold<int>(0, (s, e) => s + e.totalMinutes);
    return '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final pad = isWide ? 24.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Select Date Range'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerField(
                            'From',
                            fromDate,
                            fmt,
                            onPickFrom,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: _textMid,
                            size: 18,
                          ),
                        ),
                        Expanded(
                          child: _DatePickerField('To', toDate, fmt, onPickTo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _QuickChip('This Month', () {
                          final now = DateTime.now();
                          onQuickRange(DateTime(now.year, now.month, 1), now);
                        }),
                        _QuickChip('Last Month', () {
                          final now = DateTime.now();
                          onQuickRange(
                            DateTime(now.year, now.month - 1, 1),
                            DateTime(now.year, now.month, 0),
                          );
                        }),
                        _QuickChip(
                          'Last 30 Days',
                          () => onQuickRange(
                            DateTime.now().subtract(const Duration(days: 29)),
                            DateTime.now(),
                          ),
                        ),
                        _QuickChip('Last 3 Months', () {
                          final now = DateTime.now();
                          onQuickRange(
                            DateTime(now.year, now.month - 2, 1),
                            now,
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Button(
                      label: 'Fetch Data',
                      icon: Icons.refresh_rounded,
                      color: _primary,
                      loading: loading,
                      onTap: onFetch,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Button(
                      label: 'Download Excel',
                      icon: Icons.download_rounded,
                      color: _accent,
                      loading: false,
                      enabled: fetched && !loading,
                      onTap: onDownload,
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                _ErrorCard(error!),
              ],
              if (fetched && !loading) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.people_alt_rounded,
                      label: 'Employees',
                      value: data.map((e) => e.empId).toSet().length.toString(),
                      color: _primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.location_on_rounded,
                      label: 'Total Visits',
                      value: data
                          .fold(0, (s, e) => s + e.visits.length)
                          .toString(),
                      color: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: 'Total Hrs',
                      value: _totalWorked,
                      color: _accent,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MonthlyPreview(data: data, from: fromDate, to: toDate),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MONTHLY PREVIEW  (sticky-left + scrollable date columns) — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class _MonthlyPreview extends StatefulWidget {
  final List<_EmpDay> data;
  final DateTime from, to;
  const _MonthlyPreview({
    required this.data,
    required this.from,
    required this.to,
  });

  @override
  State<_MonthlyPreview> createState() => _MonthlyPreviewState();
}

class _MonthlyPreviewState extends State<_MonthlyPreview> {
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const double _rowH = 38.0;
  static const double _hdrH1 = 38.0;
  static const double _hdrH2 = 32.0;
  static const double wSno = 44.0;
  static const double wId = 72.0;
  static const double wName = 150.0;
  static const double wDay = 32.0;
  static const double wSummary = 76.0;

  static const Color _hdr1 = Color(0xFF1E3A8A);
  static const Color _hdr2 = Color(0xFF2563EB);
  static const Color _hdr3 = Color(0xFF1D4ED8);
  static const Color _divCol = Color(0xFF93C5FD);
  static const Color _presentBg = Color(0xFFDCFCE7);
  static const Color _absentBg = Color(0xFFFEE2E2);

  Widget _vDiv() => Container(width: 1, color: _divCol);
  Widget _hDiv(double w) => Container(height: 1, width: w, color: _divCol);

  Widget _fixCell(
    String t,
    double w,
    double h, {
    Color bg = Colors.white,
    TextStyle? style,
    bool center = true,
    bool isHeader = false,
  }) => Container(
    width: w,
    height: h,
    color: bg,
    alignment: center ? Alignment.center : Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Text(
      t,
      style:
          style ??
          (isHeader
              ? const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                )
              : const TextStyle(fontSize: 10, color: _textDark)),
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _scrollCell(
    String t,
    double w,
    double h, {
    Color? bg,
    TextStyle? style,
    bool center = true,
  }) => Container(
    width: w,
    height: h,
    color: bg ?? Colors.transparent,
    alignment: center ? Alignment.center : Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Text(
      t,
      style: style ?? const TextStyle(fontSize: 10, color: _textDark),
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final List<_EmpDay> data = widget.data;
    final DateTime from = widget.from;
    final DateTime to = widget.to;

    if (data.isEmpty) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 40,
                  color: _textMid.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No data for the selected period.',
                  style: TextStyle(color: _textMid, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final List<DateTime> dates = [];
    for (DateTime d = from; !d.isAfter(to); d = d.add(const Duration(days: 1)))
      dates.add(d);

    final Map<int, String> empNames = {};
    final Map<int, Map<String, List<_Visit>>> empDateV = {};
    for (final day in data) {
      empNames[day.empId] = day.empName;
      empDateV.putIfAbsent(day.empId, () => {});
      empDateV[day.empId]![_dk(day.date)] = day.visits;
    }
    final sortedEmpIds = empNames.keys.toList()..sort();

    final empStats = <int, _EmpStat>{};
    for (final empId in sortedEmpIds) {
      final dateMap = empDateV[empId] ?? {};
      final statuses = <String>[];
      int present = 0, absent = 0, lateDays = 0, lateMins = 0;
      for (final d in dates) {
        final visits = dateMap[_dk(d)];
        if (visits != null && visits.isNotEmpty) {
          present++;
          final firstIn = visits
              .where((v) => v.inTime != null)
              .map((v) => v.inTime!)
              .fold<DateTime?>(
                null,
                (a, b) => a == null || b.isBefore(a) ? b : a,
              );
          final threshold = DateTime(d.year, d.month, d.day, 9, 30);
          final noon = DateTime(d.year, d.month, d.day, 12, 0);
          if (firstIn != null &&
              firstIn.isAfter(threshold) &&
              firstIn.isBefore(noon)) {
            lateDays++;
            lateMins += firstIn.difference(threshold).inMinutes;
          }
          statuses.add('P');
        } else {
          absent++;
          statuses.add('A');
        }
      }
      empStats[empId] = _EmpStat(
        statuses: statuses,
        present: present,
        absent: absent,
        lateDays: lateDays,
        lateMins: lateMins,
        totalWorkedMins: empDateV[empId]!.values.fold(
          0,
          (s, visits) => s + visits.fold(0, (s2, v) => s2 + v.workedMinutes),
        ),
      );
    }

    final double scrollW = dates.length * wDay + 1 + 6 * wSummary + 5;

    Widget leftPanel() => Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _divCol, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _fixCell('S.No', wSno, _hdrH1, bg: _hdr1, isHeader: true),
              _vDiv(),
              _fixCell('Emp ID', wId, _hdrH1, bg: _hdr1, isHeader: true),
              _vDiv(),
              _fixCell('Name', wName, _hdrH1, bg: _hdr1, isHeader: true),
            ],
          ),
          _hDiv(wSno + 1 + wId + 1 + wName),
          Row(
            children: [
              _fixCell('', wSno, _hdrH2, bg: _hdr2),
              _vDiv(),
              _fixCell('', wId, _hdrH2, bg: _hdr2),
              _vDiv(),
              _fixCell('', wName, _hdrH2, bg: _hdr2),
            ],
          ),
          _hDiv(wSno + 1 + wId + 1 + wName),
          for (int idx = 0; idx < sortedEmpIds.length; idx++) ...[
            Builder(
              builder: (_) {
                final empId = sortedEmpIds[idx];
                final name = empNames[empId] ?? '';
                final rowBg = idx.isEven
                    ? Colors.white
                    : const Color(0xFFF8FAFF);
                return Row(
                  children: [
                    _fixCell(
                      '${idx + 1}',
                      wSno,
                      _rowH,
                      bg: rowBg,
                      style: const TextStyle(fontSize: 10, color: _textMid),
                    ),
                    _vDiv(),
                    _fixCell(
                      empId.toString(),
                      wId,
                      _rowH,
                      bg: rowBg,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                    _vDiv(),
                    _fixCell(
                      name,
                      wName,
                      _rowH,
                      bg: rowBg,
                      center: false,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                  ],
                );
              },
            ),
            _hDiv(wSno + 1 + wId + 1 + wName),
          ],
        ],
      ),
    );

    Widget rightPanel() => ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: Scrollbar(
        controller: _hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: dates.length * wDay,
                    height: _hdrH1,
                    color: _hdr1,
                    alignment: Alignment.center,
                    child: Text(
                      '${_fmtDate(from)}  –  ${_fmtDate(to)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _vDiv(),
                  Container(
                    width: 6 * wSummary + 5,
                    height: _hdrH1,
                    color: _hdr3,
                    alignment: Alignment.center,
                    child: const Text(
                      'Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              _hDiv(scrollW),
              Row(
                children: [
                  for (int i = 0; i < dates.length; i++)
                    _scrollCell(
                      '${dates[i].day}',
                      wDay,
                      _hdrH2,
                      bg: _hdr2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  _vDiv(),
                  for (final (label, bg) in [
                    ('Total\nDays', _hdr3),
                    ('Present\nDays', _hdr3),
                    ('Absent\nDays', _hdr3),
                    ('Late\nDays', _hdr3),
                    ('Late\nHrs', _hdr3),
                    ('Total\nWork\nHrs', const Color(0xFF065F46)),
                  ]) ...[
                    _scrollCell(
                      label,
                      wSummary,
                      _hdrH2,
                      bg: bg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (label != 'Total\nWork\nHrs') _vDiv(),
                  ],
                ],
              ),
              _hDiv(scrollW),
              for (int idx = 0; idx < sortedEmpIds.length; idx++) ...[
                Builder(
                  builder: (_) {
                    final empId = sortedEmpIds[idx];
                    final stat = empStats[empId]!;
                    final rowBg = idx.isEven
                        ? Colors.white
                        : const Color(0xFFF8FAFF);
                    final lateH = stat.lateMins ~/ 60;
                    final lateM = stat.lateMins % 60;
                    final lateStr = stat.lateMins == 0
                        ? '0h'
                        : '${lateH}h ${lateM.toString().padLeft(2, '0')}m';
                    return Row(
                      children: [
                        for (int di = 0; di < dates.length; di++)
                          _scrollCell(
                            stat.statuses[di],
                            wDay,
                            _rowH,
                            bg: stat.statuses[di] == 'A'
                                ? _absentBg
                                : _presentBg,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: stat.statuses[di] == 'A'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF16A34A),
                            ),
                          ),
                        _vDiv(),
                        _scrollCell(
                          dates.length.toString(),
                          wSummary,
                          _rowH,
                          bg: rowBg,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          stat.present.toString(),
                          wSummary,
                          _rowH,
                          bg: stat.present > 0
                              ? const Color(0xFFECFDF5)
                              : rowBg,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stat.present > 0
                                ? const Color(0xFF16A34A)
                                : _textMid,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          stat.absent.toString(),
                          wSummary,
                          _rowH,
                          bg: stat.absent > 0 ? const Color(0xFFFEF2F2) : rowBg,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stat.absent > 0
                                ? const Color(0xFFDC2626)
                                : _textMid,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          stat.lateDays.toString(),
                          wSummary,
                          _rowH,
                          bg: stat.lateDays > 0
                              ? const Color(0xFFFFFBEB)
                              : rowBg,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stat.lateDays > 0
                                ? const Color(0xFFD97706)
                                : _textMid,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          lateStr,
                          wSummary,
                          _rowH,
                          bg: stat.lateMins > 0
                              ? const Color(0xFFFFFBEB)
                              : rowBg,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stat.lateMins > 0
                                ? const Color(0xFFD97706)
                                : _textMid,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          _minsToWorkedStr(stat.totalWorkedMins),
                          wSummary,
                          _rowH,
                          bg: const Color(0xFFECFDF5),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                _hDiv(scrollW),
              ],
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: _hdr1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Text(
                'Monthly Attendance Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _Badge(
                '${sortedEmpIds.length} employee${sortedEmpIds.length == 1 ? '' : 's'}',
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _divCol),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            color: Colors.white,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leftPanel(),
              Expanded(child: rightPanel()),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmpStat {
  final List<String> statuses;
  final int present, absent, lateDays, lateMins, totalWorkedMins;
  const _EmpStat({
    required this.statuses,
    required this.present,
    required this.absent,
    required this.lateDays,
    required this.lateMins,
    required this.totalWorkedMins,
  });
}

String _minsToWorkedStr(int mins) {
  final h = mins ~/ 60;
  final m = mins % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: _textDark,
    ),
  );
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final String Function(DateTime) fmt;
  final VoidCallback onTap;
  const _DatePickerField(this.label, this.date, this.fmt, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, size: 16, color: _primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: _textMid),
              ),
              Text(
                fmt(date),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DropdownField extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: _textMid,
        ),
        style: const TextStyle(fontSize: 12, color: _textDark),
        items: items
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: onChanged,
        hint: Row(
          children: [
            Icon(icon, size: 14, color: _textMid),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: _textMid)),
          ],
        ),
      ),
    ),
  );
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip(this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _primary,
        ),
      ),
    ),
  );
}

class _Button extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading, enabled;
  final VoidCallback onTap;
  const _Button({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, color: _textMid),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: _primary,
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _red.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _red.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: _red, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: _red),
          ),
        ),
      ],
    ),
  );
}
