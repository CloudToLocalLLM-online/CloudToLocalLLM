import 'package:flutter/material.dart';
import '../config/theme.dart';

class MessageContent extends StatelessWidget {
  final String content;
  final bool isStreaming;

  const MessageContent({super.key, required this.content}) : isStreaming = false;
  const MessageContent.streaming({super.key, this.content = ''})
      : isStreaming = true;

  @override
  Widget build(BuildContext context) {
    if (isStreaming) {
      return _buildStreamingContent(context);
    }
    return SelectableText(
      content,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppTheme.textColor, height: 1.5),
    );
  }

  Widget _buildStreamingContent(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content.isEmpty) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          SizedBox(width: AppTheme.spacingS),
          Text(
            'Thinking...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textColorLight,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ] else
          Expanded(
            child: SelectableText(
              content,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textColor, height: 1.5),
            ),
          ),
      ],
    );
  }
}
