import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart'; // Import aggiornato
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
  ServerSocket? _server;
  Socket? _ffmpegSocket;
  ResolutionPreset _res = ResolutionPreset.medium;

  @override
  void initState() { super.initState(); _initCam(); }

  Future<void> _initCam() async {
    _controller = CameraController(widget.cameras[0], _res, enableAudio: false);
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
      final outPath = "${dir.path}/vid_${DateTime.now().millisecondsSinceEpoch}.mp4";
      
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _server!.listen((client) => _ffmpegSocket = client);

      // Usiamo parametri video universali per evitare errori di codec
      String cmd = "-f rawvideo -pix_fmt yuv420p -s 720x480 -r 2 -i tcp://127.0.0.1:${_server!.port} -c:v libx264 -preset ultrafast -y $outPath";
      
      FFmpegKit.executeAsync(cmd);

      int frameCount = 0;
      await _controller!.startImageStream((image) {
        frameCount++;
        if (frameCount % 15 == 0 && _ffmpegSocket != null) {
          for (var plane in image.planes) { _ffmpegSocket!.add(plane.bytes); }
        }
      });
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) return const Scaffold();
    return Scaffold(
      body: Stack(children: [
        CameraPreview(_controller!),
        Positioned(bottom: 50, left: 0, right: 0, child: Center(
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