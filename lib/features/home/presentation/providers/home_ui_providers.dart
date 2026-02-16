import 'package:flutter_riverpod/legacy.dart';

/// UI-scoped provider that tracks the currently selected collection on Home.
final selectedCollectionIdProvider = StateProvider<String?>((ref) => 'default');

