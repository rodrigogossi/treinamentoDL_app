/// Este arquivo é o "maestro" do app: orquestra a chamada, em sequência, de
/// cada camada do pipeline de ALPR (detecção -> recorte -> OCR) e guarda o
/// estado compartilhado entre telas (resultado atual, histórico, modo
/// explicação, carregamento do modelo).
///
/// POR QUE PROVIDER (E NÃO RIVERPOD)?
/// Para um app didático de demonstração, com uma árvore de estado pequena
/// (praticamente um único `ChangeNotifier` global), o Provider oferece o
/// menor caminho entre "ligar o app" e "estudantes conseguem ler o código
/// sem aprender um framework de gerenciamento de estado à parte". O Riverpod
/// é mais robusto para apps grandes (testável sem `BuildContext`, detecção
/// de erros em tempo de compilação), mas isso é over-engineering aqui: não
/// há múltiplos providers concorrentes nem necessidade de testes unitários
/// de estado isolados de widgets. `ChangeNotifier` + `Provider` é o padrão
/// mais citado nos próprios tutoriais oficiais do Flutter, o que ajuda quem
/// está começando em visão computacional a não se perder também em uma
/// arquitetura de estado desconhecida.
library;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'deteccao/detector_yolo.dart';
import 'deteccao/utilitarios_imagem.dart';
import 'modelos/resultado_leitura.dart';
import 'ocr/servico_ocr.dart';

class EstadoApp extends ChangeNotifier {
  final DetectorYolo _detector = DetectorYolo();
  final ServicoOcr _ocr = ServicoOcr();

  /// Enquanto verdadeiro, a tela de captura mostra um indicador de
  /// carregamento — o modelo TFLite precisa ser lido do disco antes da
  /// primeira detecção.
  bool carregandoModelo = true;

  /// Enquanto verdadeiro, o pipeline está processando uma foto (detecção +
  /// OCR). A UI usa isso para mostrar a animação de "escaneando".
  bool processando = false;

  /// Liga/desliga o "Modo Explicação" — quando ativo, a tela de resultado
  /// mostra as etapas intermediárias lado a lado em vez de só o resultado
  /// final. Este é o coração do propósito didático do app.
  bool modoExplicacao = false;

  ResultadoLeitura? ultimoResultado;

  /// Histórico das últimas leituras, mais recente primeiro. Guardado só em
  /// memória (RAM) — de propósito: é um app de demonstração de aula, não
  /// precisa sobreviver ao fechamento do app.
  final List<ResultadoLeitura> historico = [];

  /// Carrega o modelo YOLOv8n uma única vez, no início da vida do app.
  Future<void> inicializar() async {
    await _detector.carregar();
    carregandoModelo = false;
    notifyListeners();
  }

  void alternarModoExplicacao(bool valor) {
    modoExplicacao = valor;
    notifyListeners();
  }

  /// Executa o pipeline completo de ALPR sobre uma foto (vinda da câmera ou
  /// da galeria) e devolve o [ResultadoLeitura] com todas as etapas
  /// preenchidas.
  Future<ResultadoLeitura> processarImagem(Uint8List bytesOriginais) async {
    processando = true;
    notifyListeners();

    try {
      final imagemDecodificada = img.decodeImage(bytesOriginais);
      if (imagemDecodificada == null) {
        throw StateError('Não foi possível decodificar a foto capturada.');
      }

      // Fotos de câmera frequentemente vêm com a orientação real guardada
      // apenas nos metadados EXIF (o pixel em si está "deitado"). Sem esse
      // passo, a caixa detectada apareceria girada em relação à foto exibida.
      final imagemNormalizada = img.bakeOrientation(imagemDecodificada);
      final bytesNormalizados = Uint8List.fromList(
        img.encodePng(imagemNormalizada),
      );

      // ETAPA 1 (detecção): roda o YOLOv8n sobre a foto inteira.
      final deteccoes = await _detector.detectar(imagemNormalizada);

      // Como treinamos para 1 placa por foto neste app de demonstração,
      // ficamos apenas com a detecção de maior confiança quando o modelo
      // encontra mais de uma candidata.
      final melhorDeteccao = deteccoes.isEmpty
          ? null
          : deteccoes.reduce((a, b) => a.confianca >= b.confianca ? a : b);

      Uint8List imagemComCaixa = bytesNormalizados;
      Uint8List? recorte;
      String? textoBruto;
      String? textoFinal;

      if (melhorDeteccao != null) {
        // ETAPA 2 (visualização): desenha a caixa sobre a foto original.
        imagemComCaixa = desenharCaixaNaImagem(
          bytesNormalizados,
          melhorDeteccao.caixa,
        );

        // ETAPA 3 (recorte): isola só a região da placa.
        recorte = recortarRegiao(bytesNormalizados, melhorDeteccao.caixa);

        // ETAPA 4 (OCR): lê o texto do recorte.
        final textoReconhecido = await _ocr.reconhecerTexto(recorte);
        textoBruto = textoReconhecido?.bruto;
        textoFinal = textoReconhecido?.normalizado;
      }

      // ETAPA 5 (resultado final): agrega tudo em um único objeto, que
      // alimenta tanto a tela de resultado quanto o histórico.
      final resultado = ResultadoLeitura(
        imagemOriginal: bytesNormalizados,
        imagemComCaixa: imagemComCaixa,
        imagemRecortada: recorte,
        deteccao: melhorDeteccao,
        textoBruto: textoBruto,
        textoFinal: textoFinal,
        momento: DateTime.now(),
      );

      ultimoResultado = resultado;
      historico.insert(0, resultado);

      return resultado;
    } finally {
      processando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _detector.dispose();
    _ocr.dispose();
    super.dispose();
  }
}
