import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/message.dart';
import '../services/streaming_chat_service.dart';
import 'message_actions.dart';
import 'message_content.dart';
import '../utils/color_extensions.dart';

/// A bubble-styled widget for displaying a single chat message.
class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool showAvatar;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.onRetry,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final theme = Theme.of(context);
    final chatService = context.watch<StreamingChatService>();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser && widget.showAvatar) _buildAvatar(),
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _getBubbleColor(context),
                        borderRadius: _getBorderRadius(),
                        border: _getBubbleBorder(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.message.isStreaming &&
                              widget.message.content.isEmpty)
                            _buildTypingIndicator()
                          else
                            _buildMessageContent(theme),
                        ],
                      ),
                    ),
                    if (_isHovered || widget.message.hasError)
                      MessageActions(
                        message: widget.message,
                        onCopy: () => _copyToClipboard(context),
                        onRetry: widget.onRetry,
                      ),
                  ],
                ),
              ),
              if (isUser && widget.showAvatar) _buildAvatar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Icon(
        widget.message.isUser ? Icons.person : Icons.computer,
        size: 18,
        color: AppTheme.textColorLight,
      ),
    );
  }

  Color _getBubbleColor(BuildContext context) {
    if (widget.message.hasError) {
      return AppTheme.dangerColor.withValues(alpha: 0.1);
    }
    return widget.message.isUser
        ? AppTheme.primaryColor.withValues(alpha: 0.1)
        : AppTheme.backgroundCard;
  }

  Border? _getBubbleBorder(BuildContext context) {
    if (widget.message.hasError) {
      return Border.all(
        color: AppTheme.dangerColor.withValues(alpha: 0.3),
        width: 1.5,
      );
    }
    return Border.all(
      color: widget.message.isUser
          ? AppTheme.primaryColor.withValues(alpha: 0.3)
          : AppTheme.secondaryColor.withValues(alpha: 0.2),
      width: 1.5,
    );
  }

  BorderRadius _getBorderRadius() {
    return BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft:
          widget.message.isUser ? const Radius.circular(18) : Radius.zero,
      bottomRight:
          widget.message.isUser ? Radius.zero : const Radius.circular(18),
    );
  }

  Widget _buildTypingIndicator() {
    return const SizedBox(
      height: 24, // Matches default text height
      child: MessageContent.streaming(),
    );
  }

  Widget _buildMessageContent(ThemeData theme) {
    // This part remains mostly the same as what was in the previous MessageContent widget
    if (widget.message.isStreaming) {
      return MessageContent.streaming(content: widget.message.content);
    }
    // Handle potential markdown and code blocks here if needed
    return SelectableText(
      widget.message.content,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: AppTheme.textColor,
        height: 1.5,
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final chatService = context.read<StreamingChatService>();
    chatService.copyToClipboard(widget.message.content);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
