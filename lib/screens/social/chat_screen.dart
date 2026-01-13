// File: lib/screens/social/chat_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../models/chat_theme.dart';
import '../../services/auth_service.dart';
import '../../services/call_service.dart';
import '../../services/message_service.dart';
import '../../utils/sticker_list.dart';
import '../games/chess_screen.dart';
import '../games/snake_screen.dart';
import '../games/tic_tac_toe_screen.dart';
import '../map_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final UserModel targetUser;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.targetUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode();
  Map<String, String> _nicknames = {};
  int _selectedStickerPackIndex = 0;
  // --- BIẾN ĐIỀU KHIỂN UI ---
  bool _showSticker = false; // Biến bật tắt bảng Sticker
  bool _isComposing = false;
  bool _showEmoji = false;
  Message? _replyMessage;
  // --- BIẾN CHO USER TARGET (ĐỂ CẬP NHẬT TRẠNG THÁI ONLINE) ---
  late UserModel _targetUser;
  String _quickReaction = "👍";
  Timer? _refreshTimer;
// --- HÀM HELPER: LẤY TÊN HIỂN THỊ ---
  String _getDisplayName(UserModel user) {
    if (_nicknames.containsKey(user.id)) {
      return _nicknames[user.id]!;
    }
    return user.displayName;
  }
  // --- BIẾN CHO VOICE CHAT ---
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  String _recordDurationText = "00:00";
  Timer? _recordTimer;
  int _recordSeconds = 0;

  // --- BIẾN THEME ---
  static final Map<String, String> _savedThemes = {};
  ChatTheme _currentTheme = appThemes[0];
  Color get _themeColor => _currentTheme.primaryColor;


  @override
  void initState() {
    super.initState();

    // 1. Khởi tạo biến cơ bản
    _targetUser = widget.targetUser;
    _currentTheme = appThemes[0];

    // 2. Setup Ghi âm
    _initRecorder();

    // 3. Setup Timer tự động cập nhật trạng thái User (Backup cho Socket)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchTargetUserLatestInfo();
      }
    });

    // 4. LOGIC SETUP DỮ LIỆU & SOCKET (Chạy sau khi build xong frame đầu tiên)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final messageService = Provider.of<MessageService>(context, listen: false);

      // --- A. LẤY DỮ LIỆU MỚI NHẤT TỪ SERVER ---
      try {
        // Fetch dữ liệu hội thoại để lấy Theme, Nickname, QuickReaction mới nhất
        await messageService.fetchConversations();

        final currentConv = messageService.conversations.firstWhere(
                (c) => c.id == widget.conversationId,
            orElse: () => Conversation(id: '', participants: [], updatedAt: DateTime.now(), themeId: null)
        );

        if (currentConv.id.isNotEmpty && mounted) {
          setState(() {
            // Cập nhật Theme
            if (currentConv.themeId != null) {
              final savedTheme = appThemes.firstWhere(
                      (t) => t.id == currentConv.themeId,
                  orElse: () => appThemes[0]
              );
              _currentTheme = savedTheme;
              _savedThemes[widget.conversationId] = savedTheme.id;
            }

            // Cập nhật Quick Reaction
            if (currentConv.quickReaction != null && currentConv.quickReaction!.isNotEmpty) {
              _quickReaction = currentConv.quickReaction!;
            }

            // Cập nhật Nicknames
            if (currentConv.nicknames.isNotEmpty) {
              _nicknames = Map<String, String>.from(currentConv.nicknames);
            }
          });
        }
      } catch (e) {
        print("❌ Lỗi load data ban đầu: $e");
      }

      // --- B. TẢI TIN NHẮN & BÁO ĐÃ XEM ---
      await messageService.fetchMessages(widget.conversationId);
      if (mounted) {
        messageService.markAsRead(widget.conversationId);
      }

      // --- C. LẤY THÔNG TIN USER MỚI NHẤT (CẬP NHẬT LAST ACTIVE NGAY LẬP TỨC) ---
      _fetchTargetUserLatestInfo();

      // --- D. LẮNG NGHE SOCKET ---

      // 1. Trạng thái Online/Offline
      messageService.socket?.on('user_status', (data) {
        if (data['userId'] == widget.targetUser.id && mounted) {
          setState(() {
            bool newStatus = data['isOnline'] ?? false;
            _targetUser = _targetUser.copyWith(
              isOnline: newStatus,
              lastActive: newStatus
                  ? DateTime.now()
                  : (data['lastActive'] != null ? DateTime.tryParse(data['lastActive']) : DateTime.now()),
            );
          });
        }
      });

      // 2. Đổi Theme
      messageService.socket?.on('theme_changed', (data) {
        if (data['conversationId'] == widget.conversationId) {
          String newThemeId = data['themeId'];
          final newTheme = appThemes.firstWhere((t) => t.id == newThemeId, orElse: () => appThemes[0]);
          if (mounted) {
            setState(() {
              _currentTheme = newTheme;
              _savedThemes[widget.conversationId] = newTheme.id;
            });
          }
        }
      });

      // 3. Tin nhắn mới (Gộp chung logic đánh dấu đã đọc)
      messageService.socket?.on('new_message', (data) {
        if (data['conversationId'] == widget.conversationId) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              messageService.markAsRead(widget.conversationId);
            }
          });
        }
      });

      // Lắng nghe cuộc gọi đến
      messageService.socket?.on('call_invite', (data) {
        if (mounted) {
          print("🔔 Nhận lời mời gọi từ: ${data['fromName']}"); // Thêm dòng này để debug

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text("Cuộc gọi đến từ ${data['fromName']}"),
              content: Text(data['isVideo'] ? "Cuộc gọi video..." : "Cuộc gọi thoại..."),
              actions: [
                // Nút Từ chối
                TextButton(
                  onPressed: () {
                    messageService.socket?.emit('call_rejected', {'to': data['fromId']});
                    Navigator.pop(context);
                  },
                  child: const Text("Từ chối", style: TextStyle(color: Colors.red)),
                ),
                // Nút Trả lời
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Đóng dialog
                    // Emit lệnh accepted
                    messageService.socket?.emit('call_accepted', {
                      'to': data['fromId'],
                      'isVideo': data['isVideo']
                    });
                    // Vào phòng gọi
                    _joinCall(data);
                  },
                  child: const Text("Trả lời"),
                ),
              ],
            ),
          );
        }
      });


      // Lắng nghe xem đối phương có từ chối cuộc gọi không
      messageService.socket?.on('call_rejected', (data) {
        if (mounted) {
          // Đóng màn hình Zego của máy mình
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cuộc gọi đã bị từ chối")),
          );
        }
      });

      messageService.socket?.on('call_accepted', (data) {
        if (mounted) {
          // Lấy lại currentUser để fix lỗi Undefined
          final authService = Provider.of<AuthService>(context, listen: false);
          final currentUser = authService.user;

          if (currentUser == null) return;

          // 1. Tắt cái Dialog "Đang gọi..." của người gọi
          Navigator.of(context, rootNavigator: true).pop();

          // 2. GIỜ MỚI NHẢY VÀO PHÒNG GỌI THỰC SỰ
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallService.makeCallPage(
                callID: widget.conversationId,
                userID: currentUser.id,
                userName: currentUser.displayName ?? "User",
                isVideo: data['isVideo'],
                messageService: messageService,
                targetUserId: _targetUser.id,
              ),
            ),
          );
        }
      });

// Lắng nghe khi người gọi Hủy (call_cancelled) hoặc kết thúc (call_ended)
      messageService.socket?.on('call_cancelled', (data) {
        if (mounted) {
          // Chỉ đóng Dialog đang hiển thị, không đóng màn hình Chat
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      });


      // Lắng nghe khi cuộc gọi kết thúc (Một trong hai người dập máy)
      messageService.socket?.on('call_ended', (data) {
        if (mounted) {
          // 1. Tìm và đóng màn hình Zego nếu nó đang hiển thị
          // Dùng popUntil để quét sạch các màn hình phụ và quay về màn hình Chat
          Navigator.of(context).popUntil((route) =>
          route.isFirst || route.settings.name != 'ZegoUIKitPrebuiltCall'
          );

          // 2. Thông báo nhẹ cho người dùng
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Cuộc gọi đã kết thúc"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      });







      // 4. Đổi Quick Reaction
      messageService.socket?.on('quick_reaction_changed', (data) {
        if (data['conversationId'] == widget.conversationId && mounted) {
          setState(() {
            _quickReaction = data['reaction'];
          });
        }
      });

      // 5. Đổi Biệt Hiệu (Nickname)
      messageService.socket?.on('nickname_changed', (data) {
        if (data['conversationId'] == widget.conversationId && mounted) {
          setState(() {
            String targetId = data['targetUserId'];
            String newName = data['nickname'] ?? "";

            if (newName.isEmpty) {
              _nicknames.remove(targetId);
            } else {
              _nicknames[targetId] = newName;
            }
          });
        }
      });

      // 6. Thu hồi tin nhắn
      messageService.socket?.on('delete_message', (data) {
        if (data['conversationId'] == widget.conversationId && mounted) {
          final msgs = messageService.messagesCache[widget.conversationId];
          if (msgs != null) {
            final index = msgs.indexWhere((m) => m.id == data['messageId']);
            if (index != -1) {
              setState(() {
                msgs[index] = Message(
                    id: msgs[index].id,
                    sender: msgs[index].sender,
                    content: "Tin nhắn đã được thu hồi",
                    type: "revoked",
                    createdAt: msgs[index].createdAt,
                    isRead: msgs[index].isRead,
                    reaction: msgs[index].reaction,
                    isRecalled: true,
                    replyTo: msgs[index].replyTo
                );
              });
            }
          }
        }
      });

      // 7. Thả tim tin nhắn
      messageService.socket?.on('message_reaction', (data) {
        if (data['conversationId'] == widget.conversationId && mounted) {
          final messagesInCache = messageService.messagesCache[widget.conversationId];
          if (messagesInCache != null) {
            final index = messagesInCache.indexWhere((m) => m.id == data['messageId']);
            if (index != -1) {
              setState(() {
                messagesInCache[index].reaction = data['reaction'];
              });
            }
          }
        }
      });

      // 9. Lắng nghe Game bắt đầu (Đã cập nhật để chuyển màn hình thật)
      messageService.socket?.on('game_started', (data) {
        if (mounted) {
          final gameType = data['gameType']; // 'caro' hoặc 'chess'
          final roomId = data['roomId'];
          final hostId = data['hostId'];
          final inviteMsgId = data['inviteMessageId'];

          // Lấy ID của mình để biết mình là Host (X) hay Guest (O)
          final currentUserId = Provider.of<AuthService>(context, listen: false).user?.id;
          final isHost = (currentUserId == hostId);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Đang vào phòng game: $roomId...")),
          );

          // Logic chuyển màn hình
          if (gameType == 'caro') {
            // Đã xóa comment, code chạy thật:
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => TicTacToeScreen(
                        roomId: roomId,
                        isOnline: true,
                        isHost: isHost,
                        inviteMessageId: inviteMsgId
                    )
                )
            );
            print("ĐANG VÀO CARO ONLINE: Room $roomId");
          } else if (gameType == 'chess') {
            // Tương tự cho cờ vua (sau này bro làm ChessScreen thì mở comment ra)
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChessScreen( // Đảm bảo bro import ChessScreen
                        roomId: roomId,
                        isOnline: true,
                        isHost: isHost,
                        inviteMessageId: inviteMsgId
                    )
                )
            );
          }  // 🔥 3. RẮN SĂN MỒI (THÊM MỚI Ở ĐÂY)
          else if (gameType == 'snake') {
            messageService.socket?.emit('join_game_room', roomId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SnakeScreen(
                  isOnline: true,
                  roomId: roomId,
                  isHost: isHost, // Host điều khiển rắn 1, Guest rắn 2
                ),
              ),
            );
          }
        }
      });

      // THÊM LẮNG NGHE SỰ KIỆN CẬP NHẬT TIN NHẮN (để UI tự đổi từ Mời -> Kết thúc)
      messageService.socket?.on('message_updated', (data) {
        if (data['conversationId'] == widget.conversationId && mounted) {
          final updatedMsg = data['message'];
          final msgs = messageService.messagesCache[widget.conversationId];

          if (msgs != null) {
            final index = msgs.indexWhere((m) => m.id == updatedMsg['_id']);
            if (index != -1) {
              setState(() {
                // Cập nhật lại nội dung tin nhắn trong list
                // Ví dụ: Đổi type từ 'game_invite' thành 'text'
                msgs[index] = Message.fromJson(updatedMsg);
              });
            }
          }
        }
      });

    });
  }

  // Hàm bổ trợ để người nhận gia nhập cuộc gọi khi nhấn "Trả lời"
  void _joinCall(Map<String, dynamic> data) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final messageService = Provider.of<MessageService>(context, listen: false);
    final currentUser = authService.user;

    if (currentUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallService.makeCallPage(
          callID: data['room'],
          userID: currentUser.id,
          targetAvatar: _targetUser.avatarUrl,
          userName: currentUser.displayName ?? "User",
          isVideo: data['isVideo'],
          messageService: messageService,
          targetUserId: data['fromId'], // ID của người gọi
        ),
      ),
    );
  }



  // --- MENU CHỌN ẢNH (CAMERA HOẶC THƯ VIỆN) ---
  void _showImagePickerModal() {
    // Lấy màu theme
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor, // SỬA: Màu nền động
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 15),
            Text("Gửi hình ảnh", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)), // SỬA: Màu chữ
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionItem(Icons.camera_alt, "Chụp ảnh", Colors.blue, () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSource.camera);
                }),
                _buildOptionItem(Icons.photo_library, "Thư viện", Colors.purple, () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSource.gallery);
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }




// --- HÀM HIỂN THỊ DANH SÁCH CHỌN NGƯỜI ĐỔI TÊN ---
  void _showNicknameDialog() {
    final currentUser = Provider.of<AuthService>(context, listen: false).user;

    // Lấy màu theme
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 250,
          color: cardColor, // SỬA: Màu nền
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Đặt biệt hiệu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)), // SỬA: Màu chữ
              const SizedBox(height: 15),

              // 1. Đặt cho Đối phương
              ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(_targetUser.avatarUrl ?? "")),
                title: Text(_getDisplayName(_targetUser), style: TextStyle(color: textColor)), // SỬA: Màu chữ
                subtitle: const Text("Đặt biệt hiệu", style: TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.edit, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context);
                  _showEditNameDialog(_targetUser);
                },
              ),

              // 2. Đặt cho Mình
              if (currentUser != null)
                ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(currentUser.avatarUrl ?? "")),
                  title: Text(_nicknames[currentUser.id] ?? currentUser.displayName, style: TextStyle(color: textColor)), // SỬA: Màu chữ
                  subtitle: const Text("Đặt biệt hiệu", style: TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.edit, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditNameDialog(currentUser);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // --- LOGIC MỜI GAME (Dán vào trong _ChatScreenState) ---

  // 1. Hàm gửi lời mời
  void _sendGameInvite(String gameType) {
    final currentUser = Provider.of<AuthService>(context, listen: false).user;
    final messageService = Provider.of<MessageService>(context, listen: false);

    if (currentUser == null) return;

    // Gửi socket event lên server
    // (Server sẽ lo việc lưu vào DB và bắn lại tin nhắn 'new_message' cho mình)
    messageService.socket?.emit('send_game_invite', {
      'fromUser': currentUser.id,
      'toUser': widget.targetUser.id,
      'gameType': gameType
    });


    Navigator.pop(context); // Đóng menu chọn game
  }

  // 2. Hàm hiển thị Dialog chọn game
  void _showGameInviteDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 15),
            const Text("Mời bạn bè chơi game", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 👇 CẬP NHẬT ROW NÀY ĐỂ THÊM GAME RẮN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGameOptionItem("Cờ Caro", Icons.grid_3x3, Colors.blue, () => _sendGameInvite("caro")),

                _buildGameOptionItem("Cờ Vua", Icons.psychology, Colors.brown, () => _sendGameInvite("chess")),

                // 🔥 NÚT GAME RẮN MỚI
                _buildGameOptionItem("Rắn", Icons.gesture, Colors.green, () => _sendGameInvite("snake")),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  // 3. Widget con hiển thị icon game
  Widget _buildGameOptionItem(String name, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _handleSendLocation() async {
    // 1. Hiển thị thông báo xác nhận
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chia sẻ vị trí"),
        content: const Text("Gửi vị trí hiện tại của bạn cho đối phương?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Đồng ý")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 2. Kiểm tra quyền và lấy vị trí
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high
        );

        // 3. FIX LỖI BACKEND: Gửi dưới dạng 'text' kèm tiền tố LOCATION:
        // Backend sẽ chấp nhận type 'text', còn App sẽ dựa vào prefix để vẽ bản đồ.
        String locationData = "LOCATION:${position.latitude},${position.longitude}";

        // Gửi qua MessageService với type là 'text'
        Provider.of<MessageService>(context, listen: false)
            .sendMessage(widget.conversationId, locationData, type: 'text');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã gửi vị trí!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi lấy vị trí: $e")),
      );
    }
  }


  // --- MENU CÁC TÍNH NĂNG MỞ RỘNG (KHI BẤM DẤU +) ---
  void _showMediaOptions() {
    // Lấy màu theme
    final cardColor = Theme.of(context).cardColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor, // SỬA: Màu nền động
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

// Tìm đoạn Row trong hàm _showMediaOptions và sửa thành như sau:
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOptionItem(Icons.image, "Ảnh", Colors.blue, () {
                  Navigator.pop(context);
                  _showImagePickerModal();
                }),

                // --- THÊM MỤC NÀY ---
                _buildOptionItem(Icons.sports_esports, "Mời Game", Colors.purpleAccent, () {
                  Navigator.pop(context);
                  _showGameInviteDialog(); // Gọi hàm vừa tạo ở Bước 2
                }),
                // --------------------

                _buildOptionItem(Icons.location_on, "Vị trí", Colors.redAccent, () {
                  Navigator.pop(context); // Đóng menu
                  _handleSendLocation(); // Gọi hàm xử lý gửi vị trí
                }),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }



  // Widget con để vẽ item trong menu
  Widget _buildOptionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    // Lấy màu chữ
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)), // SỬA: Màu chữ
        ],
      ),
    );
  }



  // --- HÀM NHẬP TÊN MỚI (ĐÃ FIX LOGIC UI) ---
  void _showEditNameDialog(UserModel user) {
    final controller = TextEditingController(text: _nicknames[user.id] ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Đặt biệt hiệu cho ${user.displayName}"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nhập biệt hiệu mới"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              // 1. Lấy giá trị trước khi đóng dialog
              final newName = controller.text.trim();

              // 2. Đóng dialog
              Navigator.pop(context);

              // 3. Gọi API (Backend)
              Provider.of<MessageService>(context, listen: false)
                  .updateNickname(widget.conversationId, user.id, newName);

              // 4. Cập nhật UI ngay lập tức (Optimistic Update)
              // Lưu ý: Phải gọi setState của ChatScreen chứ không phải của Dialog
              if (mounted) {
                setState(() {
                  if (newName.isEmpty) {
                    _nicknames.remove(user.id);
                  } else {
                    _nicknames[user.id] = newName;
                  }
                });
              }
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }


  Widget _buildReplyPreview() {
    if (_replyMessage == null) return const SizedBox.shrink();

    // Lấy màu theme
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    // Lấy màu chữ chuẩn của hệ thống (đen ở Light Mode, trắng ở Dark Mode)
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    String senderName = _nicknames[_replyMessage!.sender.id] ?? _replyMessage!.sender.displayName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 35,
            decoration: BoxDecoration(color: _themeColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Đang trả lời $senderName",
                  style: TextStyle(fontWeight: FontWeight.bold, color: _themeColor, fontSize: 13),
                ),
                Text(
                  _replyMessage!.type == 'text' ? _replyMessage!.content : "[${_replyMessage!.type}]",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 👇 THAY ĐỔI Ở ĐÂY: Dùng màu chữ hệ thống với độ mờ 70% thay vì màu xám cứng
                  style: TextStyle(
                    color: textColor.withOpacity(0.8), // Rõ hơn nhiều so với Colors.grey
                    fontSize: 13,
                    fontWeight: FontWeight.w400, // Tăng độ dày chữ lên một chút nếu cần
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            // 👇 Icon cũng nên theo màu chữ hệ thống cho đồng bộ
            icon: Icon(Icons.close, color: textColor.withOpacity(0.6), size: 20),
            onPressed: () => setState(() => _replyMessage = null),
          )
        ],
      ),
    );
  }




  // --- HÀM LẤY INFO MỚI NHẤT CỦA TARGET USER ---
  Future<void> _fetchTargetUserLatestInfo() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dio = Dio();
      final token = authService.token;

      if (token != null) {
        final response = await dio.get(
          '${authService.baseUrl}/api/users/${widget.targetUser.id}',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        if (response.statusCode == 200) {
          final updatedUser = UserModel.fromJson(response.data, baseUrl: authService.baseUrl);
          if (mounted) {
            setState(() {
              _targetUser = updatedUser;
            });
          }
        }
      }
    } catch (e) {
      print("⚠️ Lỗi cập nhật trạng thái user: $e");
    }
  }

  // --- LOGIC GỬI STICKER ---
  void _handleSendSticker(String url) {
    Provider.of<MessageService>(context, listen: false)
        .sendMessage(widget.conversationId, url, type: 'sticker');
    // setState(() => _showSticker = false); // Tùy chọn: ẩn bảng sau khi gửi
  }

  Widget _buildStickerPicker() {
    // Lấy màu theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Nền bảng sticker: Light thì xám nhạt, Dark thì xám đậm
    final pickerBgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);
    final tabBarColor = Theme.of(context).cardColor; // Màu nền thanh tab dưới cùng
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final dividerColor = Theme.of(context).dividerColor;

    if (myStickerPacks.isEmpty) {
      return Container(
          height: 250,
          color: pickerBgColor, // SỬA
          child: Center(child: Text("Chưa có bộ nhãn dán nào", style: TextStyle(color: textColor)))); // SỬA
    }

    final index = (_selectedStickerPackIndex >= myStickerPacks.length) ? 0 : _selectedStickerPackIndex;
    final currentPack = myStickerPacks[index];

    return Container(
      height: 280,
      color: pickerBgColor, // SỬA: Màu nền tổng
      child: Column(
        children: [
          // 1. GRID
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: currentPack.stickers.length,
              itemBuilder: (context, index) {
                final stickerPath = currentPack.getStickerPath(index);
                return GestureDetector(
                  onTap: () => _handleSendSticker(stickerPath),
                  child: Image.asset(
                    stickerPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, color: Colors.grey);
                    },
                  ),
                );
              },
            ),
          ),

          // 2. TAB BAR
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: tabBarColor, // SỬA: Màu nền thanh tab
              border: Border(top: BorderSide(color: dividerColor)), // SỬA: Viền
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: myStickerPacks.length,
              itemBuilder: (context, index) {
                final pack = myStickerPacks[index];
                final isSelected = _selectedStickerPackIndex == index;

                // Màu nền highlight khi chọn
                final selectedBg = isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200];

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedStickerPackIndex = index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    color: isSelected ? selectedBg : Colors.transparent, // SỬA
                    child: Opacity(
                      opacity: isSelected ? 1.0 : 0.5,
                      child: Image.asset(
                        pack.icon,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => Icon(Icons.image, size: 20, color: textColor),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }





  // --- LOGIC ĐỔI THEME ---
  void _changeTheme(ChatTheme theme) {
    setState(() {
      _currentTheme = theme;
      _savedThemes[widget.conversationId] = theme.id;
    });

    final currentUser = Provider.of<AuthService>(context, listen: false).user;
    final messageService = Provider.of<MessageService>(context, listen: false);

    String systemContent = "${currentUser?.displayName ?? 'Ai đó'} đã đổi chủ đề sang ${theme.name}";
    messageService.sendMessage(widget.conversationId, systemContent, type: 'system');
    messageService.updateTheme(widget.conversationId, theme.id);
  }

  // --- LOGIC GHI ÂM ---
  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print('❌ Không có quyền truy cập Micro');
      return;
    }
    await _recorder.openRecorder();
    _isRecorderInitialized = true;
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;
    try {
      Directory tempDir = await getTemporaryDirectory();
      String path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(toFile: path);
      _recordSeconds = 0;
      _recordDurationText = "00:00";
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordSeconds++;
        final m = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
        final s = (_recordSeconds % 60).toString().padLeft(2, '0');
        setState(() => _recordDurationText = "$m:$s");
      });
      setState(() => _isRecording = true);
    } catch (e) { print("❌ Lỗi ghi âm: $e"); }
  }

  Future<void> _stopRecording() async {
    if (!_isRecorderInitialized || !_isRecording) return;
    try {
      final path = await _recorder.stopRecorder();
      _recordTimer?.cancel();
      setState(() => _isRecording = false);
      if (path != null) {
        Provider.of<MessageService>(context, listen: false).sendAudioMessage(context, widget.conversationId, path);
      }
    } catch (e) { print("❌ Lỗi dừng ghi âm: $e"); }
  }




  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _recorder.closeRecorder();
    _recordTimer?.cancel();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Gửi tin nhắn kèm ID của tin nhắn đang reply (nếu có)
    Provider.of<MessageService>(context, listen: false).sendMessage(
        widget.conversationId,
        text,
        replyToId: _replyMessage?.id // <--- QUAN TRỌNG
    );

    _textController.clear();
    setState(() {
      _isComposing = false;
      _replyMessage = null; // <--- QUAN TRỌNG: Reset lại sau khi gửi xong
    });
  }


  // tiếp tục

  void _handleSendLike() {
    Provider.of<MessageService>(context, listen: false).sendMessage(widget.conversationId, "👍");
  }

  Future<void> _handleImageSelection(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null && mounted) {
        Provider.of<MessageService>(context, listen: false)
            .sendImageMessage(context, widget.conversationId, pickedFile.path);
      }
    } catch (e) { print("Lỗi chọn ảnh: $e"); }
  }

  void _onEmojiSelected(Emoji emoji) {
    _textController.text += emoji.emoji;
    setState(() => _isComposing = true);
  }

  Future<bool> _onWillPop() async {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      return false;
    }
    if (_showSticker) {
      setState(() => _showSticker = false);
      return false;
    }
    return true;
  }

  // --- CÁC HÀM UI PHỤ TRỢ (Menu, Reaction, Recall) ---
  void _showMessageOptions(BuildContext context, Message message, bool isMe) {
    // Lấy màu Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor; // Màu nền bảng
    final textColor = Theme.of(context).textTheme.bodyLarge?.color; // Màu chữ

    // Nền của thanh cảm xúc (Emoji bar)
    final reactionBarColor = isDark ? Colors.grey[800] : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: cardColor, // SỬA: Màu nền động
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- 1. THANH CẢM XÚC (REACTIONS) ---
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: reactionBarColor, // SỬA: Màu nền thanh emoji
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  if (!isDark) // Chỉ đổ bóng nếu là Light Mode
                    BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 2))
                ],
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: ["👍", "❤️", "😂", "😮", "😢", "😡"].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Provider.of<MessageService>(context, listen: false).reactToMessage(widget.conversationId, message.id, emoji);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // --- 2. CÁC TÙY CHỌN (TRẢ LỜI, COPY, THU HỒI) ---

            // Nút Trả lời
            _buildOptionRow(Icons.reply, "Trả lời", textColor, () {
              Navigator.pop(context);
              setState(() => _replyMessage = message);
              _focusNode.requestFocus();
            }),

            // Nút Copy (chỉ hiện cho tin nhắn văn bản)
            if (message.type == 'text')
              _buildOptionRow(Icons.copy, "Sao chép", textColor, () {
                Navigator.pop(context);
                // Code copy clipboard (cần import package:flutter/services.dart)
                // Clipboard.setData(ClipboardData(text: message.content));
              }),

            // Nút Thu hồi (Chỉ hiện nếu là tin của mình)
            if (isMe)
              _buildOptionRow(Icons.delete_outline, "Thu hồi tin nhắn", Colors.red, () { // Màu đỏ giữ nguyên
                Navigator.pop(context);
                Provider.of<MessageService>(context, listen: false).recallMessage(widget.conversationId, message.id);
              }),
          ],
        ),
      ),
    );
  }

  // Widget con để vẽ dòng option cho gọn
  Widget _buildOptionRow(IconData icon, String text, Color? color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }


  // --- HÀM CHỌN EMOJI CHO QUICK REACTION ---
  void _showQuickReactionPicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              // 1. Đóng bảng chọn
              Navigator.pop(context);

              // 2. Cập nhật UI ngay lập tức
              setState(() {
                _quickReaction = emoji.emoji;
              });

              // 3. Gọi API cập nhật & Báo cho người kia
              Provider.of<MessageService>(context, listen: false)
                  .updateQuickReaction(widget.conversationId, emoji.emoji);
            },
            config: Config(
              checkPlatformCompatibility: false,
              emojiViewConfig: EmojiViewConfig(
                columns: 7,
                emojiSizeMax: 32 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
              ),
            ),
          ),
        );
      },
    );
  }




  void _handleReaction(Message message, String emoji) {
    setState(() {
      message.reaction = emoji;
    });
  }

  void _handleRecallMessage(Message message) async {
    final messageService = Provider.of<MessageService>(context, listen: false);
    await messageService.recallMessage(widget.conversationId, message.id);

    if (messageService.messagesCache[widget.conversationId] != null) {
      setState(() {
        final index = messageService.messagesCache[widget.conversationId]!.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          final oldMsg = messageService.messagesCache[widget.conversationId]![index];
          messageService.messagesCache[widget.conversationId]![index] = Message(
            id: oldMsg.id,
            sender: oldMsg.sender,
            content: "Tin nhắn đã được thu hồi",
            type: "revoked",
            createdAt: oldMsg.createdAt,
            isRead: oldMsg.isRead,
            isRecalled: true,
          );
        }
      });
    }
  }

  void _showChatDetails() {
    // Lấy màu Theme
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final dividerColor = Theme.of(context).dividerColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép full chiều cao nếu cần
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7, // Chiếm 70% màn hình
        decoration: BoxDecoration(
          color: cardColor, // SỬA: Màu nền động
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Thanh gạch ngang nhỏ
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            // --- AVATAR & TÊN USER ---
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(_targetUser.avatarUrl ?? 'https://i.pravatar.cc/150'),
            ),
            const SizedBox(height: 10),
            Text(
              _getDisplayName(_targetUser),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor), // SỬA: Màu chữ
            ),
            const SizedBox(height: 30),

            // --- DANH SÁCH CHỨC NĂNG ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // 1. Đổi chủ đề
                  _buildDetailItem(Icons.color_lens, "Chủ đề", textColor, () {
                    // Đóng menu hiện tại rồi mở menu chọn theme
                    Navigator.pop(context);
                    _showThemePicker();
                  }),
                  Divider(color: dividerColor),

                  // 2. Biệt hiệu
                  _buildDetailItem(Icons.text_fields, "Biệt hiệu", textColor, () {
                    Navigator.pop(context);
                    _showNicknameDialog();
                  }),
                  Divider(color: dividerColor),

                  // 3. Tìm kiếm
                  _buildDetailItem(Icons.search, "Tìm kiếm trong cuộc trò chuyện", textColor, () {
                    Navigator.pop(context);
                    // TODO: Logic tìm kiếm
                  }),
                  Divider(color: dividerColor),

                  // 4. Chặn (Màu đỏ)
                  _buildDetailItem(Icons.block, "Chặn", Colors.red, () {
                    // TODO: Logic chặn
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text, Color? color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(text, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: color)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }


  // Đã đổi tên từ _openThemePicker -> _showThemePicker để khớp với _showChatDetails
  void _showThemePicker() {
    // Lấy màu Theme
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    // Border màu đen hoặc trắng tùy nền
    final selectedBorderColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 350,
          decoration: BoxDecoration(
            color: cardColor, // SỬA: Màu nền động
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text("Chọn chủ đề", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))), // SỬA: Màu chữ
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: appThemes.length,
                  itemBuilder: (context, index) {
                    final theme = appThemes[index];
                    final isSelected = _currentTheme.id == theme.id;
                    return GestureDetector(
                      onTap: () {
                        _changeTheme(theme);
                        Navigator.pop(context);
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: theme.gradient,
                                ),
                                border: isSelected
                                    ? Border.all(color: selectedBorderColor, width: 3) // SỬA: Viền khi chọn
                                    : Border.all(color: Colors.grey[300]!),
                                boxShadow: [
                                  if (isSelected) BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)
                                ],
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 30) : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(theme.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)), // SỬA: Màu chữ tên theme
                        ],
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // --- HÀM HELPER: FORMAT THỜI GIAN OFFLINE ---
  String _formatLastActive(DateTime? lastActive) {
    if (lastActive == null) return "Offline";

    final now = DateTime.now();
    // Chuyển lastActive về giờ địa phương
    final localTime = lastActive.toLocal();
    final diff = now.difference(localTime);

    if (diff.inMinutes < 1) return "Vừa truy cập";
    if (diff.inMinutes < 60) return "Hoạt động ${diff.inMinutes} phút trước";
    if (diff.inHours < 24) return "Hoạt động ${diff.inHours} giờ trước";
    if (diff.inDays < 7) return "Hoạt động ${diff.inDays} ngày trước";

    return "Hoạt động ${localTime.day}/${localTime.month}";
  }

  // Hàm khởi tạo cuộc gọi ZegoCloud (Đã cập nhật giao diện chờ)
  void _initiateZegoCall(bool isVideo) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.user;
    final messageService = Provider.of<MessageService>(context, listen: false);

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lỗi: Không tìm thấy thông tin người dùng!")),
      );
      return;
    }

    final String callId = widget.conversationId;

    // 1. Hiển thị Dialog "Đang gọi..." cho người gọi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 45,
              backgroundImage: NetworkImage(_targetUser.avatarUrl ?? ""),
            ),
            const SizedBox(height: 20),
            Text(
              "Đang gọi cho ${_targetUser.displayName}...",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            const Text("Chờ đối phương trả lời", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 30),
            // Nút hủy cuộc gọi
            IconButton(
              iconSize: 60,
              icon: const Icon(Icons.call_end, color: Colors.redAccent),
              onPressed: () {
                messageService.socket?.emit('call_cancelled', {'to': _targetUser.id});
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );

    // 2. Gửi tín hiệu invite qua Socket
    messageService.socket?.emit('call_invite', {
      'fromId': currentUser.id,
      'fromName': currentUser.displayName,
      'fromAvatar': currentUser.avatarUrl,
      'to': _targetUser.id,
      'room': callId,
      'isVideo': isVideo
    });
  }




  // --- HÀM HELPER URL ---
  String _getValidImageUrl(String content) {
    final baseUrl = Provider.of<AuthService>(context, listen: false).baseUrl;
    if (content.startsWith('http')) {
      if (content.contains('localhost') && baseUrl != null && baseUrl.contains('10.0.2.2')) {
        return content.replaceFirst('localhost', '10.0.2.2');
      }
      return content;
    }
    String cleanPath = content;
    if (cleanPath.startsWith('public/')) cleanPath = cleanPath.substring(7);
    else if (cleanPath.startsWith('public\\')) cleanPath = cleanPath.substring(7);
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
    return '$baseUrl$cleanPath';
  }

// --- GIAO DIỆN APP BAR (ĐÃ FIX TÊN BIẾN) ---
  // --- GIAO DIỆN APP BAR (ĐÃ FIX LOGIC ONLINE) ---
  AppBar _buildMessengerAppBar() {
    // 1. Lấy trạng thái thực tế từ _targetUser
    // Lưu ý: Nếu server chưa gửi update socket, biến này có thể là false.
    // Nhưng nếu bro đã làm bước lắng nghe socket ở trên thì nó sẽ tự cập nhật.
    final bool isOnline = _targetUser.isOnline;

    // 2. Tính toán Text trạng thái
    String statusText;
    Color statusColor;

    if (isOnline) {
      statusText = 'Đang hoạt động';
      statusColor = Colors.green;
    } else {
      // Nếu offline, tính thời gian dựa trên lastActive
      statusText = _formatLastActive(_targetUser.lastActive);
      statusColor = Colors.grey;
    }

    // 3. Lấy màu giao diện
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.9);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return AppBar(
      elevation: 0,
      backgroundColor: appBarBg,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: _themeColor),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // --- AVATAR & CHẤM XANH ---
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                    _targetUser.avatarUrl ?? 'https://i.pravatar.cc/150'
                ),
                backgroundColor: Colors.grey[200],
              ),

              // LOGIC HIỆN CHẤM XANH: Chỉ hiện khi isOnline == true
              if (isOnline)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: appBarBg,
                          width: 2.5
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),

          // --- TÊN & TRẠNG THÁI ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _getDisplayName(_targetUser),
                    style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold
                    )
                ),
                Text(
                    statusText, // Đã được tính toán ở bước 2
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12
                    )
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Nút gọi thoại
        IconButton(
          icon: Icon(Icons.call, color: _themeColor),
          onPressed: () => _initiateZegoCall(false), // false = Gọi thoại
        ),

        // Nút gọi video
        IconButton(
          icon: Icon(Icons.videocam, color: _themeColor),
          onPressed: () => _initiateZegoCall(true), // true = Gọi video
        ),

        IconButton(
          icon: Icon(Icons.info, color: _themeColor),
          onPressed: _showChatDetails,
        ),
      ],









    );
  }





  // --- GIAO DIỆN GHI ÂM ---
  Widget _buildRecordingUI() {
    // Lấy màu theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: bgColor, border: Border(top: BorderSide(color: borderColor))), // SỬA: Màu nền và viền
      child: SafeArea(
        child: Row(
          children: [
            const Icon(Icons.fiber_manual_record, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(_recordDurationText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)), // SỬA: Màu chữ thời gian
            const SizedBox(width: 16),
            Expanded(child: SizedBox(height: 30, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(15, (index) => AnimatedContainer(duration: const Duration(milliseconds: 300), width: 4, height: 10.0 + Random().nextInt(20), decoration: BoxDecoration(color: _themeColor.withOpacity(0.6), borderRadius: BorderRadius.circular(5))))))),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _stopRecording,
              child: CircleAvatar(radius: 22, backgroundColor: _themeColor, child: const Icon(Icons.arrow_upward, color: Colors.white, size: 24)),
            )
          ],
        ),
      ),
    );
  }


  Widget _buildInputBar() {
    // Lấy màu theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white; // Nền thanh chat
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final inputFillColor = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFF0F2F5); // Nền ô nhập
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. PREVIEW TRẢ LỜI
        _buildReplyPreview(),

        // 2. THANH NHẬP LIỆU
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: barBgColor, // SỬA: Màu nền thanh chat
            border: Border(top: BorderSide(color: borderColor)), // SỬA: Màu viền
          ),
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!_isComposing) ...[
                  _buildIconBtn(Icons.add_circle, color: _themeColor, onTap: _showMediaOptions),
                  const SizedBox(width: 12),
                  // _buildIconBtn(Icons.image, color: _themeColor, onTap: _showImagePickerModal),
                  // const SizedBox(width: 12),
                  _buildIconBtn(Icons.sticky_note_2_outlined, color: _themeColor, onTap: () async {
                    _focusNode.unfocus();
                    await Future.delayed(const Duration(milliseconds: 50));
                    setState(() {
                      _showSticker = !_showSticker;
                      _showEmoji = false;
                    });
                  }),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _startRecording,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Icon(Icons.mic, color: _themeColor, size: 26),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, right: 12),
                    child: InkWell(
                      onTap: () => setState(() => _isComposing = false),
                      child: Icon(Icons.arrow_forward_ios, color: _themeColor, size: 22),
                    ),
                  ),

                const SizedBox(width: 8),

                // --- Ô NHẬP LIỆU ---
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: inputFillColor, // SỬA: Màu nền ô nhập liệu
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 6,
                            style: TextStyle(fontSize: 16, color: textColor), // SỬA: Màu chữ nhập vào
                            decoration: const InputDecoration(
                              hintText: 'Nhắn tin...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.only(left: 16, top: 10, bottom: 10, right: 8),
                            ),
                            onTap: () {
                              if (_showEmoji || _showSticker) {
                                setState(() {
                                  _showEmoji = false;
                                  _showSticker = false;
                                });
                              }
                            },
                            onChanged: (text) {
                              final shouldCompose = text.trim().isNotEmpty;
                              if (_isComposing != shouldCompose) setState(() => _isComposing = shouldCompose);
                            },
                          ),
                        ),
                        // Icon Emoji
                        IconButton(
                          icon: Icon(_showEmoji ? Icons.keyboard : Icons.sentiment_satisfied_alt, color: _themeColor, size: 26),
                          onPressed: () async {
                            if (_showEmoji) {
                              _focusNode.requestFocus();
                              setState(() => _showEmoji = false);
                            } else {
                              _focusNode.unfocus();
                              await Future.delayed(const Duration(milliseconds: 50));
                              setState(() {
                                _showEmoji = true;
                                _showSticker = false;
                              });
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),

                // --- NÚT GỬI / LIKE ---
                Container(
                  margin: const EdgeInsets.only(left: 8, bottom: 4),
                  child: _isComposing
                      ? GestureDetector(
                    onTap: _handleSend,
                    child: Icon(Icons.send, color: _themeColor, size: 30),
                  )
                      : GestureDetector(
                    onTap: () {
                      Provider.of<MessageService>(context, listen: false)
                          .sendMessage(widget.conversationId, _quickReaction);
                    },
                    child: Text(_quickReaction, style: const TextStyle(fontSize: 34)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }







  Widget _buildIconBtn(IconData icon, {required Color color, required VoidCallback onTap}) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: GestureDetector(onTap: onTap, child: Icon(icon, color: color, size: 26)));
  }

  // Hàm phụ trợ để lấy nội dung hiển thị cho gọn
  String _getReplyContent(Message msg) {
    if (msg.type == 'image') return "[Hình ảnh]";
    if (msg.type == 'sticker') return "[Nhãn dán]";
    if (msg.type == 'audio') return "[Ghi âm]";
    return msg.content;
  }


  // --- BONG BÓNG CHAT (Đã tích hợp Sticker + Thời gian) ---
  Widget _buildMessengerBubble(Message message, bool isMe, bool showAvatar, bool isFirst, bool isLast) {
    // 1. Xử lý hiển thị tin hệ thống / thu hồi (Giữ nguyên)
    if (message.type == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 15),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
        ),
      );
    }

    if (message.isRecalled || message.type == 'revoked' || message.content == 'Tin nhắn đã được thu hồi') {
      return Container(
        margin: EdgeInsets.only(bottom: (isLast) ? 2 : 12),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              if (showAvatar) CircleAvatar(radius: 14, backgroundImage: NetworkImage(_targetUser.avatarUrl ?? 'https://i.pravatar.cc/150')) else const SizedBox(width: 28),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16), color: Colors.white.withOpacity(0.5)),
              child: const Text("Tin nhắn đã được thu hồi", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    // 2. Xác định các biến màu sắc, theme
    final bool isAudio = message.type == 'audio' || message.content.endsWith('.aac') || message.content.endsWith('.m4a');
    final bool isImage = (message.type == 'image' && !isAudio);
    final bool isSticker = message.type == 'sticker';

    // --- FIX LOGIC DARK MODE ---
    final bool isSystemDark = Theme.of(context).brightness == Brightness.dark;
    final bool useWhiteText = isSystemDark || _currentTheme.backgroundImage != null;
    final Color receivedMsgColor = useWhiteText ? Colors.white : Colors.black;
    final Color receivedMsgBg = _currentTheme.backgroundImage != null
        ? Colors.black.withOpacity(0.4)
        : (isSystemDark ? const Color(0xFF3E4042) : const Color(0xFFE4E6EB));

    // 👇👇👇 2.1. FORMAT THỜI GIAN (HH:mm) 👇👇👇
    // (Đảm bảo bro đã import 'package:intl/intl.dart')
    final String timeString = DateFormat('HH:mm').format(message.createdAt.toLocal());
    final Color timeColor = isMe
        ? Colors.white.withOpacity(0.7) // Tin mình: Trắng mờ
        : (useWhiteText ? Colors.white70 : Colors.grey[600]!); // Tin bạn: Xám hoặc trắng mờ tùy nền
    // ---------------------------------------------

    // 3. Xây dựng Widget Reply (ĐÃ FIX MÀU SẮC CHO RÕ NÉT)
    Widget? replyWidget;
    if (message.replyTo != null) {
      final reply = message.replyTo!;
      String replyContent = reply.content;
      if (reply.type == 'image') replyContent = "[Hình ảnh]";
      if (reply.type == 'sticker') replyContent = "[Nhãn dán]";
      else if (reply.type == 'audio') replyContent = "[Ghi âm]";
      else if (reply.type == 'video') replyContent = "[Video]";

      // Xác định màu chữ cho phần Reply bên trong bong bóng
      // - Nếu là tin của mình (isMe): Nền bong bóng là Gradient màu -> Chữ Reply nên là trắng mờ.
      // - Nếu là tin người khác (!isMe): Nền bong bóng là Xám/Trắng -> Chữ Reply nên là Đen/Xám đậm.
      // - Tuy nhiên nếu DarkMode (!isMe nhưng nền tối) -> Chữ Reply nên là Trắng.

      final Color replyNameColor = isMe
          ? Colors.white.withOpacity(0.95)
          : (useWhiteText ? Colors.white : Colors.black87);

      final Color replyContentColor = isMe
          ? Colors.white.withOpacity(0.8)
          : (useWhiteText ? Colors.white70 : Colors.black54);

      final Color replyBgColor = isMe
          ? Colors.black.withOpacity(0.1) // Tin mình: Nền đen mờ nhẹ trên nền màu
          : (useWhiteText ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)); // Tin bạn: Nền tương phản nhẹ

      replyWidget = Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: replyBgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(
              color: isMe ? Colors.white70 : _themeColor,
              width: 3
          )),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reply.sender.displayName,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: replyNameColor // Đã fix màu
              ),
            ),
            const SizedBox(height: 2),
            Text(
              replyContent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: replyContentColor // Đã fix màu
              ),
            ),
          ],
        ),
      );
    }


    // 4. Xây dựng nội dung tin nhắn chính
    Widget messageContent;
    if (isSticker) {
      bool isLocalAsset = !message.content.startsWith('http');
      messageContent = Container(
        width: 140, height: 140,
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: isLocalAsset
            ? Image.asset(message.content, fit: BoxFit.contain)
            : Image.network(message.content, fit: BoxFit.contain),
      );
    } else if (isImage) {
      messageContent = GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImagePage(imageUrl: _getValidImageUrl(message.content)))),
        child: Hero(
            tag: message.content,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(color: Colors.grey[200], border: Border.all(color: Colors.grey[300]!)),
                    child: Image.network(_getValidImageUrl(message.content), fit: BoxFit.cover)
                )
            )
        ),
      );
    } else if (isAudio) {
      messageContent = AudioMessageBubble(audioUrl: _getValidImageUrl(message.content), isMe: isMe, activeGradient: _currentTheme.gradient);
    } else if (message.content.startsWith("LOCATION:")) {
      messageContent = GestureDetector(
        onTap: () {
          final String coordsRaw = message.content.replaceFirst("LOCATION:", "");
          final coords = coordsRaw.split(',');

          if (coords.length == 2) {
            final double lat = double.parse(coords[0]);
            final double lng = double.parse(coords[1]);

            // Lấy avatar của chính mình từ Provider
            final myAvatar = Provider.of<AuthService>(context, listen: false).user?.avatarUrl;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MapScreen(
                  initialTargetLocation: LatLng(lat, lng),
                  targetAddress: "Vị trí của ${isMe ? 'bạn' : _targetUser.displayName}",
                  // Người gửi (chủ nhân cái ghim trên map)
                  senderAvatar: isMe ? myAvatar : _targetUser.avatarUrl,
                  // Người nhận (vị trí hiện tại của mình)
                  receiverAvatar: isMe ? _targetUser.avatarUrl : myAvatar,
                ),
              ),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Text(
                  "Vị trí hiện tại",
                  style: TextStyle(
                    color: isMe ? Colors.white : receivedMsgColor,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Bấm để xem và dẫn đường",
              style: TextStyle(
                color: isMe ? Colors.white70 : receivedMsgColor.withOpacity(0.7),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );

    }  else {
      messageContent = Text(
          message.content,
          style: TextStyle(color: isMe ? Colors.white : receivedMsgColor, fontSize: 15, height: 1.3)
      );
    }

    // 5. GỘP REPLY + TIN NHẮN CHÍNH + THỜI GIAN
    Widget finalBubbleContent = IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyWidget != null) replyWidget,

          // Nội dung tin nhắn (Text, Audio...)
          // Dùng ConstrainedBox để đảm bảo tin nhắn cực ngắn vẫn có đủ chỗ hiện thời gian
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 50),
            child: messageContent,
          ),

          // 👇👇👇 THỜI GIAN VÀO CUỐI BONG BÓNG 👇👇👇
          if (!isSticker && !isImage)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min, // Cực kỳ quan trọng để không đẩy bong bóng rộng ra
                children: [
                  Text(
                    timeString,
                    style: TextStyle(fontSize: 10, color: timeColor, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

// 6. TRẢ VỀ CẤU TRÚC BONG BÓNG CHAT HOÀN CHỈNH
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: (isLast && message.reaction == null) ? 2 : 12),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                if (showAvatar)
                  CircleAvatar(radius: 14, backgroundImage: NetworkImage(_targetUser.avatarUrl ?? 'https://i.pravatar.cc/150'))
                else
                  const SizedBox(width: 28),
                const SizedBox(width: 8),
              ],

              GestureDetector(
                onLongPress: () => _showMessageOptions(context, message, isMe),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      // maxWidth vẫn giữ để tin nhắn quá dài thì xuống dòng
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      padding: (isSticker || isImage)
                          ? EdgeInsets.zero
                          : (isAudio
                          ? const EdgeInsets.all(4)
                          : const EdgeInsets.symmetric(horizontal: 14, vertical: 8)), // Chỉnh padding nhỏ lại xíu cho đẹp
                      decoration: (isSticker || isImage)
                          ? null
                          : BoxDecoration(
                          color: isMe ? null : receivedMsgBg,
                          gradient: isMe ? LinearGradient(colors: _currentTheme.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                          borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : (isLast ? 18 : 4)),
                              bottomRight: Radius.circular(isMe ? (isLast ? 18 : 4) : 18)
                          )
                      ),
                      child: finalBubbleContent, // Đã có IntrinsicWidth bên trong
                    ),

                    // Xử lý thời gian cho Sticker/Image (Giữ nguyên của bro)
                    if (isSticker || isImage)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                          child: Text(timeString, style: const TextStyle(fontSize: 10, color: Colors.white)),
                        ),
                      ),

                    // Reaction (Giữ nguyên của bro)
                    if (message.reaction != null)
                      Positioned(
                        bottom: -10,
                        right: isMe ? 0 : null,
                        left: isMe ? null : 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)),
                          child: Text(message.reaction!, style: const TextStyle(fontSize: 14)),
                        ),
                      )
                  ],
                ),
              ),
            ],
          ),
        ),
        // Avatar nhỏ báo đã xem (Giữ nguyên)
        if (isMe && isLast && message.isRead)
          Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 10, top: 2),
            child: CircleAvatar(radius: 8, backgroundImage: NetworkImage(_targetUser.avatarUrl ?? 'https://i.pravatar.cc/150')),
          ),
      ],
    );
  }






  Widget _buildEmptyState() {
    // Lấy màu chữ
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardColor;

    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Stack(alignment: Alignment.bottomRight, children: [CircleAvatar(radius: 50, backgroundImage: NetworkImage(_targetUser.avatarUrl ?? 'https://i.pravatar.cc/150')), Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)))]), const SizedBox(height: 16),
      Text(_getDisplayName(_targetUser), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)), // SỬA: Màu tên
      const SizedBox(height: 8), const Text("Hãy gửi một lời chào đến bạn bè!", style: TextStyle(color: Colors.grey)), const SizedBox(height: 24),
      ElevatedButton(onPressed: () { _textController.text = "Xin chào! 👋"; _handleSend(); },
          style: ElevatedButton.styleFrom(
              backgroundColor: cardColor, // SỬA: Màu nền nút
              foregroundColor: textColor, // SỬA: Màu chữ nút
              elevation: 0,
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
          ),
          child: const Text("👋 Vẫy tay chào"))]));
  }


  // --- HÀM BUILD CHÍNH ---
  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).user;
    BoxDecoration backgroundDecoration;
    if (_currentTheme.backgroundImage != null) {
      backgroundDecoration = BoxDecoration(
        image: DecorationImage(image: NetworkImage(_currentTheme.backgroundImage!), fit: BoxFit.cover),
      );
    } else {
      final bgGradient = _currentTheme.backgroundGradient ?? [Colors.white, Colors.white];
      backgroundDecoration = BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bgGradient),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildMessengerAppBar(),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: backgroundDecoration,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Consumer<MessageService>(
                    builder: (context, messageService, child) {
                      final messages = messageService.messagesCache[widget.conversationId] ?? [];
                      if (messages.isEmpty) return _buildEmptyState();

                      String? lastReadMessageId;
                      for (var m in messages) {
                        if (m.sender.id == currentUser?.id && m.isRead) {
                          lastReadMessageId = m.id;
                          break;
                        }
                      }
                      bool hasRenderedSeenStatus = false;

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.sender.id == currentUser?.id;

                          // --- 1. CHÈN ĐOẠN NÀY ĐỂ HIỂN THỊ LỜI MỜI GAME ---
                          if (message.type == 'game_invite') {
                            return GameInviteBubble(
                              message: message,
                              isMe: isMe,
                              onAccept: () {
                                // Gửi sự kiện chấp nhận lên server
                                final msgService = Provider.of<MessageService>(context, listen: false);
                                msgService.socket?.emit('accept_game_invite', {
                                  'fromUser': message.sender.id, // Người mời
                                  'toUser': currentUser?.id,     // Mình (Người nhận)
                                  'gameType': message.content,   // Loại game (caro/chess)
                                  'inviteMessageId': message.id  // <--- Gửi thêm cái này để server biết cập nhật tin nhắn nào
                                });
                              },
                              // 👇 THÊM DÒNG NÀY ĐỂ GỌI HÀM THU HỒI 👇
                              onRevoke: () {
                                // Gọi hàm thu hồi tin nhắn (Giống như thu hồi tin nhắn thường)
                                final msgService = Provider.of<MessageService>(context, listen: false);
                                msgService.revokeMessage(message.id, widget.conversationId);
                              },
                            );

                          }
                          // --------------------------------------------------

                          // === LOGIC CŨ CỦA BRO (GIỮ NGUYÊN) ===
                          bool showAvatar = true;
                          bool isFirstInGroup = true;
                          bool isLastInGroup = true;

                          if (index + 1 < messages.length && messages[index + 1].sender.id == message.sender.id) isFirstInGroup = false;
                          if (index - 1 >= 0 && messages[index - 1].sender.id == message.sender.id) {
                            showAvatar = false;
                            isLastInGroup = false;
                          }

                          bool showSeenStatus = false;
                          if (!hasRenderedSeenStatus && lastReadMessageId != null && message.id == lastReadMessageId && isMe) {
                            showSeenStatus = true;
                            hasRenderedSeenStatus = true;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Tin nhắn thường (Text, Ảnh, Audio...)
                              _buildMessengerBubble(message, isMe, showAvatar, isFirstInGroup, isLastInGroup),

                              if (showSeenStatus)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12, top: 2, bottom: 4),
                                  child: CircleAvatar(radius: 7, backgroundImage: NetworkImage(_targetUser.avatarUrl ?? 'https://i.pravatar.cc/150')),
                                ),
                            ],
                          );
                        },
                      );

                    },
                  ),
                ),
                _isRecording ? _buildRecordingUI() : _buildInputBar(),
                if (_showEmoji)
                  SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) => _onEmojiSelected(emoji),
                      config: Config(
                        checkPlatformCompatibility: false,
                        emojiViewConfig: EmojiViewConfig(
                          emojiSizeMax: 32 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                          columns: 7,
                          recentsLimit: 28,
                          backgroundColor: const Color(0xFFF2F2F2),
                          buttonMode: ButtonMode.MATERIAL,
                        ),
                        skinToneConfig: const SkinToneConfig(enabled: true, dialogBackgroundColor: Colors.white, indicatorColor: Colors.grey),
                        categoryViewConfig: const CategoryViewConfig(initCategory: Category.SMILEYS, backgroundColor: Color(0xFFF2F2F2), indicatorColor: Colors.blue, iconColor: Colors.grey, iconColorSelected: Colors.blue, backspaceColor: Colors.blue),
                        bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                        searchViewConfig: const SearchViewConfig(backgroundColor: Color(0xFFF2F2F2)),
                      ),
                    ),
                  ),

                // ===> HIỂN THỊ BẢNG STICKER NẾU ĐƯỢC BẬT <===
                if (_showSticker)
                  _buildStickerPicker(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



// --- CLASS AUDIO MESSAGE (Đã update Dark Mode & Gradient) ---
class AudioMessageBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final List<Color>? activeGradient;

  const AudioMessageBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
    this.activeGradient
  });

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}


class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });

    // Load file audio
    _audioPlayer.setSourceUrl(widget.audioUrl);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl));
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  // --- HÀM HELPER: FORMAT THỜI GIAN OFFLINE ---
  String _formatLastActive(DateTime? lastActive) {
    if (lastActive == null) return "Offline";

    final now = DateTime.now();
    // Chuyển lastActive về giờ địa phương
    final localTime = lastActive.toLocal();
    final diff = now.difference(localTime);

    if (diff.inMinutes < 1) return "Vừa truy cập";
    if (diff.inMinutes < 60) return "Hoạt động ${diff.inMinutes} phút trước";
    if (diff.inHours < 24) return "Hoạt động ${diff.inHours} giờ trước";
    if (diff.inDays < 7) return "Hoạt động ${diff.inDays} ngày trước";

    return "Hoạt động ${localTime.day}/${localTime.month}";
  }

  @override
  Widget build(BuildContext context) {
    // 1. Xác định chế độ tối
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. Màu cho tin nhắn người nhận
    final receivedBgColor = isDark ? const Color(0xFF3E4042) : const Color(0xFFE4E6EB);
    final receivedTextColor = isDark ? Colors.white : Colors.black87;

    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        // HIỂN THỊ GRADIENT CHO AUDIO
          gradient: widget.isMe && widget.activeGradient != null
              ? LinearGradient(colors: widget.activeGradient!)
              : null,
          // Màu nền động theo theme
          color: widget.isMe ? null : receivedBgColor,
          borderRadius: BorderRadius.circular(20)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                // Màu icon động
                color: widget.isMe ? Colors.white : receivedTextColor,
                size: 30
            ),
            onPressed: _togglePlay,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text(
              _duration.inSeconds == 0 ? "Loading..." : "${_formatTime(_position)} / ${_formatTime(_duration)}",
              style: TextStyle(
                // Màu chữ động
                  color: widget.isMe ? Colors.white : receivedTextColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 13
              )
          ),
        ],
      ),
    );
  }
}


// --- CLASS XEM ẢNH FULL SCREEN ---
class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0
        ),
        extendBodyBehindAppBar: true,
        body: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(20.0),
                minScale: 0.1,
                maxScale: 5.0,
                panEnabled: true,
                child: Center(
                    child: Hero(
                        tag: imageUrl,
                        child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, p) => p == null ? child : const CircularProgressIndicator(color: Colors.white),
                            errorBuilder: (ctx, err, stack) => const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.white, size: 50),
                                  Text("Lỗi tải ảnh", style: TextStyle(color: Colors.white))
                                ]
                            )
                        )
                    )
                )
            )
        )
    );
  }
}

// --- WIDGET LỜI MỜI GAME (Đã thêm nút Thu hồi) ---
class GameInviteBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback onAccept;
  final VoidCallback? onRevoke; // 1. Thêm callback thu hồi

  const GameInviteBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onAccept,
    this.onRevoke, // 2. Thêm vào constructor
  });

  @override
  Widget build(BuildContext context) {
    // 1. Kiểm tra xem game đã kết thúc chưa
    final isFinished = message.content.contains('_finished'); // Ví dụ: 'caro_finished'

    // Lấy tên game (bỏ đuôi _finished nếu có)
    String rawContent = message.content.replaceAll('_finished', '');
    String gameName = 'Game';
    if (rawContent == 'caro') gameName = 'Cờ Caro';
    else if (rawContent == 'chess') gameName = 'Cờ Vua';
    else if (rawContent == 'snake') gameName = 'Rắn Săn Mồi';

    // 2. Logic màu sắc
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color? cardColor;
    if (isFinished) {
      cardColor = isDark ? Colors.grey[900] : Colors.grey[300];
    } else {
      cardColor = isMe
          ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50])
          : (isDark ? Colors.grey[800] : Colors.white);
    }

    final borderColor = isFinished
        ? Colors.grey
        : (isMe ? Colors.blue : (isDark ? Colors.grey[700] : Colors.grey[300]));

    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isFinished ? textColor.withOpacity(0.6) : textColor.withOpacity(0.8);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor!, width: 1.5),
          boxShadow: [
            if (!isDark && !isFinished) BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))
          ]
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: isFinished ? Colors.grey : Colors.purpleAccent.withOpacity(0.2),
                    shape: BoxShape.circle
                ),
                child: Icon(Icons.sports_esports, size: 28, color: isFinished ? Colors.white : Colors.purpleAccent),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // Đổi text nếu game đã xong
                      isFinished
                          ? "Ván đấu đã kết thúc"
                          : (isMe ? "Bạn đã gửi lời mời" : "Lời mời thách đấu!"),
                      style: TextStyle(fontWeight: FontWeight.normal, fontSize: 14, color: subTextColor)
                  ),
                  Text(
                      gameName,
                      style: TextStyle(
                          color: isFinished ? subTextColor : (isDark ? Colors.purpleAccent : Colors.purple),
                          fontWeight: FontWeight.bold,
                          fontSize: 18
                      )
                  ),
                ],
              )
            ],
          ),

          // 3. LOGIC NÚT BẤM
          if (!isFinished) ...[
            const SizedBox(height: 12),

            // TRƯỜNG HỢP 1: NGƯỜI NHẬN -> Hiện nút CHẤP NHẬN
            if (!isMe)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: const Text("CHẤP NHẬN", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

            // TRƯỜNG HỢP 2: NGƯỜI GỬI -> Hiện nút HỦY LỜI MỜI
            if (isMe)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onRevoke, // Gọi hàm thu hồi
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: const Text("HỦY LỜI MỜI", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
          ]
        ],
      ),
    );
  }
}




