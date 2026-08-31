/// Esta é a tela principal do app durante a aula: mostra o preview ao vivo
/// da câmera, permite tirar uma foto ou escolher uma da galeria, e dispara o
/// pipeline completo de ALPR a cada foto. Também hospeda o interruptor
/// "Modo Explicação", que controla como a próxima tela (`tela_resultado.dart`)
/// vai exibir o resultado.
library;

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../captura/servico_camera.dart';
import '../estado_app.dart';
import '../tema.dart';
import 'tela_historico.dart';
import 'tela_resultado.dart';
import 'tela_sobre.dart';
import 'widgets/overlay_escaneando.dart';

class TelaCaptura extends StatefulWidget {
  const TelaCaptura({super.key});

  @override
  State<TelaCaptura> createState() => _TelaCapturaState();
}

class _TelaCapturaState extends State<TelaCaptura> {
  final ServicoCamera _servicoCamera = ServicoCamera();
  final ImagePicker _seletorGaleria = ImagePicker();

  // A câmera NÃO é iniciada automaticamente ao abrir a tela — só quando o
  // usuário toca em "Abrir câmera". Isso evita pedir a permissão de câmera
  // (e ocupar o hardware) para quem só quer usar fotos da galeria.
  bool _cameraAtiva = false;
  bool _cameraIniciando = false;
  String? _erroCamera;

  Future<void> _iniciarCamera() async {
    setState(() {
      _cameraIniciando = true;
      _erroCamera = null;
    });
    try {
      await _servicoCamera.iniciar();
      _cameraAtiva = true;
    } catch (e) {
      _erroCamera = 'Não consegui acessar a câmera. Você pode usar a '
          'galeria enquanto isso. ($e)';
    } finally {
      if (mounted) setState(() => _cameraIniciando = false);
    }
  }

  Future<void> _fecharCamera() async {
    await _servicoCamera.encerrar();
    if (mounted) setState(() => _cameraAtiva = false);
  }

  @override
  void dispose() {
    _servicoCamera.encerrar();
    super.dispose();
  }

  Future<void> _capturarDaCamera() async {
    try {
      final caminho = await _servicoCamera.capturarFoto();
      final bytes = await File(caminho).readAsBytes();
      await _processarEExibir(bytes);
    } catch (e) {
      _mostrarErro('Falha ao capturar a foto: $e');
    }
  }

  Future<void> _escolherDaGaleria() async {
    final arquivo = await _seletorGaleria.pickImage(
      source: ImageSource.gallery,
    );
    if (arquivo == null) return;
    final bytes = await arquivo.readAsBytes();
    await _processarEExibir(bytes);
  }

  /// Chama o pipeline em `EstadoApp`, dá o feedback tátil/sonoro adequado ao
  /// resultado (microinteração pedida no briefing) e abre a tela de
  /// resultado.
  Future<void> _processarEExibir(Uint8List bytes) async {
    final estado = context.read<EstadoApp>();
    final resultado = await estado.processarImagem(bytes);

    if (resultado.sucesso) {
      // Placa lida com sucesso: vibração + som curtos, para reforçar "achei!".
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    } else {
      // Nenhuma placa encontrada: feedback mais discreto — não é um erro,
      // é só "tente de novo", então evitamos qualquer som/vibração de alerta.
      HapticFeedback.lightImpact();
    }

    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TelaResultado()));
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoApp>();
    final ocupado = estado.carregandoModelo || estado.processando;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capturar foto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Sobre o app',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TelaSobre())),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Histórico de leituras',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TelaHistorico()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _SeletorModoExplicacao(estado: estado),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _construirPreview(estado),
            ),
          ),
          _construirBarraAcoes(ocupado: ocupado),
        ],
      ),
    );
  }

  Widget _construirPreview(EstadoApp estado) {
    if (estado.carregandoModelo) {
      return const _EstadoCarregando(
        mensagem: 'Carregando o modelo de IA…',
      );
    }

    if (_cameraIniciando) {
      return const _EstadoCarregando(mensagem: 'Abrindo a câmera…');
    }

    if (!_cameraAtiva) {
      return _EstadoCameraFechada(
        erro: _erroCamera,
        aoTocarAbrir: _iniciarCamera,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_servicoCamera.pronta)
            CameraPreview(_servicoCamera.controlador!)
          else
            _EstadoSemCamera(mensagem: _erroCamera),
          if (estado.processando) const OverlayEscaneando(),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.videocam_off_rounded),
              tooltip: 'Fechar câmera',
              onPressed: _fecharCamera,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBarraAcoes({required bool ocupado}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton.filledTonal(
            iconSize: 30,
            icon: const Icon(Icons.photo_library_rounded),
            tooltip: 'Escolher da galeria',
            onPressed: ocupado ? null : _escolherDaGaleria,
          ),
          _BotaoCapturar(
            ocupado: ocupado,
            aoTocar: (_cameraAtiva && _servicoCamera.pronta)
                ? _capturarDaCamera
                : null,
          ),
          const SizedBox(width: 48), // balanceia visualmente a fileira
        ],
      ),
    );
  }
}

/// Interruptor "Modo Explicação", exibido no topo da tela de captura.
class _SeletorModoExplicacao extends StatelessWidget {
  const _SeletorModoExplicacao({required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CoresApp.primaria.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: CoresApp.primaria),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Modo Explicação',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Switch(
            value: estado.modoExplicacao,
            onChanged: estado.alternarModoExplicacao,
          ),
        ],
      ),
    );
  }
}

class _BotaoCapturar extends StatelessWidget {
  const _BotaoCapturar({required this.ocupado, required this.aoTocar});

  final bool ocupado;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ocupado ? null : aoTocar,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ocupado ? Colors.grey.shade300 : CoresApp.primaria,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: CoresApp.primaria.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ocupado
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(color: Colors.white),
              )
            : const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 34,
              ),
      ),
    );
  }
}

class _EstadoCarregando extends StatelessWidget {
  const _EstadoCarregando({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CoresApp.primaria.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: CoresApp.primaria),
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CoresApp.textoPrincipal),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado inicial da tela: câmera ainda não foi aberta. Mostra um convite
/// simpático para o usuário abrir a câmera quando quiser — em vez de pedir
/// a permissão e ligar o hardware automaticamente assim que a tela abre.
class _EstadoCameraFechada extends StatelessWidget {
  const _EstadoCameraFechada({required this.erro, required this.aoTocarAbrir});

  final String? erro;
  final VoidCallback aoTocarAbrir;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CoresApp.primaria.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              erro == null
                  ? Icons.camera_alt_rounded
                  : Icons.no_photography_rounded,
              size: 56,
              color: erro == null ? CoresApp.primaria : CoresApp.alerta,
            ),
            const SizedBox(height: 16),
            Text(
              erro ?? 'A câmera está desligada para economizar bateria.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: CoresApp.textoPrincipal),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(erro == null ? 'Abrir câmera' : 'Tentar de novo'),
              onPressed: aoTocarAbrir,
            ),
            const SizedBox(height: 4),
            const Text(
              'ou use o botão da galeria abaixo',
              style: TextStyle(color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoSemCamera extends StatelessWidget {
  const _EstadoSemCamera({this.mensagem});

  final String? mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CoresApp.primaria.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_rounded,
              size: 48,
              color: CoresApp.alerta,
            ),
            const SizedBox(height: 12),
            Text(
              mensagem ?? 'Câmera indisponível.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: CoresApp.textoPrincipal),
            ),
            const SizedBox(height: 4),
            const Text(
              'Use o botão da galeria abaixo.',
              style: TextStyle(color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
