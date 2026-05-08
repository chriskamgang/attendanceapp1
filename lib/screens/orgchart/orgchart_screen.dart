import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class OrgChartScreen extends StatefulWidget {
  const OrgChartScreen({super.key});

  @override
  State<OrgChartScreen> createState() => _OrgChartScreenState();
}

class _OrgChartScreenState extends State<OrgChartScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  List<dynamic> _departments = [];
  Map<String, dynamic>? _hierarchy;
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
    final results = await Future.wait([
      _apiService.getOrgChartDepartments(),
      _apiService.getMyHierarchy(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results[0]['success']) _departments = results[0]['departments'];
        if (results[1]['success']) _hierarchy = results[1] as Map<String, dynamic>;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organigramme'),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Departements', icon: Icon(Icons.business, size: 18)),
            Tab(text: 'Ma hierarchie', icon: Icon(Icons.account_tree, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDepartmentsTab(),
                _buildHierarchyTab(),
              ],
            ),
    );
  }

  Widget _buildDepartmentsTab() {
    if (_departments.isEmpty) {
      return const Center(child: Text('Aucun departement'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _departments.length,
        itemBuilder: (context, index) {
          final dept = _departments[index];
          return _buildDepartmentCard(dept);
        },
      ),
    );
  }

  Widget _buildDepartmentCard(Map<String, dynamic> dept) {
    final head = dept['head'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openDepartmentMembers(dept['id'], dept['name']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A148C).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business, color: Color(0xFF4A148C)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dept['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (dept['code'] != null) Text(dept['code'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 4),
                    if (head != null)
                      Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: Color(0xFF4A148C)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${head['full_name']}${head['position'] != null ? ' - ${head['position']}' : ''}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${dept['employee_count'] ?? 0}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[700], fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHierarchyTab() {
    if (_hierarchy == null) {
      return const Center(child: Text('Impossible de charger votre hierarchie'));
    }

    final me = _hierarchy!['me'];
    final manager = _hierarchy!['manager'];
    final subordinates = _hierarchy!['subordinates'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Manager
            if (manager != null) ...[
              const Text('Mon responsable', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              _buildPersonCard(manager, Colors.orange),
              const SizedBox(height: 4),
              const Icon(Icons.arrow_downward, color: Colors.grey, size: 28),
              const SizedBox(height: 4),
            ],

            // Me
            const Text('Moi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildPersonCard({
              'full_name': me?['full_name'] ?? '',
              'position': me?['position'],
              'photo': me?['photo'],
            }, const Color(0xFF4A148C), isMe: true),

            if (subordinates.isNotEmpty) ...[
              const SizedBox(height: 4),
              const Icon(Icons.arrow_downward, color: Colors.grey, size: 28),
              const SizedBox(height: 4),
              Text('Mes subordonnes (${subordinates.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              ...subordinates.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPersonCard(s, Colors.teal),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPersonCard(Map<String, dynamic> person, Color color, {bool isMe = false}) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMe ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      elevation: isMe ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withAlpha(30),
              child: Icon(Icons.person, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person['full_name'] ?? '',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isMe ? color : null),
                  ),
                  if (person['position'] != null)
                    Text(person['position'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDepartmentMembers(int departmentId, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DepartmentMembersScreen(departmentId: departmentId, departmentName: name)),
    );
  }
}

// ===== DEPARTMENT MEMBERS SCREEN =====

class DepartmentMembersScreen extends StatefulWidget {
  final int departmentId;
  final String departmentName;
  const DepartmentMembersScreen({super.key, required this.departmentId, required this.departmentName});

  @override
  State<DepartmentMembersScreen> createState() => _DepartmentMembersScreenState();
}

class _DepartmentMembersScreenState extends State<DepartmentMembersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final result = await _apiService.getDepartmentMembers(widget.departmentId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) _members = result['members'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.departmentName),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? const Center(child: Text('Aucun membre'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final m = _members[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF4A148C).withAlpha(20),
                          child: const Icon(Icons.person, color: Color(0xFF4A148C)),
                        ),
                        title: Text(m['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          [m['position'], m['employee_type']].where((e) => e != null).join(' - '),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        trailing: m['manager'] != null
                            ? Tooltip(
                                message: 'Manager: ${m['manager']}',
                                child: Icon(Icons.supervisor_account, color: Colors.grey[400], size: 20),
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
