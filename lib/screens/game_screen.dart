import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:ui'; // --- CAMBIO: Necesario para el BackdropFilter (blur) ---
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // --- CAMBIO: Para iconos bonitos ---

// IMPORTACIONES
import '../providers/game_provider.dart';
import '../widgets/board_widget.dart';
import '../services/level_service.dart';
import '../services/persistence_service.dart';

// PROVIDERS
final levelServiceProvider = Provider<LevelService>((ref) => LevelService());
final persistenceServiceProvider = Provider<PersistenceService>(
  (ref) => PersistenceService(),
);

class GameScreen extends ConsumerStatefulWidget {
  final String levelAssetPath;

  const GameScreen({super.key, required this.levelAssetPath});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  // --- CAMBIO: Ya no necesitamos _isDialogShowing ---
  // bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _startNewGame();
    });
  }

  void _startNewGame() {
    // --- CAMBIO: Ya no se necesita setState ---
    ref.read(gameProvider.notifier).newGame(widget.levelAssetPath);
  }

  // --- CAMBIO: La función _showResultDialog se elimina por completo ---

  @override
  Widget build(BuildContext context) {
    // --- CAMBIO: ref.listen ahora SOLO se encarga de guardar el progreso ---
    ref.listen<GameState>(gameProvider, (previousState, newState) {
      if (newState.status == GameStatus.won) {
        // Guarda el progreso en segundo plano
        ref
            .read(persistenceServiceProvider)
            .saveLevelProgress(widget.levelAssetPath);
      }
      // Ya no llamamos a _showResultDialog
    });

    final gameState = ref.watch(gameProvider);
    final gameStatus = gameState.status;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tametsi Lógico'),
        backgroundColor: theme.colorScheme.surfaceVariant,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startNewGame,
            tooltip: 'Reiniciar Nivel',
          ),
        ],
      ),
      // --- CAMBIO: El body ahora es un Stack ---
      // Esto nos permite poner el overlay de resultados ENCIMA del juego.
      body: Stack(
        children: [
          // --- 1. El Juego (tu código de columna anterior) ---
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🚩 ${gameState.flagCount} / ${gameState.mineCount}',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      '⏰ ${gameState.timer.inSeconds}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: const BoardWidget(),
                ),
              ),
            ],
          ),

          // --- 2. El Overlay de Resultados (¡Nuevo!) ---
          // AnimatedSwitcher manejará la aparición y desaparición
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: (gameStatus == GameStatus.playing)
                // Si está jugando, no muestra nada
                ? const SizedBox.shrink()
                // Si gana o pierde, muestra la tarjeta de resultados
                : _buildResultCard(context, gameState, gameStatus),
          ),
        ],
      ),
    );
  }

  // --- ¡NUEVO WIDGET COMPLETO PARA LA TARJETA DE RESULTADOS! ---
  Widget _buildResultCard(
    BuildContext context,
    GameState gameState,
    GameStatus status,
  ) {
    final bool didWin = status == GameStatus.won;
    final theme = Theme.of(context);

    return Container(
      // 1. El fondo de "vidrio esmerilado"
      color:
          Colors.transparent, // Necesario para que el BackdropFilter funcione
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          // 2. Un overlay oscuro para que el blur sea más notorio
          color: Colors.black.withOpacity(0.3),
          child: Center(
            // 3. La tarjeta de contenido
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Para que la tarjeta se encoja
                children: [
                  // Icono (Trofeo o Bomba)
                  Icon(
                    didWin ? FontAwesomeIcons.trophy : FontAwesomeIcons.bomb,
                    color: didWin
                        ? Colors.amber.shade700
                        : theme.colorScheme.error,
                    size: 60,
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Text(
                    didWin ? "¡Nivel Completado!" : "¡Perdiste!",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Estadísticas
                  Text(
                    'Tiempo: ${gameState.timer.inSeconds} segundos',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botón de Menú
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Menú'),
                        onPressed: () {
                          // Cierra la pantalla del juego y vuelve al menú
                          Navigator.of(context).pop();
                        },
                      ),
                      // Botón de Reiniciar
                      FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Reiniciar'),
                        onPressed: _startNewGame, // Llama a la misma función
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
