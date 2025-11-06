import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/level_model.dart';

class LevelService {
  Future<Level> loadLevel(String levelPath) async {
    final String response = await rootBundle.loadString(levelPath);
    final data = await json.decode(response);
    return Level.fromJson(data);
  }
}
