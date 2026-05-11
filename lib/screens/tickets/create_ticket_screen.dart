import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

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

  final Map<String, String> _categories = {
    'rh': 'Ressources Humaines',
    'scolarite': 'Scolarite',
    'finance': 'Finance',
    'technique': 'Technique',
    'infrastructure': 'Infrastructure',
    'autre': 'Autre',
  };

  final Map<String, Map<String, dynamic>> _services = {
    'rh': {'label': 'Ressources Humaines', 'icon': Icons.people, 'color': Colors.blue},
    'scolarite': {'label': 'Scolarite', 'icon': Icons.school, 'color': Colors.purple},
    'finance': {'label': 'Finance', 'icon': Icons.account_balance, 'color': Colors.green},
    'technique': {'label': 'Service Technique', 'icon': Icons.build, 'color': Colors.orange},
    'direction': {'label': 'Direction', 'icon': Icons.business, 'color': Colors.red},
    'general': {'label': 'Services Generaux', 'icon': Icons.home_repair_service, 'color': Colors.teal},
  };

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
      body: SingleChildScrollView(
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
                  final color = e.value['color'] as Color;
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
                          Icon(e.value['icon'] as IconData, color: isSelected ? color : Colors.grey[500], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.value['label'] as String,
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
