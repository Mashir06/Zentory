import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../routes.dart';
import '../services/zentory_repository.dart';
import '../theme/app_colors.dart';
import '../utils/manual.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> {
  final _repo = ZentoryRepository.instance;
  String _userName = '';
  String _storeName = '';
  bool _showContacts = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _repo.currentUser;
    if (user == null) return;
    try {
      final userDoc = await _repo.userRef(user.uid).get();
      final name = (userDoc.data()?['nombre'] as String?) ??
          user.displayName ??
          'Usuario';
      final tiendaId = userDoc.data()?['tiendaId'] as String?;
      var storeName = '';
      if (tiendaId != null) {
        final tienda = await _repo.stores.doc(tiendaId).get();
        storeName = (tienda.data()?['nombre'] as String?) ?? 'Sin tienda';
      }
      if (!mounted) return;
      setState(() {
        _userName = name;
        _storeName = storeName;
      });
    } catch (_) {
      // Los datos solo se usan para personalizar el mensaje de WhatsApp.
    }
  }

  Future<void> _openWhatsApp(String phone, String reason) async {
    final message =
        'Hola, soy $_userName de la tienda $_storeName. $reason';
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showMessage(context, 'No se pudo abrir WhatsApp');
  }

  Future<void> _openManual() async {
    final error = await openWordManual();
    if (error != null && mounted) showMessage(context, error, long: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZentoryBackground(
        child: SafeArea(
          child: Column(
            children: [
              ZentoryHeader(
                subtitle: 'Ayuda y Soporte',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      '¿En qué podemos ayudarte?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SettingsOption(
                      icon: Icons.quiz_outlined,
                      title: 'Preguntas Frecuentes (FAQ)',
                      onTap: () => Navigator.of(context).pushNamed(Routes.faq),
                    ),
                    SettingsOption(
                      icon: Icons.support_agent,
                      title: 'Contactar Soporte',
                      onTap: () =>
                          setState(() => _showContacts = !_showContacts),
                      trailing: AnimatedRotation(
                        turns: _showContacts ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary),
                      ),
                    ),
                    if (_showContacts)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          children: [
                            SettingsOption(
                              icon: Icons.chat_outlined,
                              iconColor: AppColors.whatsapp,
                              title: 'Soporte Técnico',
                              onTap: () => _openWhatsApp(
                                '67968449',
                                'Necesito soporte técnico.',
                              ),
                            ),
                            SettingsOption(
                              icon: Icons.chat_outlined,
                              iconColor: AppColors.whatsapp,
                              title: 'Consultas Generales',
                              onTap: () => _openWhatsApp(
                                '61857395',
                                'Tengo una consulta general.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    SettingsOption(
                      icon: Icons.menu_book_outlined,
                      title: 'Ver Manual de Usuario',
                      onTap: _openManual,
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
