import 'package:flutter/foundation.dart';
import 'langchain_ollama_service.dart';
import 'package:langchain/langchain.dart';

class LangChainRAGService extends ChangeNotifier {
  LangChainRAGService({required LangChainOllamaService ollamaService});

  bool get isInitialized => false;
  bool get isLoading => false;
  String? get error => 'RAG not supported on this platform';
  int get documentCount => 0;
  bool get hasDocuments => false;

  Future<void> initialize() async {
    debugPrint('[LangChainRAG] RAG not supported on web');
  }

  Future<void> addDocuments(
    List<String> texts, {
    List<Map<String, dynamic>>? metadatas,
  }) async {
    throw UnimplementedError('RAG not supported on web');
  }

  Future<void> loadDocumentFromFile(dynamic file) async {
    throw UnimplementedError('RAG not supported on web');
  }

  Future<String> askQuestion(String question) async {
    throw UnimplementedError('RAG not supported on web');
  }

  Future<List<Document>> searchDocuments(String query, {int limit = 5}) async {
    throw UnimplementedError('RAG not supported on web');
  }

  Future<void> clearDocuments() async {}
}
