import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class RecruitmentScreen extends StatefulWidget {
  const RecruitmentScreen({super.key});

  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _postings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPostings();
  }

  Future<void> _loadPostings() async {
    final result = await _apiService.getJobPostings();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) _postings = result['postings'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offres d\'emploi'),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _postings.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucune offre disponible', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPostings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _postings.length,
                    itemBuilder: (context, index) => _buildPostingCard(_postings[index]),
                  ),
                ),
    );
  }

  Widget _buildPostingCard(Map<String, dynamic> posting) {
    final isOpen = posting['is_open'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openDetail(posting['id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(posting['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOpen ? 'Ouvert' : 'Ferme',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isOpen ? Colors.green[700] : Colors.red[700]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (posting['department'] != null)
                    _chip(Icons.business, posting['department'], Colors.blue),
                  _chip(Icons.description, posting['contract_label'] ?? '', Colors.purple),
                  if (posting['location'] != null)
                    _chip(Icons.location_on, posting['location'], Colors.teal),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (posting['salary_range'] != null) ...[
                    Icon(Icons.payments, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(posting['salary_range'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  Text(
                    '${posting['positions_count'] ?? 1} poste(s)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.people, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${posting['applications_count'] ?? 0} candidatures', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
              if (posting['closes_at'] != null) ...[
                const SizedBox(height: 6),
                Text('Date limite: ${posting['closes_at']}', style: TextStyle(color: Colors.orange[700], fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _openDetail(int id) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => JobPostingDetailScreen(postingId: id)));
  }
}

// ===== JOB POSTING DETAIL =====

class JobPostingDetailScreen extends StatefulWidget {
  final int postingId;
  const JobPostingDetailScreen({super.key, required this.postingId});

  @override
  State<JobPostingDetailScreen> createState() => _JobPostingDetailScreenState();
}

class _JobPostingDetailScreenState extends State<JobPostingDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _posting;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final result = await _apiService.getJobPostingDetail(widget.postingId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) _posting = result['posting'];
      });
    }
  }

  void _showApplyDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final coverCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Postuler'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom complet *')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email *'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telephone'), keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              TextField(controller: coverCtrl, decoration: const InputDecoration(labelText: 'Lettre de motivation'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              final result = await _apiService.applyToJob(
                widget.postingId,
                name: nameCtrl.text,
                email: emailCtrl.text,
                phone: phoneCtrl.text.isNotEmpty ? phoneCtrl.text : null,
                coverLetter: coverCtrl.text.isNotEmpty ? coverCtrl.text : null,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? (result['success'] ? 'Candidature soumise' : 'Erreur'))),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_posting?['title'] ?? 'Offre'),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posting == null
              ? const Center(child: Text('Offre introuvable'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_posting!['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (_posting!['department'] != null) _infoChip(Icons.business, _posting!['department']),
                                  _infoChip(Icons.description, _posting!['contract_label'] ?? ''),
                                  if (_posting!['location'] != null) _infoChip(Icons.location_on, _posting!['location']),
                                  if (_posting!['salary_range'] != null) _infoChip(Icons.payments, _posting!['salary_range']),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _section('Description', _posting!['description']),
                      if (_posting!['requirements'] != null) _section('Exigences', _posting!['requirements']),
                      if (_posting!['responsibilities'] != null) _section('Responsabilites', _posting!['responsibilities']),
                      if (_posting!['benefits'] != null) _section('Avantages', _posting!['benefits']),

                      const SizedBox(height: 16),
                      if (_posting!['is_open'] == true)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _showApplyDialog,
                            icon: const Icon(Icons.send),
                            label: const Text('Postuler', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE65100),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _section(String title, String? content) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(content, style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}
