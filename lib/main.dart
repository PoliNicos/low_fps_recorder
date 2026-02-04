import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit_config.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(theme: ThemeData.dark(), home: LowFPSStreamer(cameras: cameras)));
}

class LowFPSStreamer extends StatefulWidget {
  final List<CameraDescription> cameras;
  const LowFPSStreamer({super.key, required this.cameras});
  @override
  State<LowFPSStreamer> createState() => _LowFPSStreamerState();
}

class _LowFPSStreamerState extends State<LowFPSStreamer> {
  CameraController? _controller;
  bool _isRecording = false;
  ResolutionPreset _currentRes = ResolutionPreset.medium;
  String? _pipePath;

  final Map<ResolutionPreset, String> _resSizes = {
    ResolutionPreset.low: "320x240",
    ResolutionPreset.medium: "720x480",
    ResolutionPreset.high: "1280x720",
  };

  @override
  void initState() { super.initState(); _initCam(_currentRes); }

  Future<void> _initCam(ResolutionPreset res) async {
    _controller = CameraController(widget.cameras[0], res, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Uint8List _processYUV420(CameraImage img) {
    final int ySize = img.width * img.height;
    final int uvSize = (img.width / 2).floor() * (img.height / 2).floor();
    final result = Uint8List(ySize + 2 * uvSize);
    result.setRange(0, ySize, img.planes[0].bytes);
    result.setRange(ySize, ySize + img.planes[1].bytes.length, img.planes[1].bytes);
    result.setRange(ySize + img.planes[1].bytes.length, result.length, img.planes[2].bytes);
    return result;
  }

  void _action() async {
    if (_isRecording) {
      await _controller!.stopImageStream();
      if (_pipePath != null) FFmpegKitConfig.closeCustomNamedPipe(_pipePath!);
      setState(() => _isRecording = false);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final outPath = "${dir.path}/2fps_${DateTime.now().millisecondsSinceEpoch}.mp4";
      _pipePath = await FFmpegKitConfig.registerNewCustomNamedPipe("vidpipe");
      
      String cmd = "-f rawvideo -pix_fmt yuv420p -s ${_resSizes[_currentRes]} -r 2 -i $_pipePath -c:v libx264 -preset ultrafast -y $outPath";
      FFmpegKit.executeAsync(cmd);

      int frameCount = 0;
      await _controller!.startImageStream((image) {
        frameCount++;
        if (frameCount % 15 == 0 && _pipePath != null) {
          FFmpegKitConfig.writeToDefaultPipe(_pipePath!, _processYUV420(image));
        }
      });
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) return const Scaffold();
    return Scaffold(
      appBar: AppBar(title: const Text("2FPS Smart Cam"), actions: [
        DropdownButton<ResolutionPreset>(
          value: _currentRes,
          items: _resSizes.keys.map((r) => DropdownMenuItem(value: r, child: Text(r.name.toUpperCase()))).toList(),
          onChanged: _isRecording ? null : (r) { setState(() => _currentRes = r!); _initCam(r!); },
        )
      ]),
      body: Stack(children: [
        CameraPreview(_controller!),
        Positioned(bottom: 50, left: 0, right: 0, child: Center(
          child: FloatingActionButton(onPressed: _action, backgroundColor: _isRecording ? Colors.red : Colors.green, child: Icon(_isRecording ? Icons.stop : Icons.videocam)),
        ))
      ]),
    );
  }
}