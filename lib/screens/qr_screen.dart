import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../l10n/strings.dart';

/// Escáner de códigos de barras (reemplaza CameraX + ML Kit).
///
/// Se abre desde "Agregar producto" y devuelve el código leído con
/// `Navigator.pop`; el formulario decide qué hacer con él.
class QRScreen extends StatefulWidget {
  const QRScreen({super.key});

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (code == null) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (mounted) showMessage(context, tr('La linterna no está disponible'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ZentoryHeader(onBack: () => Navigator.of(context).maybePop()),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    Text(
                      tr('Escanear producto'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      tr('Escanea el código de barras del producto'),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
                              controller: _controller,
                              onDetect: _onDetect,
                            ),
                            // Marco de enfoque
                            Center(
                              child: FractionallySizedBox(
                                widthFactor: 0.75,
                                heightFactor: 0.35,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Text(
                                tr('Coloca el código de barras dentro del marco'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.onColor,
                                  shadows: [
                                    Shadow(blurRadius: 6, color: Colors.black),
                                  ],
                                ),
                              ),
                            ),
                            // La linterna no se puede controlar desde el navegador.
                            if (!kIsWeb) Positioned(
                              top: 12,
                              right: 12,
                              child: ValueListenableBuilder<MobileScannerState>(
                                valueListenable: _controller,
                                builder: (context, state, _) {
                                  final on = state.torchState == TorchState.on;
                                  return FilledButton.icon(
                                    onPressed: _toggleTorch,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Color(0x99000000),
                                      foregroundColor: AppColors.onColor,
                                    ),
                                    icon: Icon(
                                      on ? Icons.flash_off : Icons.flash_on,
                                    ),
                                    label: Text(on ? tr('Apagar') : tr('Linterna')),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      tr('Instrucciones'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Step(
                          icon: Icons.center_focus_strong,
                          text: tr('1. Enfoca el código de barras'),
                        ),
                        _Step(
                          icon: Icons.wb_sunny_outlined,
                          text: tr('2. Asegúrate de tener buena iluminación'),
                        ),
                        _Step(
                          icon: Icons.pan_tool_outlined,
                          text: tr('3. Mantén el dispositivo estable'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
