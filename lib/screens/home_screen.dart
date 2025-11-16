import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/app_initialization_service.dart';
import '../services/streaming_chat_service.dart';
import 'home/home_layout.dart';

/// Modern ChatGPT-like chat interface
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool? _compactSidebarPreference;
  bool _initializedWithContext = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedWithContext) return;
    _initializedWithContext = true;
    final appInit = context.read<AppInitializationService>();
    scheduleMicrotask(() => appInit.initializeWithContext(context));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < AppConfig.mobileBreakpoint;
        final isSidebarCollapsed =
            isCompact ? (_compactSidebarPreference ?? true) : false;

        return HomeLayout(
          isCompact: isCompact,
          isSidebarCollapsed: isSidebarCollapsed,
          onSidebarToggle: () {
            if (!isCompact) {
              return;
            }
            setState(() {
              _compactSidebarPreference = !isSidebarCollapsed;
            });
          },
          scrollController: _scrollController,
          onSendMessage: _handleSendMessage,
        );
      },
    );
  }

  Future<void> _handleSendMessage(
    StreamingChatService chatService,
    String message,
  ) async {
    await chatService.sendMessage(message);
    scheduleMicrotask(() {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
}
