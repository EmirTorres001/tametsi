import 'dart:convert'; // Para decodificar el AssetManifest.json
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. IMPORTA TUS SERVICIOS Y PANTALLAS
// Asegúrate de que estas rutas coincidan con la estructura de tu proyecto.
import '../services/persistence_service.dart';
import '../screens/game_screen.dart';

// 2. PROVIDER PARA TU SERVICIO DE PERSISTENCIA
// Esto nos permite acceder al PersistenceService desde cualquier widget
// que sea un ConsumerWidget, como nuestro LevelListTile.
final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  return PersistenceService();
});

// 3. PROVIDER PARA CARGAR LA LISTA DE NIVELES
// Usamos un FutureProvider para realizar esta operación asíncrona una sola vez
// y cachear el resultado.
final levelListProvider = FutureProvider<List<String>>((ref) async {
  // Carga el manifiesto de assets, que es un JSON que lista todos los archivos.
  final manifestContent = await rootBundle.loadString('AssetManifest.json');
  final Map<String, dynamic> manifestMap = json.decode(manifestContent);

  // Filtra las claves del manifiesto para encontrar solo nuestros archivos JSON de niveles.
  final levelPaths = manifestMap.keys
      .where(
        (path) => path.startsWith('assets/levels/') && path.endsWith('.json'),
      )
      .toList();

  // Ordena los niveles alfabéticamente para asegurar un orden consistente.
  levelPaths.sort();

  return levelPaths;
});

// 4. PANTALLA DEL MENÚ PRINCIPAL
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observa el estado de nuestro FutureProvider.
    // Riverpod maneja automáticamente los estados de carga, error y datos.
    final levelListAsync = ref.watch(levelListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar Nivel"),
        // El color del fondo de la AppBar se adaptará al tema (claro/oscuro)
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      ),
      body: levelListAsync.when(
        // --- Estado: Datos cargados ---
        data: (levelPaths) {
          if (levelPaths.isEmpty) {
            return const Center(
              child: Text("No se encontraron niveles en 'assets/levels/'"),
            );
          }

          // Construye la lista usando los paths de los niveles
          return ListView.builder(
            itemCount: levelPaths.length,
            itemBuilder: (context, index) {
              final levelPath = levelPaths[index];
              // Crea un nombre legible para el nivel. Ej: "Nivel 1"
              final levelName = "Nivel ${index + 1}";

              // Usamos un widget separado para el ListTile
              // para mantener el código limpio.
              return LevelListTile(levelName: levelName, levelPath: levelPath);
            },
          );
        },
        // --- Estado: Error ---
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Error al cargar niveles:\n$err"),
          ),
        ),
        // --- Estado: Cargando ---
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// 5. WIDGET REUTILIZABLE PARA CADA FILA DE LA LISTA
// Lo hacemos un ConsumerWidget para que pueda leer el persistenceServiceProvider.
class LevelListTile extends ConsumerWidget {
  const LevelListTile({
    required this.levelName,
    required this.levelPath,
    super.key,
  });

  final String levelName;
  final String levelPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observa el servicio de persistencia
    final persistenceService = ref.watch(persistenceServiceProvider);

    return ListTile(
      title: Text(levelName),

      // Usa un FutureBuilder para verificar el estado de completado
      // Usamos el 'levelPath' como clave única para guardar el progreso.
      trailing: FutureBuilder<bool>(
        future: persistenceService.isLevelCompleted(levelPath),
        builder: (context, snapshot) {
          final isCompleted = snapshot.data ?? false;

          if (isCompleted) {
            // Nivel completado
            return Icon(Icons.check_circle, color: Colors.green.shade600);
          } else {
            // Nivel no completado
            return Icon(
              Icons.check_circle_outline,
              color: Colors.grey.shade400,
            );
          }
        },
      ),
      onTap: () {
        // Navega a la pantalla de juego, pasando el path del nivel.
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => GameScreen(levelAssetPath: levelPath),
              ),
            )
            .then((_) {
              ref.invalidate(persistenceServiceProvider);
            });
      },
    );
  }
}
