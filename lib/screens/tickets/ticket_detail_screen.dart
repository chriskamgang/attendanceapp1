import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final ApiService _apiService = ApiService();
  final _commentController = TextEditingController();
  bool _isSending = false;
  bool _hasChanges = false;

  late Map<String, dynamic> _ticket;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final result = await _apiService.addTicketComment(_ticket['id'], text);
      if (!mounted) return;
      if (result['success'] == true) {
        _commentController.clear();
        _hasChanges = true;
        // Ajouter le commentaire localement
        setState(() {
          final comments = List<dynamic>.from(_ticket['comments'] ?? []);
          comments.add({
            'comment': text,
            'user_name': 'Moi',
            'type': 'public',
            'created_at': DateTime.now().toIso8601String(),
          });
          _ticket['comments'] = comments;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commentaire envoye'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Erreur'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _rateTicket(int rating) async {
    final result = await _apiService.rateTicket(_ticket['id'], rating);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _ticket['satisfaction_rating'] = rating);
      _hasChanges = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci pour votre evaluation !'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _ticket['status'] as String? ?? 'new';
    final comments = _ticket['comments'] as List? ?? [];
    final rating = _ticket['satisfaction_rating'];
    final isResolved = status == 'resolved' || status == 'closed';
    final isClosed = status == 'closed';

    final statusColors = {
      'new': Colors.red,
      'assigned': Colors.orange,
      'in_progress': Colors.blue,
      'responded': Colors.purple,
      'resolved': Colors.green,
      'closed': Colors.grey,
    };
    final statusColor = statusColors[status] ?? Colors.grey;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _hasChanges) {
          // Will return true to trigger refresh
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_ticket['ticket_number'] ?? 'Ticket'),
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status + service
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _ticket['status_label'] ?? status,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _ticket['service_label'] ?? '',
                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                          ),
                        ),
                        if (_ticket['was_redirected'] == true) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.swap_horiz, size: 16, color: Colors.orange[700]),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Subject
                    Text(
                      _ticket['subject'] ?? '',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Date
                    Text(
                      'Cree le ${_formatDate(_ticket['created_at'])}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        _ticket['description'] ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),

                    // Rating (si résolu et pas encore noté)
                    if (isResolved && rating == null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Comment evaluez-vous le traitement ?',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (i) => GestureDetector(
                                onTap: () => _rateTicket(i + 1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(Icons.star, size: 36, color: Colors.grey[300]),
                                ),
                              )),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Rating affiché
                    if (rating != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Votre note : ', style: TextStyle(fontSize: 13)),
                          ...List.generate(5, (i) => Icon(
                            Icons.star,
                            size: 18,
                            color: i < (rating as int) ? Colors.amber : Colors.grey[300],
                          )),
                        ],
                      ),
                    ],

                    // Commentaires / Réponses
                    if (comments.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('Echanges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      ...comments.map<Widget>((c) {
                        final isResponse = c['type'] == 'response';
                        final dt = DateTime.tryParse(c['created_at'] ?? '');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isResponse ? Colors.blue[50] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isResponse ? Colors.blue[200]! : Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isResponse ? Icons.support_agent : Icons.person,
                                    size: 16,
                                    color: isResponse ? Colors.blue[700] : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isResponse ? (c['user_name'] ?? 'Reception') : 'Moi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: isResponse ? Colors.blue[700] : Colors.grey[700],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (dt != null)
                                    Text(
                                      DateFormat('dd/MM HH:mm').format(dt),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(c['comment'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4)),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Zone de commentaire (si pas clôturé)
            if (!isClosed)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Ajouter un commentaire...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey[300]!)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF0D47A1),
                      child: _isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : IconButton(
                              icon: const Icon(Icons.send, color: Colors.white, size: 18),
                              onPressed: _sendComment,
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy a HH:mm').format(dt);
  }
}
