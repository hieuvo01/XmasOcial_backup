// File: lib/screens/admin/user_management_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import '../../models/user_model.dart'; // Tạm thời dùng Map dynamic vì User Model của bro có thể chưa update đủ field
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  final bool isReadOnly;
  const UserManagementScreen({super.key, this.isReadOnly = false});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {

  bool _isLoading = true;
  List<dynamic> _users = []; // Dùng dynamic để linh hoạt với dữ liệu JSON trả về
  final AdminService _adminService = AdminService();
  String _currentRole = 'user';

  @override
  void initState() {
    super.initState();
    _checkRole();
    _fetchUsers();
  }

  void _checkRole() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _currentRole = authService.user?.role ?? 'user';
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _adminService.getAllUsers(context);
      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 1. DIALOG CHỈNH SỬA FULL (INFO + ROLE) ---
  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameCtrl = TextEditingController(text: user['displayName']);
    final usernameCtrl = TextEditingController(text: user['username']);
    final emailCtrl = TextEditingController(text: user['email']);
    final avatarCtrl = TextEditingController(text: user['avatarUrl'] ?? '');

    String selectedRole = user['role'] ?? 'user';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Chỉnh sửa User"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Tên hiển thị")),
                    const SizedBox(height: 10),
                    TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: "Username")),
                    const SizedBox(height: 10),
                    TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
                    const SizedBox(height: 10),
                    TextField(controller: avatarCtrl, decoration: const InputDecoration(labelText: "Avatar URL")),
                    const SizedBox(height: 15),

                    // Dropdown chọn Role (Chỉ Admin mới chỉnh được Role)
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: "Vai trò", border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('User')),
                        DropdownMenuItem(value: 'moderator', child: Text('Moderator')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (val) => setStateDialog(() => selectedRole = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _adminService.updateUser(context, user['_id'], {
                        'displayName': nameCtrl.text,
                        'username': usernameCtrl.text,
                        'email': emailCtrl.text,
                        'avatarUrl': avatarCtrl.text,
                        'role': selectedRole,
                      });
                      Navigator.pop(ctx);
                      _fetchUsers();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã cập nhật"), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi cập nhật"), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text("Lưu"),
                ),
              ],
            );
          }
      ),
    );
  }

  // --- 2. XÁC NHẬN XÓA ---
  void _confirmDelete(String userId, String userName) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text("Xóa $userName?"),
        content: const Text("Hành động này không thể hoàn tác."),
        actions: [
          CupertinoDialogAction(child: const Text("Hủy"), onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Xóa vĩnh viễn"),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _adminService.deleteUser(context, userId);
                setState(() => _users.removeWhere((u) => u['_id'] == userId));
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa"), backgroundColor: Colors.green));
              } catch (e) {
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi xóa"), backgroundColor: Colors.red));
              }
            },
          ),
        ],
      ),
    );
  }

  // --- 3. KHÓA / MỞ KHÓA ---
  Future<void> _toggleBlock(String id, bool currentStatus) async {
    try {
      if (currentStatus) {
        await _adminService.unblockUser(context, id);
      } else {
        await _adminService.blockUser(context, id);
      }
      _fetchUsers(); // Load lại để update UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi thao tác")));
    }
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role) {
      case 'admin': color = Colors.red; break;
      case 'moderator': color = Colors.blue; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color, width: 0.5), borderRadius: BorderRadius.circular(4)),
      child: Text(role.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý Người dùng"), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final role = user['role'] ?? 'user';
          final isBlocked = user['isBlocked'] ?? false;

          // Logic Phân Quyền UI:
          // - Admin: Thấy mọi nút (Edit, Block, Delete).
          // - Mod: Chỉ thấy nút Block (nhưng không được block Admin).
          bool canEdit = _currentRole == 'admin';
          bool canBlock = (_currentRole == 'admin') || (_currentRole == 'moderator' && role != 'admin');
          bool canDelete = _currentRole == 'admin';

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: (user['avatarUrl'] != null && user['avatarUrl'] != '')
                    ? NetworkImage(user['avatarUrl'])
                    : null,
                child: (user['avatarUrl'] == null || user['avatarUrl'] == '') ? const Icon(Icons.person) : null,
              ),
              title: Row(
                children: [
                  Flexible(child: Text(user['displayName'] ?? 'No Name', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  _buildRoleBadge(role),
                ],
              ),
              subtitle: Text(user['email'] ?? '', style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nút Edit (Chỉ Admin)
                  if (canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditUserDialog(user),
                    ),

                  // Nút Block/Unblock (Admin & Mod)
                  if (canBlock)
                    IconButton(
                      icon: Icon(isBlocked ? Icons.lock_open : Icons.lock_outline, color: isBlocked ? Colors.green : Colors.orange),
                      onPressed: () => _toggleBlock(user['_id'], isBlocked),
                    ),

                  // Nút Delete (Chỉ Admin)
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _confirmDelete(user['_id'], user['displayName']),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
