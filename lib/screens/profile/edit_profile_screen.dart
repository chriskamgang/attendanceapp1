import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _bankController;
  late TextEditingController _accountController;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _firstNameController = TextEditingController(text: user?.firstName);
    _lastNameController = TextEditingController(text: user?.lastName);
    _emailController = TextEditingController(text: user?.email);
    _phoneController = TextEditingController(text: user?.phone);
    _addressController = TextEditingController();
    _emergencyNameController = TextEditingController();
    _emergencyPhoneController = TextEditingController();
    _bankController = TextEditingController();
    _accountController = TextEditingController();

    // Charger les champs supplementaires depuis le profil API
    _loadFullProfile();
  }

  Future<void> _loadFullProfile() async {
    final result = await _apiService.getProfile();
    if (mounted && result['success'] == true) {
      final userData = result['user'] ?? result['data'];
      if (userData != null) {
        setState(() {
          _addressController.text = userData['address'] ?? '';
          _emergencyNameController.text = userData['emergency_contact_name'] ?? '';
          _emergencyPhoneController.text = userData['emergency_contact_phone'] ?? '';
          _bankController.text = userData['banque'] ?? '';
          _accountController.text = userData['numero_compte'] ?? '';
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'emergency_contact_name': _emergencyNameController.text.trim(),
        'emergency_contact_phone': _emergencyPhoneController.text.trim(),
        'banque': _bankController.text.trim(),
        'numero_compte': _accountController.text.trim(),
      };

      final result = await _apiService.updateProfile(data);

      if (result['success']) {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).setUser(result['user']);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil mis a jour avec succes'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Erreur lors de la mise a jour')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A237E),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Informations personnelles'),
                    _buildField(
                      controller: _firstNameController,
                      label: 'Prenom',
                      icon: Icons.person_outline,
                      validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                    ),
                    _buildField(
                      controller: _lastNameController,
                      label: 'Nom',
                      icon: Icons.person_outline,
                      validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                    ),
                    _buildField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Champ requis';
                        if (!v.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    _buildField(
                      controller: _phoneController,
                      label: 'Telephone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    _buildField(
                      controller: _addressController,
                      label: 'Adresse',
                      icon: Icons.location_on_outlined,
                    ),

                    _buildSectionTitle('Contact d\'urgence'),
                    _buildField(
                      controller: _emergencyNameController,
                      label: 'Nom du contact',
                      icon: Icons.emergency_outlined,
                    ),
                    _buildField(
                      controller: _emergencyPhoneController,
                      label: 'Telephone d\'urgence',
                      icon: Icons.phone_in_talk_outlined,
                      keyboardType: TextInputType.phone,
                    ),

                    _buildSectionTitle('Informations bancaires'),
                    _buildField(
                      controller: _bankController,
                      label: 'Banque',
                      icon: Icons.account_balance_outlined,
                    ),
                    _buildField(
                      controller: _accountController,
                      label: 'Numero de compte',
                      icon: Icons.credit_card_outlined,
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('ENREGISTRER LES MODIFICATIONS', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
