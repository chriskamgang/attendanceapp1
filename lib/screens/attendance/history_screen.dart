import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/attendance.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Attendance> _attendances = [];
  bool _isLoading = true;
  String _filterType = 'month'; // 'month' or 'day'
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.getMyHistory();
    print('=== HISTORIQUE DEBUG ===');
    print('Result: $result');
    print('Success: ${result['success']}');
    print('Attendances type: ${result['attendances'].runtimeType}');
    print('Attendances length: ${result['attendances']?.length ?? 0}');
    print('=======================');

    if (result['success']) {
      setState(() {
        _attendances = (result['attendances'] as List)
            .map((a) => Attendance.fromJson(a))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Attendance> get _filteredAttendances {
    if (_filterType == 'month') {
      return _attendances.where((attendance) {
        return attendance.timestamp.month == _selectedDate.month &&
            attendance.timestamp.year == _selectedDate.year;
      }).toList();
    } else {
      return _attendances.where((attendance) {
        return attendance.timestamp.day == _selectedDate.day &&
            attendance.timestamp.month == _selectedDate.month &&
            attendance.timestamp.year == _selectedDate.year;
      }).toList();
    }
  }

  // Grouper les présences par date
  Map<String, List<Attendance>> get _groupedAttendances {
    final Map<String, List<Attendance>> grouped = {};

    for (var attendance in _filteredAttendances) {
      final dateKey = DateFormat('yyyy-MM-dd').format(attendance.timestamp);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(attendance);
    }

    return grouped;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedAttendances;
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'month', label: Text('Mois'), icon: Icon(Icons.calendar_view_month)),
                          ButtonSegment(value: 'day', label: Text('Jour'), icon: Icon(Icons.calendar_today)),
                        ],
                        selected: {_filterType},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _filterType = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _filterType == 'month'
                              ? DateFormat('MMMM yyyy', 'fr_FR').format(_selectedDate)
                              : DateFormat('dd MMMM yyyy', 'fr_FR').format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Icon(Icons.calendar_today, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : grouped.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun historique pour cette période',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sortedDates.length,
                          itemBuilder: (context, index) {
                            final dateKey = sortedDates[index];
                            final dayAttendances = grouped[dateKey]!;
                            final date = DateTime.parse(dateKey);

                            return _buildDayCard(date, dayAttendances);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(DateTime date, List<Attendance> attendances) {
    final checkIn = attendances.firstWhere(
      (a) => a.type == 'check-in',
      orElse: () => attendances.first,
    );
    final checkOut = attendances.firstWhere(
      (a) => a.type == 'check-out',
      orElse: () => attendances.first,
    );

    final hasCheckIn = attendances.any((a) => a.type == 'check-in');
    final hasCheckOut = attendances.any((a) => a.type == 'check-out');

    Duration? workedDuration;
    if (hasCheckIn && hasCheckOut) {
      // Plafonner : check-in min 08:00, check-out max 17:00 (sauf soirée)
      DateTime effectiveIn = checkIn.timestamp;
      DateTime effectiveOut = checkOut.timestamp;

      final workStart = DateTime(effectiveIn.year, effectiveIn.month, effectiveIn.day, 8, 0);
      final workEnd = DateTime(effectiveIn.year, effectiveIn.month, effectiveIn.day, 17, 0);

      if (effectiveIn.isBefore(workStart)) effectiveIn = workStart;
      // Ne plafonner à 17h que si check-in avant 17h (sinon c'est une session du soir)
      if (checkIn.timestamp.hour < 17 && effectiveOut.isAfter(workEnd)) {
        effectiveOut = workEnd;
      }

      int totalMinutes = effectiveOut.difference(effectiveIn).inMinutes;

      // Soustraire la pause déjeuner (12:00-13:00) si la session la chevauche
      final breakStart = DateTime(effectiveIn.year, effectiveIn.month, effectiveIn.day, 12, 0);
      final breakEnd = DateTime(effectiveIn.year, effectiveIn.month, effectiveIn.day, 13, 0);
      if (effectiveIn.isBefore(breakEnd) && effectiveOut.isAfter(breakStart)) {
        final overlapStart = effectiveIn.isAfter(breakStart) ? effectiveIn : breakStart;
        final overlapEnd = effectiveOut.isBefore(breakEnd) ? effectiveOut : breakEnd;
        final breakMinutes = overlapEnd.difference(overlapStart).inMinutes;
        if (breakMinutes > 0) totalMinutes -= breakMinutes;
      }

      if (totalMinutes < 0) totalMinutes = 0;
      workedDuration = Duration(minutes: totalMinutes);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Check-in
            _buildAttendanceRow(
              'Check-in',
              hasCheckIn ? DateFormat('HH:mm:ss').format(checkIn.timestamp) : 'N/A',
              hasCheckIn ? (checkIn.isLate ? Colors.orange : Colors.green) : Colors.grey,
              hasCheckIn ? checkIn.campus?.name : null,
              hasCheckIn && checkIn.uniteEnseignement != null
                  ? '${checkIn.uniteEnseignement!.codeUe} - ${checkIn.uniteEnseignement!.nomMatiere}'
                  : null,
              hasCheckIn && checkIn.isLate ? 'Retard: ${checkIn.lateMinutes} min' : null,
            ),

            const SizedBox(height: 8),

            // Check-out
            _buildAttendanceRow(
              'Check-out',
              hasCheckOut ? DateFormat('HH:mm:ss').format(checkOut.timestamp) : 'N/A',
              hasCheckOut ? Colors.blue : Colors.grey,
              hasCheckOut ? checkOut.campus?.name : null,
              hasCheckOut && checkOut.uniteEnseignement != null
                  ? '${checkOut.uniteEnseignement!.codeUe} - ${checkOut.uniteEnseignement!.nomMatiere}'
                  : null,
              null,
            ),

            // Durée
            if (workedDuration != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Durée travaillée: ${workedDuration.inHours}h ${workedDuration.inMinutes.remainder(60)}min',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceRow(String label, String time, Color color, String? campus, String? ue, String? extra) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        if (campus != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                campus,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
        if (ue != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.school, size: 14, color: Colors.blue[400]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  ue,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (extra != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.warning_amber, size: 14, color: Colors.orange[600]),
              const SizedBox(width: 4),
              Text(
                extra,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
