import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/bus_service.dart';

class BusQrPassScreen extends StatefulWidget {
  const BusQrPassScreen({super.key});

  @override
  State<BusQrPassScreen> createState() => _BusQrPassScreenState();
}

class _BusQrPassScreenState extends State<BusQrPassScreen> {
  final BusService _busService = BusService();
  bool _isLoading = true;
  Map<String, dynamic>? _passData;
  String? _error;
  Timer? _refreshTimer;
  int _countdown = 30;

  @override
  void initState() {
    super.initState();
    _loadPass();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPass() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _busService.getQrPass();

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _isLoading = false;
        _passData = result;
        _countdown = result['validite_secondes'] ?? 30;
      });
      _startCountdown();
    } else {
      setState(() {
        _isLoading = false;
        _error = result['message'] ?? 'Impossible de generer le QR Pass.';
      });
    }
  }

  void _startCountdown() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _loadPass(); // Auto-refresh
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('QR Pass'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildPass(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              _error!,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadPass,
              icon: const Icon(Icons.refresh),
              label: const Text('Reessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPass() {
    final jeton = _passData?['jeton'] ?? '';
    final passList = _passData?['pass'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            'Presentez ce QR code au chauffeur',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // QR Code placeholder (le vrai QR sera genere avec le jeton)
          Container(
            width: 280,
            height: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1565C0), width: 3),
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2, size: 120, color: Colors.grey.shade800),
                  const SizedBox(height: 12),
                  Text(
                    jeton.toString().length > 20 ? '${jeton.toString().substring(0, 20)}...' : jeton.toString(),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Countdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _countdown > 10 ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 20,
                  color: _countdown > 10 ? Colors.green.shade700 : Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Expire dans ${_countdown}s',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _countdown > 10 ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Pass info
          if (passList.isNotEmpty)
            ...passList.map((pass) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.card_membership, color: Color(0xFF1565C0), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pass['abonnement']?['tarif']?['nom'] ?? 'Abonnement actif',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )),

          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadPass,
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerer le QR'),
          ),
        ],
      ),
    );
  }
}
