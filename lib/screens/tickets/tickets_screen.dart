import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';
import 'package:intl/intl.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _tickets = [];
  Map<String, dynamic> _services = {};
  Map<String, dynamic> _categories = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getTickets();
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _tickets = result['tickets'] ?? [];
          if (result['services'] is Map) _services = Map<String, dynamic>.from(result['services']);
          if (result['categories'] is Map) _categories = Map<String, dynamic>.from(result['categories']);
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement tickets: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Tickets'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadTickets,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tickets.length,
                    itemBuilder: (context, index) => _buildTicketCard(_tickets[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateTicketScreen(services: _services, categories: _categories)),
          );
          if (result == true) _loadTickets();
        },
        backgroundColor: const Color(0xFF0D47A1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucun ticket pour le moment',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Creez un ticket pour contacter un service',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateTicketScreen(services: _services, categories: _categories)),
              );
              if (result == true) _loadTickets();
            },
            icon: const Icon(Icons.add),
            label: const Text('NOUVEAU TICKET'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final statusColors = {
      'new': Colors.red,
      'assigned': Colors.orange,
      'in_progress': Colors.blue,
      'responded': Colors.purple,
      'resolved': Colors.green,
      'closed': Colors.grey,
    };

    final status = ticket['status'] as String? ?? 'new';
    final statusColor = statusColors[status] ?? Colors.grey;
    final statusLabel = ticket['status_label'] ?? status;
    final createdAt = DateTime.tryParse(ticket['created_at'] ?? '');
    final comments = ticket['comments'] as List? ?? [];
    final hasResponse = comments.any((c) => c['type'] == 'response');
    final rating = ticket['satisfaction_rating'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)),
          );
          if (result == true) _loadTickets();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    ticket['ticket_number'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Subject
              Text(
                ticket['subject'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Service + date
              Row(
                children: [
                  Icon(Icons.business, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    ticket['service_label'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    createdAt != null ? DateFormat('dd/MM/yyyy').format(createdAt) : '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              // Indicateurs
              if (hasResponse || rating != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (hasResponse)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.reply, size: 12, color: Colors.green[700]),
                            const SizedBox(width: 3),
                            Text('Reponse recue', style: TextStyle(fontSize: 10, color: Colors.green[700])),
                          ],
                        ),
                      ),
                    if (rating != null) ...[
                      const SizedBox(width: 8),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          Icons.star,
                          size: 14,
                          color: i < (rating as int) ? Colors.amber : Colors.grey[300],
                        )),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
