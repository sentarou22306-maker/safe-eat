import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../theme_settings.dart';

class AllergenReportScreen extends StatefulWidget {
  final String initialJanCode;

  const AllergenReportScreen({super.key, this.initialJanCode = ''});

  @override
  State<AllergenReportScreen> createState() => _AllergenReportScreenState();
}

class _AllergenReportScreenState extends State<AllergenReportScreen> {
  late TextEditingController _janCodeController;
  final _noteController = TextEditingController();
  final Set<String> _selectedAllergens = {};
  bool _isSubmitting = false;
  bool _isLookingUp = false;
  String? _productName;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  static const String _webhookUrl =
      'https://discord.com/api/webhooks/1511754386467192842/RBNxEnt3QCD000DP2KG9xLGUDu-eI5GMMvX5308HiR7145Iw-No2PNEawTbTCb6PAbeg';

  @override
  void initState() {
    super.initState();
    _janCodeController = TextEditingController(text: widget.initialJanCode);
    if (widget.initialJanCode.isNotEmpty) {
      _lookupProductName(widget.initialJanCode);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    setState(() {
      _pickedImage = photo;
      _pickedImageBytes = bytes;
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(t('Take a photo', 'カメラで撮影')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(t('Choose from gallery', 'ギャラリーから選択')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadImage(String janCode) async {
    if (_pickedImageBytes == null) return null;
    try {
      final ext = _pickedImage?.name.split('.').last ?? 'jpg';
      final fileName =
          '${janCode}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage
          .from('product-images')
          .uploadBinary(
            fileName,
            _pickedImageBytes!,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      return Supabase.instance.client.storage
          .from('product-images')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  Future<void> _lookupProductName(String janCode) async {
    if (janCode.isEmpty) return;
    setState(() => _isLookingUp = true);
    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$janCode.json',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 1 && data['product'] != null) {
          final p = data['product'] as Map<String, dynamic>;
          final name =
              p['product_name_ja']?.toString() ??
              p['product_name']?.toString();
          if (mounted) setState(() => _productName = name);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLookingUp = false);
  }

  Future<void> _submit() async {
    final janCode = _janCodeController.text.trim();
    if (janCode.isEmpty) {
      _showSnackBar(t('Please enter a barcode.', 'バーコードを入力してください。'));
      return;
    }
    if (_selectedAllergens.isEmpty) {
      _showSnackBar(
        t('Select at least one allergen.', 'アレルゲンを1つ以上選択してください。'),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final imageUrl = await _uploadImage(janCode);

      final reportData = <String, dynamic>{
        'jan_code': janCode,
        'allergens': _selectedAllergens.toList(),
        'note': _noteController.text.trim(),
        'submitted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_approved': false,
      };
      if (imageUrl != null) reportData['image_url'] = imageUrl;

      await Supabase.instance.client
          .from('allergen_corrections')
          .upsert(reportData, onConflict: 'jan_code');

      if (!mounted) return;

      await _sendDiscordNotification(janCode, imageUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Report submitted. Thank you!', '報告を受け付けました。ありがとうございます！'),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showSnackBar(t('Error: $e', 'エラー: $e'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendDiscordNotification(
    String janCode,
    String? imageUrl,
  ) async {
    final allergenList = _selectedAllergens.join(', ');
    final note = _noteController.text.trim();
    final message = {
      "content":
          "🔔 **アレルゲン訂正報告**\n"
          "**JANコード:** `$janCode`\n"
          "${_productName != null ? '**商品名:** $_productName\n' : ''}"
          "**報告アレルゲン:** $allergenList\n"
          "${note.isNotEmpty ? '**備考:** $note\n' : ''}"
          "${imageUrl != null ? '**写真:** $imageUrl\n' : ''}"
          "\n👉 `allergen_corrections` テーブルで `is_approved: true` に変更してください。",
    };
    try {
      await http.post(
        Uri.parse(_webhookUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(message),
      );
    } catch (_) {}
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _janCodeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(t('Report Allergen Issue', 'アレルゲン情報を訂正')),
            actions: [buildGlobalSettingsButton(context)],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t(
                            'If the allergen information is incorrect or missing, please report it here. Your report will be reviewed before being published.',
                            'アレルゲン情報に誤りや不足がある場合はこちらから報告してください。審査後に反映されます。',
                          ),
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _janCodeController,
                  decoration: InputDecoration(
                    labelText: t('Barcode / JAN', 'バーコード / JANコード'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.qr_code),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () =>
                          _lookupProductName(_janCodeController.text.trim()),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (_isLookingUp)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (_productName != null && !_isLookingUp)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _productName!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                Text(
                  t(
                    'Allergens contained in this product',
                    'この商品に含まれるアレルゲン',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allergenDictionary.entries.map((entry) {
                    final jp = entry.key;
                    final en = entry.value['en']!;
                    final emoji = entry.value['emoji']!;
                    final isSelected = _selectedAllergens.contains(jp);
                    return FilterChip(
                      label: Text('$emoji $jp ($en)'),
                      selected: isSelected,
                      selectedColor: Colors.orange.shade100,
                      checkmarkColor: Colors.orange.shade800,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedAllergens.add(jp);
                          } else {
                            _selectedAllergens.remove(jp);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: t('Note (Optional)', '備考（任意）'),
                    hintText: t(
                      'e.g. Not listed on package',
                      '例：パッケージに記載なし',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 24),

                // 写真セクション
                Text(
                  t('Photo (Optional)', '写真（任意）'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_pickedImageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _pickedImageBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() {
                          _pickedImage = null;
                          _pickedImageBytes = null;
                        }),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: Text(
                      t('Remove photo', '写真を削除'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      t('Add photo of package label', '商品ラベルの写真を追加'),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(
                      'A photo helps admins verify the information.',
                      '写真があると管理者が内容を確認しやすくなります。',
                    ),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appThemeColor.value,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            t('Submit Report', '報告を送信'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
