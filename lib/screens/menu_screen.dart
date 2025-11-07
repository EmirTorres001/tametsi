import 'dart:convert';
import 'dart:math'; // Para la animación
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/persistence_service.dart';
import 'game_screen.dart';

// (Los providers 'persistenceServiceProvider' y 'levelListProvider'
// se quedan exactamente igual que antes)
final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  return PersistenceService();
});

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

// --- PANTALLA DEL MENÚ (HÍBRIDA) ---
// Usamos ConsumerStatefulWidget para manejar el PageController
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  late PageController _pageController;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    // Configura el PageController para mostrar "vistas previas"
    _pageController = PageController(
      viewportFraction: 0.8, // Muestra el 80% de la tarjeta
      initialPage: 0,
    );
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelListAsync = ref.watch(levelListProvider);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      // Usamos CustomScrollView para combinar Slivers y otros widgets
      body: CustomScrollView(
        slivers: [
          // --- 1. El AppBar Flexible (de la V-Premium) ---
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            stretch: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Niveles",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.8),
                      theme.scaffoldBackgroundColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 1.0],
                  ),
                ),
                child: const Icon(
                  FontAwesomeIcons.brain,
                  size: 80,
                  color: Colors.white24,
                ),
              ),
            ),
          ),

          // --- 2. El PageView (de la V-Carrusel) ---
          // Usamos 'when' para manejar los estados de carga
          levelListAsync.when(
            data: (levelPaths) {
              if (levelPaths.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      "No se encontraron niveles en 'assets/levels/'",
                    ),
                  ),
                );
              }

              // Usamos SliverToBoxAdapter para poner un widget normal
              // (como un PageView) dentro de un CustomScrollView.
              return SliverToBoxAdapter(
                child: Container(
                  // Le damos una altura fija al carrusel
                  height: 450,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: levelPaths.length,
                    itemBuilder: (context, index) {
                      final levelPath = levelPaths[index];
                      final levelName = levelPath
                          .split('/')
                          .last
                          .replaceAll('.json', '')
                          .replaceAll('_', ' ')
                          .replaceAll('level ', '');

                      final bool isHex = levelPath.contains('hex');

                      // --- Lógica de Animación ---
                      double difference = (index - _currentPage).abs();
                      double scale = (1.0 - (difference * 0.15)).clamp(
                        0.85,
                        1.0,
                      );
                      double opacity = (1.0 - (difference * 0.4)).clamp(
                        0.6,
                        1.0,
                      );

                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          child: LevelCard(
                            levelName: levelName,
                            levelPath: levelPath,
                            isHex: isHex,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            // --- Estados de Error y Carga ---
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text("Error al cargar niveles:\n$err")),
            ),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET DE TARJETA DE NIVEL (de la V-Carrusel) ---
class LevelCard extends ConsumerWidget {
  const LevelCard({
    required this.levelName,
    required this.levelPath,
    required this.isHex,
    super.key,
  });

  final String levelName;
  final String levelPath;
  final bool isHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final persistenceService = ref.watch(persistenceServiceProvider);

    return FutureBuilder<bool>(
      future: persistenceService.isLevelCompleted(levelPath),
      builder: (context, snapshot) {
        final isCompleted = snapshot.data ?? false;

        final Gradient defaultGradient = LinearGradient(
          colors: [
            theme.colorScheme.surfaceVariant.withOpacity(0.7),
            theme.colorScheme.surfaceVariant,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        final Gradient completedGradient = LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 10.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: isCompleted ? completedGradient : defaultGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (context) =>
                              GameScreen(levelAssetPath: levelPath),
                        ),
                      )
                      .then((_) {
                        ref.invalidate(persistenceServiceProvider);
                      });
                },
                child: Stack(
                  children: [
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Icon(
                        isHex
                            ? FontAwesomeIcons.hexagon
                            : FontAwesomeIcons.square,
                        size: 150,
                        color: isCompleted
                            ? theme.colorScheme.onPrimary.withOpacity(0.1)
                            : theme.colorScheme.onSurface.withOpacity(0.05),
                      ),
                    ),
                    Positioned(
                      top: 30,
                      left: 24,
                      right: 24,
                      child: Text(
                        "Nivel",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isCompleted
                              ? theme.colorScheme.onPrimary.withOpacity(0.8)
                              : theme.colorScheme.onSurfaceVariant.withOpacity(
                                  0.8,
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 50,
                      left: 24,
                      right: 24,
                      child: Text(
                        levelName,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCompleted)
                      Positioned(
                        bottom: 24,
                        left: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade300,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Completado",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
