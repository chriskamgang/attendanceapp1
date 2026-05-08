import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class EvaluationsScreen extends StatefulWidget {
  const EvaluationsScreen({super.key});

  @override
  State<EvaluationsScreen> createState() => _EvaluationsScreenState();
}

class _EvaluationsScreenState extends State<EvaluationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _evaluations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvaluations();
  }

  Future<void> _loadEvaluations() async {
    final result = await _apiService.getEvaluations();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) _evaluations = result['evaluations'];
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'self_evaluated':
        return Colors.blue;
      case 'evaluated':
        return Colors.purple;
      case 'validated':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'self_evaluated':
        return 'Auto-evalue';
      case 'evaluated':
        return 'Evalue';
      case 'validated':
        return 'Valide';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Evaluations'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _evaluations.isEmpty
              ? const Center(child: Text('Aucune evaluation'))
              : RefreshIndicator(
                  onRefresh: _loadEvaluations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _evaluations.length,
                    itemBuilder: (context, index) {
                      final eval = _evaluations[index];
                      return _buildEvalCard(eval);
                    },
                  ),
                ),
    );
  }

  Widget _buildEvalCard(Map<String, dynamic> eval) {
    final campaign = eval['campaign'] ?? {};
    final status = eval['status'] ?? 'pending';
    final score = eval['overall_score'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openDetail(eval['id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign['title'] ?? 'Campagne',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Annee ${campaign['year'] ?? ''}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(width: 16),
                  if (eval['evaluator'] != null) ...[
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(eval['evaluator'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ],
              ),
              if (score != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${(score is num ? score.toStringAsFixed(1) : score)}/5',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (score is num ? score / 5 : 0).toDouble(),
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            score > 3.5 ? Colors.green : score > 2.5 ? Colors.orange : Colors.red,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (status == 'pending') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openDetail(eval['id']),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Faire mon auto-evaluation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EvaluationDetailScreen(evaluationId: id)),
    ).then((_) => _loadEvaluations());
  }
}

// ===== EVALUATION DETAIL SCREEN =====

class EvaluationDetailScreen extends StatefulWidget {
  final int evaluationId;
  const EvaluationDetailScreen({super.key, required this.evaluationId});

  @override
  State<EvaluationDetailScreen> createState() => _EvaluationDetailScreenState();
}

class _EvaluationDetailScreenState extends State<EvaluationDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _evaluation;
  List<dynamic> _criteria = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  final Map<int, int> _selfScores = {};
  final TextEditingController _commentsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final result = await _apiService.getEvaluationDetail(widget.evaluationId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _evaluation = result['evaluation'];
          _criteria = result['criteria'];
          for (var c in _criteria) {
            if (c['employee_score'] != null) {
              _selfScores[c['id']] = c['employee_score'];
            }
          }
        }
      });
    }
  }

  Future<void> _submitSelfEvaluation() async {
    if (_selfScores.length < _criteria.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez noter tous les criteres')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final scores = _selfScores.entries
        .map((e) => {'criteria_id': e.key, 'score': e.value})
        .toList();

    final result = await _apiService.submitSelfEvaluation(
      widget.evaluationId,
      scores: scores,
      comments: _commentsController.text.isNotEmpty ? _commentsController.text : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? (result['success'] ? 'Soumis' : 'Erreur'))),
      );
      if (result['success']) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _evaluation?['status'] == 'pending';

    return Scaffold(
      appBar: AppBar(
        title: Text(_evaluation?['campaign']?['title'] ?? 'Evaluation'),
        backgroundColor: const Color(0xFF1A237E),
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
                        children: [
                          _infoRow('Campagne', _evaluation?['campaign']?['title'] ?? ''),
                          _infoRow('Annee', '${_evaluation?['campaign']?['year'] ?? ''}'),
                          _infoRow('Evaluateur', _evaluation?['evaluator'] ?? 'Non assigne'),
                          if (_evaluation?['overall_score'] != null)
                            _infoRow('Note globale', '${_evaluation!['overall_score']}/5'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Criteria
                  const Text('Criteres d\'evaluation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  ..._criteria.map((c) => _buildCriteriaCard(c, isPending)),

                  if (isPending) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _commentsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Commentaires (optionnel)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitSelfEvaluation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Soumettre mon auto-evaluation', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],

                  // Comments sections
                  if (_evaluation?['employee_comments'] != null) ...[
                    const SizedBox(height: 16),
                    _buildCommentSection('Vos commentaires', _evaluation!['employee_comments']),
                  ],
                  if (_evaluation?['evaluator_comments'] != null) ...[
                    const SizedBox(height: 12),
                    _buildCommentSection('Commentaires evaluateur', _evaluation!['evaluator_comments']),
                  ],
                  if (_evaluation?['objectives_next_year'] != null) ...[
                    const SizedBox(height: 12),
                    _buildCommentSection('Objectifs prochaine annee', _evaluation!['objectives_next_year']),
                  ],
                  if (_evaluation?['training_needs'] != null) ...[
                    const SizedBox(height: 12),
                    _buildCommentSection('Besoins en formation', _evaluation!['training_needs']),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCriteriaCard(Map<String, dynamic> criteria, bool editable) {
    final maxScore = criteria['max_score'] ?? 5;
    final weight = criteria['weight'] ?? 1;
    final selfScore = _selfScores[criteria['id']];
    final evalScore = criteria['evaluator_score'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(criteria['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                  child: Text('Poids: $weight', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                ),
              ],
            ),
            if (criteria['description'] != null && criteria['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(criteria['description'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
            const SizedBox(height: 10),
            if (editable)
              Row(
                children: [
                  const Text('Ma note: ', style: TextStyle(fontSize: 13)),
                  ...List.generate(maxScore, (i) {
                    final score = i + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _selfScores[criteria['id']] = score),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          selfScore != null && score <= selfScore ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                  if (selfScore != null) Text(' $selfScore/$maxScore', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            else ...[
              if (selfScore != null)
                _scoreRow('Auto-evaluation', selfScore, maxScore, Colors.blue),
              if (evalScore != null)
                _scoreRow('Note evaluateur', evalScore, maxScore, Colors.purple),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scoreRow(String label, dynamic score, int max, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ...List.generate(max, (i) => Icon(
            i < (score as num).toInt() ? Icons.star : Icons.star_border,
            color: color,
            size: 18,
          )),
          Text(' $score/$max', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCommentSection(String title, String content) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text(content, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
