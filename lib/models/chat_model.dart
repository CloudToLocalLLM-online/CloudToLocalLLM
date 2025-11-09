import 'conversation.dart';
import 'message.dart';

export 'conversation.dart' show Conversation;
export 'message.dart' show Message, MessageRole, MessageStatus;

/// Backwards-compatibility typedefs for legacy chat model names.
typedef ChatConversation = Conversation;
typedef ChatMessage = Message;
