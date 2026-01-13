// File: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_maps/services/game_service.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import các service
import 'services/local_notification_service.dart';
import 'services/auth_service.dart';
import 'services/post_service.dart';
import 'services/story_service.dart';
import 'services/user_service.dart';
import 'services/navigation_service.dart';
import 'services/notification_service.dart';
import 'services/reel_service.dart';
import 'services/social_search_service.dart';
import 'services/message_service.dart';
import 'services/theme_service.dart';

// Import màn hình
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("⚠️ Warning: Không tìm thấy file .env, dùng cấu hình mặc định.");
  }

  await LocalNotificationService.initialize();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  timeago.setLocaleMessages('vi', timeago.ViMessages());

  runApp(const MyApp());
}

// 1. MyApp: Khởi tạo Provider
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, ReelService>(
          create: (context) => ReelService(Provider.of<AuthService>(context, listen: false)),
          update: (context, auth, previous) => previous!..updateAuth(auth),
        ),

        // 2. THÊM PROVIDER GAME SERVICE Ở ĐÂY
        // Vì GameService không kế thừa ChangeNotifier nên dùng ProxyProvider (không cần ChangeNotifierProxyProvider)
        // Hoặc nếu bro có `with ChangeNotifier` trong GameService thì dùng ChangeNotifierProxyProvider
        ProxyProvider<AuthService, GameService>(
          // Mỗi khi AuthService thay đổi (ví dụ: login thành công -> có token),
          // nó sẽ tạo lại GameService mới với AuthService đó.
          update: (_, authService, __) => GameService(authService),
        ),
        ChangeNotifierProxyProvider<AuthService, PostService>(
          create: (context) => PostService(Provider.of<AuthService>(context, listen: false)),
          update: (context, auth, previous) => previous!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthService, StoryService>(
          create: (context) => StoryService(Provider.of<AuthService>(context, listen: false)),
          update: (context, auth, previous) => (previous?..updateAuth(auth)) ?? StoryService(auth),
        ),
        ProxyProvider<AuthService, UserService>(
          update: (_, authService, __) => UserService(authService),
        ),
        ChangeNotifierProxyProvider<AuthService, NotificationService>(
          create: (context) => NotificationService(Provider.of<AuthService>(context, listen: false)),
          update: (context, auth, previous) => previous!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthService, SocialSearchService>(
          create: (ctx) => SocialSearchService(Provider.of<AuthService>(ctx, listen: false)),
          update: (ctx, auth, previous) => SocialSearchService(auth),
        ),
        ChangeNotifierProxyProvider<AuthService, MessageService>(
          create: (context) => MessageService(Provider.of<AuthService>(context, listen: false)),
          update: (context, auth, previous) => previous!..updateAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => NavigationService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      // Gọi Widget cấu hình App
      child: const MyAppConfiguration(),
    );
  }
}

// 2. MyAppConfiguration: Cấu hình MaterialApp và Theme
// (Không xử lý Lifecycle ở đây để tránh lỗi Context)
class MyAppConfiguration extends StatelessWidget {
  const MyAppConfiguration({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      title: 'XmasOcial',
      debugShowCheckedModeBanner: false,
      themeMode: themeService.themeMode,

      // --- LIGHT THEME ---
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        cardColor: Colors.white,
        dividerColor: Colors.grey[300],
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),

      // --- DARK THEME ---
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF18191A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF242526),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFE4E6EB)),
          titleTextStyle: TextStyle(color: Color(0xFFE4E6EB), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        cardColor: const Color(0xFF242526),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: const Color(0xFF3A3B3C),
          filled: true,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFB0B3B8)),
        dividerColor: const Color(0xFF3E4042),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFE4E6EB)),
          bodyMedium: TextStyle(color: Color(0xFFE4E6EB)),
          titleMedium: TextStyle(color: Color(0xFFE4E6EB)),
          titleSmall: TextStyle(color: Color(0xFFB0B3B8)),
        ),
      ),

      // 👇 BỌC AppLifecycleManager Ở ĐÂY
      // Vì nó nằm trong MaterialApp, nó CHẮC CHẮN truy cập được Provider từ context
      home: const AppLifecycleManager(
        child: AuthGate(),
      ),
    );
  }
}

// 3. WIDGET MỚI: CHUYÊN XỬ LÝ LIFECYCLE VÀ AUTO LOGIN
class AppLifecycleManager extends StatefulWidget {
  final Widget child;
  const AppLifecycleManager({super.key, required this.child});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Auto Login khi app khởi chạy
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check context.mounted để an toàn
      if (mounted) {
        Provider.of<AuthService>(context, listen: false).tryAutoLogin();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Logic cập nhật trạng thái hoạt động
    if (state == AppLifecycleState.resumed && mounted) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        if (authService.isLoggedIn) {
          print("🟢 App Resumed: Cập nhật trạng thái hoạt động...");
          authService.updateLastActive();
        }
      } catch (e) {
        print("⚠️ Lỗi updateLastActive: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
