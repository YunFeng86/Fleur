import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/services/opml/opml_service.dart';

final opmlServiceProvider = Provider<OpmlService>((ref) => OpmlService());
