import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';

class PayslipHistoryScreen extends StatefulWidget {
  const PayslipHistoryScreen({super.key});

  @override
  State<PayslipHistoryScreen> createState() => _PayslipHistoryScreenState();
}

class _PayslipHistoryScreenState extends State<PayslipHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _history = [];
  bool _isLoading = true;
  bool _isVacataire = false;
  int? _downloadingIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getPayslipHistory();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _history = result['history'] as List;
          _isVacataire = result['is_vacataire'] == true;
        }
      });
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0 FCFA';
    final number = value is String ? double.tryParse(value) ?? 0 : value.toDouble();
    return '${NumberFormat('#,##0', 'fr_FR').format(number)} FCFA';
  }

  Future<void> _downloadPayslip(int index, int month, int year) async {
    setState(() => _downloadingIndex = index);

    try {
      final token = await StorageService().getToken();
      final dio = Dio();
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/fiche-paie-$month-$year.pdf';

      await dio.download(
        '${ApiConstants.baseUrl}/user/payslip?month=$month&year=$year',
        filePath,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf',
        }),
      );

      if (mounted) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossible d\'ouvrir: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique Fiches de Paie'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Aucune fiche de paie', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final month = item['month'] as int;
                      final year = item['year'] as int;
                      final period = item['period'] as String;
                      final netSalary = item['net_salary'];
                      final grossSalary = item['gross_salary'];
                      final isDownloading = _downloadingIndex == index;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: isDownloading ? null : () => _downloadPayslip(index, month, year),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A237E).withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        month.toString().padLeft(2, '0'),
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                                      ),
                                      Text(
                                        year.toString().substring(2),
                                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        period[0].toUpperCase() + period.substring(1),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Net: ${_formatCurrency(netSalary)}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Brut: ${_formatCurrency(grossSalary)}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                isDownloading
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(Icons.download_rounded, color: Colors.grey[600]),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
