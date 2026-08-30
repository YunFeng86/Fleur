class ResponseShapeException extends StateError {
  ResponseShapeException({
    required this.backend,
    required this.endpoint,
    required this.field,
    required this.expectedType,
    required this.actualType,
    this.itemIndex,
  }) : super('invalid response shape');

  final String backend;
  final String endpoint;
  final String field;
  final String expectedType;
  final String actualType;
  final int? itemIndex;

  @override
  String toString() {
    final index = itemIndex == null ? '' : ', itemIndex=$itemIndex';
    return 'Invalid response shape (backend=$backend, endpoint=$endpoint, '
        'field=$field, expectedType=$expectedType, actualType=$actualType$index)';
  }
}
