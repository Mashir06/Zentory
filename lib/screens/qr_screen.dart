import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../routes.dart';
import '../services/product_lookup_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Escáner de códigos de barras (reemplaza CameraX + ML Kit).
///
/// Al leer un código consulta OpenFoodFacts y abre el formulario de registro
/// con los datos del producto.
class QRScreen extends StatefulWidget {
  const QRScreen({super.key});

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (code == null) return;

    setState(() => _busy = true);
    try {
      final product = await ProductLookupService.lookup(code);
      if (!mounted) return;
      if (product == null) {
        showMessage(
          context,
          'No se encontró información del producto',
          long: true,
        );
        return;
      }
      await _controller.stop();
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        Routes.addProduct,
        arguments: AddProductArgs(
          qrNombre: product.nombre,
          qrCategoria: product.categoria,
          qrMarca: product.marca,
          qrPresentacion: product.presentacion,
        ),
      );
      if (mounted) await _controller.start();
    } catch (e) {
      if (mounted) showMessage(context, 'Error de red: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (mounted) showMessage(context, 'La linterna no está disponible');
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
              const ZentoryHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Escanear producto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Escanea el código de barras del producto',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
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
                                _busy
                                    ? 'Buscando producto...'
                                    : 'Coloca el código de barras dentro del marco',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(blurRadius: 6, color: Colors.black),
                                  ],
                                ),
                              ),
                            ),
                            if (_busy)
                              const ColoredBox(
                                color: Color(0x80000000),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: ValueListenableBuilder<MobileScannerState>(
                                valueListenable: _controller,
                                builder: (context, state, _) {
                                  final on = state.torchState == TorchState.on;
                                  return FilledButton.icon(
                                    onPressed: _toggleTorch,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0x99000000),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: Icon(
                                      on ? Icons.flash_off : Icons.flash_on,
                                    ),
                                    label: Text(on ? 'Apagar' : 'Linterna'),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Instrucciones',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Step(
                          icon: Icons.center_focus_strong,
                          text: '1. Enfoca el código de barras',
                        ),
                        _Step(
                          icon: Icons.wb_sunny_outlined,
                          text: '2. Asegúrate de tener buena iluminación',
                        ),
                        _Step(
                          icon: Icons.pan_tool_outlined,
                          text: '3. Mantén el dispositivo estable',
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
      bottomNavigationBar: const ZentoryBottomNav(current: Routes.scan),
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
