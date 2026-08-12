import '../utils/json_utils.dart';
import 'enums.dart';

class ChainStep {
  final String requestId;
  final String requestName;
  final int delayMs;
  final bool usePreviousResponse;

  const ChainStep({
    required this.requestId,
    required this.requestName,
    this.delayMs = 0,
    this.usePreviousResponse = false,
  });

  ChainStep copyWith({int? delayMs, bool? usePreviousResponse}) {
    return ChainStep(
      requestId: requestId,
      requestName: requestName,
      delayMs: delayMs ?? this.delayMs,
      usePreviousResponse: usePreviousResponse ?? this.usePreviousResponse,
    );
  }

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'requestName': requestName,
    'delayMs': delayMs,
    'usePreviousResponse': usePreviousResponse,
  };

  factory ChainStep.fromJson(Map<String, dynamic> json) {
    return ChainStep(
      requestId: json['requestId'] as String,
      requestName: json['requestName'] as String? ?? '',
      delayMs: json['delayMs'] as int? ?? 0,
      usePreviousResponse: json['usePreviousResponse'] as bool? ?? false,
    );
  }
}

class SavedChain {
  final String id;
  final String name;
  final String? description;
  final List<ChainStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedChain({
    required this.id,
    required this.name,
    this.description,
    this.steps = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  SavedChain copyWith({String? name, String? description, List<ChainStep>? steps, DateTime? updatedAt}) {
    return SavedChain(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      steps: steps ?? this.steps,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'steps': steps.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SavedChain.fromJson(Map<String, dynamic> json) {
    return SavedChain(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled Flow',
      description: json['description'] as String?,
      steps: (json['steps'] as List? ?? const []).whereType<Map>().map((e) => ChainStep.fromJson(Map<String, dynamic>.from(e))).toList(),
      createdAt: dateTimeFrom(json['createdAt']),
      updatedAt: dateTimeFrom(json['updatedAt']),
    );
  }
}

class ChainStepResult {
  final ChainStep step;
  final RunStatus status;
  final int? statusCode;
  final Duration? duration;
  final String? errorMessage;
  final dynamic responseBody;

  const ChainStepResult({
    required this.step,
    required this.status,
    this.statusCode,
    this.duration,
    this.errorMessage,
    this.responseBody,
  });
}
