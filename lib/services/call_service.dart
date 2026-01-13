// lib/services/call_service.dart
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import '../config/app_config.dart';

class CallService {
  static void initCallInvitationService(String userID, String userName) {
    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: AppConfig.zegoAppId,
      appSign: AppConfig.zegoAppSign,
      userID: userID,
      userName: userName,
      plugins: [ZegoUIKitSignalingPlugin()],
      // FIX LỖI: Cấu hình nhạc chuông ở đây cho toàn bộ Service
      ringtoneConfig: ZegoCallRingtoneConfig(
        incomingCallPath: "assets/ringtone.mp3",
        outgoingCallPath: "assets/ringtone.mp3",
      ),
      // THÊM ĐOẠN NÀY VÀO DƯỚI RINGTONECONFIG:
      notificationConfig: ZegoCallInvitationNotificationConfig(
        androidNotificationConfig: ZegoAndroidNotificationConfig(
          channelID: "zego_video_call",
          channelName: "Video Call",
          sound: "ringtone", // Tên file nhạc chuông (không có đuôi .mp3)
          icon: "call", // Tên icon trong folder drawable (nếu có)
        ),
      ),
    );
  }

  static void uninitCallInvitationService() {
    ZegoUIKitPrebuiltCallInvitationService().uninit();
  }

  static Widget makeCallPage({
    required String callID,
    required String userID,
    required String userName,
    required dynamic messageService,
    required String targetUserId,
    String? targetAvatar,
    String? myAvatar,
    bool isVideo = true,
  }) {
    final config = isVideo
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();
    // --- FIX LỖI & TỰ ĐỘNG BẬT LOA NGOÀI ---

    // 1. Đối với Video Call, Zego thường mặc định loa ngoài.
    // 2. Đối với Voice Call, ta ép dùng loa ngoài bằng cách sau:
    config.useSpeakerWhenJoining = true;
    // Cấu hình thanh Menu trên (Top Menu Bar)
    config.topMenuBarConfig.isVisible = true;
    config.topMenuBarConfig.buttons = [
      ZegoCallMenuBarButtonName.showMemberListButton, // Nút xem danh sách người trong room
    ];

    // Nếu version của bro không nhận thuộc tính trên, hãy dùng audioVideoViewConfig
    config.audioVideoViewConfig.useVideoViewAspectFill = true;

    // Thay vì dùng config.audio (bị lỗi), hãy dùng trực tiếp nếu có hoặc bỏ qua
    // Vì mặc định Zego đã có khử nhiễu tốt rồi.
    try {
      config.audioVideoViewConfig.useVideoViewAspectFill = true;
    } catch (e) {}


    // 1. Cấu hình Camera/Mic
    config.turnOnCameraWhenJoining = isVideo;
    config.turnOnMicrophoneWhenJoining = true;

    // FIX LỖI 'backgroundColor': Thay bằng việc dùng Container làm lớp nền trong avatarBuilder
    // và thiết lập lớp phủ trong suốt
    config.audioVideoViewConfig.foregroundBuilder = (context, size, user, extraInfo) {
      return const SizedBox.shrink();
    };

    // 2. Custom Giao diện Avatar & Card (Phủ đen nền để tiễn màu xám)
    config.avatarBuilder = (BuildContext context, Size size, dynamic user, Map extraInfo) {
      if (extraInfo['is_video_on'] == true && isVideo) {
        return const SizedBox.shrink();
      }

      bool isMe = user?.id == userID;
      String currentAvatar = isMe
          ? (myAvatar ?? "https://ui-avatars.com/api/?name=$userName&background=random")
          : (targetAvatar ?? "https://www.w3schools.com/howto/img_avatar.png");
      String currentName = isMe ? userName : (user?.name ?? "Người dùng");

      return Container(
        color: const Color(0xFF121212), // Đây chính là cách thay thế backgroundColor
        child: Center(
          child: FittedBox(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 45),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: const Color(0xFF1E1E1E).withOpacity(0.85),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isVideo ? Colors.blueAccent : Colors.greenAccent,
                          width: 3
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isVideo ? Colors.blueAccent : Colors.greenAccent).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ],
                      image: DecorationImage(
                        image: NetworkImage(currentAvatar),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    currentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          Icons.graphic_eq,
                          color: isVideo ? Colors.blueAccent : Colors.greenAccent,
                          size: 18
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isVideo ? "Video Calling..." : "Voice Calling...",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    // 3. Tùy chỉnh thanh Menu
    config.bottomMenuBarConfig.buttons = [
      ZegoCallMenuBarButtonName.toggleMicrophoneButton,
      ZegoCallMenuBarButtonName.hangUpButton,
      ZegoCallMenuBarButtonName.switchAudioOutputButton,
      if (isVideo) ZegoCallMenuBarButtonName.toggleCameraButton,
    ];

    return ZegoUIKitPrebuiltCall(
      appID: AppConfig.zegoAppId,
      appSign: AppConfig.zegoAppSign,
      userID: userID,
      userName: userName,
      callID: callID,
      config: config,
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (event, defaultAction) {
          messageService.socket?.emit('call_ended', {'to': targetUserId, 'room': callID});
          defaultAction.call();
        },
      ),
    );
  }
}
