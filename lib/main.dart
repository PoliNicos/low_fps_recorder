import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
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
  ServerSocket? _server;
  Socket? _ffmpegSocket;

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

  void _action() async {
    if (_isRecording) {
      await _controller!.stopImageStream();
      _ffmpegSocket?.destroy();
      await _server?.close();
      setState(() => _isRecording = false);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final outPath = "${dir.path}/out_${DateTime.now().millisecondsSinceEpoch}.mp4";
      
      // 1. Apriamo un socket locale
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      int port = _server!.port;

      _server!.listen((client) {
        _ffmpegSocket = client;
      });

      // 2. Comando FFmpeg che legge dal socket TCP locale
      String cmd = "-f rawvideo -pix_fmt yuv420p -s ${_resSizes[_currentRes]} -r 2 -i tcp://127.0.0.1:$port -c:v libx264 -preset ultrafast -y $outPath";
      
      FFmpegKit.executeAsync(cmd);

      int frameCount = 0;
      await _controller!.startImageStream((image) {
        frameCount++;
        if (frameCount % 15 == 0 && _ffmpegSocket != null) {
          // Scriviamo i piani YUV direttamente nel socket
          for (var plane in image.planes) {
            _ffmpegSocket!.add(plane.bytes);
          }
        }
      });
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) return const Scaffold();
    return Scaffold(
      appBar: AppBar(title: const Text("2FPS Socket Cam"), actions: [
        DropdownButton<ResolutionPreset>(
          value: _currentRes,
          items: _resSizes.keys.map((r) => DropdownMenuItem(value: r, child: Text(r.name.toUpperCase()))).toList(),
          onChanged: _isRecording ? null : (r) { setState(() => _currentRes = r!); _initCam(r!); },
        )
      ]),
      body: Stack(children: [
        CameraPreview(_controller!),
        Positioned(bottom: 40, left: 0, right: 0, child: Center(
          child: FloatingActionButton.large(
            onPressed: _action,
            backgroundColor: _isRecording ? Colors.red : Colors.green,
            child: Icon(_isRecording ? Icons.stop : Icons.videocam),
          ),
        ))
      ]),
    );
  }
}