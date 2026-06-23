import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../services/ai_service.dart';

class AiGuidanceScreen extends StatefulWidget {
  const AiGuidanceScreen({super.key});

  @override
  State<AiGuidanceScreen> createState() => _AiGuidanceScreenState();
}

class _AiGuidanceScreenState extends State<AiGuidanceScreen> {
  final service = AiService();
  final controller = TextEditingController();
  final messages = <({bool user, String text})>[];
  bool loading = false;

  Future<void> _send() async {
    final question = controller.text.trim();
    if (question.isEmpty || loading) return;
    setState(() {
      messages.add((user: true, text: question));
      loading = true;
      controller.clear();
    });
    final answer = await service.ask(question);
    if (!mounted) return;
    setState(() {
      messages.add((user: false, text: answer));
      loading = false;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Guidance')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'General information only. This assistant does not replace medical, legal, or emergency professionals.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Ask about emergency preparation, trusted contacts, funeral preferences, or storing a will.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return Align(
                        alignment: message.user
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: message.user
                                ? AppColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: message.user
                                ? null
                                : Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: message.user
                                  ? Colors.white
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLength: 500,
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        labelText: 'Ask a question',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: loading ? null : _send,
                    icon: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
