import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CreateTicketScreen extends StatefulWidget {
  final Map<String, dynamic>? services;
  final Map<String, dynamic>? categories;

  const CreateTicketScreen({super.key, this.services, this.categories});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCategory;
  String? _selectedService;
  bool _isSubmitting = false;
  bool _isLoading = true;

  Map<String, String> _categories = {};
  Map<String, String> _services = {};

  // Fallback icons/colors for known services
  final Map<String, IconData> _serviceIcons = {
    'rh': Icons.people,
    'scolarite': Icons.school,
    'finance': Icons.account_balance,
    'technique': Icons.build,
    'direction': Icons.business,
    'general': Icons.home_repair_service,
  };

  final Map<String, Color> _serviceColors = {
    'rh': Colors.blue,
    'scolarite': Colors.purple,
    'finance': Colors.green,
    'technique': Colors.orange,
    'direction': Colors.red,
    'general': Colors.teal,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Use passed data if available
    if (widget.services != null && widget.categories != null) {
      _services = Map<String, String>.from(widget.services!.map((k, v) => MapEntry(k.toString(), v.toString())));
      _categories = Map<String, String>.from(widget.categories!.map((k, v) => MapEntry(k.toString(), v.toString())));
      setState(() => _isLoading = false);
      return;
    }

    // Otherwise fetch from API
    try {
      final result = await _apiService.getTickets();
      if (result['success'] == true) {
        final svc = result['services'];
        final cat = result['categories'];
        if (svc is Map) {
          _services = Map<String, String>.from(svc.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
        if (cat is Map) {
          _categories = Map<String, String>.from(cat.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
      }
    } catch (_) {}

    // Fallback if empty
    if (_services.isEmpty) {
      _services = {
        'rh': 'Ressources Humaines',
        'scolarite': 'Scolarite',
        'finance': 'Finance',
        'technique': 'Service Technique',
        'direction': 'Direction',
        'general': 'Services Generaux',
      };
    }
    if (_categories.isEmpty) {
      _categories = {
        'rh': 'Ressources Humaines',
        'scolarite': 'Scolarite',
        'finance': 'Finance',
        'technique': 'Technique',
        'infrastructure': 'Infrastructure',
        'autre': 'Autre',
      };
    }

    if (mounted) setState(() => _isLoading = false);
  }

  IconData _getServiceIcon(String slug) {
    return _serviceIcons[slug] ?? Icons.miscellaneous_services;
  }

  Color _getServiceColor(String slug) {
    return _serviceColors[slug] ?? Colors.blueGrey;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez selectionner une categorie et un service'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _apiService.createTicket(
        category: _selectedCategory!,
        targetService: _selectedService!,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final ticketNum = result['ticket']?['ticket_number'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket $ticketNum cree avec succes'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
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

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau Ticket'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Catégorie
                    const Text('Categorie', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        hintText: 'Selectionner une categorie',
                      ),
                      items: _categories.entries.map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                      validator: (v) => v == null ? 'Requis' : null,
                    ),

                    const SizedBox(height: 20),

                    // Service destinataire
                    const Text('Service destinataire', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'Choisissez le service qui doit traiter votre demande',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _services.entries.map((e) {
                        final isSelected = _selectedService == e.key;
                        final color = _getServiceColor(e.key);
                        return GestureDetector(
                          onTap: () => setState(() => _selectedService = e.key),
                          child: Container(
                            width: (MediaQuery.of(context).size.width - 48) / 2,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withOpacity(0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? color : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(_getServiceIcon(e.key), color: isSelected ? color : Colors.grey[500], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e.value,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? color : Colors.grey[700],
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle, color: color, size: 18),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Objet
                    const Text('Objet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        hintText: 'Resume en quelques mots',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      maxLength: 255,
                    ),

                    const SizedBox(height: 12),

                    // Description
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                        hintText: 'Decrivez votre probleme en detail...',
                      ),
                      maxLines: 6,
                      maxLength: 3000,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),

                    const SizedBox(height: 24),

                    // Bouton
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('ENVOYER LE TICKET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
