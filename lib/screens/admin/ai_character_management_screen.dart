// File: lib/screens/admin/ai_character_management_screen.dart

import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AICharacterManagementScreen extends StatefulWidget {
  const AICharacterManagementScreen({super.key});

  @override
  State<AICharacterManagementScreen> createState() => _AICharacterManagementScreenState();
}

class _AICharacterManagementScreenState extends State<AICharacterManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _characters = [];
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _adminService.getAllAICharacters(context);
      if (mounted) {
        setState(() {
          _characters = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await _adminService.deleteAICharacter(context, id);
      setState(() => _characters.removeWhere((item) => item['_id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi xóa"), backgroundColor: Colors.red));
    }
  }

  // Hiện Dialog Thêm/Sửa
  void _showEditor({Map<String, dynamic>? item}) {
    final isEditing = item != null;
    final nameCtrl = TextEditingController(text: item?['name'] ?? '');
    final bioCtrl = TextEditingController(text: item?['bio'] ?? '');
    final promptCtrl = TextEditingController(text: item?['systemPrompt'] ?? '');
    final avatarCtrl = TextEditingController(text: item?['avatarUrl'] ?? '');

    String selectedPersonality = item?['personality'] ?? 'normal';
    bool isEnabled = item?['isEnabled'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEditing ? "Sửa Nhân vật" : "Thêm Nhân vật AI"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Tên nhân vật")),
                    TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: "Mô tả ngắn (Bio)")),
                    TextField(controller: avatarCtrl, decoration: const InputDecoration(labelText: "Link Avatar URL")),
                    const SizedBox(height: 10),
                    TextField(
                      controller: promptCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "System Prompt (Quan trọng)",
                        hintText: "Ví dụ: Bạn là đại ca giang hồ...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedPersonality,
                      decoration: const InputDecoration(labelText: "Tính cách (Icon/Màu)"),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Bình thường (Normal)')),
                        DropdownMenuItem(value: 'gangster', child: Text('Giang hồ (Gangster)')),
                        DropdownMenuItem(value: 'cute', child: Text('Dễ thương (Cute)')),
                        DropdownMenuItem(value: 'cold', child: Text('Lạnh lùng (Cold)')),
                        DropdownMenuItem(value: 'funny', child: Text('Hài hước (Funny)')),
                      ],
                      onChanged: (val) => setStateDialog(() => selectedPersonality = val!),
                    ),
                    SwitchListTile(
                      title: const Text("Kích hoạt"),
                      value: isEnabled,
                      onChanged: (val) => setStateDialog(() => isEnabled = val),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(child: const Text("Hủy"), onPressed: () => Navigator.pop(ctx)),
                ElevatedButton(
                  child: const Text("Lưu"),
                  onPressed: () async {
                    final data = {
                      'name': nameCtrl.text,
                      'bio': bioCtrl.text,
                      'avatarUrl': avatarCtrl.text,
                      'systemPrompt': promptCtrl.text,
                      'personality': selectedPersonality,
                      'isEnabled': isEnabled
                    };

                    try {
                      Navigator.pop(ctx); // Đóng dialog trước
                      if (isEditing) {
                        await _adminService.updateAICharacter(context, item!['_id'], data);
                      } else {
                        await _adminService.createAICharacter(context, data);
                      }
                      _fetchData(); // Load lại list
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thành công"), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi lưu dữ liệu"), backgroundColor: Colors.red));
                    }
                  },
                ),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý AI Characters"), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _characters.isEmpty
          ? const Center(child: Text("Chưa có nhân vật nào"))
          : ListView.builder(
        itemCount: _characters.length,
        padding: const EdgeInsets.all(10),
        itemBuilder: (ctx, index) {
          final item = _characters[index];
          return Card(
            color: (item['isEnabled'] == false) ? Colors.grey.shade200 : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: (item['avatarUrl'] != null && item['avatarUrl'] != '')
                    ? NetworkImage(item['avatarUrl'])
                    : null,
                child: (item['avatarUrl'] == null || item['avatarUrl'] == '')
                    ? const Icon(Icons.person) : null,
              ),
              title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${item['bio']}\nPrompt: ${item['systemPrompt'] ?? '...'}", maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditor(item: item)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteItem(item['_id'])),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
