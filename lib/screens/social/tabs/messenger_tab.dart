// File: lib/screens/social/tabs/messenger_tab.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/message_model.dart';
import '../../../models/user_model.dart';
import '../../../models/ai_character_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/character_ai_service.dart';
import '../../../services/message_service.dart';
import '../chat_screen.dart';
import '../../ai/ai_chat_screen.dart';

class MessengerTab extends StatefulWidget {
  const MessengerTab({super.key});

  @override
  State<MessengerTab> createState() => _MessengerTabState();
}

class _MessengerTabState extends State<MessengerTab> {
  late TextEditingController _searchController;
  String _searchQuery = ""; // 👇 Biến lưu từ khóa tìm kiếm

  List<AICharacter> _aiCharacters = [];
  bool _isLoadingAI = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MessageService>(context, listen: false).fetchConversations();
      _fetchAICharacters();
    });
  }

  Future<void> _fetchAICharacters() async {
    try {
      final service = CharacterAiService();
      final data = await service.fetchActiveCharacters(context);
      if (mounted) {
        setState(() {
          _aiCharacters = data;
          _isLoadingAI = false;
        });
      }
    } catch (e) {
      print("Lỗi load AI: $e");
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  UserModel _getOtherUser(Conversation conversation, String myId) {
    return conversation.participants.firstWhere(
          (u) => u.id != myId,
      orElse: () => UserModel.anonymous(),
    );
  }

  String _getLastMessagePreview(Message? message, String myId) {
    if (message == null) return "Bắt đầu trò chuyện ngay 👋";
    bool isMe = message.sender.id == myId;
    String prefix = isMe ? "Bạn: " : "";
    if (message.isRecalled) return "Tin nhắn đã được thu hồi";

    switch (message.type) {
      case 'image': return "$prefix Đã gửi một ảnh";
      case 'audio': return "$prefix Đã gửi một tin nhắn thoại";
      case 'video': return "$prefix Đã gửi một video";
      case 'sticker': return "$prefix Đã gửi một nhãn dán";
      case 'file': return "$prefix Đã gửi một tệp";
      case 'location':
      return "$prefix Đã chia sẻ một vị trí";
      case 'call':
      return "$prefix Cuộc gọi thoại/video";
      default:
      // Kiểm tra thêm nếu content chứa tọa độ nhưng type vẫn là text
        if (message.content.startsWith("LOCATION:")) {
          return "$prefix Đã chia sẻ một vị trí";
        }
        return "$prefix${message.content}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final searchBarColor = isDark ? const Color(0xFF3A3B3C) : CupertinoColors.systemGrey6;

    return CupertinoPageScaffold(
      backgroundColor: scaffoldBgColor,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Đoạn chat', style: TextStyle(color: textColor)),
            backgroundColor: scaffoldBgColor.withOpacity(0.95),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.create, color: CupertinoColors.activeBlue, size: 26),
              onPressed: () {},
            ),
          ),

          // 2. THANH TÌM KIẾM
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Tìm kiếm người dùng hoặc AI',
                style: TextStyle(color: textColor),
                placeholderStyle: TextStyle(color: Colors.grey[500]),
                backgroundColor: searchBarColor,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase(); // 👇 Cập nhật query khi gõ
                  });
                },
              ),
            ),
          ),

          CupertinoSliverRefreshControl(
            onRefresh: () async {
              await Provider.of<MessageService>(context, listen: false).fetchConversations();
              await _fetchAICharacters();
            },
          ),

          Consumer<MessageService>(
            builder: (context, messageService, child) {
              final allConversations = messageService.conversations;

              // 👇 1. Lọc danh sách AI theo tên
              final List<AICharacter> filteredAI = _aiCharacters.where((ai) {
                return ai.name.toLowerCase().contains(_searchQuery);
              }).toList();

              // 👇 2. Lọc danh sách đoạn chat thật theo tên hiển thị hoặc biệt danh
              final List<Conversation> filteredConversations = allConversations.where((conv) {
                final otherUser = _getOtherUser(conv, currentUser?.id ?? '');
                String nameToSearch = otherUser.displayName.toLowerCase();

                // Nếu có nickname thì lọc theo cả nickname
                if (conv.nicknames.containsKey(otherUser.id)) {
                  nameToSearch += " ${conv.nicknames[otherUser.id]!.toLowerCase()}";
                }

                return nameToSearch.contains(_searchQuery);
              }).toList();

              final totalCount = filteredAI.length + filteredConversations.length;

              if (messageService.isLoading && allConversations.isEmpty && _isLoadingAI) {
                return const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()));
              }

// 👇 Cập nhật đoạn này trong Consumer của MessengerTab
              if (totalCount == 0 && _searchQuery.isNotEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false, // Để căn giữa chuẩn hơn
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          size: 60,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        // Bọc trong Material để fix lỗi chữ vàng gạch chân
                        Material(
                          color: Colors.transparent,
                          child: Text(
                            'Không tìm thấy kết quả cho "$_searchQuery"',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.none, // Bỏ gạch chân dứt điểm
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }


              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    // Render AI trước
                    if (index < filteredAI.length) {
                      final ai = filteredAI[index];
                      return _buildAIItem(context, ai, scaffoldBgColor, textColor);
                    }

                    // Render Chat thật sau
                    final realIndex = index - filteredAI.length;
                    if (realIndex >= filteredConversations.length) return const SizedBox.shrink();

                    final conversation = filteredConversations[realIndex];
                    return _buildConversationItem(context, conversation, currentUser, scaffoldBgColor, textColor);
                  },
                  childCount: totalCount,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- WIDGET CON: HIỂN THỊ AI CHARACTER (Giữ nguyên) ---
  Widget _buildAIItem(BuildContext context, AICharacter ai, Color bgColor, Color? textColor) {
    return Material(
      color: bgColor,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => AIChatScreen(character: ai)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.purpleAccent.withOpacity(0.6), width: 2),
                      image: DecorationImage(image: NetworkImage(ai.avatarUrl), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
                      child: const Icon(Icons.smart_toy, color: Colors.white, size: 12),
                    ),
                  )
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ai.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: const Text("AI Model", style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(ai.bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET CON: HIỂN THỊ CHAT USER THẬT (Giữ nguyên) ---
  Widget _buildConversationItem(BuildContext context, Conversation conversation, UserModel? currentUser, Color bgColor, Color? textColor) {
    final otherUser = _getOtherUser(conversation, currentUser?.id ?? '');
    final lastMsg = conversation.lastMessage;
    final isUnread = conversation.unreadCount > 0;

    String timeString = '';
    if (conversation.updatedAt != null) {
      final now = DateTime.now();
      final localUpdateTime = conversation.updatedAt!.toLocal();
      final diff = now.difference(localUpdateTime);
      timeString = diff.inDays > 0 ? "${localUpdateTime.day}/${localUpdateTime.month}" : "${localUpdateTime.hour}:${localUpdateTime.minute.toString().padLeft(2, '0')}";
    }

    String nameToShow = otherUser.displayName;
    if (conversation.nicknames.containsKey(otherUser.id)) {
      nameToShow = conversation.nicknames[otherUser.id]!;
    }

    return Material(
      color: bgColor,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ChatScreen(conversationId: conversation.id, targetUser: otherUser)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: (otherUser.avatarUrl != null) ? NetworkImage(otherUser.avatarUrl!) : const NetworkImage('https://i.pravatar.cc/150') as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (otherUser.isOnline == true)
                    Positioned(
                      bottom: 2, right: 2,
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: bgColor, width: 3)),
                      ),
                    )
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(nameToShow, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text(timeString, style: TextStyle(color: isUnread ? CupertinoColors.activeBlue : Colors.grey, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: Text(_getLastMessagePreview(lastMsg, currentUser?.id ?? ''), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: isUnread ? textColor : Colors.grey, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal))),
                        if (isUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: CupertinoColors.activeBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
