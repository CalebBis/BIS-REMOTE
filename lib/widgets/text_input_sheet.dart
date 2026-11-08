import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tv_capability.dart';
import '../services/tv_controller.dart';

/// Modal bottom sheet pour la saisie de texte à destination du téléviseur.
class TextInputSheet extends ConsumerStatefulWidget {
  const TextInputSheet({super.key});

  /// Ouvre le bottom sheet de saisie au-dessus du clavier virtuel.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B2223),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const TextInputSheet(),
    );
  }

  @override
  ConsumerState<TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends ConsumerState<TextInputSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _previousText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String newText, TvController controller) {
    if (newText.length > _previousText.length) {
      // Caractères ajoutés
      final added = newText.substring(_previousText.length);
      controller.sendText(added);
    } else if (newText.length < _previousText.length) {
      // Caractères supprimés (Backspace)
      final count = _previousText.length - newText.length;
      for (int i = 0; i < count; i++) {
        controller.sendBackspace();
      }
    }
    _previousText = newText;
  }

  void _handleSubmit(TvController controller) {
    HapticFeedback.lightImpact();
    controller.sendEnter();
    _focusNode.unfocus();
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Envoyé à la TV'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF00525A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(tvControllerProvider);
    final hasTextInput = controller.capabilities.contains(TvCapability.textInput);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poignée et Titre
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saisir sur la TV',
                style: TextStyle(
                  color: Color(0xFFE3E8E8),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF8E999A)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!hasTextInput) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF262D2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA01818), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Saisie de texte non supportée par cette TV',
                      style: TextStyle(
                        color: Color(0xFFE3E8E8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Champ de texte
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    onChanged: (text) => _onTextChanged(text, controller),
                    onSubmitted: (_) => _handleSubmit(controller),
                    style: const TextStyle(color: Color(0xFFE3E8E8), fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Saisir sur la TV…',
                      hintStyle: const TextStyle(color: Color(0xFF8E999A)),
                      filled: true,
                      fillColor: const Color(0xFF262D2E),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF00C8F0),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Bouton Envoyer cyan
                ElevatedButton(
                  onPressed: () => _handleSubmit(controller),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C8F0),
                    foregroundColor: const Color(0xFF111418),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Envoyer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Ligne d'aide
            const Text(
              'Chaque caractère est envoyé à la TV au fur et à mesure. Retour arrière et Entrée sont aussi transmis.',
              style: TextStyle(
                color: Color(0xFF8E999A),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

