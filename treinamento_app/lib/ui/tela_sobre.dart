/// Tela institucional simples: explica o propósito didático do app e traz
/// um contato para dúvidas/feedback. Não faz parte do pipeline de ALPR —
/// existe só para dar contexto de quem fez o app e por quê.
library;

import 'package:flutter/material.dart';

import '../tema.dart';

class TelaSobre extends StatelessWidget {
  const TelaSobre({super.key});

  static const String _emailContato = 'contato@rodrigogossi';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o app')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.directions_car_filled_rounded,
              size: 72,
              color: CoresApp.primaria,
            ),
            const SizedBox(height: 12),
            Text(
              'Leitor de Placas com IA',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: CoresApp.textoPrincipal,
              ),
            ),
            const SizedBox(height: 20),
            const _CartaoSobre(
              icone: Icons.school_rounded,
              titulo: 'Propósito',
              texto:
                  'Este app foi criado como material de apoio para um '
                  'minicurso introdutório de Visão Computacional. Ele existe '
                  'para mostrar, de forma visual e ao vivo, como funciona um '
                  'pipeline de ALPR (Automatic License Plate Recognition): '
                  'captura de foto, detecção da placa com um modelo YOLOv8n '
                  'treinado do zero, recorte da região detectada e leitura '
                  'do texto via OCR — tudo rodando localmente no celular.',
            ),
            const SizedBox(height: 16),
            const _CartaoSobre(
              icone: Icons.info_outline_rounded,
              titulo: 'Não é um produto',
              texto:
                  'É uma ferramenta de ensino, não um sistema de produção: '
                  'não valida formato oficial de placa, não persiste dados '
                  'em banco, e prioriza clareza de código sobre robustez '
                  'de borda. Ative o "Modo Explicação" na tela de captura '
                  'para ver cada etapa do pipeline separadamente.',
            ),
            const SizedBox(height: 16),
            _CartaoSobre(
              icone: Icons.mail_outline_rounded,
              titulo: 'Contato',
              texto: 'Dúvidas, sugestões ou bugs? Escreva para:',
              rodape: SelectableText(
                _emailContato,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CoresApp.primaria,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoSobre extends StatelessWidget {
  const _CartaoSobre({
    required this.icone,
    required this.titulo,
    required this.texto,
    this.rodape,
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: CoresApp.primaria),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(texto, style: const TextStyle(color: Colors.black87, height: 1.4)),
            if (rodape != null) ...[
              const SizedBox(height: 8),
              rodape!,
            ],
          ],
        ),
      ),
    );
  }
}
