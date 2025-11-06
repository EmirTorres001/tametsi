import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

// IMPORTACIONES
import '../providers/game_provider.dart';
import '../widgets/board_widget.dart';
import '../services/level_service.dart';
import '../services/persistence_service.dart';

// PROVIDERS
final levelServiceProvider = Provider<LevelService>((ref) => LevelService());
// AÑADE ESTA LÍNEA - Esta era la pieza que faltaba en este archivo
final persistenceServiceProvider = Provider<PersistenceService>(
  (ref) => PersistenceService(),
);

class GameScreen extends ConsumerStatefulWidget {
  // ... el resto de tu código es correcto y no necesita cambios ...
  final String levelAssetPath;

  const GameScreen({super.key, required this.levelAssetPath});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _startNewGame();
    });
  }

  void _startNewGame() {
    ref.read(gameProvider.notifier).newGame(widget.levelAssetPath);
    setState(() {
      _isDialogShowing = false;
    });
  }

  void _showResultDialog(BuildContext context, String title) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final gameState = ref.read(gameProvider);

        return AlertDialog(
          title: Text(title),
          content: Text('Tiempo: ${gameState.timer.inSeconds} segundos.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Menú'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              child: const Text('Reiniciar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _startNewGame();
              },
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameProvider, (previousState, newState) {
      if (newState.status == GameStatus.won) {
        ref
            .read(persistenceServiceProvider)
            .saveLevelProgress(widget.levelAssetPath);
        _showResultDialog(context, '¡Ganaste! 🏆');
      } else if (newState.status == GameStatus.lost) {
        _showResultDialog(context, '¡Perdiste! 💣');
      }
    });

    final gameState = ref.watch(gameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tametsi Lógico'),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startNewGame,
            tooltip: 'Reiniciar Nivel',
          ),
        ],
      ),
      body: gameState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '⏰ ${gameState.timer.inSeconds}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: BoardWidget(),
                  ),
                ),
              ],
            ),
    );
  }
}
