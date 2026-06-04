import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/reader_document/reader_document_cache.dart';
import '../services/reader_document/reader_document_handle.dart';
import '../services/reader_document/reader_document_models.dart';
import '../services/reader_document/reader_document_pipeline.dart';

final readerDocumentCacheProvider = Provider<ReaderDocumentCache>((ref) {
  final cache = ReaderDocumentCache();
  ref.onDispose(cache.clear);
  return cache;
});

final readerDocumentPipelineProvider = Provider<ReaderDocumentPipeline>((ref) {
  return const ReaderDocumentPipeline();
});

final readerDocumentProvider =
    AutoDisposeProviderFamily<ReaderDocumentHandle, ReaderDocumentRequest>((
      ref,
      request,
    ) {
      final handle = ref
          .watch(readerDocumentPipelineProvider)
          .build(
            request: request,
            cache: ref.watch(readerDocumentCacheProvider),
          );
      ref.onDispose(handle.dispose);
      return handle;
    });
