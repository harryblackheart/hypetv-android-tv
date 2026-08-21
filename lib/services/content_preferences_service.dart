import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/services/secure_storage_service.dart';


enum DisplayMode {
  automatic,
  tv,
  mobile;

  String get label => switch (this) {
        automatic => 'Automatic',
        tv => 'TV mode',
        mobile => 'Mobile mode',
      };
}

enum StartScreen {
  landing,
  live,
  movies,
  series;

  String get label => switch (this) {
        landing => 'Landing page',
        live => 'Live TV',
        movies => 'Movies',
        series => 'Series',
      };

  String get route => switch (this) {
        landing => '/home',
        live => '/live',
        movies => '/movies',
        series => '/series',
      };
}

class ContentPreferences {
  const ContentPreferences({
    this.startScreen = StartScreen.landing,
    this.showLive = true,
    this.showMovies = true,
    this.showSeries = true,
    this.hiddenLiveGroups = const <String>{},
    this.displayMode = DisplayMode.automatic,
    this.deviceName = 'HypeTV Device',
  });

  final StartScreen startScreen;
  final bool showLive;
  final bool showMovies;
  final bool showSeries;
  final Set<String> hiddenLiveGroups;
  final DisplayMode displayMode;
  final String deviceName;

  ContentPreferences copyWith({
    StartScreen? startScreen,
    bool? showLive,
    bool? showMovies,
    bool? showSeries,
    Set<String>? hiddenLiveGroups,
    DisplayMode? displayMode,
    String? deviceName,
  }) => ContentPreferences(
        startScreen: startScreen ?? this.startScreen,
        showLive: showLive ?? this.showLive,
        showMovies: showMovies ?? this.showMovies,
        showSeries: showSeries ?? this.showSeries,
        hiddenLiveGroups: hiddenLiveGroups ?? this.hiddenLiveGroups,
        displayMode: displayMode ?? this.displayMode,
        deviceName: deviceName ?? this.deviceName,
      );

  Map<String, dynamic> toJson() => {
        'start_screen': startScreen.name,
        'show_live': showLive,
        'show_movies': showMovies,
        'show_series': showSeries,
        'hidden_live_groups': hiddenLiveGroups.toList(),
        'display_mode': displayMode.name,
        'device_name': deviceName,
      };

  factory ContentPreferences.fromJson(Map<String, dynamic> json) {
    final startName = json['start_screen']?.toString();
    final displayName = json['display_mode']?.toString();
    return ContentPreferences(
      startScreen: StartScreen.values.firstWhere(
        (value) => value.name == startName,
        orElse: () => StartScreen.landing,
      ),
      showLive: json['show_live'] != false,
      showMovies: json['show_movies'] != false,
      showSeries: json['show_series'] != false,
      hiddenLiveGroups: (json['hidden_live_groups'] is List)
          ? (json['hidden_live_groups'] as List)
              .map((value) => value.toString())
              .toSet()
          : const <String>{},
      deviceName: json['device_name']?.toString().trim().isNotEmpty == true
          ? json['device_name'].toString().trim()
          : 'HypeTV Device',
      displayMode: DisplayMode.values.firstWhere(
        (value) => value.name == displayName,
        orElse: () => DisplayMode.automatic,
      ),
    );
  }
}

final contentPreferencesProvider =
    AsyncNotifierProvider<ContentPreferencesNotifier, ContentPreferences>(
  ContentPreferencesNotifier.new,
);

class ContentPreferencesNotifier extends AsyncNotifier<ContentPreferences> {
  @override
  Future<ContentPreferences> build() async {
    final raw = await ref.read(secureStorageServiceProvider).contentPreferences;
    if (raw == null || raw.isEmpty) return const ContentPreferences();
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? ContentPreferences.fromJson(decoded)
          : const ContentPreferences();
    } catch (_) {
      return const ContentPreferences();
    }
  }

  Future<void> save(ContentPreferences value) async {
    state = AsyncData(value);
    await ref
        .read(secureStorageServiceProvider)
        .saveContentPreferences(jsonEncode(value.toJson()));
  }
}
