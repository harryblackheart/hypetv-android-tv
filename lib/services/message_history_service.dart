import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/features/platform/domain/app_bootstrap.dart';
import 'package:hypetv/services/secure_storage_service.dart';

final messageHistoryProvider =
    AsyncNotifierProvider<MessageHistoryNotifier, List<AppMessage>>(
  MessageHistoryNotifier.new,
);

class MessageHistoryNotifier extends AsyncNotifier<List<AppMessage>> {
  @override
  Future<List<AppMessage>> build() async {
    final raw = await ref.read(secureStorageServiceProvider).messageHistory;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AppMessage.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> rememberAll(Iterable<AppMessage> messages) async {
    final current = state.value ?? const <AppMessage>[];
    final byId = <String, AppMessage>{for (final item in current) item.id: item};
    for (final item in messages) {
      if (item.id.isNotEmpty) byId[item.id] = item;
    }
    final updated = byId.values.toList(growable: false);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    await _persist(const []);
  }

  Future<void> _persist(List<AppMessage> messages) async {
    await ref.read(secureStorageServiceProvider).saveMessageHistory(
          jsonEncode(messages.map((item) => item.toJson()).toList()),
        );
  }
}
