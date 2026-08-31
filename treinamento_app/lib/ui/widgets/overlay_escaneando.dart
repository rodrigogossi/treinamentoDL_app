/// Este widget é puramente decorativo/didático: uma linha luminosa que
/// varre a imagem de cima para baixo (efeito "leitor de código de barras"),
/// exibida enquanto o pipeline está processando uma foto.
///
/// Ele não tem nenhuma lógica de visão computacional — existe só para dar
/// feedback visual de "a IA está trabalhando agora" durante a aula, no
/// tempo (curto, mas perceptível) em que o modelo roda a inferência.
library;

import 'package:flutter/material.dart';

import '../../tema.dart';

class OverlayEscaneando extends StatefulWidget {
  const OverlayEscaneando({super.key});

  @override
  State<OverlayEscaneando> createState() => _OverlayEscaneandoState();
}

class _OverlayEscaneandoState extends State<OverlayEscaneando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: _controlador,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final topo = constraints.maxHeight * _controlador.value;
                return Stack(
                  children: [
                    // Leve véu escuro para destacar a linha de escaneamento.
                    Container(color: Colors.black.withValues(alpha: 0.15)),
                    Positioned(
                      top: topo.clamp(0, constraints.maxHeight - 4),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              CoresApp.destaque.withValues(alpha: 0.0),
                              CoresApp.destaque,
                              CoresApp.destaque.withValues(alpha: 0.0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CoresApp.destaque.withValues(alpha: 0.8),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
