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
    final key = dotenv.env['ADMIN_KEY'] ?? '';
    if (key.isEmpty) {
      setState(() => _pinError = 'ADMIN_KEY not set in .env');
      return;
    }
    if (_pinController.text.trim() == key) {
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
      final products = await Supabase.instance.client
          .from('products')
          .select()
          .eq('is_approved', false)
          .order('jan_code');
      final corrections = await Supabase.instance.client
          .from('allergen_corrections')
          .select()
          .eq('is_approved', false)
          .order('submitted_at', ascending: false);
      if (mounted) {
        setState(() {
          _pendingProducts = List<Map<String, dynamic>>.from(products);
          _pendingCorrections = List<Map<String, dynamic>>.from(corrections);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Load error: $e\n(Check Supabase RLS policies)'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveProduct(String janCode) async {
    try {
      await Supabase.instance.client
          .from('products')
          .update({'is_approved': true}).eq('jan_code', janCode);
      setState(() =>
          _pendingProducts.removeWhere((p) => p['jan_code'] == janCode));
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _deleteProduct(String janCode) async {
    final ok = await _confirmDelete(context);
    if (!ok) return;
    try {
      await Supabase.instance.client
          .from('products')
          .delete()
          .eq('jan_code', janCode)
          .eq('is_approved', false);
      setState(() =>
          _pendingProducts.removeWhere((p) => p['jan_code'] == janCode));
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _approveCorrection(String janCode) async {
    try {
      await Supabase.instance.client
          .from('allergen_corrections')
          .update({
            'is_approved': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('jan_code', janCode);
      setState(() =>
          _pendingCorrections.removeWhere((c) => c['jan_code'] == janCode));
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _deleteCorrection(String janCode) async {
    final ok = await _confirmDelete(context);
    if (!ok) return;
    try {
      await Supabase.instance.client
          .from('allergen_corrections')
          .delete()
          .eq('jan_code', janCode);
      setState(() =>
          _pendingCorrections.removeWhere((c) => c['jan_code'] == janCode));
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
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    janCode,
                    style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.blue.shade700),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('OFA auto-save',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              ],
            ),
            if (nameJp.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(nameJp,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
            if (nameEn.isNotEmpty)
              Text(nameEn,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
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
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteProduct(janCode),
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
                    onPressed: () => _approveProduct(janCode),
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

  Widget _buildCorrectionCard(Map<String, dynamic> row) {
    final janCode = row['jan_code']?.toString() ?? '';
    final allergens = List<String>.from(row['allergens'] ?? []);
    final note = row['note']?.toString() ?? '';
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
