import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'chat_screen.dart';

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _contacts = [];
  List<dynamic> _filteredContacts = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final result = await _apiService.getContacts();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _contacts = result['contacts'] as List;
          _filteredContacts = _contacts;
        }
      });
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((c) {
          final name = (c['full_name'] as String).toLowerCase();
          final dept = ((c['department'] ?? '') as String).toLowerCase();
          return name.contains(query.toLowerCase()) || dept.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _startConversation(Map<String, dynamic> contact) async {
    final messageController = TextEditingController();

    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Message a ${contact['full_name']}'),
        content: TextField(
          controller: messageController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Votre message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer')),
        ],
      ),
    );

    if (sent != true || messageController.text.trim().isEmpty) return;

    final result = await _apiService.createConversation(
      recipientId: contact['id'],
      message: messageController.text.trim(),
    );

    if (mounted && result['success']) {
      Navigator.pop(context, true); // return to conversations list
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: result['conversation_id'],
            title: contact['full_name'],
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Erreur'), backgroundColor: Colors.red),
      );
    }
  }

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'enseignant_vacataire': return 'Vacataire';
      case 'semi_permanent': return 'Semi-Permanent';
      case 'enseignant_titulaire': return 'Permanent';
      case 'administratif': return 'Administratif';
      case 'technique': return 'Technique';
      case 'direction': return 'Direction';
      default: return type ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau message'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              decoration: InputDecoration(
                hintText: 'Rechercher un contact...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? Center(child: Text('Aucun contact trouve', style: TextStyle(color: Colors.grey[600])))
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final photo = contact['photo'];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1A237E).withAlpha(25),
                              backgroundImage: photo != null
                                  ? NetworkImage('${ApiConstants.baseUrl.replaceAll('/api', '')}/storage/$photo')
                                  : null,
                              child: photo == null
                                  ? Text(
                                      (contact['full_name'] ?? '?')[0].toUpperCase(),
                                      style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(contact['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              [_getTypeLabel(contact['employee_type']), contact['department']].where((s) => s != null && s.isNotEmpty).join(' - '),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            onTap: () => _startConversation(contact),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
