/// RAG (Retrieval-Augmented Generation) service using LangChain
///
/// Provides document Q&A capabilities by combining document retrieval
/// with LLM generation for accurate, context-aware responses.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_ollama/langchain_ollama.dart';

import 'langchain_ollama_service.dart';

/// Document Q&A service using RAG (Retrieval-Augmented Generation)
class LangChainRAGService extends ChangeNotifier {
  final LangChainOllamaService _ollamaService;

  // RAG components
  MemoryVectorStore? _vectorStore;
  OllamaEmbeddings? _embeddings;
  VectorStoreRetriever? _retriever;
  Runnable? _ragChain;

  // State management
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  final List<Document> _documents = [];
  int _documentCount = 0;

  LangChainRAGService({required LangChainOllamaService ollamaService})
    : _ollamaService = ollamaService;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get documentCount => _documentCount;
  bool get hasDocuments => _documentCount > 0;

  /// Initialize the RAG service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true);
      _clearError();

      debugPrint('[langchain_rag_service] Initializing RAG service');

      // Ensure Ollama service is initialized
      if (!_ollamaService.isInitialized) {
        await _ollamaService.initialize();
      }

      // Initialize embeddings model
      await _initializeEmbeddings();

      // Create vector store
      await _createVectorStore();

      // Create RAG chain
      await _createRAGChain();

      _isInitialized = true;
      debugPrint('[langchain_rag_service] RAG service initialized successfully');
    } catch (e) {
      _error = 'Failed to initialize RAG service: $e';
      debugPrint('[LangChainRAG] ERROR: RAG_INIT_FAILED - $_error - $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Initialize embeddings model
  Future<void> _initializeEmbeddings() async {
    try {
      // Use a lightweight embedding model for local processing
      _embeddings = OllamaEmbeddings(
        model: 'jina/jina-embeddings-v2-small-en',
        baseUrl: _getOllamaBaseUrl(),
      );

      debugPrint('[langchain_rag_service] Embeddings model initialized');
    } catch (e) {
      debugPrint('[LangChainRAG] ERROR: EMBEDDINGS_INIT_FAILED - Failed to initialize embeddings model - $e');
      rethrow;
    }
  }

  /// Create vector store for document storage and retrieval
  Future<void> _createVectorStore() async {
    if (_embeddings == null) {
      throw StateError('Embeddings not initialized');
    }

    try {
      _vectorStore = MemoryVectorStore(embeddings: _embeddings!);

      // Create retriever with similarity search
      _retriever = _vectorStore!.asRetriever(
        defaultOptions: const VectorStoreRetrieverOptions(
          searchType: VectorStoreSimilaritySearch(k: 3),
        ),
      );

      debugPrint('[langchain_rag_service] Vector store created successfully');
    } catch (e) {
      debugPrint('[LangChainRAG] ERROR: VECTOR_STORE_FAILED - Failed to create vector store - $e');
      rethrow;
    }
  }

  /// Create RAG chain for question answering
  Future<void> _createRAGChain() async {
    if (_retriever == null || _ollamaService.chatModel == null) {
      throw StateError('Required components not initialized');
    }

    try {
      // Create RAG prompt template
      final promptTemplate = ChatPromptTemplate.fromTemplates([
        (
          ChatMessageType.system,
          '''You are a helpful assistant that answers questions based on the provided context.

Use the following pieces of context to answer the user's question. If you don't know the answer based on the context, just say that you don't know.

Context:
{context}

Guidelines:
- Be accurate and concise
- Use only information from the provided context
- If the context doesn't contain relevant information, say so
- Cite specific parts of the context when possible''',
        ),
        (ChatMessageType.human, '{question}'),
      ]);

      // Create document combiner
      String combineDocuments(List<Document> documents) {
        return documents.map((doc) => doc.pageContent).join('\n\n---\n\n');
      }

      // Create RAG chain
      _ragChain =
          Runnable.fromMap<String>({
                'context': _retriever!.pipe(
                  Runnable.mapInput<List<Document>, String>(combineDocuments),
                ),
                'question': Runnable.passthrough(),
              })
              .pipe(promptTemplate)
              .pipe(_ollamaService.chatModel!)
              .pipe(const StringOutputParser<ChatResult>());

      debugPrint('[langchain_rag_service] RAG chain created successfully');
    } catch (e) {
      debugPrint('[LangChainRAG] ERROR: RAG_CHAIN_FAILED - Failed to create RAG chain - $e');
      rethrow;
    }
  }

  /// Add documents from text content
  Future<void> addDocuments(
    List<String> texts, {
    List<Map<String, dynamic>>? metadatas,
  }) async {
    if (!_isInitialized || _vectorStore == null) {
      throw StateError('RAG service not initialized');
    }

    try {
      _setLoading(true);
      _clearError();

      // Create documents from texts
      final documents = texts.asMap().entries.map((entry) {
        final index = entry.key;
        final text = entry.value;
        final metadata = metadatas?[index] ?? {};

        return Document(
          pageContent: text,
          metadata: {
            'source': 'user_input',
            'index': index,
            'timestamp': DateTime.now().toIso8601String(),
            ...metadata,
          },
        );
      }).toList();

      // Add to vector store
      await _vectorStore!.addDocuments(documents: documents);

      // Update local state
      _documents.addAll(documents);
      _documentCount = _documents.length;

      debugPrint('[LangChainRAG] Documents added successfully: ${documents.length} documents, total: $_documentCount');

      notifyListeners();
    } catch (e) {
      _error = 'Failed to add documents: $e';
      debugPrint('[LangChainRAG] ERROR: DOCUMENTS_ADD_FAILED - $_error - $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Load documents from file
  Future<void> loadDocumentFromFile(File file) async {
    try {
      _setLoading(true);
      _clearError();

      final content = await file.readAsString();
      final fileName = file.path.split('/').last;

      // Split large documents into chunks
      const textSplitter = RecursiveCharacterTextSplitter(
        chunkSize: 1000,
        chunkOverlap: 200,
      );

      final chunks = textSplitter.splitText(content);

      // Create metadata for each chunk
      final metadatas = chunks
          .asMap()
          .entries
          .map(
            (entry) => {
              'source': fileName,
              'chunk': entry.key,
              'file_path': file.path,
            },
          )
          .toList();

      await addDocuments(chunks, metadatas: metadatas);

      debugPrint('[LangChainRAG] Document loaded from file: $fileName (${chunks.length} chunks)');
    } catch (e) {
      _error = 'Failed to load document from file: $e';
      debugPrint('[LangChainRAG] ERROR: FILE_LOAD_FAILED - $_error - $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Ask a question about the loaded documents
  Future<String> askQuestion(String question) async {
    if (!_isInitialized || _ragChain == null) {
      throw StateError('RAG service not initialized');
    }

    if (_documentCount == 0) {
      throw StateError('No documents loaded. Please add documents first.');
    }

    try {
      _setLoading(true);
      _clearError();

      debugPrint('[LangChainRAG] Processing question: length=${question.length}, docs=$_documentCount');

      // Invoke RAG chain
      final answer = await _ragChain!.invoke(question);

      final answerString = answer.toString();
      debugPrint('[LangChainRAG] Question answered successfully: length=${answerString.length}');

      return answerString;
    } catch (e) {
      _error = 'Failed to answer question: $e';
      debugPrint('[LangChainRAG] ERROR: QUESTION_FAILED - $_error - $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Search for relevant documents
  Future<List<Document>> searchDocuments(String query, {int limit = 5}) async {
    if (!_isInitialized || _retriever == null) {
      throw StateError('RAG service not initialized');
    }

    try {
      final results = await _retriever!.invoke(query);
      return results.take(limit).toList();
    } catch (e) {
      debugPrint('[LangChainRAG] ERROR: SEARCH_FAILED - Failed to search documents - $e');
      rethrow;
    }
  }

  /// Clear all documents
  Future<void> clearDocuments() async {
    try {
      _documents.clear();
      _documentCount = 0;

      // Recreate vector store to clear embeddings
      await _createVectorStore();
      await _createRAGChain();

      debugPrint('[langchain_rag_service] All documents cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('[LangChainRAG] ERROR: CLEAR_DOCUMENTS_FAILED - Failed to clear documents - $e');
      rethrow;
    }
  }

  /// Get Ollama base URL from the main service
  String _getOllamaBaseUrl() {
    // Use the same URL logic as the main Ollama service
    return 'http://localhost:11434'; // This should be coordinated with the main service
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _documents.clear();
    super.dispose();
  }
}

