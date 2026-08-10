enum AppMessagePriority { normal, important, critical }


class AppEntitlements {
  const AppEntitlements({
    required this.hypeCatalogue,
    required this.premiumVod,
    required this.mode,
  });

  final bool hypeCatalogue;
  final bool premiumVod;
  final String mode;

  factory AppEntitlements.fromJson(Map<String, dynamic> json) {
    return AppEntitlements(
      hypeCatalogue: json['hype_catalogue'] != false,
      premiumVod: json['premium_vod'] == true,
      mode: json['mode']?.toString() ?? 'hype_only',
    );
  }
}

class MaintenanceStatus {
  const MaintenanceStatus({
    required this.enabled,
    this.message,
    this.estimatedReturn,
  });

  final bool enabled;
  final String? message;
  final String? estimatedReturn;

  factory MaintenanceStatus.fromJson(Map<String, dynamic> json) {
    return MaintenanceStatus(
      enabled: json['enabled'] == true,
      message: json['message']?.toString(),
      estimatedReturn: json['estimated_return']?.toString(),
    );
  }
}

class AppMessage {
  const AppMessage({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
  });

  final String id;
  final String title;
  final String message;
  final AppMessagePriority priority;

  factory AppMessage.fromJson(Map<String, dynamic> json) {
    final priority = switch (json['priority']?.toString().toLowerCase()) {
      'critical' => AppMessagePriority.critical,
      'important' => AppMessagePriority.important,
      _ => AppMessagePriority.normal,
    };
    return AppMessage(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'HypeTV',
      message: json['message']?.toString() ?? '',
      priority: priority,
    );
  }
}

class AppBootstrap {
  const AppBootstrap({
    required this.maintenance,
    required this.messages,
    required this.entitlements,
  });

  final MaintenanceStatus maintenance;
  final List<AppMessage> messages;
  final AppEntitlements entitlements;

  factory AppBootstrap.fromJson(Map<String, dynamic> json) {
    final maintenanceJson = json['maintenance'];
    final messageJson = json['messages'];
    final entitlementJson = json['entitlements'];
    return AppBootstrap(
      maintenance: MaintenanceStatus.fromJson(
        maintenanceJson is Map<String, dynamic> ? maintenanceJson : const {},
      ),
      entitlements: AppEntitlements.fromJson(
        entitlementJson is Map<String, dynamic> ? entitlementJson : const {},
      ),
      messages: messageJson is List
          ? messageJson
                .whereType<Map<String, dynamic>>()
                .map(AppMessage.fromJson)
                .where((message) => message.id.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}
