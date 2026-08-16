enum AppMessagePriority { normal, important, critical }

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'priority': priority.name,
      };

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
  const AppBootstrap({required this.maintenance, required this.messages});

  final MaintenanceStatus maintenance;
  final List<AppMessage> messages;

  factory AppBootstrap.fromJson(Map<String, dynamic> json) {
    final maintenanceJson = json['maintenance'];
    final messageJson = json['messages'];
    return AppBootstrap(
      maintenance: MaintenanceStatus.fromJson(
        maintenanceJson is Map<String, dynamic> ? maintenanceJson : const {},
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
