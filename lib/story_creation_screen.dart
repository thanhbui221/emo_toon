import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'gemini_api.dart';
import 'story_display_screen.dart';

class StoryCreationScreen extends StatefulWidget {
  final List<Content>? history;

  const StoryCreationScreen({super.key, this.history});

  @override
  _StoryCreationScreenState createState() => _StoryCreationScreenState();
}

class _StoryCreationScreenState extends State<StoryCreationScreen> {
  GeminiAPI? geminiAPI;
  int step = 0;
  String character = 'dog';
  String storyOverview = '';
  String userFeelings = '';
  List<String> characterImages = [];
  List<Content> storyHistory = [];
  final TextEditingController _storyOverviewController = TextEditingController();
  final TextEditingController _feelingsController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _micText = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeGeminiAPI();
    _loadCharacterImages();
    _speech = stt.SpeechToText();
    if (widget.history != null) {
      storyHistory = widget.history!;
      _submitStory(); // Recreate the story if history is provided
    }
  }

  @override
  void dispose() {
    _storyOverviewController.dispose();
    _feelingsController.dispose();
    super.dispose();
  }

  Future<void> _initializeGeminiAPI() async {
    try {
      geminiAPI = await GeminiAPI.initialize();
    } catch (e) {
      print('Failed to initialize Gemini API: $e');
    }
  }

  Future<void> _loadCharacterImages() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      final characterPath = 'assets/$character/';
      final images = manifestMap.keys
          .where((String key) => key.startsWith(characterPath))
          .where((String key) => key.endsWith('.png'))
          .toList();

      setState(() {
        characterImages = images.map((image) => image.split('/').last).toList();
      });
    } catch (e) {
      print('Error loading character images: $e');
    }
  }

  Future<void> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  void _nextStep() {
    if (step == 1 && _storyOverviewController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter story details.')),
      );
    } else if (step == 2 && _feelingsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feelings.')),
      );
    } else {
      setState(() {
        if (step == 1) {
          storyOverview = _storyOverviewController.text;
          storyHistory.add(Content.text('Story Overview: $storyOverview'));
        } else if (step == 2) {
          userFeelings = _feelingsController.text;
          storyHistory.add(Content.text('User Feelings: $userFeelings'));
        }

        if (step < 2) {
          step++;
        } else {
          _submitStory();
        }

        if (step == 1) {
          _feelingsController.clear();
        } else if (step == 2) {
          _storyOverviewController.clear();
        }
      });
    }
  }

  void _previousStep() {
    setState(() {
      if (step > 0) step--;
    });
  }

  Future<void> _submitStory() async {
    setState(() {
      _isLoading = true;
    });

    if (geminiAPI != null) {
      try {
        final imagesList = characterImages.join(', ');
        final content = [
          Content.text('Character: $character'),
          Content.text('Overview: $storyOverview'),
          Content.text('User Feelings: $userFeelings'),
          Content.text(
              '''I have a set of characters with levels of emotions: $imagesList. 
              For each panel, no need to generate images, just tell me which character to use along with the conversation. 
              Results should be presented as JSON with keys like "panel_1": {"caption": "...", "character": "..."}, "panel_2": {"caption": "...", "character": "..."}, etc.
              Must choose the character in the list $imagesList.'''),
        ];

        final response = await geminiAPI!.generateContent(content);

        if (response.candidates.isNotEmpty) {
          String cleanedResponse = response.candidates.first.text!;
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

          print(captions);

          print(characters);


          // Check if the lists are of the same length and are not empty
          if (characters.length == captions.length && characters.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoryDisplayScreen(
                  images: characters,
                  conversations: captions,
                  history: storyHistory, // Pass the history to the display screen
                  character: character,
                  storyOverview: storyOverview,
                  userFeelings: userFeelings,
                  imagesList: imagesList,
                ),
              ),
            );
          } else {
            print('Error: Characters and captions list lengths do not match or are empty.');
            // Optionally, show an error message to the user
          }
        } else {
          print('No candidates received, check prompt feedback');
          print('Prompt feedback: ${response.promptFeedback}');
        }
      } catch (e) {
        print('Error generating story: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
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
                        _listen(controller, setState);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _requestMicrophonePermission();
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

  void _listen(TextEditingController controller, StateSetter setState) async {
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

  @override
  Widget build(BuildContext context) {
    List<Widget> steps = [
      _buildCharacterSelectionStep(),
      _buildStoryOverviewStep(),
      _buildUserRoleAndFeelingsStep(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Create New Story',
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
              const SizedBox(height: 20), // Add some spacing at the top
              steps[step],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (step > 0)
                    ElevatedButton(
                      onPressed: _previousStep,
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
                    onPressed: _isLoading ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontFamily: 'ComicSans', fontSize: 16, inherit: true),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(step == steps.length - 1 ? 'Submit' : 'Next'),
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

  Widget _buildCharacterSelectionStep() {
    return Column(
      children: [
        const Text(
          'Choose a character for your story:',
          style: TextStyle(
            fontFamily: 'ComicSans',
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        ListTile(
          title: const Text('Dog'),
          leading: Radio<String>(
            value: 'dog',
            groupValue: character,
            onChanged: (value) {
              setState(() {
                character = value!;
                _loadCharacterImages();
              });
            },
          ),
        ),
        ListTile(
          title: const Text('Cat'),
          leading: Radio<String>(
            value: 'cat',
            groupValue: character,
            onChanged: (value) {
              setState(() {
                character = value!;
                _loadCharacterImages();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoryOverviewStep() {
    return Column(
      children: [
        const Text(
          'Provide details of the story:',
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
                  controller: _storyOverviewController,
                  onChanged: (value) {
                    setState(() {
                      storyOverview = value;
                    });
                  },
                  style: const TextStyle(fontFamily: 'ComicSans'),
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Enter story details...',
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
              onPressed: () => _showRecordingDialog(_storyOverviewController),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildUserRoleAndFeelingsStep() {
    return Column(
      children: [
        const Text(
          'Tell me your feelings:',
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
                  controller: _feelingsController,
                  onChanged: (value) {
                    setState(() {
                      userFeelings = value;
                    });
                  },
                  style: const TextStyle(fontFamily: 'ComicSans'),
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Enter your feelings...',
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
              onPressed: () => _showRecordingDialog(_feelingsController),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
