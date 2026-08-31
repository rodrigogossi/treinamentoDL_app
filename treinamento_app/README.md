# Leitor de Placas com IA — App didático de ALPR em Flutter

App de demonstração para minicurso introdutório de Visão Computacional. Ele
roda um pipeline completo de **ALPR (Automatic License Plate Recognition)**
inteiramente **no dispositivo** (sem enviar nada para servidores):

```
Foto (câmera/galeria) → Detecção da placa (YOLOv8n, TFLite) → Recorte →
OCR do recorte (Google ML Kit) → Texto final
```

Este README foi escrito para servir como **roteiro de aula**: cada seção
explica não só *o que* o código faz, mas *por que* ele foi feito assim —
são justamente essas decisões que valem a pena parar e discutir com a
turma.

---

## Índice

1. [Visão geral e arquitetura](#1-visão-geral-e-arquitetura)
2. [Como rodar o projeto do zero](#2-como-rodar-o-projeto-do-zero)
3. [Como o modelo é carregado e usado](#3-como-o-modelo-é-carregado-e-usado)
4. [Como o pós-processamento do YOLO funciona](#4-como-o-pós-processamento-do-yolo-funciona-passo-a-passo)
5. [Como o OCR é aplicado sobre o recorte](#5-como-o-ocr-é-aplicado-sobre-o-recorte)
6. [Como regenerar o modelo (.pt → .tflite)](#6-como-regenerar-o-modelo-pt--tflite)
7. [Decisões técnicas e seus porquês](#7-decisões-técnicas-e-seus-porquês)
8. [Limitações conhecidas](#8-limitações-conhecidas)
9. [Estrutura de pastas](#9-estrutura-de-pastas)
10. [Roteiro sugerido para a aula](#10-roteiro-sugerido-para-a-aula)

---

## 1. Visão geral e arquitetura

O app tem 4 telas e 5 camadas de código:

```
┌─────────────────────────────────────────────────────────────────────┐
│                              lib/ui/                                 │
│                                                                        │
│  tela_inicial.dart          tela_captura.dart        tela_resultado  │
│  (storytelling,     ──────▶ (câmera/galeria +  ────▶ .dart           │
│   "1,2,3,4")                modo explicação)          (etapas ou     │
│                                       │                 resultado)    │
│                                       ▼                    │         │
│                              tela_historico.dart ◀─────────┘         │
└─────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
                          ┌─────────────────────────┐
                          │     lib/estado_app.dart   │  (ChangeNotifier /
                          │  orquestra o pipeline     │   Provider)
                          └─────────────────────────┘
                     │                 │                  │
                     ▼                 ▼                  ▼
        ┌───────────────────┐ ┌────────────────┐ ┌─────────────────┐
        │  lib/captura/       │ │ lib/deteccao/    │ │  lib/ocr/         │
        │  ServicoCamera       │ │ DetectorYolo     │ │  ServicoOcr       │
        │  (câmera ao vivo)    │ │ + pós-proc. +    │ │  (Google ML Kit)  │
        │                      │ │ utilitários de   │ │                   │
        │                      │ │ imagem           │ │                   │
        └───────────────────┘ └────────────────┘ └─────────────────┘
                                       │
                                       ▼
                             ┌───────────────────┐
                             │ assets/models/      │
                             │ best_float32.tflite  │
                             └───────────────────┘
```

`lib/modelos/` (não aparece no diagrama por ser "passiva") define as duas
estruturas de dados que atravessam todas as camadas: `Deteccao` (uma caixa
+ confiança) e `ResultadoLeitura` (todas as etapas de uma leitura, usada
tanto pelo Modo Explicação quanto pelo histórico).

### Por que essa separação em camadas?

Cada pasta corresponde a uma responsabilidade única e isolada, para que
durante a aula você consiga abrir *só* a pasta relevante ao explicar aquela
etapa, sem o aluno precisar entender o app inteiro de uma vez:

- `captura/` → só sabe "ligar a câmera e tirar foto". Não sabe nada sobre
  IA.
- `deteccao/` → só sabe "dado uma imagem, onde está a placa?". Não sabe
  nada sobre câmera nem sobre OCR.
- `ocr/` → só sabe "dado um recorte de imagem, qual o texto?". Não sabe
  nada sobre detecção.
- `ui/` → só sabe "como mostrar isso na tela". Não faz nenhum
  processamento de imagem/IA diretamente.
- `estado_app.dart` → a única peça que conhece todas as outras — é o
  "maestro" que chama cada camada na ordem certa.

---

## 2. Como rodar o projeto do zero

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal
  stable; testado com Flutter 3.47).
- Um dispositivo Android físico conectado (USB + depuração ativada) **ou**
  um emulador Android configurado no Android Studio.
- O arquivo do modelo já exportado: `assets/models/best_float32.tflite`
  (ver seção 6 se você só tem o `best.pt`).

### Passos

```bash
# 1. Instale as dependências
flutter pub get

# 2. Confirme que o modelo está no lugar certo
ls assets/models/
#   best_float32.tflite   labels.txt

# 3. Rode em um dispositivo/emulador conectado
flutter devices
flutter run
```

Na primeira execução, o Android vai pedir a permissão de câmera — aceite
para o preview ao vivo funcionar. Se você negar, o app continua funcional
usando apenas a galeria (ver `_EstadoSemCamera` em
`lib/ui/tela_captura.dart`).

> **Dica para a aula:** rode com `flutter run` (não `flutter build apk`) —
> assim você tem hot reload para, ao vivo, mudar por exemplo o
> `limiarConfianca` em `DetectorYolo` e mostrar o efeito imediatamente na
> tela.

---

## 3. Como o modelo é carregado e usado

Arquivo: [`lib/deteccao/detector_yolo.dart`](lib/deteccao/detector_yolo.dart)

O carregamento acontece **uma única vez**, quando o app sobe
(`EstadoApp.inicializar()`, chamado em `main.dart`):

```dart
_interpreter = await Interpreter.fromAsset('assets/models/best_float32.tflite');
```

Isso cria um `Interpreter` do pacote `tflite_flutter`, que carrega o grafo
do modelo na memória e prepara o runtime (LiteRT/TensorFlow Lite) para
rodar inferências. Carregar o modelo é uma operação relativamente lenta
(leitura de arquivo + alocação de memória para os tensores) — por isso é
feita uma vez só, na inicialização, e não a cada foto.

A cada foto tirada, `DetectorYolo.detectar(imagem)` faz 5 passos (cada um
comentado extensivamente no próprio arquivo):

1. **Letterbox**: redimensiona a foto para 640×640 preservando a proporção
   (barras cinza nas bordas, como uma foto widescreen numa TV 4:3).
2. **Tensorização**: converte os pixels em uma lista aninhada com valores
   normalizados de 0.0 a 1.0, na ordem de eixos que o modelo carregado
   realmente espera (ver caixa "NHWC vs NCHW" logo abaixo).
3. **Inferência**: `interpreter.run(entrada, saida)` — a única linha que de
   fato "roda a rede neural".
4. **Pós-processamento**: delega para `pos_processamento_yolo.dart` (seção
   4 abaixo).
5. **Conversão de coordenadas**: desfaz o letterbox do passo 1, para que a
   caixa final esteja em pixels da foto ORIGINAL (não da imagem 640×640
   interna) — essencial para desenhar a caixa corretamente sobre a foto que
   o usuário vê.

> **Pegadinha real que apareceu durante o desenvolvimento deste app — NHWC
> vs NCHW:** exportações TFLite "clássicas" (via TensorFlow) usam a ordem
> de eixos NHWC: `[batch, altura, largura, canais]`, ex. `[1, 640, 640,
> 3]`. Mas exportações mais recentes do Ultralytics (via o conversor
> LiteRT-Torch, usado neste projeto) preservam a ordem NATIVA do PyTorch,
> NCHW: `[batch, canais, altura, largura]`, ex. `[1, 3, 640, 640]` — foi
> exatamente o que o `best.tflite` deste projeto trouxe. É o MESMO modelo,
> mas o tensor de entrada precisa ser montado de um jeito diferente em cada
> caso; montar no formato errado não gera nenhum erro — a inferência roda
> normalmente e devolve resultados sem sentido, porque os números caem nas
> posições erradas do tensor. Por isso `construirTensorEntrada` (em
> `utilitarios_imagem.dart`) lê a forma real do tensor de entrada
> (`interpreter.getInputTensor(0).shape`) e monta o tensor no formato
> correto automaticamente, em vez de assumir um dos dois formatos. É um
> ótimo exemplo, em aula, de como a "pequena letra miúda" de uma exportação
> pode quebrar silenciosamente um pipeline inteiro.

---

## 4. Como o pós-processamento do YOLO funciona (passo a passo)

Arquivo: [`lib/deteccao/pos_processamento_yolo.dart`](lib/deteccao/pos_processamento_yolo.dart)

Esta é, de longe, a parte mais "mágica" do pipeline — e a que mais vale a
pena parar e desenhar no quadro durante a aula.

### O problema: a saída bruta do modelo não é "uma caixa", são 8400 candidatos

Para uma imagem de entrada 640×640, o YOLOv8n gera uma grade de **8400
candidatos** a caixa (resultado de somar 3 escalas de detecção: 80×80 +
40×40 + 20×20 = 8400). Para cada candidato, o modelo devolve 5 números
(porque treinamos 1 classe só, "placa"):

```
[centro_x, centro_y, largura, altura, confiança]
```

A esmagadora maioria desses 8400 candidatos é ruído — o modelo aprendeu a
atribuir confiança bem baixa a eles. O trabalho deste arquivo é extrair só
os candidatos que realmente importam.

### Passo 1 — Filtro de confiança

Descartamos qualquer candidato com `confiança < limiarConfianca` (padrão:
**0.4**). Ver seção 7 para o porquê desse valor específico.

### Passo 2 — Conversão de formato

O modelo devolve `(centro_x, centro_y, largura, altura)`. Para calcular
sobreposição de área no passo seguinte, é mais fácil trabalhar com
`(x1, y1, x2, y2)` (canto superior-esquerdo + canto inferior-direito), então
convertemos:

```
x1 = centro_x - largura/2
y1 = centro_y - altura/2
x2 = centro_x + largura/2
y2 = centro_y + altura/2
```

### Passo 3 — Non-Maximum Suppression (NMS)

Mesmo depois do filtro de confiança, é comum sobrarem **várias caixas
para a mesma placa** — o modelo às vezes "vota" no mesmo objeto com caixas
ligeiramente diferentes em posição/tamanho. O NMS resolve isso com um
algoritmo guloso:

1. Ordena os candidatos da maior para a menor confiança.
2. Percorre em ordem, aceitando cada candidato **a menos que** ele se
   sobreponha demais (acima do `limiarIoU`, padrão **0.45**) com alguma
   caixa já aceita antes.
3. O resultado final é uma caixa por objeto real — sem duplicatas.

A métrica de sobreposição usada é o **IoU (Intersection over Union)**:

```
IoU = área da interseção das duas caixas / área da união das duas caixas
```

`IoU = 1.0` significa caixas idênticas; `IoU = 0.0` significa que elas nem
se tocam. Um `limiarIoU` de 0.45 diz: "se duas caixas se sobrepõem mais de
45%, são a mesma placa".

### Passo 4 — Conversão para o espaço da imagem original

Isso já não acontece dentro de `pos_processamento_yolo.dart` (que é
propositalmente "puro" — só trabalha com números, não sabe nada sobre a
foto original) e sim em `utilitarios_imagem.dart`
(`converterCaixaParaImagemOriginal`), que desfaz o letterbox do passo de
pré-processamento.

---

## 5. Como o OCR é aplicado sobre o recorte

Arquivo: [`lib/ocr/servico_ocr.dart`](lib/ocr/servico_ocr.dart)

Depois que `utilitarios_imagem.recortarRegiao` isola só a região da placa
(com uma margem extra de 8% para não cortar a lateral de nenhum caractere),
o recorte é passado para o `google_mlkit_text_recognition`:

1. O recorte (que existe só em memória, como `Uint8List`) é salvo em um
   arquivo temporário — a API do ML Kit espera um `InputImage`, que é mais
   simples de construir a partir de um caminho de arquivo
   (`InputImage.fromFilePath`).
2. `TextRecognizer.processImage(...)` roda o OCR on-device e devolve o
   texto detectado.
3. O texto bruto é normalizado (`_normalizarTextoPlaca`): maiúsculas, e
   remoção de qualquer caractere que não seja letra ou número — isso NÃO é
   um validador de formato de placa (Mercosul, antigo, etc.), é só uma
   limpeza simples para exibição.
4. O arquivo temporário é apagado — ele só existia para satisfazer a API.

Por que dois campos (`textoBruto` e `textoFinal`/normalizado) no
`ResultadoLeitura`? Justamente para o Modo Explicação poder mostrar, lado a
lado, a diferença entre "o que o OCR devolveu cru" e "o que decidimos
mostrar depois de limpar" — um ótimo gancho para discutir com a turma por
que quase todo pipeline de OCR real precisa de pós-processamento.

---

## 6. Como regenerar o modelo (.pt → .tflite)

O modelo treinado (`best.pt`, formato Ultralytics/PyTorch) precisa ser
exportado para TFLite antes de entrar no app — o `tflite_flutter` só
carrega arquivos `.tflite`.

### Passo a passo (script pronto)

A exportação do modelo é uma tarefa de Python/Ultralytics, separada do
projeto Flutter — por isso o script fica FORA da pasta do app, em uma
pasta irmã dedicada só a isso:

```
treinamentoDL_app/
├── best.pt                      # modelo treinado (formato Ultralytics)
├── exportar_modelo/             # conversão .pt -> .tflite (fora do Flutter)
│   ├── exportar_modelo.py
│   └── requirements.txt
└── treinamento_app/             # o app Flutter em si
```

```bash
cd exportar_modelo

# 1. Crie um ambiente virtual Python 3.10+ dedicado à exportação
#    (IMPORTANTE: veja a nota abaixo sobre versão do Python)
python3.11 -m venv venv_export
source venv_export/bin/activate   # no Windows: venv_export\Scripts\activate

# 2. Instale a dependência (só o Ultralytics)
pip install -r requirements.txt

# 3. Rode a exportação (por padrão, lê ../best.pt — ajuste dentro do
#    script se o seu .pt estiver em outro lugar)
python exportar_modelo.py
```

O script (curto e comentado em português — vale a pena abrir e ler durante
a aula) só faz a exportação, nada mais. Ao final, o próprio Ultralytics
imprime no terminal o caminho do arquivo `.tflite` gerado — copie-o para
dentro do app manualmente:

```bash
cp best.tflite ../treinamento_app/assets/models/best_float32.tflite
```

(Se sua versão do Ultralytics gerar uma pasta com variantes em vez de um
arquivo único, use a variante `best_float32.tflite` de dentro dela.)

> **Nota — versão mínima do Python:** a partir do Ultralytics 8.4, a
> exportação para TFLite passou a se chamar internamente "LiteRT" e
> depende do pacote `litert-torch`, que **exige Python 3.10 ou superior**.
> Se você estiver em um Python 3.9 (comum em instalações padrão de macOS/
> Linux mais antigas), a exportação falha com
> `ModuleNotFoundError: No module named 'litert_torch'`. Solução: crie o
> ambiente virtual com uma versão mais nova do Python (ex:
> `brew install python@3.11` no macOS), como no comando acima. Foi
> exatamente esse o obstáculo encontrado ao gerar o modelo deste projeto —
> resolvido recriando o ambiente virtual com Python 3.11.

### Por que `imgsz=640`?

Precisa bater exatamente com o `tamanhoEntrada` usado em
`DetectorYolo` (também 640 por padrão). Se você treinar/exportar com outro
tamanho, atualize o construtor de `DetectorYolo` no app para o mesmo valor.

### Se a forma da saída for diferente do esperado

O código em `detector_yolo.dart` foi escrito para se adaptar a saídas no
formato `[1, 4+numeroClasses, numeroCaixas]` ou `[1, numeroCaixas,
4+numeroClasses]` automaticamente. Se você treinar com mais de 1 classe ou
usar uma versão do Ultralytics com uma saída bem diferente, abra o arquivo
`.tflite` no [Netron](https://netron.app) (uma ferramenta gratuita e
visual para inspecionar redes neurais) para conferir a forma real de
entrada/saída antes de mexer no código.

---

## 7. Decisões técnicas e seus porquês

| Decisão | Por quê |
|---|---|
| **TFLite em vez de ONNX** | Runtime mobile nativo mantido pelo Google (LiteRT), com binding Dart oficial (`tflite_flutter`) e execução eficiente em CPU/GPU/NNAPI no Android sem exigir compilação manual de bibliotecas nativas extras. ONNX Runtime funciona em Flutter, mas exige mais configuração nativa por plataforma — atrito desnecessário para um app didático. |
| **Google ML Kit em vez de EasyOCR/Tesseract** | EasyOCR é uma biblioteca Python sem binding Flutter — "portar" seria reimplementar o modelo em outro runtime. Tesseract tem plugins Flutter, mas costuma exigir mais pré-processamento manual (binarização/contraste) para ler bem texto curto como placas. O ML Kit roda 100% on-device (sem enviar fotos a servidores), tem plugin Flutter oficial do Google e funciona bem "out of the box" para blocos curtos de texto. |
| **`limiarConfianca = 0.4`** | Alto o suficiente para evitar caixas "fantasma" em fundos que lembram uma placa (ex: uma faixa retangular clara), mas baixo o suficiente para não perder detecções em fotos tiradas ao vivo, na hora, com ângulo/iluminação imperfeitos — exatamente o cenário de uma demonstração em sala de aula. |
| **`limiarIoU = 0.45` (NMS)** | Valor padrão usado pelo próprio Ultralytics. Funciona bem porque placas veiculares raramente aparecem coladas umas nas outras na mesma foto — um limiar moderadamente permissivo não corre risco de fundir duas placas diferentes. |
| **Provider em vez de Riverpod** | Para uma árvore de estado pequena (praticamente um único `ChangeNotifier` global), o Provider é o caminho mais curto entre "ligar o app" e "aluno consegue ler o código sem aprender outro framework à parte". Riverpod é mais robusto para apps grandes (testável sem `BuildContext`, checagem em tempo de compilação), mas isso seria over-engineering para um app de demonstração com uma única fonte de estado compartilhado. |
| **Histórico só em memória** | É um app de demonstração de aula — reiniciar o app entre turmas/demonstrações "limpar tudo" é o comportamento desejado, não um bug. Adicionar persistência em banco de dados seria complexidade sem benefício didático. |
| **Margem de 8% no recorte da placa** | O YOLO às vezes desenha a caixa "coladinha" nos caracteres. Recortar exatamente na borda arrisca cortar a lateral de uma letra, prejudicando o OCR. A margem dá folga sem incluir fundo demais. |

---

## 7.1. Obstáculos reais de build encontrados (e suas correções)

Vale a pena mencionar em aula: nenhuma dessas correções tem relação com
Visão Computacional — são "letra miúda" de toolchain que qualquer
integração de um plugin nativo (câmera, TFLite, ML Kit) pode expor.

- **`Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks`**:
  o módulo Android do `tflite_flutter` não fixa a JVM target do Kotlin,
  deixando o Gradle inferi-la a partir do JDK instalado na máquina (que
  pode ser bem mais novo que o Java 1.8 usado na parte Java do mesmo
  plugin). Corrigido em `android/build.gradle.kts`, forçando 17 (Java e
  Kotlin) em todos os subprojetos via a extensão `android.compileOptions`
  — sobrescrever a task `JavaCompile` diretamente não funciona, porque o
  AGP recalcula esse valor a partir da extensão em um momento posterior da
  configuração.
- **`Namespace 'org.tensorflow.lite' is used in multiple modules and/or
  libraries`**: os artefatos nativos do TensorFlow Lite 2.11.0
  (`tensorflow-lite`, `tensorflow-lite-api`, `tensorflow-lite-gpu`), usados
  internamente pelo `tflite_flutter`, compartilham o mesmo namespace
  Android no próprio manifesto — um problema conhecido e documentado do
  lado do TensorFlow ([tensorflow/tensorflow#109508](https://github.com/tensorflow/tensorflow/issues/109508)),
  que o AGP 9 passou a rejeitar por validação mais estrita. Corrigido com
  `android.uniquePackageNames=false` em `android/gradle.properties` —
  workaround reconhecido oficialmente pelo próprio time do Google/
  TensorFlow enquanto os mantenedores não publicam uma correção definitiva
  nos artefatos.

---

## 8. Limitações conhecidas

- **Placas muito pequenas ou distantes na foto**: como a imagem é
  redimensionada para 640×640 antes da detecção, uma placa que já ocupa
  poucos pixels na foto original fica ainda menor após o redimensionamento
  — o que degrada tanto a detecção quanto o OCR do recorte.
- **Fotos borradas / baixa luminosidade**: o modelo foi treinado em
  condições relativamente controladas; movimento (mão trêmula, carro em
  movimento) ou pouca luz reduzem bastante a confiança da detecção e a
  legibilidade do recorte para o OCR.
- **Ângulos extremos (placa muito inclinada/de lado)**: o OCR do ML Kit
  assume texto razoavelmente horizontal; ângulos fortes de perspectiva
  distorcem os caracteres o suficiente para atrapalhar o reconhecimento,
  mesmo quando a detecção da caixa funciona bem.
- **Uma única classe treinada**: o modelo só reconhece "placa" — não
  distingue tipo de veículo, país/estado, ou formato Mercosul vs. antigo. A
  normalização do texto do OCR também não valida formato de placa.
- **Múltiplas placas na mesma foto**: o app fica só com a detecção de
  maior confiança por foto (decisão de simplicidade para a demo). Se
  houver mais de um veículo na cena, apenas uma placa é processada.
- **Performance em dispositivos mais antigos**: a inferência roda na CPU
  por padrão (não há delegate de GPU/NNAPI configurado, de propósito, para
  manter o código de carregamento do modelo simples e didático) — em
  aparelhos muito antigos, o tempo entre tirar a foto e ver o resultado
  pode ser perceptível.

---

## 9. Estrutura de pastas

```
lib/
├── main.dart                       # ponto de entrada, monta Provider + MaterialApp
├── tema.dart                       # paleta de cores e ThemeData
├── estado_app.dart                 # ChangeNotifier que orquestra o pipeline completo
├── modelos/
│   ├── deteccao.dart               # classe Deteccao (caixa + confiança)
│   └── resultado_leitura.dart      # classe ResultadoLeitura (todas as etapas)
├── captura/
│   └── servico_camera.dart         # inicialização/ciclo de vida da câmera
├── deteccao/
│   ├── detector_yolo.dart          # carrega o .tflite e roda a inferência
│   ├── pos_processamento_yolo.dart # decodifica a saída bruta + NMS
│   └── utilitarios_imagem.dart     # letterbox, tensor de entrada, recorte, desenho de caixa
├── ocr/
│   └── servico_ocr.dart            # Google ML Kit + normalização do texto
└── ui/
    ├── tela_inicial.dart           # storytelling ("1,2,3,4")
    ├── tela_captura.dart           # câmera/galeria + interruptor Modo Explicação
    ├── tela_resultado.dart         # resultado resumido OU 5 etapas didáticas
    ├── tela_historico.dart         # lista das últimas leituras (em memória)
    └── widgets/
        ├── overlay_escaneando.dart     # efeito "leitor de código de barras"
        ├── pintor_caixa_animada.dart   # caixa desenhada com animação de traçado
        └── cartao_historico.dart       # item da lista de histórico

assets/models/
├── best_float32.tflite            # modelo YOLOv8n exportado (ver seção 6)
└── labels.txt                     # nomes das classes ("placa")
```

O script de exportação do modelo (`exportar_modelo.py`) fica FORA desta
pasta, em `../exportar_modelo/` — ver seção 6.

---

## 10. Roteiro sugerido para a aula

Uma ordem de apresentação que segue a estrutura deste README:

1. **Abra `tela_inicial.dart`** — mostre o storytelling, explique que cada
   um dos 4 passos vira uma camada de código diferente.
2. **Ligue o "Modo Explicação"** e tire uma foto ao vivo de uma placa (ou
   escolha uma foto de exemplo da galeria). Deixe a turma ver as 5 etapas
   lado a lado.
3. **Abra `pos_processamento_yolo.dart`** — este é o momento de desenhar no
   quadro os 8400 candidatos, o filtro de confiança e o NMS. É a parte que
   mais gera perguntas.
4. **Abra `servico_ocr.dart`** — mostre a diferença entre `textoBruto` e
   `textoFinal` na tela de resultado, e discuta por que OCR raramente é
   "plug and play" sem pós-processamento.
5. **Desligue o Modo Explicação** e mostre o app "como produto final" —
   rápido, com a animação de caixa e o feedback tátil/sonoro.
6. **(Opcional) Mexa ao vivo em `limiarConfianca`** no `DetectorYolo`, dê
   hot reload, e mostre o efeito de baixar/subir o limiar em uma mesma
   foto — ótimo para ilustrar o trade-off entre falsos positivos e falsos
   negativos.
