import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  int _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  int _currentPage = 1;
  bool _hasMorePages = true;
  bool _isLoadingMore = false;

  static const Color _primaryDark = Color(0xFF1A237E);
  static const Color _primaryMid = Color(0xFF283593);
  static const Color _accentBlue = Color(0xFF42A5F5);

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0 FCFA';
    final number = value is String ? int.tryParse(value) ?? 0 : (value is double ? value.toInt() : value as int);
    return '${NumberFormat('#,##0', 'fr_FR').format(number)} FCFA';
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getWallet();
    if (result['success'] && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;
      _balance = (data['balance'] is int) ? data['balance'] : (data['balance'] as num).toInt();
      _transactions = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
      _currentPage = 1;
      _hasMorePages = _transactions.length >= 15;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMorePages) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final result = await _apiService.getWalletTransactions(nextPage);
    if (result['success'] && result['data'] != null) {
      final data = result['data'];
      List<Map<String, dynamic>> newTransactions;
      if (data is List) {
        newTransactions = List<Map<String, dynamic>>.from(data);
      } else if (data is Map && data['data'] != null) {
        newTransactions = List<Map<String, dynamic>>.from(data['data']);
      } else {
        newTransactions = [];
      }

      if (newTransactions.isEmpty) {
        _hasMorePages = false;
      } else {
        _currentPage = nextPage;
        _transactions.addAll(newTransactions);
      }
    } else {
      _hasMorePages = false;
    }
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _showWithdrawSheet() {
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    String selectedMethod = '';
    bool isSubmitting = false;
    final formKey = GlobalKey<FormState>();
    final parentMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void autoDetectMethod(String phone) {
            final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
            String detected = '';
            if (cleaned.startsWith('67') || cleaned.startsWith('+23767') || cleaned.startsWith('23767') ||
                cleaned.startsWith('65') || cleaned.startsWith('+23765') || cleaned.startsWith('23765') ||
                cleaned.startsWith('68') || cleaned.startsWith('+23768') || cleaned.startsWith('23768')) {
              detected = 'mtn_mobile_money';
            } else if (cleaned.startsWith('69') || cleaned.startsWith('+23769') || cleaned.startsWith('23769') ||
                       cleaned.startsWith('65') || cleaned.startsWith('+23765') || cleaned.startsWith('23765')) {
              detected = 'orange_money';
            }
            if (detected.isNotEmpty && detected != selectedMethod) {
              setSheetState(() => selectedMethod = detected);
            }
          }

          Future<void> submitTransfer() async {
            if (!formKey.currentState!.validate()) return;
            if (selectedMethod.isEmpty) {
              parentMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Veuillez selectionner une methode de paiement'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            setSheetState(() => isSubmitting = true);

            final phone = phoneController.text.trim();
            final amount = int.parse(amountController.text.trim());
            final navigator = Navigator.of(sheetContext);

            final result = await _apiService.walletTransfer(phone, amount, selectedMethod);

            if (!sheetContext.mounted) return;
            setSheetState(() => isSubmitting = false);

            if (result['success']) {
              navigator.pop();
              parentMessenger.showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? 'Retrait effectue avec succes'),
                  backgroundColor: Colors.green,
                ),
              );
              _loadWallet();
            } else {
              navigator.pop();
              parentMessenger.showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? 'Erreur lors du retrait'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Retirer des fonds',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryDark,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Phone number input
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                    onChanged: autoDetectMethod,
                    decoration: InputDecoration(
                      labelText: 'Numero de telephone',
                      prefixText: '+237 ',
                      prefixStyle: const TextStyle(
                        color: _primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _primaryDark, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le numero de telephone est requis';
                      }
                      final cleaned = value.replaceAll(RegExp(r'\s+'), '');
                      if (cleaned.length < 9) {
                        return 'Numero invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Amount input
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Montant (FCFA)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _primaryDark, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le montant est requis';
                      }
                      final amount = int.tryParse(value.trim());
                      if (amount == null || amount <= 0) {
                        return 'Le montant doit etre superieur a 0';
                      }
                      if (amount > _balance) {
                        return 'Solde insuffisant (${_formatCurrency(_balance)})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Method selector
                  const Text(
                    'Methode de paiement',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedMethod = 'mtn_mobile_money'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'mtn_mobile_money'
                                  ? const Color(0xFFFFCA28)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedMethod == 'mtn_mobile_money'
                                    ? const Color(0xFFF9A825)
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'MTN Mobile Money',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: selectedMethod == 'mtn_mobile_money'
                                      ? Colors.black87
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedMethod = 'orange_money'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'orange_money'
                                  ? const Color(0xFFFF9800)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedMethod == 'orange_money'
                                    ? const Color(0xFFE65100)
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Orange Money',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: selectedMethod == 'orange_money'
                                      ? Colors.white
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Warning text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Des frais de transfert peuvent etre appliques par l\'operateur.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : submitTransfer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Confirmer le retrait',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Mon Portefeuille',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryDark))
          : RefreshIndicator(
              onRefresh: _loadWallet,
              color: _primaryDark,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Balance card
                  _buildBalanceCard(),
                  const SizedBox(height: 20),

                  // Transaction history header
                  const Text(
                    'Historique des transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Transactions list
                  if (_transactions.isEmpty)
                    _buildEmptyState()
                  else ...[
                    ..._transactions.map((t) => _buildTransactionItem(t)),
                    if (_hasMorePages)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: _isLoadingMore
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _primaryDark,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _loadMoreTransactions,
                                  child: const Text(
                                    'Voir plus',
                                    style: TextStyle(
                                      color: _primaryDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryDark, _primaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Solde disponible',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _formatCurrency(_balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showWithdrawSheet,
              icon: const Icon(Icons.send, size: 18),
              label: const Text(
                'Retirer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Aucune transaction',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type']?.toString() ?? '';
    final amount = transaction['amount'] is int
        ? transaction['amount']
        : (transaction['amount'] is String
            ? int.tryParse(transaction['amount']) ?? 0
            : (transaction['amount'] as num?)?.toInt() ?? 0);
    final description = transaction['description']?.toString() ?? '';
    final createdAt = transaction['created_at']?.toString() ?? '';
    final transferPhone = transaction['transfer_phone']?.toString();
    final transferMethod = transaction['transfer_method']?.toString();
    final elgiopayStatus = transaction['elgiopay_status']?.toString();
    final sourceType = transaction['source_type']?.toString() ?? '';

    // Icon and color based on type
    IconData icon;
    Color iconColor;
    Color iconBgColor;
    String amountPrefix;
    Color amountColor;

    if (type == 'credit') {
      icon = Icons.arrow_downward;
      iconColor = Colors.green[700]!;
      iconBgColor = Colors.green[50]!;
      amountPrefix = '+';
      amountColor = Colors.green[700]!;
    } else if (type == 'debit') {
      icon = Icons.arrow_upward;
      iconColor = Colors.red[700]!;
      iconBgColor = Colors.red[50]!;
      amountPrefix = '-';
      amountColor = Colors.red[700]!;
    } else {
      // transfer
      icon = Icons.send;
      iconColor = _accentBlue;
      iconBgColor = Colors.blue[50]!;
      amountPrefix = '-';
      amountColor = _accentBlue;
    }

    // Format date
    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3142),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                if (sourceType == 'transfer' && transferPhone != null && transferPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        transferPhone,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (transferMethod != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: transferMethod == 'mtn_mobile_money'
                                ? const Color(0xFFFFF9C4)
                                : const Color(0xFFFFE0B2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transferMethod == 'mtn_mobile_money' ? 'MTN' : 'Orange',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: transferMethod == 'mtn_mobile_money'
                                  ? Colors.black87
                                  : const Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (elgiopayStatus != null && elgiopayStatus.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildStatusBadge(elgiopayStatus),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$amountPrefix${_formatCurrency(amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        label = 'En attente';
        break;
      case 'completed':
        bgColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        label = 'Termine';
        break;
      case 'failed':
        bgColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        label = 'Echoue';
        break;
      default:
        bgColor = Colors.grey[100]!;
        textColor = Colors.grey[600]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
