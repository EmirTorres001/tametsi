// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'level_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Level _$LevelFromJson(Map<String, dynamic> json) => Level(
  name: json['name'] as String,
  rows: (json['rows'] as num).toInt(),
  cols: (json['cols'] as num).toInt(),
  topology: json['topology'] as String,
  layout: (json['layout'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$LevelToJson(Level instance) => <String, dynamic>{
  'name': instance.name,
  'rows': instance.rows,
  'cols': instance.cols,
  'topology': instance.topology,
  'layout': instance.layout,
};
