import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class AIChatbotScreen extends StatefulWidget {
  const AIChatbotScreen({super.key});
  @override
  State createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  final String _apiKey =
      "YOUR_GEMINI_API_KEY"; // Replace with your Gemini API key

  Future _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _textController.clear();
      _isLoading = true;
    });
    try {
      final response = await http
          .post(
            Uri.parse(
              "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=$_apiKey",
            ),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {
                      "text":
                          "You are a helpful assistant for a blood donation app called Pulse Sync. "
                          "You help users with questions about blood donation, eligibility, "
                          "finding donors, and general health information related to blood donation. "
                          "Keep your answers concise and accurate (under 200 words).\n\n"
                          "User: $text",
                    },
                  ],
                },
              ],
              "generationConfig": {
                "temperature": 0.7,
                "topK": 1,
                "topP": 1,
                "maxOutputTokens": 1000,
                "stopSequences": [],
              },
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final botReply =
            responseBody['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
            "Sorry, I couldn't understand the server.";
        setState(() {
          _messages.add(ChatMessage(text: botReply, isUser: false));
        });
      } else {
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  "Sorry, I couldn't process your request. Please try again later.",
              isUser: false,
            ),
          );
        });
      }
    } on TimeoutException {
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Request timed out. Please check your internet connection.",
            isUser: false,
          ),
        );
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(text: "An unexpected error occurred: $e", isUser: false),
        );
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Donation Assistant'),
        backgroundColor: Colors.red[700],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return ChatBubble(message: message);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "Ask about blood donation...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red[700],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.red[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
