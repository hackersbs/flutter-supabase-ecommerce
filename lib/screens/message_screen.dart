import 'package:e_comerce_appliction/provider/messageprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MessageProvider>();
      provider.loadContacts();
      provider.subscribeToRealtimeMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFF2874F0),
        foregroundColor: Colors.white,
      ),
      body: Consumer<MessageProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null && provider.contacts.isEmpty) {
            return _MessageError(
              message: provider.errorMessage!,
              onRetry: provider.loadContacts,
            );
          }
          if (provider.contacts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Messages with buyers and sellers will appear here after a purchase.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: provider.loadContacts,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.contacts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final contact = provider.contacts[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                    child: Text(_initials(contact.name)),
                  ),
                  title: Text(
                    contact.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    contact.lastMessage.isEmpty
                        ? 'Start a conversation'
                        : contact.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(contact: contact),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

class ChatScreen extends StatefulWidget {
  final MessageContact contact;

  const ChatScreen({super.key, required this.contact});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  MessageProvider? _messageProvider;

  @override
  void initState() {
    super.initState();
    final provider = context.read<MessageProvider>();
    _messageProvider = provider;
    provider.addListener(_handleProviderUpdate);
    _loadConversation();
  }

  @override
  void dispose() {
    _messageProvider?.removeListener(_handleProviderUpdate);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleProviderUpdate() {
    if (!mounted) return;
    final provider = _messageProvider;
    if (provider == null) return;
    final messages = provider.conversationFor(widget.contact.userId);
    if (messages.isEmpty && _messages.isNotEmpty) return;
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _loadConversation() async {
    final provider = _messageProvider;
    if (provider == null) return;
    final messages = await provider.loadConversation(widget.contact.userId);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    if (_isSending || _controller.text.trim().isEmpty) return;
    final provider = _messageProvider;
    if (provider == null) return;
    final text = _controller.text;
    _controller.clear();
    setState(() => _isSending = true);
    final sent = await provider.sendMessage(
      contact: widget.contact,
      body: text,
    );
    if (!mounted) return;
    setState(() => _isSending = false);
    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Message could not be sent.'),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MessageProvider>(
      builder: (context, provider, child) {
        final currentUserId = provider.currentUserId;
        final liveMessages = provider.conversationFor(widget.contact.userId);
        final messages = liveMessages.isNotEmpty ? liveMessages : _messages;

        // Auto-scroll on new message
        if (messages.length != _messages.length) {
          _messages = messages;
          _scrollToBottom();
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: const Color(0xFF2874F0),
                  child: Text(widget.contact.name[0].toUpperCase()),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(widget.contact.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2874F0),
            foregroundColor: Colors.white,
          ),
          body: Column(
            children: [
              Expanded(
                child: _isLoading && messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : messages.isEmpty
                        ? const Center(child: Text('Start the conversation'))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isMine = message['sender_id'] == currentUserId;
                              return _MessageBubble(
                                text: message['body']?.toString() ?? '',
                                isMine: isMine,
                                createdAt: DateTime.tryParse(
                                  message['created_at']?.toString() ?? '',
                                ),
                              );
                            },
                          ),
              ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.contact.name}',
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final DateTime? createdAt;

  const _MessageBubble({
    required this.text,
    required this.isMine,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final time = createdAt == null
        ? ''
        : MaterialLocalizations.of(context)
              .formatTimeOfDay(TimeOfDay.fromDateTime(createdAt!.toLocal()));
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 7),
        decoration: BoxDecoration(
          color: isMine
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 2)],
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Text(text),
            Text(
              time,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MessageError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
