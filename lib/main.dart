import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';

void main() => runApp(VideoEditorApp());

class VideoEditorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Video Editor',
        theme: ThemeData.dark(),
        home: HomeScreen(),
        debugShowCheckedModeBanner: false,
      );
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Editor Pro')),
        body: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildButton(Icons.photo, 'Edit Photo', () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(type: MediaType.image)))),
              SizedBox(height: 20),
              _buildButton(Icons.video_library, 'Edit Video', () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(type: MediaType.video)))),
            ],
          ),
        ),
      );

  Widget _buildButton(IconData icon, String label, VoidCallback onTap) => ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 60)),
      );
}

enum MediaType { image, video }

class EditorScreen extends StatefulWidget {
  final MediaType type;
  EditorScreen({required this.type});

  @override
  _EditorScreenState createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  File? _file;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final List<String> filters = ['Original', 'Vintage', 'BW', 'Sepia', 'Vivid'];
  String selectedFilter = 'Original';

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final picked = widget.type == MediaType.image ? await picker.pickImage(source: ImageSource.gallery) : await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _file = File(picked.path));
      if (widget.type == MediaType.video) {
        _videoController = VideoPlayerController.file(_file!);
        await _videoController!.initialize();
        _chewieController = ChewieController(videoPlayerController: _videoController!, autoPlay: false, looping: false);
        setState(() {});
      }
    }
  }

  Future<void> _saveToGallery() async {
    if (_file != null) {
      widget.type == MediaType.image ? await GallerySaver.saveImage(_file!.path) : await GallerySaver.saveVideo(_file!.path);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to gallery')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.type == MediaType.image ? 'Photo Editor' : 'Video Editor'), actions: [IconButton(onPressed: _saveToGallery, icon: Icon(Icons.save))]),
        body: _file == null
            ? Center(child: ElevatedButton(onPressed: _pickMedia, child: Text('Select ${widget.type == MediaType.image ? 'Photo' : 'Video'}')))
            : Column(
                children: [
                  Expanded(
                    child: widget.type == MediaType.image
                        ? Image.file(_file!)
                        : _chewieController != null
                            ? Chewie(controller: _chewieController!)
                            : Center(child: CircularProgressIndicator()),
                  ),
                  if (widget.type == MediaType.image)
                    Container(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: filters.length,
                        itemBuilder: (ctx, i) => GestureDetector(
                          onTap: () => setState(() => selectedFilter = filters[i]),
                          child: Container(
                            margin: EdgeInsets.all(8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(border: Border.all(color: selectedFilter == filters[i] ? Colors.deepPurple : Colors.grey), borderRadius: BorderRadius.circular(12)),
                            child: Text(filters[i]),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(onPressed: _pickMedia, icon: Icon(Icons.add_photo_alternate)),
                      IconButton(onPressed: () => Share.shareXFiles([XFile(_file!.path)]), icon: Icon(Icons.share)),
                    ],
                  ),
                ],
              ),
      );
}
