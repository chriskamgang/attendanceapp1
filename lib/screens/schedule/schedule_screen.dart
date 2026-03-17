import 'package:flutter/material.dart';
import '../../models/ue_schedule.dart';
import '../../services/api_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ApiService _apiService = ApiService();
  Map<String, List<UeSchedule>> _weekSchedule = {};
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _jours = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.getMySchedule();
      if (result['success']) {
        final raw = result['data'];
        final Map<String, List<UeSchedule>> grouped = {};

        if (raw is Map<String, dynamic>) {
          // Format: { "lundi": [...], "mardi": [...] }
          raw.forEach((jour, items) {
            if (items is List) {
              grouped[jour] = items
                  .map((item) => UeSchedule.fromJson(item as Map<String, dynamic>))
                  .toList();
            }
          });
        } else if (raw is List) {
          // Format: [ { "jour_semaine": "lundi", ... }, ... ]
          for (final item in raw) {
            final map = item as Map<String, dynamic>;
            final jour = (map['jour_semaine'] ?? map['jour'] ?? '').toString().toLowerCase();
            if (jour.isNotEmpty) {
              grouped.putIfAbsent(jour, () => []);
              grouped[jour]!.add(UeSchedule.fromJson(map));
            }
          }
        }

        setState(() {
          _weekSchedule = grouped;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Erreur de chargement';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Emploi du Temps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedule,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: TextStyle(color: Colors.red[700])),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSchedule,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSchedule,
                  child: _buildWeekView(),
                ),
    );
  }

  Widget _buildWeekView() {
    final bool hasAnySchedule = _weekSchedule.values.any((list) => list.isNotEmpty);

    if (!hasAnySchedule) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Aucun emploi du temps',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Contactez l\'administration pour programmer vos cours.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _jours.length,
      itemBuilder: (context, index) {
        final jour = _jours[index];
        final schedules = _weekSchedule[jour] ?? [];
        return _buildDayCard(jour, schedules);
      },
    );
  }

  Widget _buildDayCard(String jour, List<UeSchedule> schedules) {
    final isToday = _isToday(jour);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isToday ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday
            ? BorderSide(color: Colors.blue[400]!, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du jour
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isToday ? Colors.blue[600] : Colors.grey[800],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  UeSchedule.jourSemaineLabel(jour),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Aujourd'hui",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                if (schedules.isNotEmpty)
                  Text(
                    '${schedules.length} cours',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          // Contenu
          if (schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pas de cours',
                style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic),
              ),
            )
          else
            ...schedules.map((schedule) => _buildScheduleItem(schedule)),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(UeSchedule schedule) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horaire
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  schedule.heureDebut,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                    fontSize: 14,
                  ),
                ),
                Text(
                  schedule.heureFin,
                  style: TextStyle(
                    color: Colors.blue[400],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Détails
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.ueCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  schedule.ueNom,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      schedule.campusName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (schedule.salle != null && schedule.salle!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.meeting_room, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Salle ${schedule.salle}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
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

  bool _isToday(String jour) {
    final days = {
      1: 'lundi',
      2: 'mardi',
      3: 'mercredi',
      4: 'jeudi',
      5: 'vendredi',
      6: 'samedi',
      7: 'dimanche',
    };
    return days[DateTime.now().weekday] == jour;
  }
}
