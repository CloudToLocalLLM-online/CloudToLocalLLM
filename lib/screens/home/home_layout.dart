import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/chat_model.dart';
import '../../services/streaming_chat_service.dart';
import '../../components/message_bubble.dart';
import '../../components/message_input.dart';
import '../../components/app_logo.dart';
import '../../components/tunnel_status_button.dart';
import '../../components/web_download_prompt.dart';
import '../../components/conversation_list.dart';
import '../../services/auth_service.dart';
import '../../services/connection_manager_service.dart';
import '../../services/web_download_prompt_service.dart';

/// Main layout for the chat interface, handling responsiveness and sidebar toggle.
class HomeLayout extends StatefulWidget {
  const HomeLayout({
    super.key,
    required this.isCompact,
    required this.isSidebarCollapsed,
    required this.onSidebarToggle,
    required this.scrollController,
    required this.onSendMessage,
  });

  final bool isCompact;
  final bool isSidebarCollapsed;
  final VoidCallback onSidebarToggle;
  final ScrollController scrollController;
  final void Function(StreamingChatService service, String message)
  onSendMessage;

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  @override
  Widget build(BuildContext context) {
    final showSidebar = !widget.isSidebarCollapsed;

    return Scaffold(
      backgroundColor: AppTheme.backgroundMain,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.headerGradient,
                ),
                child: _HeaderBar(
                  isCompact: widget.isCompact,
                  isSidebarCollapsed: widget.isSidebarCollapsed,
                  onSidebarToggle: widget.onSidebarToggle,
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      width: showSidebar ? (widget.isCompact ? 260 : 300) : 0,
                      child: showSidebar
                          ? const _SidebarPane()
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: _ChatPane(
                        isCompact: widget.isCompact,
                        scrollController: widget.scrollController,
                        onSendMessage: widget.onSendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (kIsWeb) const Positioned.fill(child: _WebDownloadOverlay()),
          if (kIsWeb) const TunnelStatusButton(),
        ],
      ),
      floatingActionButton: widget.isCompact && widget.isSidebarCollapsed
          ? const _NewConversationButton()
          : null,
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.isCompact,
    required this.isSidebarCollapsed,
    required this.onSidebarToggle,
  });

  final bool isCompact;
  final bool isSidebarCollapsed;
  final VoidCallback onSidebarToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Padding(
      padding: EdgeInsets.all(spacing.m),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompact)
                IconButton(
                  onPressed: onSidebarToggle,
                  icon: Icon(
                    isSidebarCollapsed ? Icons.menu : Icons.close,
                    color: Colors.white,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo.small(
                    backgroundColor: Colors.white,
                    textColor: Color(0xFF6e8efb),
                    borderColor: Color(0xFFa777e3),
                  ),
                  SizedBox(width: spacing.s),
                  Text(
                    AppConfig.appName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          const _ModelSelector(),
          SizedBox(width: spacing.m),
          const _UserMenu(),
        ],
      ),
    );
  }
}

class _ModelSelector extends StatelessWidget {
  const _ModelSelector();

  @override
  Widget build(BuildContext context) {
    return Consumer2<StreamingChatService, ConnectionManagerService>(
      builder: (context, chatService, connectionManager, child) {
        final spacing = AppTheme.spacingOf(context);
        final models = connectionManager.availableModels;
        return Container(
          width: 200,
          padding: EdgeInsets.symmetric(horizontal: spacing.s),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: chatService.selectedModel,
              hint: Text(
                'Select Model',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                overflow: TextOverflow.ellipsis,
              ),
              items: models.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text(model, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (model) {
                if (model != null) {
                  chatService.setSelectedModel(model);
                }
              },
              dropdownColor: Colors.white,
              icon: Icon(
                Icons.arrow_drop_down,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              isExpanded: true,
            ),
          ),
        );
      },
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final spacing = AppTheme.spacingOf(context);
        final user = authService.currentUser;
        return PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'settings':
                if (context.mounted) {
                  context.go('/settings');
                }
                break;
              case 'logout':
                await authService.logout();
                if (context.mounted) {
                  context.go('/login');
                }
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  const Icon(Icons.settings, size: 18),
                  SizedBox(width: spacing.s),
                  const Text('Settings'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 18),
                  SizedBox(width: spacing.s),
                  const Text('Sign Out'),
                ],
              ),
            ),
          ],
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          ),
          color: AppTheme.backgroundCard,
          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
          child: Container(
            padding: EdgeInsets.all(spacing.xs),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                user?.initials ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SidebarPane extends StatelessWidget {
  const _SidebarPane();

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamingChatService>(
      builder: (context, chatService, child) {
        return ConversationList(
          conversations: chatService.conversations,
          selectedConversation: chatService.currentConversation,
          onConversationSelected: (conversationId) {
            final conversation = chatService.conversations.firstWhere(
              (c) => c.id == conversationId,
            );
            chatService.selectConversation(conversation);
          },
          onConversationDeleted: (conversationId) {
            final conversation = chatService.conversations.firstWhere(
              (c) => c.id == conversationId,
            );
            chatService.deleteConversation(conversation);
          },
          onConversationRenamed: (conversationId, newTitle) {
            final conversation = chatService.conversations.firstWhere(
              (c) => c.id == conversationId,
            );
            chatService.updateConversationTitle(conversation, newTitle);
          },
          onNewConversation: () => chatService.createConversation(),
          isCollapsed: false,
        );
      },
    );
  }
}

class _ChatPane extends StatelessWidget {
  const _ChatPane({
    required this.isCompact,
    required this.scrollController,
    required this.onSendMessage,
  });

  final bool isCompact;
  final ScrollController scrollController;
  final void Function(StreamingChatService service, String message)
  onSendMessage;

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamingChatService>(
      builder: (context, chatService, child) {
        final conversation = chatService.currentConversation;
        final spacing = AppTheme.spacingOf(context);

        if (conversation == null) {
          return const _EmptyConversationState();
        }

        return Container(
          color: AppTheme.backgroundMain,
          child: Column(
            children: [
              Expanded(
                child: _MessageList(
                  conversation: conversation,
                  controller: scrollController,
                ),
              ),
              Container(
                padding: EdgeInsets.only(
                  bottom: isCompact ? spacing.m : spacing.l,
                  left: spacing.m,
                  right: spacing.m,
                ),
                color: AppTheme.backgroundMain,
                child: MessageInput(
                  onSendMessage: (message) =>
                      onSendMessage(chatService, message),
                  isLoading: chatService.isLoading,
                  placeholder: chatService.selectedModel == null
                      ? 'Please select a model first...'
                      : 'Type your message...',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.conversation, required this.controller});

  final Conversation conversation;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final spacing = AppTheme.spacingOf(context);
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.symmetric(vertical: spacing.m),
      itemCount: conversation.messages.length,
      itemBuilder: (context, index) {
        if (index >= conversation.messages.length) {
          return const SizedBox.shrink();
        }
        final message = conversation.messages[index];
        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          showAvatar: true,
          onRetry: message.hasError
              ? () {
                  final chatService = context.read<StreamingChatService>();
                  _retryMessage(chatService, message);
                }
              : null,
        );
      },
    );
  }

  static void _retryMessage(
    StreamingChatService chatService,
    Message errorMessage,
  ) {
    final conversation = chatService.currentConversation;
    if (conversation == null) return;

    String? lastUserMessage;
    final messages = conversation.messages;

    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.id == errorMessage.id) {
        for (int j = i - 1; j >= 0; j--) {
          if (messages[j].role == MessageRole.user) {
            lastUserMessage = messages[j].content;
            break;
          }
        }
        break;
      }
    }

    if (lastUserMessage != null && lastUserMessage.isNotEmpty) {
      chatService.sendMessage(lastUserMessage);
    }
  }
}

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState();

  @override
  Widget build(BuildContext context) {
    final spacing = AppTheme.spacingOf(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: AppTheme.textColorLight,
                ),
                SizedBox(height: spacing.l),
                Text(
                  'Welcome to CloudToLocalLLM',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.m),
                Text(
                  'Start a new conversation to begin chatting with your local LLM',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.xl),
                Consumer<StreamingChatService>(
                  builder: (context, chatService, child) {
                    return ElevatedButton.icon(
                      onPressed: () => chatService.createConversation(),
                      icon: const Icon(Icons.add),
                      label: const Text('Start New Conversation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.l,
                          vertical: spacing.m,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WebDownloadOverlay extends StatelessWidget {
  const _WebDownloadOverlay();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Consumer<WebDownloadPromptService>(
        builder: (context, webDownloadPrompt, child) {
          if (!webDownloadPrompt.shouldShowPrompt) {
            return const SizedBox.shrink();
          }

          return WebDownloadPrompt(
            isFirstTimeUser: webDownloadPrompt.isFirstTimeUser,
            onDismiss: () async {
              await webDownloadPrompt.markPromptSeen();
              await webDownloadPrompt.hidePrompt();
            },
          );
        },
      ),
    );
  }
}

class _NewConversationButton extends StatelessWidget {
  const _NewConversationButton();

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamingChatService>(
      builder: (context, chatService, child) {
        return FloatingActionButton(
          onPressed: () => chatService.createConversation(),
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        );
      },
    );
  }
}
