enum RemoteMirrorUpsertStatus { bound, identityConflict }

class RemoteMirrorUpsertResult {
  const RemoteMirrorUpsertResult({
    required this.localId,
    required this.requestedRemoteId,
    required this.effectiveRemoteId,
    required this.status,
  });

  final int localId;
  final String requestedRemoteId;
  final String? effectiveRemoteId;
  final RemoteMirrorUpsertStatus status;

  bool get isBound => status == RemoteMirrorUpsertStatus.bound;
}
