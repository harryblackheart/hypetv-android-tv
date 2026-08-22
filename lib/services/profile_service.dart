import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/services/secure_storage_service.dart';
import 'package:uuid/uuid.dart';

enum HypeProfileKind { standard, kids }

class HypeProfile {
  const HypeProfile({
    required this.id,
    required this.name,
    required this.avatar,
    this.kind = HypeProfileKind.standard,
    this.pinHash,
  });

  final String id;
  final String name;
  final String avatar;
  final HypeProfileKind kind;
  final String? pinHash;

  bool get isKids => kind == HypeProfileKind.kids;
  bool get isLocked => pinHash?.isNotEmpty == true;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'kind': kind.name,
        'pin_hash': pinHash,
      };

  factory HypeProfile.fromJson(Map<String, dynamic> json) => HypeProfile(
        id: json['id']?.toString() ?? const Uuid().v4(),
        name: json['name']?.toString() ?? 'Profile',
        avatar: json['avatar']?.toString() ?? 'rocket',
        kind: json['kind']?.toString() == 'kids'
            ? HypeProfileKind.kids
            : HypeProfileKind.standard,
        pinHash: json['pin_hash']?.toString(),
      );
}

class ProfileState {
  const ProfileState({required this.profiles, required this.activeId});
  final List<HypeProfile> profiles;
  final String activeId;

  HypeProfile get active => profiles.firstWhere(
        (p) => p.id == activeId,
        orElse: () => profiles.first,
      );
}

final profileProvider =
    AsyncNotifierProvider<ProfileController, ProfileState>(ProfileController.new);

class ProfileController extends AsyncNotifier<ProfileState> {
  static const avatars = <String>[
    'rocket', 'robot', 'lion', 'panda', 'fox', 'unicorn', 'dino', 'ninja'
  ];

  @override
  Future<ProfileState> build() async {
    final storage = ref.read(secureStorageServiceProvider);
    final raw = await storage.profiles;
    final active = await storage.activeProfileId;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final profiles = decoded
              .whereType<Map<String, dynamic>>()
              .map(HypeProfile.fromJson)
              .toList();
          if (profiles.isNotEmpty) {
            return ProfileState(
              profiles: profiles,
              activeId: profiles.any((p) => p.id == active)
                  ? active!
                  : profiles.first.id,
            );
          }
        }
      } catch (_) {}
    }
    final first = HypeProfile(
      id: const Uuid().v4(),
      name: 'Main',
      avatar: 'rocket',
    );
    await storage.saveProfiles(jsonEncode([first.toJson()]));
    await storage.saveActiveProfileId(first.id);
    return ProfileState(profiles: [first], activeId: first.id);
  }

  Future<void> select(String id) async {
    final current = state.value;
    if (current == null || !current.profiles.any((p) => p.id == id)) return;
    state = AsyncData(ProfileState(profiles: current.profiles, activeId: id));
    await ref.read(secureStorageServiceProvider).saveActiveProfileId(id);
  }

  Future<void> add({
    required String name,
    required String avatar,
    bool kids = false,
  }) async {
    final current = state.value;
    if (current == null || current.profiles.length >= 5) return;
    final profile = HypeProfile(
      id: const Uuid().v4(),
      name: name.trim().isEmpty ? 'Profile' : name.trim(),
      avatar: avatar,
      kind: kids ? HypeProfileKind.kids : HypeProfileKind.standard,
    );
    final profiles = [...current.profiles, profile];
    state = AsyncData(ProfileState(profiles: profiles, activeId: profile.id));
    final storage = ref.read(secureStorageServiceProvider);
    await storage.saveProfiles(jsonEncode(profiles.map((p) => p.toJson()).toList()));
    await storage.saveActiveProfileId(profile.id);
  }
}
