import 'dart:convert'; // Para decodificar el AssetManifest.json
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. IMPORTA TUS SERVICIOS Y PANTALLAS
import '../services/persistence_service.dart';
import 'game_screen.dart';

// 2. PROVIDER PARA TU SERVICIO DE PERSISTENCIA
final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  return PersistenceService();
});

// 3. PROVIDER PARA CARGAR LA LISTA DE NIVELES
final levelListProvider = FutureProvider<List<String>>((ref) async {
  final manifestContent = await rootBundle.loadString('AssetManifest.json');
  final Map<String, dynamic> manifestMap = json.decode(manifestContent);

  final levelPaths = manifestMap.keys
      .where(
        (path) => path.startsWith('assets/levels/') && path.endsWith('.json'),
      )
      .toList();

  levelPaths.sort();
  return levelPaths;
});

// 4. PANTALLA DEL MENÚ PRINCIPAL
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelListAsync = ref.watch(levelListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar Nivel"),
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

          return ListView.builder(
            itemCount: levelPaths.length,
            itemBuilder: (context, index) {
              final levelPath = levelPaths[index];
              // Extrae un nombre más legible del path
              final levelName = levelPath
                  .split('/')
                  .last // Obtiene "level_hex_1.json"
                  .replaceAll('.json', '') // Quita ".json"
                  .replaceAll('_', ' '); // Reemplaza "_" con " "

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
    final persistenceService = ref.watch(persistenceServiceProvider);

    return ListTile(
      title: Text(
        levelName.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: FutureBuilder<bool>(
        future: persistenceService.isLevelCompleted(levelPath),
        builder: (context, snapshot) {
          final isCompleted = snapshot.data ?? false;
          if (isCompleted) {
            return Icon(Icons.check_circle, color: Colors.green.shade600);
          } else {
            return Icon(
              Icons.check_circle_outline,
              color: Colors.grey.shade400,
            );
          }
        },
      ),
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => GameScreen(levelAssetPath: levelPath),
              ),
            )
            .then((_) {
              // Invalida el provider para que se refresque el ícono
              ref.invalidate(persistenceServiceProvider);
            });
      },
    );
  }
}
