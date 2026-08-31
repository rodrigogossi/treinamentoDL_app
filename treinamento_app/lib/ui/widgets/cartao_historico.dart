/// Este widget renderiza um item da lista de histórico: miniatura da foto,
/// texto lido e confiança da detecção. Usado por `ui/tela_historico.dart`.
library;

import 'package:flutter/material.dart';

import '../../modelos/resultado_leitura.dart';
import '../../tema.dart';

class CartaoHistorico extends StatelessWidget {
  const CartaoHistorico({super.key, required this.resultado});

  final ResultadoLeitura resultado;

  @override
  Widget build(BuildContext context) {
    final sucesso = resultado.sucesso;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            resultado.imagemComCaixa,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(
          sucesso ? resultado.textoFinal! : 'Nenhuma placa encontrada',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: sucesso ? 1.5 : 0,
            color: sucesso ? CoresApp.textoPrincipal : CoresApp.alerta,
          ),
        ),
        subtitle: Text(_formatarHorario(resultado.momento)),
        trailing: resultado.deteccao == null
            ? const Icon(Icons.search_off, color: CoresApp.alerta)
            : Chip(
                label: Text(resultado.deteccao!.confiancaPercentual),
                backgroundColor: CoresApp.destaque.withValues(alpha: 0.15),
                labelStyle: const TextStyle(
                  color: CoresApp.destaque,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  String _formatarHorario(DateTime momento) {
    final hora = momento.hour.toString().padLeft(2, '0');
    final minuto = momento.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }
}
