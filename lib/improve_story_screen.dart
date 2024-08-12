import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'gemini_api.dart';
import 'story_display_screen.dart';

class ImproveStoryScreen extends StatefulWidget {
  final List<Content> history;
  final List<String> images;
  final List<String> conversations;
  final String character;
  final String storyOverview;
  final String userFeelings;
  final String imagesList;

  const ImproveStoryScreen({
    super.key,
    required this.history,
    required this.images,
    required this.conversations,
    required this.character,
    required this.storyOverview,
    required this.userFeelings,
    required this.imagesList,
  });

  @override
  _ImproveStoryScreenState createState() => _ImproveStoryScreenState();
}

class _ImproveStoryScreenState extends State<ImproveStoryScreen> {
  final TextEditingController _promptController = TextEditingController();
  GeminiAPI? _geminiAPI;
  bool _isLoading = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _micText = '';

  @override
  void initState() {
    super.initState();
    _initializeAPI();
    _speech = stt.SpeechToText();
    _requestMicrophonePermission();
  }

  Future<void> _initializeAPI() async {
    _geminiAPI = await GeminiAPI.initialize();
  }

  Future<void> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  void _submitImprovement() async {
    setState(() {
      _isLoading = true;
    });

    final prompt = _promptController.text;
    if (prompt.isNotEmpty && _geminiAPI != null) {
      widget.history.add(Content.text('New updates to the story: $prompt'));
      widget.history.add(Content.text(
          '''I have a set of characters with levels of emotions: ${widget.imagesList}. 
              For each panel, no need to generate images, just tell me which character to use along with the conversation. 
              Results should be presented as JSON with keys like "panel_1": {"caption": "...", "character": "..."}, "panel_2": {"caption": "...", "character": "..."}, etc.
              Must choose the character in the list ${widget.imagesList}'''));

      final response = await _geminiAPI!.generateContent(widget.history);

      if (response.candidates.isNotEmpty) {
        final generatedText = response.candidates.first.text;
        if (generatedText != null) {
          print('Response: $generatedText');
          widget.history.add(Content.text(generatedText));

          String cleanedResponse = generatedText;
          if (cleanedResponse.startsWith('```json')) {
            cleanedResponse = cleanedResponse.substring(7).trim();
          }
          if (cleanedResponse.endsWith('```')) {
            cleanedResponse = cleanedResponse.substring(0, cleanedResponse.length - 3).trim();
          }

          final result = jsonDecode(cleanedResponse);

          final captions = <String>[];
          final characters = <String>[];

          result.forEach((key, value) {
            captions.add(value['caption']);
            characters.add(value['character']);
          });

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StoryDisplayScreen(
                images: characters,
                conversations: captions,
                history: widget.history,
                character: widget.character,
                storyOverview: widget.storyOverview,
                userFeelings: widget.userFeelings,
                imagesList: widget.imagesList,
              ),
            ),
          );
        } else {
          print('Generated text is null');
        }
      } else {
        print('No candidates received, check prompt feedback');
        print('Prompt feedback: ${response.promptFeedback}');
      }

      _promptController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prompt.')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _listen(TextEditingController controller) async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _micText = val.recognizedWords;
            controller.text = _micText;
          }),
          listenFor: const Duration(seconds: 120),  // Adjust the duration as needed
          pauseFor: const Duration(seconds: 10),    // Adjust the pause duration as needed
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _showRecordingDialog(TextEditingController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Voice Input'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_isListening ? "Listening..." : "Press the button to start speaking"),
                  const SizedBox(height: 20),
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                    onPressed: () {
                      if (_isListening) {
                        setState(() => _isListening = false);
                        _speech.stop();
                      } else {
                        _listen(controller);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (_isListening) {
                      setState(() => _isListening = false);
                      _speech.stop();
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Improve Story',
          style: TextStyle(
            fontFamily: 'ComicSans',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter additional prompt to improve your story:',
                style: TextStyle(
                  fontFamily: 'ComicSans',
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.25, // 1/4 of the screen height
                      child: TextField(
                        controller: _promptController,
                        onChanged: (value) {
                          setState(() {
                            _micText = value;
                          });
                        },
                        style: const TextStyle(fontFamily: 'ComicSans'),
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'Enter your prompt here...',
                          hintStyle: const TextStyle(
                            fontFamily: 'ComicSans',
                            color: Colors.grey,
                          ),
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.yellow[100],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic),
                    onPressed: () => _showRecordingDialog(_promptController),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontFamily: 'ComicSans', fontSize: 16, inherit: true),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Back'),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitImprovement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontFamily: 'ComicSans', fontSize: 16, inherit: true),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Submit'),
                  ),
                ],
              ),
              const SizedBox(height: 20), // Add some spacing at the bottom
            ],
          ),
        ),
      ),
    );
  }
}
