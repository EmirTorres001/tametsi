import 'package:shared_preferences/shared_preferences.dart';

// Definimos una clase para encapsular la lógica de guardado y carga.
// Esto hace que nuestro código sea más limpio y fácil de probar.
class PersistenceService {
  // Utilizamos un prefijo para nuestras claves. Esto evita colisiones si en el futuro
  // guardamos otro tipo de datos en SharedPreferences (ej. "settings_darkMode").
  static const String _levelCompletedPrefix = 'level_completed_';

  /// Guarda el estado de completado para un nivel específico.
  ///
  /// Usa el [levelPath] como una clave única para identificar el nivel.
  Future<void> saveLevelProgress(String levelPath) async {
    // 1. Obtiene una instancia del almacenamiento local.
    final prefs = await SharedPreferences.getInstance();

    // 2. Construye la clave única para este nivel.
    final key = '$_levelCompletedPrefix$levelPath';

    // 3. Guarda el valor 'true' en esa clave.
    // Si la clave ya existe, su valor se sobrescribirá.
    await prefs.setBool(key, true);
  }

  /// Verifica si un nivel específico ha sido completado.
  ///
  /// Devuelve `true` si el nivel está marcado como completado, `false` en caso contrario.
  Future<bool> isLevelCompleted(String levelPath) async {
    // 1. Obtiene una instancia del almacenamiento.
    final prefs = await SharedPreferences.getInstance();

    // 2. Construye la clave que estamos buscando.
    final key = '$_levelCompletedPrefix$levelPath';

    // 3. Intenta leer el valor booleano de la clave.
    // Si la clave no existe, `getBool` devuelve `null`.
    // Usamos el operador `??` (null-aware) para devolver `false` en ese caso.
    return prefs.getBool(key) ?? false;
  }

  /// (Opcional) Método para limpiar el progreso de todos los niveles.
  /// Útil para pruebas o si quieres añadir un botón de "Reiniciar Progreso" en los ajustes.
  Future<void> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    for (String key in allKeys) {
      if (key.startsWith(_levelCompletedPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
