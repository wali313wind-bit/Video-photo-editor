import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'آتلیه حرفه‌ای',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF1E1E2F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const ImageEditorScreen(),
    );
  }
}

class ImageEditorScreen extends StatefulWidget {
  const ImageEditorScreen({super.key});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  File? _imageFile;
  ui.Image? _originalImage;
  ui.Image? _editedImage;

  // تنظیمات فیلترهای پایه
  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 0.0;
  double _exposure = 0.0;

  // فیلترهای آماده
  String _selectedFilter = 'none';

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDefaultImage();
  }

  Future<void> _loadDefaultImage() async {
    final ByteData data = await rootBundle.load('assets/default_image.png');
    final Uint8List bytes = data.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    setState(() {
      _originalImage = frameInfo.image;
      _editedImage = frameInfo.image;
    });
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
    await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final File imageFile = File(pickedFile.path);
      final Uint8List bytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      setState(() {
        _imageFile = imageFile;
        _originalImage = frameInfo.image;
        _editedImage = frameInfo.image;
        _resetFilters(); // با بارگذاری عکس جدید، تنظیمات ریست بشن
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _brightness = 0.0;
      _contrast = 0.0;
      _saturation = 0.0;
      _exposure = 0.0;
      _selectedFilter = 'none';
    });
  }

  ui.ColorFilter _getColorFilter() {
    // در اینجا باید ماتریس‌های ColorFilter رو برای ترکیب brightness, contrast, saturation و exposure بسازیم
    // اما برای سادگی و جلوگیری از خطاهای احتمالی، فعلاً فقط فیلترهای آماده رو پیاده می‌کنیم.
    // برای نسخه نهایی، می‌تونیم از کتابخونه‌ای مثل matrix_4 یا کدهای پیشرفته‌تر استفاده کنیم.

    switch (_selectedFilter) {
      case 'grayscale':
        return const ui.ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]);
      case 'sepia':
        return const ui.ColorFilter.matrix(<double>[
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0,     0,     0,     1, 0,
        ]);
      case 'invert':
        return const ui.ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]);
      case 'cool':
        return const ui.ColorFilter.matrix(<double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 40,
          0, 0, 0, 1, 0,
        ]);
      case 'warm':
        return const ui.ColorFilter.matrix(<double>[
          1, 0, 0, 0, 40,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      default:
        return const ui.ColorFilter.mode(Colors.transparent, BlendMode.src);
    }
  }

  Widget _buildImageView() {
    if (_editedImage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: RawImage(
        image: _editedImage,
        fit: BoxFit.contain,
        color: null,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Future<void> _saveImage() async {
    if (_editedImage == null) return;

    // درخواست مجوز ذخیره‌سازی
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      // در اندروید 13+ باید مجوز دسترسی به تصاویر رو جداگانه درخواست کنین
      if (!await Permission.photos.request().isGranted) {
        return;
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImage(_editedImage!, Offset.zero, paint);
    final picture = recorder.endRecording();
    final img = await picture.toImage(_editedImage!.width, _editedImage!.height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final result = await ImageGallerySaver.saveImage(byteData.buffer.asUint8List());
      if (result['isSuccess']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تصویر با موفقیت ذخیره شد.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('آتلیه حرفه‌ای'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveImage,
            tooltip: 'ذخیره در گالری',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: _buildImageView(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A40),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // دکمه انتخاب عکس
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('انتخاب عکس از گالری'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // فیلترهای آماده
                  const Text(
                    'فیلترهای سینمایی',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('بدون فیلتر', 'none'),
                      _buildFilterChip('سیاه‌وسفید', 'grayscale'),
                      _buildFilterChip('سپیا', 'sepia'),
                      _buildFilterChip('نگاتیو', 'invert'),
                      _buildFilterChip('سرد', 'cool'),
                      _buildFilterChip('گرم', 'warm'),
                    ],
                  ),

                  const Divider(height: 32, color: Colors.grey),

                  // دکمه‌های برش و چرخش
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildActionButton(
                        icon: Icons.crop,
                        label: 'برش',
                        onTap: () {
                          // TODO: پیاده‌سازی صفحه برش
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.rotate_left,
                        label: 'چرخش',
                        onTap: () {
                          // TODO: پیاده‌سازی چرخش
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.flip,
                        label: 'آینه',
                        onTap: () {
                          // TODO: پیاده‌سازی آینه
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterId) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == filterId,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? filterId : 'none';
        });
      },
      backgroundColor: Colors.grey[800],
      selectedColor: Colors.amber[700],
      labelStyle: const TextStyle(color: Colors.white),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
