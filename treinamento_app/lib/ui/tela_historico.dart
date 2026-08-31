/// Lista simples com as últimas leituras feitas na sessão atual. Guardado só
/// em memória (ver `EstadoApp.historico`) — fechar o app limpa a lista, o
/// que é intencional para um app de demonstração de aula.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado_app.dart';
import '../tema.dart';
import 'widgets/cartao_historico.dart';

class TelaHistorico extends StatelessWidget {
  const TelaHistorico({super.key});

  @override
  Widget build(BuildContext context) {
    final historico = context.watch<EstadoApp>().historico;

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de leituras')),
      body: historico.isEmpty
          ? const _HistoricoVazio()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: historico.length,
              itemBuilder: (context, indice) {
                return CartaoHistorico(resultado: historico[indice]);
              },
            ),
    );
  }
}

class _HistoricoVazio extends StatelessWidget {
  const _HistoricoVazio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_back_rounded,
              size: 56,
              color: CoresApp.primariaClara,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma leitura ainda',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tire uma foto de uma placa para começar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
