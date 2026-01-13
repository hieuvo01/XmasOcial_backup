// File: lib/screens/ai/ai_chat_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/ai_character_model.dart';
import '../../services/character_ai_service.dart';

class AIChatScreen extends StatefulWidget {
  final AICharacter character;

  const AIChatScreen({super.key, required this.character});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final CharacterAiService _aiService = CharacterAiService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _aiService.getChatHistory(widget.character.id);
    setState(() {
      _messages.clear();
      _messages.addAll(history.reversed);
      _isLoading = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    setState(() {
      _messages.insert(0, {'role': 'user', 'content': text});
      _isLoading = true;
    });

    try {
      final responseText = await _aiService.getCharacterResponse(
        userMessage: text,
        character: widget.character,
        history: _messages.reversed.toList(),
        personality: widget.character.personality,
      );

      if (mounted) {
        setState(() {
          _messages.insert(0, {'role': 'ai', 'content': responseText});
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.insert(0, {'role': 'ai', 'content': "Lỗi kết nối rồi bro!"});
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa cuộc trò chuyện?"),
        content: const Text("Toàn bộ tin nhắn với nhân vật này sẽ bị xóa vĩnh viễn."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Xóa", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _aiService.clearChatHistory(widget.character.id);

      if (mounted) {
        setState(() {
          if (success) _messages.clear();
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Đã xóa lịch sử chat!" : "Lỗi khi xóa lịch sử"),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final otherMsgColor = isDark ? const Color(0xFF3A3A3C) : Colors.grey[200];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.character.avatarUrl),
              radius: 16,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.character.name, style: const TextStyle(fontSize: 16)),
                const Text("AI Assistant", style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _handleClearHistory();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Xóa cuộc trò chuyện", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Opacity(
                        opacity: 0.8,
                        child: Image.network(widget.character.avatarUrl, width: 100, height: 100, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.character.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    // ✨ HIỂN THỊ BIO Ở GIỮA MÀN HÌNH KHI CHƯA CHAT
                    Text(
                      widget.character.bio.isNotEmpty ? widget.character.bio : "Hãy cùng trò chuyện vui vẻ nhé!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "Bắt đầu trò chuyện ngay!",
                      style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isAi = msg['role'] == 'ai';
                return Align(
                  alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAi ? otherMsgColor : Colors.blueAccent,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomLeft: isAi ? Radius.zero : const Radius.circular(16),
                        bottomRight: !isAi ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    child: Text(
                      msg['content'] ?? '',
                      style: TextStyle(
                        color: isAi ? (isDark ? Colors.white : Colors.black) : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CupertinoActivityIndicator(),
            ),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      decoration: InputDecoration(
                        // ✨ CẬP NHẬT HINT TEXT THÀNH BIO
                        hintText: "Trò chuyện cùng ${widget.character.name}...",
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey, overflow: TextOverflow.ellipsis),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
