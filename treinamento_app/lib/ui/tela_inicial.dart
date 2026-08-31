/// Esta é a primeira tela que o aluno vê: uma explicação curta e visual, em
/// formato de "storytelling", do que o app faz — antes de qualquer câmera
/// ou modelo entrar em cena. O objetivo é dar contexto ("o que vamos ver
/// acontecer") antes de mostrar "como" (a tela de captura).
library;

import 'package:flutter/material.dart';

import '../tema.dart';
import 'tela_captura.dart';

class TelaInicial extends StatelessWidget {
  const TelaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Icon(
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
              const SizedBox(height: 6),
              Text(
                'Um mini-tour pelo pipeline de ALPR (Automatic License '
                'Plate Recognition), rodando 100% no seu celular.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  children: const [
                    _PassoStorytelling(
                      numero: '1',
                      icone: Icons.camera_alt_rounded,
                      cor: CoresApp.primaria,
                      titulo: 'Tire uma foto',
                      descricao:
                          'Aponte a câmera para um carro (ou escolha uma '
                          'foto da galeria).',
                    ),
                    _PassoStorytelling(
                      numero: '2',
                      icone: Icons.center_focus_strong_rounded,
                      cor: CoresApp.destaque,
                      titulo: 'A IA encontra a placa',
                      descricao:
                          'Um modelo YOLOv8n treinado do zero desenha uma '
                          'caixa ao redor da placa detectada.',
                    ),
                    _PassoStorytelling(
                      numero: '3',
                      icone: Icons.crop_rounded,
                      cor: CoresApp.alerta,
                      titulo: 'Recortamos a região',
                      descricao:
                          'Isolamos só a placa, descartando o resto da foto.',
                    ),
                    _PassoStorytelling(
                      numero: '4',
                      icone: Icons.text_fields_rounded,
                      cor: CoresApp.primariaClara,
                      titulo: 'Lemos o texto pra você',
                      descricao:
                          'OCR on-device converte a imagem da placa em texto.',
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Começar'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TelaCaptura()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassoStorytelling extends StatelessWidget {
  const _PassoStorytelling({
    required this.numero,
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.descricao,
  });

  final String numero;
  final IconData icone;
  final Color cor;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: cor.withValues(alpha: 0.15),
            child: Icon(icone, color: cor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$numero. $titulo',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: CoresApp.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  descricao,
                  style: const TextStyle(color: Colors.black54, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
