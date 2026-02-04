import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit_config.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(
    theme: ThemeData.dark(),
    home: LowFPSStreamer(cameras: cameras),
  ));
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
  bool _isProcessing = false;
  ResolutionPreset _currentRes = ResolutionPreset.medium;
  String? _pipePath;

  // Mappa risoluzioni per FFmpeg (deve combaciare con CameraController)
  final Map<ResolutionPreset, String> _resSizes = {
    ResolutionPreset.low: "320x240",
    ResolutionPreset.medium: "720x480",
    ResolutionPreset.high: "1280x720",
  };

  @override
  void initState() {
    super.initState();
    _initCam(_currentRes);
  }

  Future<void> _initCam(ResolutionPreset res) async {
    _controller = CameraController(widget.cameras[0], res, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  // La tua funzione di conversione integrata
  Uint8List _processYUV420(CameraImage img) {
    final int width = img.width;
    final int height = img.height;
    final int ySize = width * height;
    final int uvSize = (width / 2).floor() * (height / 2).floor();
    
    final Uint8List result = Uint8List(ySize + 2 * uvSize);
    
    // Piano Y (Luminanza)
    result.setRange(0, ySize, img.planes[0].bytes);
    
    // Piani U e V (Crominanza)
    result.setRange(ySize, ySize + img.planes[1].bytes.length, img.planes[1].bytes);
    result.setRange(ySize + img.planes[1].bytes.length, result.length, img.planes[2].bytes);
    
    return result;
  }

  void _action() async {
    if (_isRecording) {
      // STOP RECORDING
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      await _controller!.stopImageStream();
      await FFmpegKitConfig.closePipe(_pipePath);
      
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Video salvato nella cartella documenti")),
      );
    } else {
      // START RECORDING
      final dir = await getApplicationDocumentsDirectory();
      final outPath = "${dir.path}/2fps_${DateTime.now().millisecondsSinceEpoch}.mp4";
      
      _pipePath = await FFmpegKitConfig.registerNewPipe();
      final String size = _resSizes[_currentRes]!;

      // Comando FFmpeg: Legge raw da pipe -> forza 2fps -> codifica H264
      String cmd = "-f rawvideo -pix_fmt yuv420p -s $size -r 2 -i $_pipePath -c:v libx264 -preset ultrafast -y $outPath";

      FFmpegKit.executeAsync(cmd);

      int frameCount = 0;
      await _controller!.startImageStream((image) {
        frameCount++;
        // Campionamento: Flutter invia ~30fps, noi ne scriviamo 1 ogni 15 per avere 2fps
        if (frameCount % 15 == 0) {
          final bytes = _processYUV420(image);
          FFmpegKitConfig.writeToPipe(_pipePath, bytes);
        }
      });

      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Low FPS Recorder"),
        actions: [
          if (!_isRecording)
            DropdownButton<ResolutionPreset>(
              value: _currentRes,
              underline: Container(),
              items: _resSizes.keys.map((r) => DropdownMenuItem(
                value: r, 
                child: Text(r.name.toUpperCase())
              )).toList(),
              onChanged: (r) {
                if (r != null) {
                  setState(() => _currentRes = r);
                  _initCam(r);
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator(color: Colors.yellow)),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.large(
                onPressed: _isProcessing ? null : _action,
                backgroundColor: _isRecording ? Colors.red : Colors.green,
                child: Icon(_isRecording ? Icons.stop : Icons.videocam),
              ),
            ),
          ),
        ],
      ),
    );
  }
}