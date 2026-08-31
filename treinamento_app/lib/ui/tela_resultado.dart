/// Esta é a tela que exibe o resultado de uma leitura. Ela tem DOIS modos
/// de exibição, controlados pelo interruptor "Modo Explicação" (definido em
/// `tela_captura.dart` e guardado em `EstadoApp`):
///
///  - Modo normal: mostra só o resultado final (foto com a caixa animada +
///    texto lido + confiança), do jeito mais rápido e "de produto" possível.
///
///  - Modo Explicação: mostra as 5 etapas do pipeline lado a lado (imagem
///    original -> imagem com a caixa -> recorte -> texto bruto do OCR ->
///    texto final), que é o coração do propósito didático do app.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado_app.dart';
import '../modelos/resultado_leitura.dart';
import '../tema.dart';
import 'widgets/pintor_caixa_animada.dart';

class TelaResultado extends StatelessWidget {
  const TelaResultado({super.key});

  @override
  Widget build(BuildContext context) {
    final resultado = context.watch<EstadoApp>().ultimoResultado;
    final modoExplicacao = context.watch<EstadoApp>().modoExplicacao;

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado da leitura')),
      body: resultado == null
          ? const Center(child: Text('Nenhum resultado ainda.'))
          : SafeArea(
              child: modoExplicacao
                  ? _EtapasDidaticas(resultado: resultado)
                  : _ResultadoResumido(resultado: resultado),
            ),
    );
  }
}

/// Modo normal: foto com a caixa desenhada (animada) + texto lido.
class _ResultadoResumido extends StatelessWidget {
  const _ResultadoResumido({required this.resultado});

  final ResultadoLeitura resultado;

  @override
  Widget build(BuildContext context) {
    final deteccao = resultado.deteccao;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          // A caixa animada é desenhada em coordenadas FRACIONÁRIAS (0.0 a
          // 1.0) supondo que a imagem preenche o widget inteiro, sem cortes.
          // Por isso é essencial que este `AspectRatio` use exatamente a
          // proporção real da foto (descoberta aqui via
          // `_decodificarParaObterTamanho`), e não um valor fixo como 4/3:
          // uma foto de câmera raramente é 4:3 (`ResolutionPreset.high`
          // costuma gerar algo perto de 16:9), então usar uma proporção
          // fixa forçaria o Flutter a CORTAR a imagem (`BoxFit.cover`) para
          // caber na caixa — e a caixa da placa, desenhada como fração do
          // tamanho ORIGINAL da foto, ficava desalinhada em relação ao
          // recorte exibido. Com a proporção real + `BoxFit.contain` (sem
          // corte), a imagem preenche o widget por inteiro e a fração bate
          // exatamente com o que é mostrado na tela.
          child: FutureBuilder<ui.Image>(
            future: _decodificarParaObterTamanho(resultado.imagemOriginal),
            builder: (context, snapshot) {
              final imagemDecodificada = snapshot.data;
              if (imagemDecodificada == null) {
                return const AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ColoredBox(color: Colors.black12),
                );
              }

              final proporcaoReal =
                  imagemDecodificada.width / imagemDecodificada.height;

              Rect? retanguloFracional;
              if (deteccao != null) {
                retanguloFracional = Rect.fromLTRB(
                  deteccao.caixa.left / imagemDecodificada.width,
                  deteccao.caixa.top / imagemDecodificada.height,
                  deteccao.caixa.right / imagemDecodificada.width,
                  deteccao.caixa.bottom / imagemDecodificada.height,
                );
              }

              return AspectRatio(
                aspectRatio: proporcaoReal,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      resultado.imagemOriginal,
                      fit: BoxFit.contain,
                    ),
                    if (retanguloFracional != null)
                      CaixaDetectadaAnimada(
                        retanguloFracional: retanguloFracional,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: resultado.sucesso
              ? _CartaoSucesso(resultado: resultado)
              : const _CartaoNenhumaPlaca(),
        ),
      ],
    );
  }

  /// Usa a API nativa do Flutter (`instantiateImageCodec`) apenas para
  /// descobrir a largura/altura em pixels da imagem — não é processamento
  /// de visão computacional, é só para converter a caixa (em pixels da foto
  /// original) em coordenadas FRACIONÁRIAS que o `CaixaDetectadaAnimada`
  /// consegue desenhar corretamente por cima da imagem, não importa o
  /// tamanho em que ela é exibida na tela.
  Future<ui.Image> _decodificarParaObterTamanho(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class _CartaoSucesso extends StatelessWidget {
  const _CartaoSucesso({required this.resultado});

  final ResultadoLeitura resultado;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CoresApp.destaque.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: CoresApp.destaque,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              resultado.textoFinal!,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: CoresApp.textoPrincipal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Confiança da detecção: '
              '${resultado.deteccao?.confiancaPercentual ?? "-"}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado "não encontrei nenhuma placa" — de propósito, NÃO parece um erro
/// seco: usa cor laranja (alerta, não vermelho de erro) e uma mensagem
/// simpática, convidando a tentar de novo.
class _CartaoNenhumaPlaca extends StatelessWidget {
  const _CartaoNenhumaPlaca();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CoresApp.alerta.withValues(alpha: 0.12),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: CoresApp.alerta, size: 40),
            SizedBox(height: 10),
            Text(
              'Hmm, não encontrei nenhuma placa nessa foto 🕵️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: CoresApp.textoPrincipal,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tente se aproximar mais ou ajustar o ângulo da câmera.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modo Explicação: as 5 etapas do pipeline, uma abaixo da outra, cada uma
/// com um rótulo numerado — como se fosse um slide de aula dentro do app.
class _EtapasDidaticas extends StatelessWidget {
  const _EtapasDidaticas({required this.resultado});

  final ResultadoLeitura resultado;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _TituloEtapas(),
        _CartaoEtapa(
          numero: 1,
          titulo: 'Imagem original',
          descricao: 'A foto exatamente como veio da câmera/galeria.',
          conteudo: _ImagemEtapa(bytes: resultado.imagemOriginal),
        ),
        _CartaoEtapa(
          numero: 2,
          titulo: 'Detecção da placa',
          descricao: resultado.deteccao == null
              ? 'O modelo YOLOv8n não encontrou nenhuma placa nesta foto.'
              : 'O modelo YOLOv8n encontrou a placa com '
                    '${resultado.deteccao!.confiancaPercentual} de confiança.',
          conteudo: _ImagemEtapa(bytes: resultado.imagemComCaixa),
        ),
        _CartaoEtapa(
          numero: 3,
          titulo: 'Recorte da placa',
          descricao: 'Apenas a região detectada, isolada do resto da foto.',
          conteudo: resultado.imagemRecortada == null
              ? const _SemConteudoEtapa()
              : _ImagemEtapa(bytes: resultado.imagemRecortada!),
        ),
        _CartaoEtapa(
          numero: 4,
          titulo: 'Texto bruto do OCR',
          descricao: 'Exatamente o que o Google ML Kit devolveu, sem limpeza.',
          conteudo: _TextoEtapa(texto: resultado.textoBruto),
        ),
        _CartaoEtapa(
          numero: 5,
          titulo: 'Texto final',
          descricao: 'Após normalização (maiúsculas, só letras e números).',
          conteudo: _TextoEtapa(texto: resultado.textoFinal, destaque: true),
        ),
      ],
    );
  }
}

class _TituloEtapas extends StatelessWidget {
  const _TituloEtapas();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.school_rounded, color: CoresApp.primaria),
          SizedBox(width: 8),
          Text(
            'O pipeline, passo a passo',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _CartaoEtapa extends StatelessWidget {
  const _CartaoEtapa({
    required this.numero,
    required this.titulo,
    required this.descricao,
    required this.conteudo,
  });

  final int numero;
  final String titulo;
  final String descricao;
  final Widget conteudo;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: CoresApp.primaria,
                  child: Text(
                    '$numero',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(descricao, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            conteudo,
          ],
        ),
      ),
    );
  }
}

class _ImagemEtapa extends StatelessWidget {
  const _ImagemEtapa({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        height: 200,
        width: double.infinity,
      ),
    );
  }
}

class _TextoEtapa extends StatelessWidget {
  const _TextoEtapa({required this.texto, this.destaque = false});

  final String? texto;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    if (texto == null || texto!.isEmpty) {
      return const _SemConteudoEtapa();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: destaque
            ? CoresApp.destaque.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        texto!,
        style: TextStyle(
          fontSize: destaque ? 24 : 16,
          fontWeight: destaque ? FontWeight.w800 : FontWeight.normal,
          letterSpacing: destaque ? 2 : 0,
        ),
      ),
    );
  }
}

class _SemConteudoEtapa extends StatelessWidget {
  const _SemConteudoEtapa();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        '— nada aqui, pois a etapa anterior não encontrou uma placa —',
        style: TextStyle(color: Colors.black45, fontStyle: FontStyle.italic),
      ),
    );
  }
}
