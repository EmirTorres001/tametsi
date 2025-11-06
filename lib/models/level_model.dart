import 'package:json_annotation/json_annotation.dart';

part 'level_model.g.dart'; // Archivo que se genera

@JsonSerializable()
class Level {
  final String name;
  final int rows;
  final int cols;
  final String topology; // <-- ¡ESTA ES LA LÍNEA NUEVA!
  final List<String> layout;

  Level({
    required this.name,
    required this.rows,
    required this.cols,
    required this.topology, // <-- AÑADE ESTO
    required this.layout,
  });

  factory Level.fromJson(Map<String, dynamic> json) => _$LevelFromJson(json);
  Map<String, dynamic> toJson() => _$LevelToJson(this);
}
