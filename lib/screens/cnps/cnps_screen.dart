import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CnpsScreen extends StatefulWidget {
  const CnpsScreen({super.key});

  @override
  State<CnpsScreen> createState() => _CnpsScreenState();
}

class _CnpsScreenState extends State<CnpsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _record;
  List<dynamic> _contributions = [];
  Map<String, dynamic>? _totals;
  int _selectedYear = DateTime.now().year;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _apiService.getCnpsRecord(),
      _apiService.getCnpsContributions(year: _selectedYear),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results[0]['success']) _record = results[0]['record'];
        if (results[1]['success']) {
          _contributions = results[1]['contributions'] ?? [];
          _totals = results[1]['totals'];
        }
      });
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 FCFA';
    final num val = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
    return '${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CNPS'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CNPS Record card
                    _buildRecordCard(),
                    const SizedBox(height: 16),

                    // Year selector
                    _buildYearSelector(),
                    const SizedBox(height: 12),

                    // Totals
                    if (_totals != null) _buildTotalsCard(),
                    const SizedBox(height: 16),

                    // Monthly contributions
                    const Text('Cotisations mensuelles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    if (_contributions.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('Aucune cotisation pour cette annee')),
                        ),
                      )
                    else
                      ..._contributions.map((c) => _buildContributionCard(c)),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRecordCard() {
    if (_record == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.orange[50],
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(child: Text('Aucun dossier CNPS enregistre. Contactez les RH.')),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)]),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text('Dossier CNPS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            _whiteInfoRow('N CNPS', _record!['cnps_number'] ?? 'N/A'),
            _whiteInfoRow('Date inscription', _record!['registration_date'] ?? 'N/A'),
            _whiteInfoRow('Statut', _record!['status'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _whiteInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => currentYear - i);

    return Row(
      children: [
        const Text('Annee: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: _selectedYear,
          items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedYear = val);
              _loadData();
            }
          },
        ),
      ],
    );
  }

  Widget _buildTotalsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Totaux $_selectedYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _totalRow('Part employee', _totals!['employee'], Colors.blue),
            _totalRow('Part employeur', _totals!['employer'], Colors.green),
            const Divider(),
            _totalRow('Total cotisations', _totals!['total'], const Color(0xFF1A237E)),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, dynamic amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(_formatCurrency(amount), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildContributionCard(Map<String, dynamic> c) {
    final status = c['status'] ?? '';
    final isPaid = status == 'paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      c['month_label'] ?? '',
                      style: TextStyle(fontWeight: FontWeight.bold, color: isPaid ? Colors.green[700] : Colors.orange[700]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Salaire brut: ${_formatCurrency(c['gross_salary'])}', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        'Total: ${_formatCurrency(c['total_contribution'])}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPaid ? 'Paye' : 'En attente',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPaid ? Colors.green[700] : Colors.orange[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _miniInfo('Employee', _formatCurrency(c['employee_contribution']))),
                Expanded(child: _miniInfo('Employeur', _formatCurrency(c['employer_contribution']))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
