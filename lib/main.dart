import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MediaEditorApp());
}

class MediaEditorApp extends StatelessWidget {
  const MediaEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro Media Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  File? _selectedImage;
  File? _selectedVideo;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied ||
          await Permission.photos.isDenied ||
          await Permission.videos.isDenied) {
        await [
          Permission.storage,
          Permission.photos,
          Permission.videos,
          Permission.camera,
        ].request();
      }
    } else if (Platform.isIOS) {
      if (await Permission.photos.isDenied ||
          await Permission.videos.isDenied) {
        await [Permission.photos, Permission.videos, Permission.camera]
            .request();
      }
    }
  }

  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      _showPermissionDenied();
      return;
    }

    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _currentIndex = 1;
      });
    }
  }

  Future<void> _pickVideo() async {
    final status = await Permission.videos.request();
    if (!status.isGranted) {
      _showPermissionDenied();
      return;
    }

    final XFile? pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedVideo = File(pickedFile.path);
        _currentIndex = 2;
      });
    }
  }

  void _showPermissionDenied() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دسترسی لازم است'),
        content: const Text('لطفاً دسترسی به گالری را در تنظیمات گوشی فعال کنید'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('تنظیمات'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pro Media Editor'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _pickImage,
            tooltip: 'انتخاب عکس',
          ),
          IconButton(
            icon: const Icon(Icons.video_library),
            onPressed: _pickVideo,
            tooltip: 'انتخاب ویدیو',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const WelcomeScreen(onPickImage: _pickImage, onPickVideo: _pickVideo),
          if (_selectedImage != null)
            PhotoEditorScreen(
              imageFile: _selectedImage!,
              onDelete: () {
                setState(() {
                  _selectedImage = null;
                  _currentIndex = 0;
                });
              },
            ),
          if (_selectedVideo != null)
            VideoEditorScreen(
              videoFile: _selectedVideo!,
              onDelete: () {
                setState(() {
                  _selectedVideo = null;
                  _currentIndex = 0;
                });
              },
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black87,
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1 && _selectedImage == null) {
            _pickImage();
          } else if (index == 2 && _selectedVideo == null) {
            _pickVideo();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'خانه'),
          BottomNavigationBarItem(icon: Icon(Icons.image), label: 'عکس'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'ویدیو'),
        ],
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;

  const WelcomeScreen({super.key, required this.onPickImage, required this.onPickVideo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit, size: 100, color: Colors.deepPurpleAccent),
            const SizedBox(height: 20),
            const Text(
              'حرفه‌ای ویرایش‌کن عکس و ویدیو',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'فیلتر، متن، برچسب، برش، تنظیم رنگ و...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _welcomeButton(Icons.image, 'انتخاب عکس', onPickImage),
                const SizedBox(width: 20),
                _welcomeButton(Icons.video_library, 'انتخاب ویدیو', onPickVideo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        backgroundColor: Colors.deepPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}

// ==================== PHOTO EDITOR SCREEN ====================

class PhotoEditorScreen extends StatefulWidget {
  final File imageFile;
  final VoidCallback onDelete;

  const PhotoEditorScreen({super.key, required this.imageFile, required this.onDelete});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  late File _currentImage;
  final TextEditingController _textController = TextEditingController();
  Color _textColor = Colors.white;
  double _textSize = 28;
  List<Map<String, dynamic>> _overlays = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.imageFile;
  }

  Future<void> _openAdvancedEditor() async {
    try {
      final editedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditor(
            image: await _currentImage.readAsBytes(),
            saveImageAsFile: true,
          ),
        ),
      );

      if (editedImage != null) {
        setState(() {
          _currentImage = File.fromRawPath(editedImage);
        });
      }
    } catch (e) {
      _showSnackBar('خطا در باز کردن ویرایشگر: $e');
    }
  }

  void _addTextOverlay() {
    if (_textController.text.trim().isEmpty) {
      _showSnackBar('لطفاً متن را وارد کنید');
      return;
    }

    setState(() {
      _overlays.add({
        'text': _textController.text,
        'color': _textColor,
        'size': _textSize,
        'x': 50.0,
        'y': 100.0,
      });
    });
    _textController.clear();
    Navigator.pop(context);
    _showSnackBar('متن اضافه شد');
  }

  void _showTextDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('افزودن متن'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'متن خود را وارد کنید',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('سایز: '),
                  Expanded(
                    child: Slider(
                      value: _textSize,
                      min: 12,
                      max: 60,
                      onChanged: (val) => setState(() => _textSize = val),
                    ),
                  ),
                  Text('${_textSize.toInt()}'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('رنگ: '),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: _textColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.color_lens),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('انتخاب رنگ'),
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: _textColor,
                              onColorChanged: (color) => setState(() => _textColor = color),
                              pickerAreaHeightPercent: 0.7,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('تأیید'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: _addTextOverlay,
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showSnackBar('دسترسی به حافظه داده نشد');
        return;
      }

      final result = await GallerySaver.saveImage(
        _currentImage.path,
        albumName: "ProEditor",
      );
      
      if (result == true) {
        _showSnackBar('تصویر با موفقیت ذخیره شد');
      } else {
        _showSnackBar('خطا در ذخیره تصویر');
      }
    } catch (e) {
      _showSnackBar('خطا: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _shareImage() async {
    try {
      await Share.shareXFiles(
        [XFile(_currentImage.path)],
        text: 'ویرایش شده با Pro Media Editor',
      );
    } catch (e) {
      _showSnackBar('خطا در اشتراک‌گذاری');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایشگر عکس'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveImage),
          IconButton(icon: const Icon(Icons.share), onPressed: _shareImage),
          IconButton(icon: const Icon(Icons.delete), onPressed: widget.onDelete),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(_currentImage, fit: BoxFit.contain),
                ..._overlays.map((overlay) => Positioned(
                  left: overlay['x'],
                  top: overlay['y'],
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        overlay['x'] = (overlay['x'] + details.delta.dx).clamp(0.0, 300.0);
                        overlay['y'] = (overlay['y'] + details.delta.dy).clamp(0.0, 500.0);
                      });
                    },
                    child: Text(
                      overlay['text'],
                      style: TextStyle(
                        color: overlay['color'],
                        fontSize: overlay['size'],
                        fontWeight: FontWeight.bold,
                        shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolButton(Icons.edit, 'پیشرفته', _openAdvancedEditor),
                _toolButton(Icons.text_fields, 'متن', _showTextDialog),
                _toolButton(Icons.crop, 'برش', _openAdvancedEditor),
                _toolButton(Icons.filter, 'فیلتر', _openAdvancedEditor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 28, color: Colors.deepPurpleAccent),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

// ==================== VIDEO EDITOR SCREEN ====================

class VideoEditorScreen extends StatefulWidget {
  final File videoFile;
  final VoidCallback onDelete;

  const VideoEditorScreen({super.key, required this.videoFile, required this.onDelete});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late VideoPlayerController _controller;
  late Trimmer _trimmer;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller.initialize();
    _controller.setLooping(true);
    
    _trimmer = Trimmer();
    await _trimmer.loadVideo(videoFile: widget.videoFile);
    
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _changeSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      _controller.setPlaybackSpeed(speed);
    });
  }

  Future<void> _saveVideo() async {
    setState(() => _isSaving = true);
    
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showSnackBar('دسترسی به حافظه داده نشد');
        return;
      }

      final result = await GallerySaver.saveVideo(
        widget.videoFile.path,
        albumName: "ProEditor",
      );
      
      if (result == true) {
        _showSnackBar('ویدیو با موفقیت ذخیره شد');
      } else {
        _showSnackBar('خطا در ذخیره ویدیو');
      }
    } catch (e) {
      _showSnackBar('خطا: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _shareVideo() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.videoFile.path)],
        text: 'ویرایش شده با Pro Media Editor',
      );
    } catch (e) {
      _showSnackBar('خطا در اشتراک‌گذاری');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایشگر ویدیو'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveVideo),
          IconButton(icon: const Icon(Icons.share), onPressed: _shareVideo),
          IconButton(icon: const Icon(Icons.delete), onPressed: widget.onDelete),
        ],
      ),
      body: _isInitialized
          ? Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
                Container(
                  height: 100,
                  padding: const EdgeInsets.all(8),
                  child: VideoTrimmer(
                    trimmer: _trimmer,
                    onTrimEnd: (start, end) {
                      debugPrint('Trim: $start - $end');
                      _showSnackBar('برش ویدیو اعمال شد');
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.black87,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 48,
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: _togglePlay,
                      ),
                      const SizedBox(width: 20),
                      _speedButton(0.5),
                      _speedButton(1.0),
                      _speedButton(1.5),
                      _speedButton(2.0),
                    ],
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _speedButton(double speed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: () => _changeSpeed(speed),
        style: ElevatedButton.styleFrom(
          backgroundColor: _playbackSpeed == speed ? Colors.deepPurple : Colors.grey[800],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          minimumSize: const Size(50, 40),
        ),
        child: Text('${speed}x'),
      ),
    );
  }
}
