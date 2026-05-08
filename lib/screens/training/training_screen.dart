import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  List<dynamic> _programs = [];
  List<dynamic> _enrollments = [];
  List<dynamic> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _apiService.getTrainingCatalog(category: _selectedCategory),
      _apiService.getMyTrainingEnrollments(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results[0]['success']) {
          _programs = results[0]['programs'];
          _categories = results[0]['categories'] ?? [];
        }
        if (results[1]['success']) _enrollments = results[1]['enrollments'];
      });
    }
  }

  Color _levelColor(String? level) {
    switch (level) {
      case 'beginner': return Colors.green;
      case 'intermediate': return Colors.orange;
      case 'advanced': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formations'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Catalogue', icon: Icon(Icons.menu_book, size: 18)),
            Tab(text: 'Mes formations', icon: Icon(Icons.school, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCatalogTab(),
                _buildMyEnrollmentsTab(),
              ],
            ),
    );
  }

  Widget _buildCatalogTab() {
    return Column(
      children: [
        // Category filter
        if (_categories.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _filterChip('Tout', _selectedCategory == null, () {
                  setState(() => _selectedCategory = null);
                  _loadData();
                }),
                ..._categories.map((c) => _filterChip(c.toString(), _selectedCategory == c.toString(), () {
                  setState(() => _selectedCategory = c.toString());
                  _loadData();
                })),
              ],
            ),
          ),
        Expanded(
          child: _programs.isEmpty
              ? const Center(child: Text('Aucune formation disponible'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _programs.length,
                    itemBuilder: (context, index) => _buildProgramCard(_programs[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF0D47A1),
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    final enrollment = program['my_enrollment'];
    final isEnrolled = enrollment != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openProgramDetail(program['id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      program['type'] == 'online' ? Icons.computer : program['type'] == 'presential' ? Icons.groups : Icons.sync,
                      color: const Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(program['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Row(
                          children: [
                            Text(program['type_label'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            if (program['duration_hours'] != null) ...[
                              const SizedBox(width: 8),
                              Text('${program['duration_hours']}h', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _levelColor(program['level']).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      program['level_label'] ?? '',
                      style: TextStyle(fontSize: 11, color: _levelColor(program['level']), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (program['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  program['description'],
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (program['category'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                      child: Text(program['category'], style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    ),
                  if (program['is_mandatory'] == true) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
                      child: Text('Obligatoire', style: TextStyle(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const Spacer(),
                  if (isEnrolled)
                    Row(
                      children: [
                        Text('${enrollment['progress']}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 50,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (enrollment['progress'] ?? 0) / 100,
                              backgroundColor: Colors.grey[200],
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  Text(
                    '${program['enrolled_count'] ?? 0} inscrits',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyEnrollmentsTab() {
    if (_enrollments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucune inscription', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _enrollments.length,
        itemBuilder: (context, index) {
          final e = _enrollments[index];
          final program = e['program'] ?? {};
          final status = e['status'] ?? 'enrolled';

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () => _openProgramDetail(program['id']),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(program['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        _statusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${program['type_label'] ?? ''} - ${program['category'] ?? ''}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (e['progress'] ?? 0) / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                status == 'completed' ? Colors.green : const Color(0xFF0D47A1),
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${e['progress'] ?? 0}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (e['score'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Note: ${e['score']}/100', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed': color = Colors.green; label = 'Termine'; break;
      case 'in_progress': color = Colors.blue; label = 'En cours'; break;
      case 'cancelled': color = Colors.red; label = 'Annule'; break;
      case 'failed': color = Colors.red; label = 'Echoue'; break;
      default: color = Colors.orange; label = 'Inscrit'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  void _openProgramDetail(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrainingDetailScreen(programId: id)),
    ).then((_) => _loadData());
  }
}

// ===== TRAINING DETAIL SCREEN =====

class TrainingDetailScreen extends StatefulWidget {
  final int programId;
  const TrainingDetailScreen({super.key, required this.programId});

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _program;
  Map<String, dynamic>? _enrollment;
  List<dynamic> _materials = [];
  List<dynamic> _sessions = [];
  bool _isLoading = true;
  bool _isEnrolling = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final result = await _apiService.getTrainingProgramDetail(widget.programId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _program = result['program'];
          _enrollment = result['enrollment'];
          _materials = result['materials'];
          _sessions = result['sessions'];
        }
      });
    }
  }

  Future<void> _enroll() async {
    setState(() => _isEnrolling = true);
    final result = await _apiService.enrollInTraining(widget.programId);
    if (mounted) {
      setState(() => _isEnrolling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? (result['success'] ? 'Inscrit' : 'Erreur'))),
      );
      if (result['success']) _loadDetail();
    }
  }

  Future<void> _completeMaterial(int materialId) async {
    final result = await _apiService.completeTrainingMaterial(widget.programId, materialId);
    if (mounted) {
      if (result['success']) {
        _loadDetail();
        if (result['program_completed'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Formation terminee ! Felicitations !'), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_program?['title'] ?? 'Formation'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_program?['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_program?['description'] != null)
                            Text(_program!['description'], style: TextStyle(color: Colors.grey[600], height: 1.5)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8, runSpacing: 4,
                            children: [
                              Chip(label: Text(_program?['type_label'] ?? '', style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact),
                              Chip(label: Text(_program?['level_label'] ?? '', style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact),
                              if (_program?['duration_hours'] != null)
                                Chip(label: Text('${_program!['duration_hours']}h', style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact),
                              if (_program?['category'] != null)
                                Chip(label: Text(_program!['category'], style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Enrollment / progress
                  if (_enrollment != null) ...[
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: const Color(0xFF0D47A1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text('Progression', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const Spacer(),
                            Text('${_enrollment!['progress'] ?? 0}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 100,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (_enrollment!['progress'] ?? 0) / 100,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  minHeight: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isEnrolling ? null : _enroll,
                        icon: _isEnrolling
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add),
                        label: const Text("S'inscrire", style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Materials
                  if (_materials.isNotEmpty) ...[
                    const Text('Contenus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._materials.map((m) => _buildMaterialCard(m)),
                  ],

                  // Sessions
                  if (_sessions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._sessions.map((s) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: const Icon(Icons.event, color: Color(0xFF0D47A1)),
                        title: Text(s['start_date'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text([s['location'], s['trainer_name']].where((e) => e != null).join(' - '), style: const TextStyle(fontSize: 12)),
                      ),
                    )),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> material) {
    final isCompleted = material['is_completed'] == true;
    final canComplete = _enrollment != null && !isCompleted;

    IconData typeIcon;
    switch (material['type']) {
      case 'video': typeIcon = Icons.play_circle; break;
      case 'pdf': typeIcon = Icons.picture_as_pdf; break;
      case 'quiz': typeIcon = Icons.quiz; break;
      case 'link': typeIcon = Icons.link; break;
      default: typeIcon = Icons.article; break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(
          isCompleted ? Icons.check_circle : typeIcon,
          color: isCompleted ? Colors.green : const Color(0xFF0D47A1),
        ),
        title: Text(
          material['title'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            if (material['duration_minutes'] != null)
              Text('${material['duration_minutes']} min', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            if (material['is_required'] == true) ...[
              const SizedBox(width: 6),
              Text('Requis', style: TextStyle(color: Colors.red[400], fontSize: 11)),
            ],
          ],
        ),
        trailing: canComplete
            ? IconButton(
                icon: const Icon(Icons.check, color: Color(0xFF0D47A1)),
                onPressed: () => _completeMaterial(material['id']),
              )
            : null,
      ),
    );
  }
}
