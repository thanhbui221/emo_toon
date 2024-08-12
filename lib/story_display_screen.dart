import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'improve_story_screen.dart';

class StoryDisplayScreen extends StatefulWidget {
  final List<String> images;
  final List<String> conversations;
  final List<Content> history;
  final String character;
  final String storyOverview;
  final String userFeelings;
  final String imagesList;

  const StoryDisplayScreen({
    super.key,
    required this.images,
    required this.conversations,
    required this.history,
    required this.character,
    required this.storyOverview,
    required this.userFeelings,
    required this.imagesList,
  });

  @override
  _StoryDisplayScreenState createState() => _StoryDisplayScreenState();
}

class _StoryDisplayScreenState extends State<StoryDisplayScreen> {
  final List<GlobalKey> _globalKeysListView = [];
  final List<GlobalKey> _globalKeysOffstage = [];

  @override
  void initState() {
    super.initState();
    _initializeGlobalKeys();
  }

  void _initializeGlobalKeys() {
    _globalKeysListView.clear();
    _globalKeysOffstage.clear();

    for (var i = 0; i < widget.images.length; i++) {
      _globalKeysListView.add(GlobalKey());
      _globalKeysOffstage.add(GlobalKey());
    }
  }

  Future<bool> requestStoragePermission() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    PermissionStatus status;

    if (androidInfo.version.sdkInt >= 33) {
      status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
    } else {
      status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
    }

    return status.isGranted;
  }

  Future<Uint8List?> _capturePng(GlobalKey key) async {
    try {
      RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage();
      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<void> saveImageToGallery(Uint8List imageBytes) async {
    final result = await ImageGallerySaver.saveImage(imageBytes);
    if (result['isSuccess']) {
      print("Image saved to gallery successfully.");
    } else {
      print("Failed to save image to gallery.");
    }
  }

  Future<void> _saveImages(BuildContext context) async {
    final bool hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required to save images.')),
      );
      return;
    }

    // Make the Offstage widget visible before capturing images
    setState(() {
      _offstage = false;
    });

    await Future.delayed(Duration(milliseconds: 100)); // Wait for the UI to update

    for (int i = 0; i < _globalKeysOffstage.length; i++) {
      final capturedImage = await _capturePng(_globalKeysOffstage[i]);
      if (capturedImage != null) {
        await saveImageToGallery(capturedImage);
      }
    }

    // Hide the Offstage widget after capturing images
    setState(() {
      _offstage = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Images saved to gallery.')),
    );
  }

  bool _offstage = true; // Initial state is offstage


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double squareSize = screenWidth * 0.9;
    final double textSize = screenWidth * 0.04; // Scale text size based on screen width
    final double paddingSize = screenWidth * 0.05; // Scale padding size

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Story'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Your existing widgets
            ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                final image = widget.images[index];
                final conversation = widget.conversations[index];
                final characterType = image.contains('dog') ? 'dog' : 'cat';
                final imagePath = 'assets/$characterType/$image';

                return Padding(
                  padding: EdgeInsets.all(paddingSize),
                  child: RepaintBoundary(
                    key: _globalKeysListView[index],
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            width: squareSize,
                            height: squareSize,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              image: DecorationImage(
                                image: AssetImage(imagePath),
                                fit: BoxFit.cover,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                        Positioned(
                          top: squareSize / 8,
                          left: squareSize / 8,
                          right: squareSize / 8, // Add a right constraint
                          child: BubbleWithText(conversation: conversation),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Offstage(
              offstage: _offstage,
              child: Column(
                children: List.generate(widget.images.length, (index) {
                  final image = widget.images[index];
                  final conversation = widget.conversations[index];
                  final characterType = image.contains('dog') ? 'dog' : 'cat';
                  final imagePath = 'assets/$characterType/$image';

                  if (index >= _globalKeysOffstage.length) {
                    return SizedBox.shrink(); // Avoid accessing out of bounds
                  }

                  return RepaintBoundary(
                    key: _globalKeysOffstage[index],
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            width: squareSize,
                            height: squareSize,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              image: DecorationImage(
                                image: AssetImage(imagePath),
                                fit: BoxFit.cover,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                        Positioned(
                          top: squareSize / 8,
                          left: squareSize / 8,
                          right: squareSize / 8, // Add a right constraint
                          child: BubbleWithText(conversation: conversation),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(paddingSize),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(Colors.blueAccent),
                      foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                      textStyle: MaterialStateProperty.all<TextStyle>(
                        TextStyle(fontFamily: 'ComicSans', fontSize: textSize),
                      ),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      padding: MaterialStateProperty.all<EdgeInsets>(
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImproveStoryScreen(
                            history: widget.history,
                            images: widget.images,
                            conversations: widget.conversations,
                            character: widget.character,
                            storyOverview: widget.storyOverview,
                            userFeelings: widget.userFeelings,
                            imagesList: widget.imagesList,
                          ),
                        ),
                      );
                    },
                    child: const Text('Improve Story'),
                  ),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(Colors.greenAccent),
                      foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                      textStyle: MaterialStateProperty.all<TextStyle>(
                        TextStyle(fontFamily: 'ComicSans', fontSize: textSize),
                      ),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      padding: MaterialStateProperty.all<EdgeInsets>(
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    onPressed: () => _saveImages(context),
                    child: const Text('Download Images'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BubbleWithText extends StatelessWidget {
  final String conversation;

  const BubbleWithText({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final double maxWidth = MediaQuery.of(context).size.width * 0.7;

    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
      ),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Text(
        conversation,
        style: TextStyle(color: Colors.black, fontSize: 16),
        textAlign: TextAlign.center,
        softWrap: true,
      ),
    );
  }
}



class SpeechBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 5)
      ..lineTo(20, size.height - 5)
      ..lineTo(20, size.height + 5)
      ..lineTo(0, size.height + 5)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}