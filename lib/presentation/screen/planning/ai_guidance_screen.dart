import 'package:flutter/material.dart';

import '../../../businessLogicLayer/controllers/ai_controller.dart';
import '../../../core/constants/colors.dart';
import '../../../models/ai_chat_message.dart';
import '../../../services/ai_chat_history_service.dart';

class AiGuidanceScreen extends StatefulWidget {
  const AiGuidanceScreen({super.key});

  @override
  State<AiGuidanceScreen> createState() => _AiGuidanceScreenState();
}

class _AiGuidanceScreenState extends State<AiGuidanceScreen> {
  final aiController = AiController();
  final historyService = AiChatHistoryService();
  final inputController = TextEditingController();
  final scrollController = ScrollController();
  final messages = <AiChatMessage>[];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await historyService.load();
    if (!mounted) return;
    setState(() => messages.addAll(history));
    _scrollToBottom();
  }

  Future<void> _send() async {
    final question = inputController.text.trim();
    if (question.isEmpty || loading) return;
    final history = List<AiChatMessage>.from(messages);
    final userMessage = AiChatMessage.user(question);
    setState(() {
      messages.add(userMessage);
      loading = true;
      inputController.clear();
    });
    await historyService.save(messages);
    _scrollToBottom();
    final answer = await aiController.ask(question, history: history);
    if (!mounted) return;
    setState(() {
      messages.add(AiChatMessage.assistant(answer));
      loading = false;
    });
    await historyService.save(messages);
    _scrollToBottom();
  }

  Future<void> _clearHistory() async {
    if (loading || messages.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text('This only clears AI Guidance history on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await historyService.clear();
    if (!mounted) return;
    setState(messages.clear);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    inputController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Guidance'),
        actions: [
          IconButton(
            onPressed: loading || messages.isEmpty ? null : _clearHistory,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat history',
          ),
        ],
      ),
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
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: _ChatBubble(
                            user: false,
                            text: 'Thinking...',
                          ),
                        );
                      }
                      final message = messages[index];
                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _ChatBubble(
                          user: message.isUser,
                          text: message.text,
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
                      controller: inputController,
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.user, required this.text});

  final bool user;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .78,
      ),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: user ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: user ? null : Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: TextStyle(color: user ? Colors.white : AppColors.ink),
      ),
    );
  }
}
