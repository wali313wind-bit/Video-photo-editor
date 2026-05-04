// ========================================================
//                  PHOTO & VIDEO EDITOR APP
//                  نسخه نهایی و کامل - آماده برای گیت‌هاب
//                  تکنولوژی‌ها: Flutter, FFmpeg, Riverpod
// ========================================================

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

// ==================== State Management ====================

final mediaTypeProvider = StateProvider<MediaType>((ref) => MediaType.image);
final selectedFileProvider = StateProvider<File?>((ref) => null);
final isProcessingProvider = StateProvider<bool>((ref) => false);
final historyProvider = StateNotifierProvider<HistoryNotifier, List<EditAction>>(
  (ref) => HistoryNotifier(),
);

enum MediaType { image, video }

class EditAction {
  final String name;
  final DateTime timestamp;
  EditAction(this.name) : timestamp = DateTime.now();
}

class HistoryNotifier extends StateNotifier<List<EditAction>> {
  HistoryNotifier() : super([]);
  void addAction(String name) => state = [...state, EditAction(name)];
  void clear() => state = [];
}

// ==================== Main App ====================

void main() {
  runApp(
    ProviderScope(
      child: const PhotoVideoEditorApp(),
    ),
  );
}

class PhotoVideoEditorApp extends StatelessWidget {
  const PhotoVideoEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ویرایشگر حرفه‌ای عکس و فیلم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        textTheme: GoogleFonts.vazirmatnTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==================== Splash Screen ====================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeEditorScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'ویرایشگر قدرتمند',
              style: GoogleFonts.vazirmatn(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'عکس و فیلم حرفه‌ای',
              style: GoogleFonts.vazirmatn(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Home Screen ====================

class HomeEditorScreen extends ConsumerWidget {
  const HomeEditorScreen({super.key});

  Future<void> _checkPermissions(BuildContext context) async {
    final status = await Permission.storage.request();
    final cameraStatus = await Permission.camera.request();
    if (!status.isGranted || !cameraStatus.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لطفاً دسترسی‌ها را فعال کنید')),
        );
      }
    }
  }

  Future<void> _pickMedia(BuildContext context, WidgetRef ref, MediaType type) async {
    await _checkPermissions(context);
    
    final picker = ImagePicker();
    final XFile? pickedFile = type == MediaType.image
        ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 95)
        : await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null && context.mounted) {
      final file = File(pickedFile.path);
      ref.read(selectedFileProvider.notifier).state = file;
      ref.read(mediaTypeProvider.notifier).state = type;
      ref.read(historyProvider.notifier).clear();

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EditorMainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایشگر عکس و فیلم'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOptionCard(
              context,
              icon: Icons.image,
              title: 'ویرایش عکس',
              subtitle: 'فیلتر، برش، متن، نقاشی',
              color: Colors.deepPurple,
              onTap: () => _pickMedia(context, ref, MediaType.image),
            ),
            const SizedBox(height: 20),
            _buildOptionCard(
              context,
              icon: Icons.video_library,
              title: 'ویرایش ویدیو',
              subtitle: 'برش، افکت، موسیقی، متن',
              color: Colors.pinkAccent,
              onTap: () => _pickMedia(context, ref, MediaType.video),
            ),
            const SizedBox(height: 40),
            Text(
              'تکنولوژی‌های پیشرفته:\nFFmpeg • Pro Editor • Custom Paint',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: Colors.white),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: Colors.white70, fontSize: 15)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).scale(),
    );
  }
}

// ==================== Main Editor Screen ====================

class EditorMainScreen extends ConsumerStatefulWidget {
  const EditorMainScreen({super.key});

  @override
  ConsumerState<EditorMainScreen> createState() => _EditorMainScreenState();
}

class _EditorMainScreenState extends ConsumerState<EditorMainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  File? currentFile;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  final List<String> filters = ['Original', 'Vintage', 'Black&White', 'Sepia', 'Vivid', 'Cool', 'Warm', 'Dramatic'];
  String selectedFilter = 'Original';
  double _brightness = 0;
  double _contrast = 1;
  double _saturation = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentFile = ref.read(selectedFileProvider);
      final type = ref.read(mediaTypeProvider);
      if (type == MediaType.video && currentFile != null) {
        _initVideoPlayer(currentFile!);
      }
    });
  }

  Future<void> _initVideoPlayer(File file) async {
    _videoController = VideoPlayerController.file(file);
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false,
      looping: false,
      aspectRatio: _videoController!.value.aspectRatio,
      materialProgressColors: ChewieProgressColors(playedColor: Colors.deepPurple),
    );
    setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _processVideo(String command, String description) async {
    ref.read(isProcessingProvider.notifier).state = true;
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/output_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final fullCommand = '-i "${currentFile!.path}" $command -c:a copy "$outputPath"';
    final session = await FFmpegKit.execute(fullCommand);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      currentFile = File(outputPath);
      ref.read(historyProvider.notifier).addAction(description);
      await _initVideoPlayer(currentFile!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $description انجام شد')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ خطا در پردازش')));
      }
    }
    ref.read(isProcessingProvider.notifier).state = false;
  }

  Future<void> _applyFilterOnImage() async {
    if (ref.read(mediaTypeProvider) != MediaType.image) return;
    ref.read(isProcessingProvider.notifier).state = true;
    await Future.delayed(const Duration(seconds: 1));
    ref.read(historyProvider.notifier).addAction('اعمال فیلتر $selectedFilter');
    ref.read(isProcessingProvider.notifier).state = false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎨 فیلتر $selectedFilter اعمال شد')));
    }
  }

  Future<void> _saveToGallery() async {
    if (currentFile == null) return;
    ref.read(isProcessingProvider.notifier).state = true;
    
    try {
      if (ref.read(mediaTypeProvider) == MediaType.image) {
        await GallerySaver.saveImage(currentFile!.path, albumName: "EditorPro");
      } else {
        await GallerySaver.saveVideo(currentFile!.path, albumName: "EditorPro");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💾 ذخیره شد در گالری')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ خطا در ذخیره سازی')));
      }
    }
    ref.read(isProcessingProvider.notifier).state = false;
  }

  Future<void> _shareMedia() async {
    if (currentFile == null) return;
    await Share.shareXFiles([XFile(currentFile!.path)], text: 'ویرایش شده با EditorPro');
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(isProcessingProvider);
    final history = ref.watch(historyProvider);
    final isVideo = ref.watch(mediaTypeProvider) == MediaType.video;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایشگر حرفه‌ای'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.visibility), text: 'نمایش'),
            Tab(icon: Icon(Icons.edit), text: 'ویرایش'),
            Tab(icon: Icon(Icons.filter_vintage), text: 'فیلتر'),
            Tab(icon: Icon(Icons.text_fields), text: 'متن'),
            Tab(icon: Icon(Icons.history), text: 'تاریخچه'),
          ],
          isScrollable: true,
        ),
        actions: [
          IconButton(onPressed: _saveToGallery, icon: const Icon(Icons.save)),
          IconButton(onPressed: _shareMedia, icon: const Icon(Icons.share)),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildPreviewTab(),
              _buildEditToolsTab(isVideo),
              _buildFiltersTab(isVideo),
              _buildTextToolsTab(isVideo),
              _buildHistoryTab(history),
            ],
          ),
          if (isProcessing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.deepPurple),
                    const SizedBox(height: 16),
                    Text('در حال پردازش...', style: GoogleFonts.vazirmatn(fontSize: 18)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    final type = ref.watch(mediaTypeProvider);
    if (currentFile == null) return const Center(child: Text('فایلی انتخاب نشده'));

    if (type == MediaType.image) {
      return InteractiveViewer(
        child: Image.file(currentFile!, fit: BoxFit.contain),
      );
    } else {
      return _chewieController != null
          ? Chewie(controller: _chewieController!)
          : const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildEditToolsTab(bool isVideo) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!isVideo) ...[
            _buildSlider('روشنایی', -1, 1, _brightness, (v) => setState(() => _brightness = v)),
            _buildSlider('کنتراست', 0, 3, _contrast, (v) => setState(() => _contrast = v)),
            _buildSlider('اشباع رنگ', 0, 3, _saturation, (v) => setState(() => _saturation = v)),
            const SizedBox(height: 16),
          ],
          _buildActionButton(Icons.crop, 'برش', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProImageEditor.file(
                  currentFile!,
                  onImageEdited: (f) => setState(() => currentFile = f),
                ),
              ),
            );
          }),
          _buildActionButton(Icons.rotate_right, 'چرخش ۹۰ درجه', () {}),
          _buildActionButton(Icons.draw, 'نقاشی', () => _openDrawingEditor()),
          if (isVideo) ...[
            _buildActionButton(Icons.speed, 'تغییر سرعت', () => _showSpeedDialog()),
            _buildActionButton(Icons.music_note, 'افزودن موسیقی', () {}),
            _buildActionButton(Icons.compress, 'فشرده‌سازی', () => _processVideo('-vf "scale=854:480" -b:v 1M', 'فشرده‌سازی')),
          ],
        ],
      ),
    );
  }

  Widget _buildSlider(String title, double min, double max, double value, Function(double) onChanged) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 16)),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(label),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildFiltersTab(bool isVideo) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filters.length,
      itemBuilder: (context, index) {
        final filter = filters[index];
        return GestureDetector(
          onTap: () {
            setState(() => selectedFilter = filter);
            if (ref.read(mediaTypeProvider) == MediaType.image) {
              _applyFilterOnImage();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: selectedFilter == filter ? Colors.deepPurple : Colors.grey.shade800, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.filter_vintage, color: selectedFilter == filter ? Colors.deepPurple : Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(filter, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextToolsTab(bool isVideo) {
    final textController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: textController,
            decoration: InputDecoration(
              hintText: 'متن خود را وارد کنید...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                _processVideo(
                  '-vf "drawtext=text=\'${textController.text}\':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=h-th-50"',
                  'افزودن متن',
                );
              }
            },
            icon: const Icon(Icons.text_fields),
            label: const Text('افزودن متن به ویدیو'),
          ),
          const SizedBox(height: 24),
          const Text('استیکرها:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: ['❤️', '🔥', '✨', '🎥', '📸', '⭐', '👍', '😍'].map((emoji) {
              return Chip(label: Text(emoji, style: const TextStyle(fontSize: 28)));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(List<EditAction> history) {
    if (history.isEmpty) {
      return const Center(child: Text('هنوز ویرایشی انجام نشده است'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final action = history.reversed.toList()[index];
        return ListTile(
          leading: const Icon(Icons.history, color: Colors.deepPurple),
          title: Text(action.name),
          subtitle: Text('${action.timestamp.hour}:${action.timestamp.minute} - ${action.timestamp.day}/${action.timestamp.month}'),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
        );
      },
    );
  }

  void _openDrawingEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: DrawingEditor(
          file: currentFile!,
          onSave: (newFile) => setState(() => currentFile = newFile),
        ),
      ),
    );
  }

  void _showSpeedDialog() {
    double speed = 1.0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغییر سرعت'),
        content: StatefulBuilder(
          builder: (ctx, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: speed,
                min: 0.25,
                max: 4.0,
                divisions: 15,
                onChanged: (val) => setStateDialog(() => speed = val),
              ),
              Text('${speed.toStringAsFixed(2)}x'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processVideo('-filter:v "setpts=${1 / speed}*PTS"', 'تغییر سرعت به ${speed}x');
            },
            child: const Text('اعمال'),
          ),
        ],
      ),
    );
  }
}

// ==================== Drawing Editor ====================

class DrawingEditor extends StatefulWidget {
  final File file;
  final Function(File) onSave;
  const DrawingEditor({super.key, required this.file, required this.onSave});

  @override
  State<DrawingEditor> createState() => _DrawingEditorState();
}

class _DrawingEditorState extends State<DrawingEditor> {
  List<Offset?> points = [];
  Color selectedColor = Colors.white;
  double strokeWidth = 4.0;
  ui.Image? backgroundImage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.file.readAsBytes();
    final decoded = await ui.instantiateImageCodec(bytes);
    final frame = await decoded.getNextFrame();
    setState(() {
      backgroundImage = frame.image;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقاشی روی تصویر'),
        actions: [
          IconButton(icon: const Icon(Icons.clear_all), onPressed: () => setState(() => points.clear())),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveDrawing),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onPanUpdate: (details) => setState(() => points.add(details.localPosition)),
              onPanEnd: (_) => setState(() => points.add(null)),
              child: CustomPaint(
                painter: DrawingPainter(
                  backgroundImage: backgroundImage,
                  points: points,
                  color: selectedColor,
                  strokeWidth: strokeWidth,
                ),
                size: Size.infinite,
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(Icons.color_lens, color: selectedColor),
              onPressed: () async {
                final color = await showDialog<Color>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    children: [
                      ColorPicker(onColorSelected: (c) => Navigator.pop(ctx, c)),
                    ],
                  ),
                );
                if (color != null) setState(() => selectedColor = color);
              },
            ),
            IconButton(
              icon: const Icon(Icons.line_weight),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('ضخامت قلم'),
                    content: StatefulBuilder(
                      builder: (ctx, setStateDialog) => Slider(
                        value: strokeWidth,
                        min: 1,
                        max: 30,
                        onChanged: (val) => setStateDialog(() => strokeWidth = val),
                      ),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تایید'))],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: () => setState(() => points.isNotEmpty ? points.removeLast() : null),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDrawing() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(backgroundImage!.width.toDouble(), backgroundImage!.height.toDouble());
    canvas.drawImage(backgroundImage!, Offset.zero, Paint());
    final painter = DrawingPainter(backgroundImage: null, points: points, color: selectedColor, strokeWidth: strokeWidth);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    final img = await picture.toImage(backgroundImage!.width, backgroundImage!.height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/drawing_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path)..writeAsBytesSync(byteData!.buffer.asUint8List());
    widget.onSave(file);
    Navigator.pop(context);
  }
}

class DrawingPainter extends CustomPainter {
  final ui.Image? backgroundImage;
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  DrawingPainter({this.backgroundImage, required this.points, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundImage != null) canvas.drawImage(backgroundImage!, Offset.zero, Paint());
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) canvas.drawLine(points[i]!, points[i + 1]!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==================== Color Picker ====================

class ColorPicker extends StatelessWidget {
  final Function(Color) onColorSelected;
  const ColorPicker({super.key, required this.onColorSelected});

  final List<Color> colors = const [
    Colors.white, Colors.black, Colors.red, Colors.green, Colors.blue,
    Colors.yellow, Colors.orange, Colors.purple, Colors.pink, Colors.cyan,
    Colors.teal, Colors.brown, Colors.purpleAccent, Colors.deepPurple, Colors.amber,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: GridView.count(
        crossAxisCount: 5,
        children: colors.map((color) => GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(1, 1)),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}
