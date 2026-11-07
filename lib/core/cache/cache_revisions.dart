import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-process signal for cache-only readers; never starts a network refresh.
final homeworkCacheRevisionProvider = StateProvider<int>((ref) => 0);

final homeworkSubmissionRevisionProvider = StateProvider<int>((ref) => 0);
