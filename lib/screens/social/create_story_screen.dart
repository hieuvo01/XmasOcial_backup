// File: lib/screens/social/create_story_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../services/story_service.dart';

class CreateStoryScreen extends StatefulWidget {
  final VoidCallback? onPostCreated;
  const CreateStoryScreen({super.key, this.onPostCreated});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();

  // Style cho Text Story
  final List<String> _styles = ['blue_gradient', 'red_gradient', 'green_gradient', 'black'];
  String _currentStyle = 'blue_gradient';

  // File Media (Ảnh/Video)
  File? _selectedFile;
  bool _isVideo = false;
  VideoPlayerController? _videoController;

  // === AUDIO & DEEZER STATE ===
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _selectedMusicUrl;
  String? _selectedMusicName;
  String? _previewingUrl;
  bool _isPlayingAudio = false;

  List<dynamic> _onlineMusicList = [];
  bool _isLoadingMusic = false;
  Timer? _debounce;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _videoController?.dispose();
    _audioPlayer.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // 👇 HÀM MỞ TRÌNH CHỈNH SỬA ẢNH GIỐNG FACEBOOK
  Future<void> _openImageEditor(File originalFile) async {
    try {
      // 1. Đọc file ảnh gốc thành bytes
      final Uint8List imageData = await originalFile.readAsBytes();

      // 2. Mở trình Editor
      final editedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditor(
            image: imageData, // Truyền ảnh gốc vào
          ),
        ),
      );

      // 3. Nếu người dùng bấm "Lưu" (editedImage khác null)
      if (editedImage != null) {
        // Tạo file tạm để lưu ảnh đã sửa
        final tempDir = await getTemporaryDirectory();
        final editedFile = await File(
          '${tempDir.path}/edited_story_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ).create();

        // Ghi dữ liệu đã sửa vào file
        await editedFile.writeAsBytes(editedImage);

        // Cập nhật giao diện
        setState(() {
          _selectedFile = editedFile;
        });
      }
    } catch (e) {
      debugPrint("Lỗi chỉnh sửa ảnh: $e");
    }
  }


  Future<void> _pickMedia(bool isVideo) async {
    final picker = ImagePicker();
    final XFile? pickedFile = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File file = File(pickedFile.path);

      // 👇 NẾU LÀ ẢNH THÌ MỞ EDITOR
      if (!isVideo) {
        // Cập nhật file tạm thời để tránh null
        setState(() {
          _selectedFile = file;
          _isVideo = false;
          _videoController?.dispose();
          _videoController = null;
        });

        // Gọi hàm mở editor
        await _openImageEditor(file);
      }
      // 👇 NẾU LÀ VIDEO THÌ GIỮ NGUYÊN LOGIC CŨ
      else {
        setState(() {
          _selectedFile = file;
          _isVideo = true;
          _videoController?.dispose();
          _videoController = null;
        });

        _videoController = VideoPlayerController.file(_selectedFile!)
          ..initialize().then((_) {
            setState(() {});
            _videoController!.play();
            _videoController!.setLooping(true);
          });
      }
    }
  }


  Future<void> _searchMusic(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _isLoadingMusic = true; });
    try {
      final url = Uri.parse('https://api.deezer.com/search?q=$query&limit=20');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() { _onlineMusicList = data['data']; });
      }
    } catch (e) {
      debugPrint("Lỗi tìm nhạc: $e");
    } finally {
      setState(() { _isLoadingMusic = false; });
    }
  }

  Future<void> _playPreview(String url) async {
    try {
      if (_previewingUrl == url && _isPlayingAudio) {
        await _audioPlayer.pause();
        setState(() { _isPlayingAudio = false; });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
        setState(() { _previewingUrl = url; _isPlayingAudio = true; });
      }
    } catch (e) {
      debugPrint("Lỗi phát nhạc: $e");
    }
  }

  void _showMusicPicker() {
    setState(() { _onlineMusicList = []; });
    TextEditingController searchCtrl = TextEditingController();

    // 👇 Lấy theme hiện tại để check Dark Mode
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor, // 👇 Màu nền dynamic
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  Text('Chọn nhạc nền', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    style: TextStyle(color: textColor), // 👇 Màu chữ input
                    decoration: InputDecoration(
                        hintText: 'Tìm bài hát (Sơn Tùng, Chill, ...)',
                        hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100] // 👇 Màu nền input dynamic
                    ),
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () async {
                        await _searchMusic(value);
                        setModalState(() {});
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _isLoadingMusic
                        ? const Center(child: CupertinoActivityIndicator())
                        : _onlineMusicList.isEmpty
                        ? Center(child: Text("Nhập tên bài hát...", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey)))
                        : ListView.builder(
                      itemCount: _onlineMusicList.length,
                      itemBuilder: (context, index) {
                        final song = _onlineMusicList[index];
                        final previewUrl = song['preview'];
                        final isSelected = _selectedMusicUrl == previewUrl;
                        final isPreviewing = _previewingUrl == previewUrl && _isPlayingAudio;

                        return ListTile(
                          leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(song['album']['cover_small'], width: 40, height: 40)),
                          title: Text(song['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          subtitle: Text(song['artist']['name'], maxLines: 1, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(isPreviewing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                                color: Colors.blue,
                                onPressed: () async {
                                  await _playPreview(previewUrl);
                                  setModalState(() {});
                                  setState(() {});
                                },
                              ),
                              if (isSelected) const Icon(Icons.check_circle, color: Colors.green)
                              else ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white : Colors.black, // 👇 Nút chọn đảo màu
                                    shape: const StadiumBorder()
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedMusicUrl = previewUrl;
                                    _selectedMusicName = "${song['title']} - ${song['artist']['name']}";
                                  });
                                  _audioPlayer.stop();
                                  Navigator.pop(context);
                                },
                                child: Text('Chọn', style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 12)),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _audioPlayer.stop();
      setState(() { _isPlayingAudio = false; _previewingUrl = null; });
    });
  }

  Future<void> _submitStory() async {
    if (_isUploading) return;

    final storyService = Provider.of<StoryService>(context, listen: false);
    setState(() => _isUploading = true);

    try {
      if (_tabController.index == 0) {
        if (_selectedFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn ảnh hoặc video")));
          return;
        }
        await storyService.createStory(
          mediaType: _isVideo ? 'video' : 'image',
          mediaFile: _selectedFile!,
          musicUrl: _selectedMusicUrl,
          musicName: _selectedMusicName,
        );
      } else {
        if (_textController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập nội dung")));
          return;
        }
        await storyService.createStory(
            mediaType: 'text',
            text: _textController.text,
            style: _currentStyle,
            musicUrl: _selectedMusicUrl,
            musicName: _selectedMusicName
        );
      }

      if (mounted) {
        widget.onPostCreated?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đăng Story thành công!")));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 👇 Lấy biến theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text("Tạo Story", style: TextStyle(color: textColor)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600], // 👇 Tab bar màu dynamic
          tabs: const [
            Tab(text: "Ảnh / Video"),
            Tab(text: "Văn bản"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMediaTab(isDark),
          _buildTextTab(isDark),
        ],
      ),
    );
  }

  Widget _buildMusicSticker() {
    if (_selectedMusicName == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(top: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
      decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.15), // Tăng độ đậm chút cho dark mode
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withOpacity(0.5))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note, size: 16, color: Colors.blue),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _selectedMusicName!,
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: () => setState(() { _selectedMusicUrl = null; _selectedMusicName = null; }),
            child: Icon(Icons.close, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey),
          )
        ],
      ),
    );
  }

  Widget _buildMediaTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 350,
            width: double.infinity,
            // 👇 Background placeholder đổi màu theo theme
            decoration: BoxDecoration(color: isDark ? Colors.grey[850] : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _selectedFile == null
                    ? Icon(Icons.add_photo_alternate, size: 50, color: isDark ? Colors.grey[600] : Colors.grey)
                    : _isVideo
                    ? (_videoController != null && _videoController!.value.isInitialized
                    ? AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!))
                    : const CircularProgressIndicator())
                    : Image.file(_selectedFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 👇 Dùng FilledButton.tonal hoặc ElevatedButton style dynamic
              ElevatedButton.icon(
                onPressed: () => _pickMedia(false),
                icon: const Icon(Icons.photo),
                label: const Text("Ảnh"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _pickMedia(true),
                icon: const Icon(Icons.videocam),
                label: const Text("Video"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          _buildMusicSticker(),
          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: _showMusicPicker,
            icon: const Icon(Icons.music_note),
            label: Text(_selectedMusicName == null ? "Thêm nhạc nền" : "Đổi nhạc"),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black,
              side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
            ),
          ),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submitStory,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Đăng Story", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 350,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: _getGradient(_currentStyle),
              borderRadius: BorderRadius.circular(12),
              // Thêm box shadow nhẹ để tách biệt khỏi nền đen nếu trùng màu
              boxShadow: isDark ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ] : null,
            ),
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: TextField(
              controller: _textController,
              textAlign: TextAlign.center,
              // Luôn dùng màu trắng cho text vì nền là Gradient màu
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.5, // Tăng chiều cao dòng chút cho đẹp
              ),
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "Nhập nội dung...",
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                filled: false, // 👇 QUAN TRỌNG: Đảm bảo không có nền màu đen/xám chèn vào
                contentPadding: EdgeInsets.zero,
              ),
              // Đổi màu con trỏ thành trắng cho dễ nhìn trên nền màu
              cursorColor: Colors.white,
            ),

          ),
          const SizedBox(height: 20),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _styles.map((style) => GestureDetector(
                onTap: () => setState(() => _currentStyle = style),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    gradient: _getGradient(style),
                    // 👇 Border màu trắng nếu nền tối, đen nếu nền sáng
                    border: _currentStyle == style
                        ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3)
                        : null,
                    shape: BoxShape.circle,
                  ),
                ),
              )).toList(),
            ),
          ),

          const SizedBox(height: 10),
          _buildMusicSticker(),
          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: _showMusicPicker,
            icon: const Icon(Icons.music_note),
            label: Text(_selectedMusicName == null ? "Thêm nhạc nền" : "Đổi nhạc"),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black,
              side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
            ),
          ),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submitStory,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Đăng", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _getGradient(String styleName) {
    switch (styleName) {
      case 'red_gradient': return const LinearGradient(colors: [Colors.orange, Colors.red]);
      case 'green_gradient': return const LinearGradient(colors: [Colors.lightGreen, Colors.green]);
      case 'black': return const LinearGradient(colors: [Colors.grey, Colors.black]);
      case 'blue_gradient': default: return const LinearGradient(colors: [Colors.cyan, Colors.blue]);
    }
  }
}
