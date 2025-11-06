import 'package:json_annotation/json_annotation.dart';
part 'level_model.g.dart'; // Archivo generado por build_runner

@JsonSerializable()
class Level {
  final String name;
  final int rows;
  final int cols;
  final String topology; // 'square' o 'hexagon'
  final List<String> layout; // Representación del tablero

  Level({
    required this.name,
    required this.rows,
    required this.cols,
    required this.topology,
    required this.layout,
  });

  factory Level.fromJson(Map<String, dynamic> json) => _$LevelFromJson(json);
  Map<String, dynamic> toJson() => _$LevelToJson(this);
}
