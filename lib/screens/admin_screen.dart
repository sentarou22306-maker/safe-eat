import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_settings.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  bool _authenticated = false;
  late final TabController _tabs;
  List<Map<String, dynamic>> _pendingProducts = [];
  List<Map<String, dynamic>> _pendingCorrections = [];
  bool _loading = false;
  final _pinController = TextEditingController();
  String _pinError = '';

  String get _adminKey => dotenv.env['ADMIN_KEY'] ?? '';

  Future<Map<String, dynamic>> _callAdminFunction(Map<String, dynamic> body) async {
    final response = await Supabase.instance.client.functions.invoke(
      'admin-action',
      headers: {'x-admin-key': _adminKey},
      body: body,
    );
    if (response.status != 200) {
      final msg = (response.data as Map?)?['error'] ?? 'Unknown error';
      throw Exception(msg);
    }
    return response.data as Map<String, dynamic>;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _tryAuth() {
    if (_adminKey.isEmpty) {
      setState(() => _pinError = 'ADMIN_KEY not set in .env');
      return;
    }
    if (_pinController.text.trim() == _adminKey) {
      setState(() {
        _authenticated = true;
        _pinError = '';
      });
      _loadPending();
    } else {
      setState(() => _pinError = 'Incorrect key');
      _pinController.clear();
    }
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    try {
      final data = await _callAdminFunction({'action': 'load-pending'});
      if (mounted) {
        setState(() {
          _pendingProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
          _pendingCorrections = List<Map<String, dynamic>>.from(data['corrections'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Load error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteProduct(String janCode) async {
    final ok = await _confirmDelete(context);
    if (!ok) return;
    try {
      await _callAdminFunction({'action': 'delete', 'table': 'products', 'janCode': janCode});
      setState(() => _pendingProducts.removeWhere((p) => p['jan_code'] == janCode));
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _approveCorrection(String janCode) async {
    try {
      await _callAdminFunction({'action': 'approve', 'table': 'allergen_corrections', 'janCode': janCode});
      setState(() => _pendingCorrections.removeWhere((c) => c['jan_code'] == janCode));
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _editAndApproveProduct(Map<String, dynamic> row) async {
    final janCode = row['jan_code']?.toString() ?? '';
    final nameJpCtrl = TextEditingController(text: row['name_jp']?.toString() ?? '');
    final nameEnCtrl = TextEditingController(text: row['name_en']?.toString() ?? '');
    var selected = Set<String>.from(List<String>.from(row['allergens'] ?? []));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit & Approve'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(janCode,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'monospace')),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameJpCtrl,
                    decoration: const InputDecoration(
                      labelText: '商品名（日本語）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameEnCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product Name (EN)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Allergens',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allergenDictionary.keys.map((jp) {
                      final info = allergenDictionary[jp]!;
                      final isSel = selected.contains(jp);
                      return FilterChip(
                        label: Text('${info['emoji']} $jp',
                            style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange.shade700,
                        side: isSel
                            ? BorderSide(color: Colors.orange.shade400)
                            : BorderSide(color: Colors.grey.shade300),
                        onSelected: (val) => setDialogState(() =>
                            val ? selected.add(jp) : selected.remove(jp)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save & Approve'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );

    final nameJp = nameJpCtrl.text.trim();
    final nameEn = nameEnCtrl.text.trim();
    nameJpCtrl.dispose();
    nameEnCtrl.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await _callAdminFunction({
        'action': 'approve',
        'table': 'products',
        'janCode': janCode,
        'updates': {
          'name_jp': nameJp,
          'name_en': nameEn,
          'allergens': selected.toList(),
        },
      });
      setState(() => _pendingProducts.removeWhere((p) => p['jan_code'] == janCode));
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _deleteCorrection(String janCode) async {
    final ok = await _confirmDelete(context);
    if (!ok) return;
    try {
      await _callAdminFunction({'action': 'delete', 'table': 'allergen_corrections', 'janCode': janCode});
      setState(() => _pendingCorrections.removeWhere((c) => c['jan_code'] == janCode));
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<bool> _confirmDelete(BuildContext ctx) async {
    return await showDialog<bool>(
          context: ctx,
          builder: (d) => AlertDialog(
            title: const Text('Delete?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(d, true),
                  child:
                      const Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings,
                color: appThemeColor.value, size: 20),
            const SizedBox(width: 8),
            const Text('Admin'),
          ],
        ),
        actions: [
          if (_authenticated)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload',
              onPressed: _loadPending,
            ),
        ],
        bottom: _authenticated
            ? TabBar(
                controller: _tabs,
                tabs: [
                  Tab(
                    child: Text(
                        'Products (${_pendingProducts.length})',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  Tab(
                    child: Text(
                        'Corrections (${_pendingCorrections.length})',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              )
            : null,
      ),
      body: _authenticated ? _buildContent() : _buildPinForm(),
    );
  }

  Widget _buildPinForm() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              const Text('Admin Access',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Access Key (ADMIN_KEY)',
                  border: const OutlineInputBorder(),
                  errorText: _pinError.isEmpty ? null : _pinError,
                ),
                onSubmitted: (_) => _tryAuth(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _tryAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appThemeColor.value,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Enter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return TabBarView(
      controller: _tabs,
      children: [
        _buildList(
          items: _pendingProducts,
          emptyLabel: 'No pending products',
          itemBuilder: _buildProductCard,
        ),
        _buildList(
          items: _pendingCorrections,
          emptyLabel: 'No pending corrections',
          itemBuilder: _buildCorrectionCard,
        ),
      ],
    );
  }

  Widget _buildList({
    required List<Map<String, dynamic>> items,
    required String emptyLabel,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: Colors.green.shade300),
            const SizedBox(height: 12),
            Text(emptyLabel,
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) => itemBuilder(items[i]),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> row) {
    final janCode = row['jan_code']?.toString() ?? '';
    final nameJp = row['name_jp']?.toString() ?? '';
    final nameEn = row['name_en']?.toString() ?? '';
    final imageUrl = row['image_url']?.toString() ?? '';
    final allergens = List<String>.from(row['allergens'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl,
                        width: 64, height: 64, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_not_supported, size: 40, color: Colors.grey)),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(janCode,
                              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blue.shade700)),
                        ),
                        const SizedBox(width: 6),
                        Text('OFA auto-save', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ]),
                      if (nameJp.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(nameJp, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                      if (nameEn.isNotEmpty)
                        Text(nameEn, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // アレルゲン（なしの場合も明示）
            if (allergens.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: allergens.map((a) {
                  final info = allergenDictionary[a];
                  final emoji = info?['emoji'] ?? '⚠';
                  return Chip(
                    label: Text('$emoji $a', style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.orange.shade50,
                    side: BorderSide(color: Colors.orange.shade200),
                  );
                }).toList(),
              )
            else
              Row(children: [
                Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade400),
                const SizedBox(width: 4),
                Text('No allergens detected', style: TextStyle(fontSize: 12, color: Colors.green.shade600)),
              ]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteProduct(janCode),
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _editAndApproveProduct(row),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit & Approve'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectionCard(Map<String, dynamic> row) {
    final janCode = row['jan_code']?.toString() ?? '';
    final allergens = List<String>.from(row['allergens'] ?? []);
    final note = row['note']?.toString() ?? '';
    final imageUrl = row['image_url']?.toString() ?? '';
    final submittedAt = row['submitted_at']?.toString() ?? '';
    final dateStr = submittedAt.length >= 10 ? submittedAt.substring(0, 10) : submittedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    janCode,
                    style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.teal.shade700),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OCR contribution · $dateStr',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
            if (allergens.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: allergens.map((a) {
                  final info = allergenDictionary[a];
                  final emoji = info?['emoji'] ?? '⚠';
                  return Chip(
                    label: Text('$emoji $a',
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.orange.shade50,
                    side: BorderSide(color: Colors.orange.shade200),
                  );
                }).toList(),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('No allergens detected',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic)),
              ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  note,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteCorrection(janCode),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveCorrection(janCode),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
