import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/campus.dart';
import '../../models/unite_enseignement.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';

class CheckInScreen extends StatefulWidget {
  final Campus campus;
  final bool preselected;
  final int? geofenceNotificationId;

  const CheckInScreen({
    super.key,
    required this.campus,
    this.preselected = false,
    this.geofenceNotificationId,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService();
  Position? _currentPosition;
  double? _distanceFromCampus;
  bool _isInZone = false;
  bool _isLoadingPosition = true;
  List<UniteEnseignement> _unitesDisponibles = [];
  UniteEnseignement? _selectedUnite;
  bool _isLoadingUnites = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadUnitesIfVacataire();

    // Si c'est un check-in rapide depuis géofencing
    if (widget.preselected && widget.geofenceNotificationId != null) {
      _markGeofenceNotificationAsClicked();
    }
  }

  Future<void> _markGeofenceNotificationAsClicked() async {
    try {
      await _apiService.markGeofenceClicked(widget.geofenceNotificationId!);
      print('✅ Notification géofencing marquée comme cliquée');
    } catch (e) {
      print('⚠️ Erreur marking notification: $e');
    }
  }

  Future<void> _loadUnitesIfVacataire() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null && (user.isVacataire() || user.isSemiPermanent())) {
      setState(() {
        _isLoadingUnites = true;
      });

      final result = await _apiService.getUnitesEnseignementActives();
      if (result['success']) {
        setState(() {
          _unitesDisponibles = result['unites'];
          _isLoadingUnites = false;
        });
      } else {
        setState(() {
          _isLoadingUnites = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingPosition = true;
    });

    try {
      _currentPosition = await _locationService.getCurrentPosition();

      if (_currentPosition != null) {
        _distanceFromCampus = _locationService.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          widget.campus.latitude,
          widget.campus.longitude,
        );

        _isInZone = _locationService.isInZone(
          userLat: _currentPosition!.latitude,
          userLon: _currentPosition!.longitude,
          zoneLat: widget.campus.latitude,
          zoneLon: widget.campus.longitude,
          radius: widget.campus.radius.toDouble(),
        );

        // Logs de débogage
        print('=== DÉTECTION DE ZONE GPS ===');
        print('Position actuelle: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        print('Position campus: ${widget.campus.latitude}, ${widget.campus.longitude}');
        print('Rayon campus: ${widget.campus.radius} mètres');
        print('Distance calculée: ${_distanceFromCampus!.toStringAsFixed(2)} mètres');
        print('Dans la zone: $_isInZone');
        print('=============================');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoadingPosition = false;
    });
  }

  Future<void> _performCheckIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    // Si vacataire ou semi-permanent, vérifier qu'une UE est sélectionnée
    if (user != null && (user.isVacataire() || user.isSemiPermanent())) {
      if (_selectedUnite == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez sélectionner une unité d\'enseignement'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

    final result = await attendanceProvider.checkIn(
      widget.campus,
      uniteEnseignementId: _selectedUnite?.id,
    );

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Check-in réussi'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Retourne true pour indiquer le succès
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur lors du check-in'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performCheckOut() async {
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

    final result = await attendanceProvider.checkOut(widget.campus);

    if (!mounted) return;

    if (result['success']) {
      final duration = result['duration_minutes'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Check-out réussi! Durée: ${duration ~/ 60}h${duration % 60}min'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Retourne true pour indiquer le succès
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur lors du check-out'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final hasActiveCheckIn = attendanceProvider.hasActiveCheckIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campus.name),
      ),
      body: _isLoadingPosition
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bannière géofencing si preselected
                  if (widget.preselected) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[400]!, Colors.green[600]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Check-in Rapide',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Vous êtes entré dans la zone du ${widget.campus.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.flash_on,
                            color: Colors.amber,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Informations du campus
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_city,
                                  color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Informations du campus',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildInfoRow('Nom', widget.campus.name),
                          _buildInfoRow('Adresse', widget.campus.address),
                          _buildInfoRow(
                            'Horaires',
                            '${widget.campus.getFormattedStartTime()} - ${widget.campus.getFormattedEndTime()}',
                          ),
                          _buildInfoRow(
                            'Tolérance retard',
                            '${widget.campus.lateTolerance} minutes',
                          ),
                          _buildInfoRow(
                            'Rayon',
                            '${widget.campus.radius} mètres',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Statut de localisation
                  Card(
                    color: _isInZone ? Colors.green[50] : Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isInZone ? Icons.check_circle : Icons.cancel,
                                color: _isInZone ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isInZone
                                    ? 'Vous êtes dans la zone'
                                    : 'Vous êtes hors de la zone',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _isInZone ? Colors.green[700] : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_distanceFromCampus != null) ...[
                            Text(
                              'Distance: ${_distanceFromCampus!.toStringAsFixed(0)} mètres',
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (_currentPosition != null) ...[
                            Text(
                              'Ma position: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Campus: ${widget.campus.latitude.toStringAsFixed(6)}, ${widget.campus.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Précision: ±${_currentPosition!.accuracy.toStringAsFixed(0)}m',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bouton rafraîchir position
                  OutlinedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rafraîchir ma position'),
                  ),
                  const SizedBox(height: 24),

                  // Sélecteur d'UE pour les vacataires et semi-permanents
                  if (Provider.of<AuthProvider>(context, listen: false).user?.isVacataire() == true ||
                      Provider.of<AuthProvider>(context, listen: false).user?.isSemiPermanent() == true) ...[
                    _buildUESelector(),
                    const SizedBox(height: 24),
                  ],

                  // Boutons check-in/check-out
                  if (attendanceProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (hasActiveCheckIn)
                    ElevatedButton.icon(
                      onPressed: _isInZone ? _performCheckOut : null,
                      icon: const Icon(Icons.logout),
                      label: const Text('CHECK-OUT'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isInZone ? _performCheckIn : null,
                      icon: const Icon(Icons.login),
                      label: const Text('CHECK-IN'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),

                  if (!_isInZone) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Vous devez être dans un rayon de ${widget.campus.radius}m du campus pour pointer.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUESelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Unité d\'Enseignement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoadingUnites)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_unitesDisponibles.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Aucune UE disponible pour le check-in',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<UniteEnseignement>(
                        isExpanded: true,
                        value: _selectedUnite,
                        hint: const Text('Sélectionner une UE'),
                        items: _unitesDisponibles.map((ue) {
                          return DropdownMenuItem<UniteEnseignement>(
                            value: ue,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ue.nomMatiere,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${ue.codeUe} • ${ue.heuresRestantes.toStringAsFixed(1)}h restantes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (UniteEnseignement? value) {
                          setState(() {
                            _selectedUnite = value;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_selectedUnite != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Heures restantes',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_selectedUnite!.heuresRestantes.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.grey[300],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Progression',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedUnite!.getFormattedPourcentage(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
