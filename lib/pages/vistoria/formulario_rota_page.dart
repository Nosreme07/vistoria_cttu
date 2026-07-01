import 'dart:io';
import 'dart:typed_data'; // ADICIONADO: Para manipular as imagens na memória (Compatível com Web/Android/iOS)
import 'dart:convert'; // ADICIONADO: Para conversão do CSV
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

class FormularioRotaPage extends StatefulWidget {
  const FormularioRotaPage({super.key});

  @override
  State<FormularioRotaPage> createState() => _FormularioRotaPageState();
}

class _FormularioRotaPageState extends State<FormularioRotaPage>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;

  late TabController _tabController;
  final TextEditingController _pesquisaAndamentoController =
      TextEditingController();
  final TextEditingController _pesquisaConcluidosController =
      TextEditingController();

  String _textoPesquisaAndamento = '';
  String _textoPesquisaConcluidos = '';

  String _nomeDoVistoriadorLogado = 'Carregando...';
  String? _fotoUrlVistoriador;
  bool _isAdmin = false;
  bool _isVistoriador = false;
  bool _carregandoPerfil = true;

  // Dados Mestre do Acervo
  List<Map<String, dynamic>> _todosSemaforosAcervo = [];
  List<String> _todasAsRotasAcervo = [];
  bool _carregandoRotas = true;
  bool _iniciandoTurno = false;

  String? _veiculoSelecionadoId;
  String? _veiculoSelecionadoPlaca;
  String? _rotaSelecionada;
  final TextEditingController _kmInicialController = TextEditingController();
  bool _confirmouTermoInicio = false;

  DocumentSnapshot? _turnoSelecionadoAdmin;

  final String textoConfirmacaoChecklist =
      'Confirmo que verifiquei a integridade física, elétrica e de funcionamento de todos os equipamentos (focos, estruturas, controladores, kit de energia e acessórios), bem como a visibilidade, sinalização associada e ausência de interferências externas.';

  // Filtros ABA Admin
  DateTime? _dataInicioFiltro;
  DateTime? _dataFimFiltro;
  String _rotaFiltro = 'Todas';
  // ==== BLOCO 1: LISTA DO ACERVO E FUNÇÃO DE BUSCA ====
  final List<String> _ordemCamposExibicao = [
    "SEMÁFORO",
    "IP DDNS",
    "SEMÁFORO COMPARTILHADO",
    "Nº CHIP",
    "ELSYS",
    "LOCALIZAÇÃO 1",
    "LOCALIZAÇÃO 2",
    "ENDEREÇO",
    "BAIRRO",
    "TIPO DE CONTROLADOR",
    "EMPRESA",
    "ROTA",
    "ORDEM",
    "OBSERVAÇOES",
    "SUB-ÁREA (TRAFGO)",
    "LATITUDE",
    "LONGITUDE",
    "GEOREFERÊNCIA",
    "NOBREAK",
    "Nº do No Break",
    "CÂMERAS",
    "BOTOEIRA COM DISPOSITIVO SONORO",
    "HORÁRIO DE FUNCIONAMENTO Do dispositivo sonoro",
    "BOTOEIRA SIMPLES",
    "Coluna Cônica",
    "Coluna Simples",
    "Semipórtico Cônico",
    "Semipórtico Simples",
    "Semipórtico Estruturado",
    "Pórtico Estruturado",
    "Veicular TIPO I",
    "VeiculaR Tipo T",
    "PEDESTRE SIMPLES",
    "Pedestre com cronômetro",
    "Ciclista",
    "Anteparo TIpo I",
    "Veicular com sequencial",
    "Veicular com cronômetro",
    "Luminárias",
    "Conta-Contrato",
    "NÚMERO DO Medidor",
    "Data de implantação",
  ];

  String _obterValorCampo(Map<String, dynamic> semaforo, String chaveOriginal) {
    // 1. Tentativa de busca direta exata
    if (semaforo.containsKey(chaveOriginal))
      return semaforo[chaveOriginal].toString();

    String chaveMinuscula = chaveOriginal.toLowerCase().trim();
    if (semaforo.containsKey(chaveMinuscula))
      return semaforo[chaveMinuscula].toString();

    // Função interna para remover acentos, espaços, sublinhados e caracteres especiais
    String simplificar(String texto) {
      return texto
          .toLowerCase()
          .replaceAll(RegExp(r'[áàâãä]'), 'a')
          .replaceAll(RegExp(r'[éèêë]'), 'e')
          .replaceAll(RegExp(r'[íìîï]'), 'i')
          .replaceAll(RegExp(r'[óòôõö]'), 'o')
          .replaceAll(RegExp(r'[úùûü]'), 'u')
          .replaceAll(RegExp(r'[ç]'), 'c')
          .replaceAll(
            RegExp(r'[^a-z0-9]'),
            '',
          ); // Remove espaços, _ , - , ( ), nº, etc.
    }

    String alvo = simplificar(chaveOriginal);

    // 2. Varredura comparando chaves limpas/saneadas
    for (var entry in semaforo.entries) {
      String chaveMapaLimpa = simplificar(entry.key);

      // Se as chaves limpas forem idênticas (ex: "tipo_de_controlador" vira "tipodecontrolador")
      if (chaveMapaLimpa == alvo) {
        return entry.value.toString();
      }

      // Se uma chave contiver a outra (ex: "tipo_controlador" vira "tipocontrolador" e alvo é "tipodecontrolador")
      if (chaveMapaLimpa.contains(alvo) || alvo.contains(chaveMapaLimpa)) {
        if (entry.key.length > 2 && chaveOriginal.length > 2) {
          return entry.value.toString();
        }
      }
    }

    // 3. Fallbacks manuais para segurança de campos vitais
    if (alvo == 'semaforo' || alvo == 'id') {
      return (semaforo['id'] ??
              semaforo['semáforo'] ??
              semaforo['semaforo'] ??
              '')
          .toString();
    }
    if (alvo == 'endereco') {
      return (semaforo['endereco'] ?? semaforo['endereço'] ?? '').toString();
    }

    return '';
  }

  // ====================================================
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _pesquisaAndamentoController.addListener(() {
      setState(
        () => _textoPesquisaAndamento = _pesquisaAndamentoController.text
            .toLowerCase(),
      );
    });

    _pesquisaConcluidosController.addListener(() {
      setState(
        () => _textoPesquisaConcluidos = _pesquisaConcluidosController.text
            .toLowerCase(),
      );
    });

    _baixarDadosIniciais();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pesquisaAndamentoController.dispose();
    _pesquisaConcluidosController.dispose();
    _kmInicialController.dispose();
    super.dispose();
  }

  // ==== LÓGICA DE CORES DA ROTA ====
  Color _obterCorDaRota(String rota) {
    String r = rota
        .trim()
        .toUpperCase()
        .replaceAll('ROTA', '')
        .replaceAll(' ', '');
    if (r.isEmpty) return Colors.grey.shade600;

    switch (r) {
      case '1':
      case '01':
        return Colors.blue.shade700;
      case '2':
      case '02':
        return Colors.green.shade700;
      case '3':
      case '03':
        return Colors.red.shade700;
      case '4':
      case '04':
        return Colors.purple.shade700;
      case '5':
      case '05':
        return Colors.amber.shade800;
      case '6':
      case '06':
        return Colors.teal.shade700;
      case '7':
      case '07':
        return Colors.indigo.shade700;
      case '8':
      case '08':
        return Colors.pink.shade700;
      case '9':
      case '09':
        return Colors.cyan.shade800;
      case '10':
        return Colors.deepOrange.shade700;
      default:
        final int hash = r.hashCode;
        final List<Color> coresDisponiveis = [
          Colors.blue.shade700,
          Colors.green.shade700,
          Colors.red.shade700,
          Colors.purple.shade700,
          Colors.amber.shade800,
          Colors.teal.shade700,
          Colors.indigo.shade700,
          Colors.pink.shade700,
          Colors.cyan.shade800,
          Colors.deepOrange.shade700,
          Colors.brown.shade600,
          Colors.blueGrey.shade700,
        ];
        return coresDisponiveis[hash.abs() % coresDisponiveis.length];
    }
  }

  Future<void> _baixarDadosIniciais() async {
    if (user == null) return;

    try {
      var docUsuario = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user!.uid)
          .get();
      if (docUsuario.exists && docUsuario.data() != null) {
        var dataUsuario = docUsuario.data()!;
        String perfil = (dataUsuario['perfil'] ?? '').toString().toLowerCase();

        _isAdmin = perfil.contains('admin') || perfil.contains('administrador');
        // ==== ADICIONADO: Valida se o perfil é estritamente de vistoriador ====
        _isVistoriador = perfil.contains('vistoriador');

        _nomeDoVistoriadorLogado =
            dataUsuario['nome'] ??
            dataUsuario['nome_completo'] ??
            user!.email?.split('@').first.toUpperCase() ??
            'Vistoriador';
      }

      var snapshotSemaforos = await FirebaseFirestore.instance
          .collection('semaforos')
          .get();

      List<Map<String, dynamic>> semaforosTemp = [];
      Set<String> rotasSet = {};

      for (var doc in snapshotSemaforos.docs) {
        var item = doc.data();
        if (item['id'] != null && item['id'].toString().isNotEmpty) {
          semaforosTemp.add(item);

          String rotaLimpa = (item['rota'] ?? '').toString().replaceAll(
            RegExp(r'[^0-9]'),
            '',
          );

          if (rotaLimpa.isNotEmpty) {
            rotasSet.add(rotaLimpa);
          }
        }
      }

      List<String> listaRotas = rotasSet.toList();
      listaRotas.sort((a, b) {
        int numA = int.tryParse(a) ?? 0;
        int numB = int.tryParse(b) ?? 0;
        return numA.compareTo(numB);
      });

      if (!mounted) return;
      setState(() {
        _todosSemaforosAcervo = semaforosTemp;
        _todasAsRotasAcervo = listaRotas;
        _carregandoPerfil = false;
        _carregandoRotas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregandoPerfil = false;
        _carregandoRotas = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao baixar os semáforos do banco de dados.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ========================================================================
  // 📐 FUNÇÃO DE INICIAR TURNO
  // ========================================================================
  Future<void> _iniciarTurno() async {
    if (_veiculoSelecionadoId == null ||
        _rotaSelecionada == null ||
        _kmInicialController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha a Moto, o KM e a Rota para iniciar!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_confirmouTermoInicio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você deve confirmar que é o vistoriador responsável!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _iniciandoTurno = true);

    try {
      // ==== BLOCO CORRIGIDO: BUSCA A FOTO DO STORAGE ====
      String? urlDaFotoFinal = _fotoUrlVistoriador;

      if (urlDaFotoFinal == null || urlDaFotoFinal.isEmpty) {
        // Tenta primeiro COM .jpg
        try {
          urlDaFotoFinal = await FirebaseStorage.instance
              .ref('fotos_vistoriadores/${user!.uid}.jpg')
              .getDownloadURL();
        } catch (e) {
          // Se falhar com .jpg, tenta SEM extensão (igual ao seu print provável)
          try {
            urlDaFotoFinal = await FirebaseStorage.instance
                .ref('fotos_vistoriadores/${user!.uid}')
                .getDownloadURL();
          } catch (e2) {
            debugPrint(
              'Nenhuma foto encontrada no Storage para o UID ${user!.uid}',
            );
          }
        }
      }
      // ===================================================

      await FirebaseFirestore.instance.collection('turnos').add({
        'vistoriador_uid': user!.uid,
        'vistoriador_nome': _nomeDoVistoriadorLogado,
        'vistoriador_foto_url':
            urlDaFotoFinal, // <-- AGORA A FOTO É SALVA NO TURNO!
        'veiculo_id': _veiculoSelecionadoId,
        'placa': _veiculoSelecionadoPlaca,
        'km_inicial': _kmInicialController.text.trim(),
        'km_final': null,
        'rota_numero': _rotaSelecionada,
        'status': 'ativo',
        'data_inicio': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('veiculos')
          .doc(_veiculoSelecionadoId)
          .update({'em_uso': true});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _iniciandoTurno = false);
    }
  }

  Future<Position> _determinarPosicao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled)
      return Future.error(
        'Os serviços de localização estão desativados no celular.',
      );

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        return Future.error('Permissão de localização negada.');
    }
    if (permission == LocationPermission.deniedForever)
      return Future.error('Permissão negada permanentemente.');

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _mostrarOpcoesGPS(String georeferencia) {
    if (georeferencia.trim().isEmpty || !georeferencia.contains(',')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semáforo sem coordenadas cadastradas!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Como deseja chegar ao semáforo?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.directions_car, size: 28),
                        label: const Text(
                          'Waze',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _abrirAppNavegacao(georeferencia, 'waze');
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.map, size: 28),
                        label: const Text(
                          'Maps',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _abrirAppNavegacao(georeferencia, 'maps');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirAppNavegacao(String georeferencia, String app) async {
    try {
      String geoLimpa = georeferencia.trim();
      List<String> partes = geoLimpa.split(',');
      if (partes.length < 2) throw 'Formato inválido';

      String lat = partes[0].trim();
      String lng = partes[1].trim();

      Uri url;
      if (app == 'waze') {
        url = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
      } else {
        url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        );
      }

      bool abriu = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!abriu) throw 'Não foi possível abrir o aplicativo.';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao abrir o $app. Verifique se ele está instalado!',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==== MODIFICADO: Função com o novo layout da mensagem ====
  Future<void> _enviarOcorrencia(
    Map<String, dynamic> semaforo,
    String falha,
    String detalhes,
    List<Uint8List> fotosLocais,
    String gpsVistoriador, // <-- ADICIONADO PARA RECEBER O GPS DA VISTORIA
  ) async {
    String idSemaforo = semaforo['id']?.toString() ?? 'S/N';
    String endereco = semaforo['endereco'] ?? 'Endereço não cadastrado';

    // Puxa a rota e a georreferência direto do mapa do acervo
    String rotaSemaforo =
        semaforo['rota']?.toString().replaceFirst(RegExp(r'^0+'), '') ?? 'S/N';
    String georefSemaforo =
        semaforo['georeferencia']?.toString() ?? 'Não informada';

    // Monta a mensagem exatamente no formato solicitado
    String mensagem =
        '🚨 *OCORRÊNCIA REGISTRADA - ROTA $rotaSemaforo* 🚨\n\n'
        '*Semáforo:* $idSemaforo\n'
        '*Endereço:* $endereco\n'
        '*Semáforo:* $georefSemaforo\n'
        '*Vistoriador:* $gpsVistoriador\n'
        '*Vistoriador:* $_nomeDoVistoriadorLogado\n'
        '*Falha:* $falha\n'
        '*Detalhes:* ${detalhes.isEmpty ? "Sem detalhes" : detalhes}';

    try {
      if (fotosLocais.isNotEmpty) {
        // Converte os dados da memória de volta para XFile que é o formato exigido pelo plugin SharePlus
        List<XFile> xFiles = [];
        for (int i = 0; i < fotosLocais.length; i++) {
          xFiles.add(
            XFile.fromData(
              fotosLocais[i],
              mimeType: 'image/jpeg',
              name: 'ocorrencia_$i.jpg',
            ),
          );
        }
        await Share.shareXFiles(xFiles, text: mensagem);
      } else {
        await Share.share(mensagem);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao compartilhar a ocorrência.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==== MODIFICADO: Função carimba a imagem usando dados em memória em vez de Arquivo ====
  Future<Uint8List> _carimbarFoto(
    Uint8List bytesOriginais,
    String semaforoInfo,
    String dataColetada,
    String gpsColetado,
  ) async {
    try {
      img.Image? imagemDecodificada = img.decodeImage(bytesOriginais);

      if (imagemDecodificada == null) return bytesOriginais;

      List<String> linhasTexto = [
        'Semaforo: $semaforoInfo',
        'Data: $dataColetada',
        'GPS: $gpsColetado',
      ];

      final fonteParaCarimbo = img.arial48;
      int yInicial =
          imagemDecodificada.height -
          (linhasTexto.length * fonteParaCarimbo.lineHeight) -
          30;

      for (int i = 0; i < linhasTexto.length; i++) {
        String texto = linhasTexto[i];
        int posY = yInicial + (i * fonteParaCarimbo.lineHeight);

        img.drawString(
          imagemDecodificada,
          texto,
          font: fonteParaCarimbo,
          x: 23,
          y: posY + 3,
          color: img.ColorRgb8(0, 0, 0),
        );
        img.drawString(
          imagemDecodificada,
          texto,
          font: fonteParaCarimbo,
          x: 20,
          y: posY,
          color: img.ColorRgb8(255, 255, 0),
        );
      }

      final novosBytes = img.encodeJpg(imagemDecodificada, quality: 85);
      return Uint8List.fromList(novosBytes);
    } catch (e) {
      return bytesOriginais;
    }
  }

  void _mostrarImagemExpandida(
    BuildContext context,
    ImageProvider imageProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image(image: imageProvider, fit: BoxFit.contain),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.white, size: 36),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  pw.Widget _buildRodapePDF(pw.Context context, String dataHora) {
    return pw.Container(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.SizedBox(width: 50),
              pw.Expanded(
                child: pw.Text(
                  'Relatório gerado pelo aplicativo Vistoria CTTU ($dataHora)',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.SizedBox(
                width: 50,
                child: pw.Text(
                  'Pág. ${context.pageNumber} / ${context.pagesCount}',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportarPDFIndividual(
    Map<String, dynamic> vistoria,
    String nomeVistoriador,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Baixando fotos e gerando PDF...'),
        backgroundColor: Colors.teal,
      ),
    );

    try {
      bool temFalha = vistoria['teve_anormalidade'] == true;
      List<dynamic> urlsFotos = vistoria['fotos'] ?? [];
      List<pw.ImageProvider> imagensPdf = [];

      for (String url in urlsFotos) {
        try {
          final imageBytes = await networkImage(url);
          imagensPdf.add(imageBytes);
        } catch (e) {
          debugPrint('Erro ao baixar imagem: $e');
        }
      }

      String coordOriginal = vistoria['coordenadas_cadastro']?.toString() ?? '';
      if (coordOriginal.isEmpty) {
        var matches = _todosSemaforosAcervo.where(
          (s) => s['id'].toString() == vistoria['semaforo_id'].toString(),
        );
        coordOriginal = matches.isNotEmpty
            ? (matches.first['georeferencia']?.toString() ?? 'Não informada')
            : 'Não informada';
      }

      String dataHoraAtual = DateFormat(
        'dd/MM/yyyy HH:mm:ss',
      ).format(DateTime.now());
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.only(
            left: 32,
            right: 32,
            top: 32,
            bottom: 20,
          ),
          footer: (pw.Context context) =>
              _buildRodapePDF(context, dataHoraAtual),
          build: (pw.Context context) {
            return [
              pw.Row(
                children: [
                  pw.Container(
                    width: 30,
                    height: 30,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: temFalha ? PdfColors.red : PdfColors.green,
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Text(
                    'Semáforo Nº ${vistoria['semaforo_id']}',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 2, height: 32),
              pw.Text(
                'Vistoriador: $nomeVistoriador',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Endereço: ${vistoria['semaforo_endereco']}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Início da vistoria: ${vistoria['data_hora_inicio']}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Fim da vistoria: ${vistoria['data_hora_fim']}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Coordenadas do Semáforo: $coordOriginal',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Coordenadas da Vistoria: ${vistoria['gps_coordenadas']}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  vistoria['resumo_checklist'] ?? 'Checklist verificado.',
                  style: pw.TextStyle(
                    color: PdfColors.blue800,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  color: temFalha ? PdfColors.red50 : PdfColors.green50,
                  border: pw.Border.all(
                    color: temFalha ? PdfColors.red : PdfColors.green,
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      temFalha ? 'FALHA REGISTRADA:' : 'STATUS:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: temFalha ? PdfColors.red : PdfColors.green,
                      ),
                    ),
                    pw.Text(
                      vistoria['falha_registrada'] ?? 'NENHUMA FALHA',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Detalhes:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: temFalha ? PdfColors.red : PdfColors.green,
                      ),
                    ),
                    pw.Text(
                      vistoria['detalhes_ocorrencia'] ?? 'SEM DETALHES',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

              if (imagensPdf.isNotEmpty) ...[
                pw.SizedBox(height: 24),
                pw.Text(
                  'Fotos da Ocorrência:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: imagensPdf
                      .map(
                        (img) => pw.Container(
                          width: 150,
                          height: 150,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey),
                            borderRadius: pw.BorderRadius.circular(8),
                            // ==== MODIFICADO: Mudou de cover para contain para não cortar o carimbo ====
                            image: pw.DecorationImage(
                              image: img,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ];
          },
        ),
      );

      String idStr = vistoria['semaforo_id']?.toString() ?? 'SN';
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Ficha_Semaforo_$idStr.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao gerar PDF da ficha!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ========================================================================
  // BLOCO DO PDF GERAL DE VISTORIAS DA ROTA (Geral)
  // ========================================================================
  Future<void> _gerarEMostrarPDF(
    List<QueryDocumentSnapshot> vistorias,
    String rotaNumero,
    String nomeVistoriador,
  ) async {
    if (_todosSemaforosAcervo.isEmpty) return;
    try {
      // ========================================================================
      // 📐 TAMANHO DAS COLUNAS DO PDF (ALTERE OS VALORES ABAIXO COMO DESEJAR)
      // ========================================================================
      double colLarguraSemaforo = 40;
      double colLarguraVistoriador = 60;
      double colLarguraEndereco = 100;
      double colLarguraGeoreferencia = 95; // <-- Nova coluna de coordenadas
      double colLarguraInicio = 50;
      double colLarguraFim = 50;
      double colLarguraStatus = 60;
      double colLarguraFalha = 70;
      double colLarguraDetalhes = 100;
      double colLarguraFotos = 100;
      // ========================================================================

      String dataHoraAtual = DateFormat(
        'dd/MM/yyyy HH:mm:ss',
      ).format(DateTime.now());
      String rotaTurnoLimpa = rotaNumero.replaceFirst(RegExp(r'^0+'), '');

      // 1. Filtra os semáforos da rota no acervo
      List<Map<String, dynamic>> semaforosDaRota = _todosSemaforosAcervo.where((
        item,
      ) {
        String rotaItem = (item['rota'] ?? '').toString().trim().replaceFirst(
          RegExp(r'^0+'),
          '',
        );
        return rotaItem == rotaTurnoLimpa;
      }).toList();

      // 2. Mapeia as vistorias realizadas
      Map<String, Map<String, dynamic>> vistoriasMap = {};
      for (var doc in vistorias) {
        var v = doc.data() as Map<String, dynamic>;
        String idSem = v['semaforo_id']?.toString() ?? '';
        if (idSem.isNotEmpty) vistoriasMap[idSem] = v;
      }

      List<Map<String, dynamic>> listaVistoriados = [];
      List<Map<String, dynamic>> listaNaoVistoriados = [];

      // 3. Cruza os dados para achar os "NÃO VISTORIADOS"
      for (var semaforoMestre in semaforosDaRota) {
        String idSem = semaforoMestre['id']?.toString() ?? '';
        if (vistoriasMap.containsKey(idSem)) {
          listaVistoriados.add(vistoriasMap[idSem]!);
        } else {
          listaNaoVistoriados.add({
            'semaforo_id': idSem,
            'semaforo_endereco': semaforoMestre['endereco'] ?? 'Sem endereço',
            'data_hora_inicio': '-',
            'data_hora_fim': '-',
            'gps_coordenadas': '-',
            'teve_anormalidade': null,
            'falha_registrada': '-',
            'detalhes_ocorrencia': '-',
            'fotos': [],
            'isNaoVistoriado': true,
            'criado_em': null,
          });
        }
      }

      // 4. Ordenação cronológica (Mais antiga para a mais recente)
      listaVistoriados.sort((a, b) {
        Timestamp? tA = a['criado_em'] as Timestamp?;
        Timestamp? tB = b['criado_em'] as Timestamp?;
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tA.compareTo(tB);
      });

      // Ordena os não vistoriados por número
      listaNaoVistoriados.sort((a, b) {
        int numA =
            int.tryParse(
              a['semaforo_id'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            9999;
        int numB =
            int.tryParse(
              b['semaforo_id'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            9999;
        return numA.compareTo(numB);
      });

      List<Map<String, dynamic>> listaFinalRelatorio = [
        ...listaVistoriados,
        ...listaNaoVistoriados,
      ];

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.only(
            left: 12,
            right: 12,
            top: 24,
            bottom: 20,
          ),
          footer: (pw.Context context) =>
              _buildRodapePDF(context, dataHoraAtual),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Relatório Unificado de Vistorias - Rota $rotaNumero',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                context: context,
                // Adicionado a coluna "Georreferência" no cabeçalho
                headers: [
                  'Semáforo',
                  'Vistoriador',
                  'Endereço',
                  'Georreferência',
                  'Início',
                  'Fim',
                  'Status',
                  'Falha',
                  'Detalhes',
                  'Fotos',
                ],
                data: listaFinalRelatorio.map((v) {
                  String status = 'OK';
                  if (v['isNaoVistoriado'] == true) {
                    status = 'NÃO VISTORIADO';
                  } else if (v['teve_anormalidade'] == true) {
                    status = 'COM FALHA';
                  }

                  // Coleta a coordenada original do acervo mestre
                  String coordOriginal =
                      v['coordenadas_cadastro']?.toString() ?? '';
                  if (coordOriginal.isEmpty) {
                    var match = _todosSemaforosAcervo.where(
                      (s) => s['id'].toString() == v['semaforo_id'].toString(),
                    );
                    coordOriginal = match.isNotEmpty
                        ? (match.first['georeferencia']?.toString() ?? '-')
                        : '-';
                  }
                  String gpsVistoriador =
                      v['gps_coordenadas']?.toString() ?? '-';
                  List<dynamic> fotos = v['fotos'] ?? [];

                  return [
                    v['semaforo_id']?.toString() ?? '',
                    v['isNaoVistoriado'] == true ? '-' : nomeVistoriador,
                    v['semaforo_endereco']?.toString() ?? '',
                    // ==== MODIFICADO: Célula customizada com duas cores e alinhamento no meio ====
                    pw.Container(
                      alignment: pw.Alignment.center, // Centraliza na célula
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'Semáforo: $coordOriginal',
                            style: pw.TextStyle(
                              color: PdfColors.green,
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Vistoria: $gpsVistoriador',
                            style: pw.TextStyle(
                              color: PdfColors.red,
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    v['data_hora_inicio']?.toString() ?? '',
                    v['data_hora_fim']?.toString() ?? '',
                    status,
                    v['falha_registrada'] ?? '-',
                    v['detalhes_ocorrencia']?.toString().replaceAll(
                          '\n',
                          ' ',
                        ) ??
                        '-',
                    fotos.join('\n\n'),
                  ];
                }).toList(),
                cellAlignment: pw
                    .Alignment
                    .center, // Garante que textos padrões fiquem no meio/centro
                headerAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 7,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.teal700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 6.5),
                columnWidths: {
                  0: pw.FixedColumnWidth(colLarguraSemaforo),
                  1: pw.FixedColumnWidth(colLarguraVistoriador),
                  2: pw.FixedColumnWidth(colLarguraEndereco),
                  3: pw.FixedColumnWidth(colLarguraGeoreferencia),
                  4: pw.FixedColumnWidth(colLarguraInicio),
                  5: pw.FixedColumnWidth(colLarguraFim),
                  6: pw.FixedColumnWidth(colLarguraStatus),
                  7: pw.FixedColumnWidth(colLarguraFalha),
                  8: pw.FixedColumnWidth(colLarguraDetalhes),
                  9: pw.FixedColumnWidth(colLarguraFotos),
                },
              ),
            ];
          },
        ),
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Relatorio_Rota$rotaNumero.pdf',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao gerar PDF!'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // ==== BLOCO 2: MODAL DOS DADOS DO ACERVO ====
  void _mostrarAcervoSemaforo(Map<String, dynamic> semaforo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dados do Acervo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(thickness: 2),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _ordemCamposExibicao.length,
                      itemBuilder: (context, index) {
                        String chaveOriginal = _ordemCamposExibicao[index];
                        String valor = _obterValorCampo(
                          semaforo,
                          chaveOriginal,
                        ).trim();

                        if (valor.isEmpty) valor = "-";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.indigo.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chaveOriginal.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                valor,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: valor == "-"
                                      ? Colors.grey
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ====================================================================
  void _abrirVistoriaSemaforo(Map<String, dynamic> semaforo, String turnoId) {
    if (!_isVistoriador) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aviso: Seu perfil permite apenas a visualização das rotas.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool vistoriaIniciada = false;
    bool salvando = false;
    String dataHoraInicio = '';
    String coordenadas = '';
    bool checklistConfirmado = false;

    String temAnormalidade = 'Não';
    String? falhaSelecionada;
    List<Map<String, dynamic>> tiposDeFalhaLista = [];

    List<Uint8List> fotosEmMemoria = [];
    bool processandoFoto = false;
    final ImagePicker picker = ImagePicker();
    final TextEditingController detalhesController = TextEditingController();

    String geoRefSemaforo = (semaforo['georeferencia'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> carregarFalhas() async {
              if (tiposDeFalhaLista.isEmpty) {
                var snapshot = await FirebaseFirestore.instance
                    .collection('tipos_falha')
                    .orderBy('falha')
                    .get();
                setModalState(() {
                  tiposDeFalhaLista = snapshot.docs
                      .map((doc) => {'id': doc.id, 'falha': doc['falha']})
                      .toList();
                });
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.shade800,
                          child: Text(
                            semaforo['id'].toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vistoria do Semáforo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                semaforo['endereco'] ?? 'Sem endereço',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!vistoriaIniciada) ...[
                            const Text(
                              'Opções para este semáforo:',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.directions, size: 28),
                                label: const Text(
                                  'COMO CHEGAR (GPS)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  _mostrarOpcoesGPS(geoRefSemaforo);
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Row(
                              children: [
                                Expanded(child: Divider(thickness: 1)),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    "OU",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(thickness: 1)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 65,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: salvando
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.play_arrow, size: 30),
                                label: Text(
                                  salvando
                                      ? 'Obtendo GPS...'
                                      : 'INICIAR VISTORIA NESTE LOCAL',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: salvando
                                    ? null
                                    : () async {
                                        setModalState(() => salvando = true);
                                        try {
                                          Position pos =
                                              await _determinarPosicao();
                                          String dataFormatada = DateFormat(
                                            'dd/MM/yyyy HH:mm:ss',
                                          ).format(DateTime.now());
                                          setModalState(() {
                                            coordenadas =
                                                '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
                                            dataHoraInicio = dataFormatada;
                                            vistoriaIniciada = true;
                                            salvando = false;
                                          });
                                        } catch (e) {
                                          setModalState(() => salvando = false);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                              ),
                            ),
                          ],

                          if (vistoriaIniciada) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Iniciado em: $dataHoraInicio',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.gps_fixed, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'GPS: $coordenadas',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.indigo,
                                  side: const BorderSide(color: Colors.indigo),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.library_books),
                                label: const Text(
                                  'VER DADOS DO ACERVO',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  _mostrarAcervoSemaforo(semaforo);
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            const Text(
                              'CHECKLIST DE VERIFICAÇÃO',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            const Divider(thickness: 2),

                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: Colors.indigo,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                textoConfirmacaoChecklist,
                                style: const TextStyle(fontSize: 14),
                              ),
                              value: checklistConfirmado,
                              onChanged: (bool? value) => setModalState(
                                () => checklistConfirmado = value ?? false,
                              ),
                            ),

                            const SizedBox(height: 24),

                            const Text(
                              'ANORMALIDADES E REGISTRO',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const Divider(thickness: 2),
                            const Text(
                              'Foi encontrada alguma anormalidade neste semáforo?',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),

                            InputDecorator(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: temAnormalidade,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Não',
                                      child: Text(
                                        'Não, está tudo OK',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Sim',
                                      child: Text(
                                        'Sim, há problemas',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setModalState(() {
                                      temAnormalidade = val!;
                                      if (val == 'Não') {
                                        falhaSelecionada = null;
                                        fotosEmMemoria.clear();
                                        detalhesController.clear();
                                      } else {
                                        carregarFalhas();
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),

                            if (temAnormalidade == 'Sim') ...[
                              const SizedBox(height: 12),
                              if (tiposDeFalhaLista.isEmpty)
                                const Center(child: CircularProgressIndicator())
                              else
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Selecione a Falha Encontrada',
                                    border: OutlineInputBorder(),
                                  ),
                                  value: falhaSelecionada,
                                  items: tiposDeFalhaLista
                                      .map(
                                        (f) => DropdownMenuItem<String>(
                                          value: f['falha'],
                                          child: Text(
                                            f['falha'],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) => setModalState(
                                    () => falhaSelecionada = val,
                                  ),
                                ),

                              const SizedBox(height: 16),
                              TextField(
                                controller: detalhesController,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Detalhes da Ocorrência',
                                  hintText: 'Descreva a anormalidade...',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                              ),

                              const SizedBox(height: 24),
                              const Text(
                                'FOTOS DO PROBLEMA (Obrigatório, Máx. 4)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (processandoFoto)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Gravando GPS e Data na foto...',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  ...List.generate(fotosEmMemoria.length, (
                                    index,
                                  ) {
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _mostrarImagemExpandida(
                                            context,
                                            MemoryImage(fotosEmMemoria[index]),
                                          ),
                                          child: Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              image: DecorationImage(
                                                image: MemoryImage(
                                                  fotosEmMemoria[index],
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            child: const Align(
                                              alignment: Alignment.bottomLeft,
                                              child: Padding(
                                                padding: EdgeInsets.all(4.0),
                                                child: Icon(
                                                  Icons.zoom_in,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: -8,
                                          top: -8,
                                          child: GestureDetector(
                                            onTap: () => setModalState(
                                              () => fotosEmMemoria.removeAt(
                                                index,
                                              ),
                                            ),
                                            child: const CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.red,
                                              child: Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                  if (fotosEmMemoria.length < 4 &&
                                      !processandoFoto)
                                    InkWell(
                                      onTap: () async {
                                        final XFile? fotoTirada = await picker
                                            .pickImage(
                                              source: ImageSource.camera,
                                              maxWidth: 1000,
                                              imageQuality: 80,
                                            );
                                        if (fotoTirada != null) {
                                          setModalState(
                                            () => processandoFoto = true,
                                          );
                                          Uint8List fotoEmBytes =
                                              await fotoTirada.readAsBytes();
                                          Uint8List fotoCarimbada =
                                              await _carimbarFoto(
                                                fotoEmBytes,
                                                semaforo['id'].toString(),
                                                dataHoraInicio,
                                                coordenadas,
                                              );
                                          setModalState(() {
                                            fotosEmMemoria.add(fotoCarimbada);
                                            processandoFoto = false;
                                          });
                                        }
                                      },
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade400,
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.camera_alt,
                                              color: Colors.grey,
                                              size: 32,
                                            ),
                                            Text(
                                              'Tirar Foto',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],

                            if (temAnormalidade == 'Não') ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  border: Border.all(color: Colors.green),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 36,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Você confirma que o semáforo foi vistoriado por completo e NÃO apresenta defeitos?',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),

                            // ==== SOLUÇÃO AQUI: SafeArea envelopando o botão final ====
                            SafeArea(
                              bottom: true,
                              child: SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: (salvando || processandoFoto)
                                      ? null
                                      : () async {
                                          if (!checklistConfirmado) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Você precisa marcar a caixa confirmando a verificação do checklist!',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }
                                          String detalhesFinais =
                                              detalhesController.text
                                                  .trim()
                                                  .toUpperCase();
                                          if (temAnormalidade == 'Sim') {
                                            if (falhaSelecionada == null) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Selecione qual foi a falha encontrada!',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }
                                            if (fotosEmMemoria.isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'É obrigatório tirar pelo menos 1 foto do defeito!',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }
                                          } else {
                                            detalhesFinais =
                                                'O SEMÁFORO FOI VISTORIADO POR COMPLETO E NÃO FORAM IDENTIFICADAS ANORMALIDADES.';
                                          }

                                          setModalState(() => salvando = true);

                                          try {
                                            List<String> urlsDasFotos = [];
                                            if (fotosEmMemoria.isNotEmpty) {
                                              for (
                                                int i = 0;
                                                i < fotosEmMemoria.length;
                                                i++
                                              ) {
                                                String nomeArquivo =
                                                    'vistoria_${semaforo['id']}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                                                Reference ref = FirebaseStorage
                                                    .instance
                                                    .ref()
                                                    .child(
                                                      'vistorias_fotos/$nomeArquivo',
                                                    );
                                                UploadTask uploadTask = ref
                                                    .putData(
                                                      fotosEmMemoria[i],
                                                      SettableMetadata(
                                                        contentType:
                                                            'image/jpeg',
                                                      ),
                                                    );
                                                TaskSnapshot snapshotDaFoto =
                                                    await uploadTask;
                                                urlsDasFotos.add(
                                                  await snapshotDaFoto.ref
                                                      .getDownloadURL(),
                                                );
                                              }
                                            }

                                            String dataFormatadaFim =
                                                DateFormat(
                                                  'dd/MM/yyyy HH:mm:ss',
                                                ).format(DateTime.now());

                                            await FirebaseFirestore.instance
                                                .collection('vistorias')
                                                .add({
                                                  'turno_id': turnoId,
                                                  'vistoriador_uid': user!.uid,
                                                  'semaforo_id': semaforo['id'],
                                                  'semaforo_endereco':
                                                      semaforo['endereco'],
                                                  'data_hora_inicio':
                                                      dataHoraInicio,
                                                  'data_hora_fim':
                                                      dataFormatadaFim,
                                                  'gps_coordenadas':
                                                      coordenadas,
                                                  'coordenadas_cadastro':
                                                      geoRefSemaforo,
                                                  'resumo_checklist':
                                                      textoConfirmacaoChecklist,
                                                  'teve_anormalidade':
                                                      temAnormalidade == 'Sim',
                                                  'falha_registrada':
                                                      falhaSelecionada ??
                                                      'NENHUMA FALHA',
                                                  'detalhes_ocorrencia':
                                                      detalhesFinais,
                                                  'fotos': urlsDasFotos,
                                                  'criado_em':
                                                      FieldValue.serverTimestamp(),
                                                });

                                            if (temAnormalidade == 'Sim') {
                                              await _enviarOcorrencia(
                                                semaforo,
                                                falhaSelecionada!,
                                                detalhesFinais,
                                                fotosEmMemoria,
                                                coordenadas,
                                              );
                                            }

                                            if (!mounted) return;
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Vistoria salva com sucesso!',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } catch (e) {
                                            setModalState(
                                              () => salvando = false,
                                            );
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Erro ao salvar vistoria! Verifique a conexão.',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                  child: salvando
                                      ? const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Enviando dados...',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'SALVAR E CONCLUIR VISTORIA',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ========================================================================
  // EXPORTAÇÃO PARA EXCEL (.CSV) ESTRUTURADO COM VISTORIADOS E NÃO VISTORIADOS
  // ========================================================================
  Future<void> _exportarExcelConcluidos(
    List<QueryDocumentSnapshot> vistorias,
    String rotaNumero,
    String nomeVistoriador,
  ) async {
    if (_todosSemaforosAcervo.isEmpty) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gerando Planilha Excel Geral...'),
          backgroundColor: Colors.green,
        ),
      );
      String rotaTurnoLimpa = rotaNumero.replaceFirst(RegExp(r'^0+'), '');

      List<Map<String, dynamic>> semaforosDaRota = _todosSemaforosAcervo.where((
        item,
      ) {
        String rotaItem = (item['rota'] ?? '').toString().trim().replaceFirst(
          RegExp(r'^0+'),
          '',
        );
        return rotaItem == rotaTurnoLimpa;
      }).toList();

      Map<String, Map<String, dynamic>> vistoriasMap = {};
      for (var doc in vistorias) {
        var v = doc.data() as Map<String, dynamic>;
        String idSem = v['semaforo_id']?.toString() ?? '';
        if (idSem.isNotEmpty) vistoriasMap[idSem] = v;
      }

      List<Map<String, dynamic>> listaVistoriados = [];
      List<Map<String, dynamic>> listaNaoVistoriados = [];

      for (var semaforoMestre in semaforosDaRota) {
        String idSem = semaforoMestre['id']?.toString() ?? '';
        if (vistoriasMap.containsKey(idSem)) {
          listaVistoriados.add(vistoriasMap[idSem]!);
        } else {
          listaNaoVistoriados.add({
            'semaforo_id': idSem,
            'semaforo_endereco': semaforoMestre['endereco'] ?? 'Sem endereço',
            'data_hora_inicio': '-',
            'data_hora_fim': '-',
            'gps_coordenadas': '-',
            'teve_anormalidade': null,
            'falha_registrada': '-',
            'detalhes_ocorrencia': '-',
            'fotos': [],
            'isNaoVistoriado': true,
            'criado_em': null,
          });
        }
      }

      // Ordenação cronológica das vistorias realizadas
      listaVistoriados.sort((a, b) {
        Timestamp? tA =
            a['criated_em']
                as Timestamp?; // Nota: se a chave for criado_em, altere aqui
        Timestamp? tB = b['criated_em'] as Timestamp?;
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tA.compareTo(tB);
      });

      listaNaoVistoriados.sort((a, b) {
        int numA =
            int.tryParse(
              a['semaforo_id'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            9999;
        int numB =
            int.tryParse(
              b['semaforo_id'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            9999;
        return numA.compareTo(numB);
      });

      List<Map<String, dynamic>> listaFinalRelatorio = [
        ...listaVistoriados,
        ...listaNaoVistoriados,
      ];

      // ==== MODIFICADO: Agora gera uma Tabela HTML oficial que aceita cores no Excel ====
      StringBuffer excelBuffer = StringBuffer();
      excelBuffer.write(
        '<!DOCTYPE html><html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40"><head><meta charset="utf-8"></head><body><table border="1">',
      );

      // Cabeçalho
      excelBuffer.write(
        '<tr style="background-color: #00796B; color: white; font-weight: bold; text-align: center;">'
        '<td>SEMÁFORO</td><td>VISTORIADOR</td><td>ENDEREÇO</td><td>GEORREFERÊNCIA</td><td>INÍCIO</td><td>FIM</td><td>STATUS</td><td>FALHA</td><td>DETALHES</td><td>FOTOS</td></tr>',
      );

      for (var v in listaFinalRelatorio) {
        String status = 'OK';
        String corStatus = 'green';

        if (v['isNaoVistoriado'] == true) {
          status = 'NÃO VISTORIADO';
          corStatus = 'orange';
        } else if (v['teve_anormalidade'] == true) {
          status = 'COM FALHA';
          corStatus = 'red';
        }

        String coordOriginal = v['coordenadas_cadastro']?.toString() ?? '';
        if (coordOriginal.isEmpty) {
          var match = _todosSemaforosAcervo.where(
            (s) => s['id'].toString() == v['semaforo_id'].toString(),
          );
          coordOriginal = match.isNotEmpty
              ? (match.first['georeferencia']?.toString() ?? '-')
              : '-';
        }
        String gpsVistoriador = v['gps_coordenadas']?.toString() ?? '-';
        List<dynamic> fotos = v['fotos'] ?? [];

        // Cada linha aplica centralização horizontal (text-align) e vertical (vertical-align) nas células
        excelBuffer.write('<tr>');
        excelBuffer.write(
          '<td style="text-align: center; vertical-align: middle;">${v['semaforo_id']}</td>',
        );
        excelBuffer.write(
          '<td style="text-align: center; vertical-align: middle;">${v['isNaoVistoriado'] == true ? "-" : nomeVistoriador}</td>',
        );
        excelBuffer.write(
          '<td style="text-align: center; vertical-align: middle;">${v['semaforo_endereco']}</td>',
        );

        // ==== MODIFICADO: Coluna de georreferência com duas cores e quebra de linha ====
        excelBuffer.write(
          '<td style="text-align: center; vertical-align: middle; white-space: nowrap;">'
          '<span style="color: green; font-weight: bold;">Semáforo: $coordOriginal</span><br/>'
          '<span style="color: red; font-weight: bold;">Vistoria: $gpsVistoriador</span></td>',
        );

        excelBuffer.write(
          '<td style="text-align: center; vertical-align: middle;">${v['data_hora_inicio']}</td>',
        );
        excelBuffer.write(
          '<td style="text-align: center; vertical-align: middle;">${v['data_hora_fim']}</td>',
        );
        excelBuffer.write(
          '<td style="text-align: center; vertical-align: middle; color: $corStatus; font-weight: bold;">$status</td>',
        );
        excelBuffer.write(
          '<td style="text-align: center; vertical-align: middle;">${v['falha_registrada'] ?? '-'}</td>',
        );
        excelBuffer.write(
          '<td style="text-align: center; vertical-align: middle;">${v['detalhes_ocorrencia']?.toString().replaceAll('\n', ' ')}</td>',
        );

        if (fotos.isNotEmpty) {
          String linksHtml = fotos
              .map((f) => '<a href="$f">Abrir Foto</a>')
              .join(' | ');
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">$linksHtml</td>',
          );
        } else {
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">-</td>',
          );
        }
        excelBuffer.write('</tr>');
      }

      excelBuffer.write('</table></body></html>');

      final String nomePlanilha = 'Relatorio_Geral_Rota$rotaNumero.xls';
      final bytes = utf8.encode(excelBuffer.toString());
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'application/vnd.ms-excel',
        name: nomePlanilha,
      );

      await Share.shareXFiles([
        xFile,
      ], text: 'Planilha de Monitoramento Rota $rotaNumero');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao gerar Excel!'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }
  // ========================================================================
  // FINAL DO CÓDIGO DE EXPORTAÇÃO PARA EXCEL (.CSV) ESTRUTURADO COM VISTORIADOS E NÃO VISTORIADOS
  // ========================================================================

  void _mostrarDetalhesVistoria(
    Map<String, dynamic> vistoria,
    String rotaDaAba,
    String nomeVistoriador,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool temFalha = vistoria['teve_anormalidade'] == true;
        List<dynamic> fotos = vistoria['fotos'] ?? [];

        String coordOriginal =
            vistoria['coordenadas_cadastro']?.toString() ?? '';
        if (coordOriginal.isEmpty) {
          var matches = _todosSemaforosAcervo.where(
            (s) => s['id'].toString() == vistoria['semaforo_id'].toString(),
          );
          coordOriginal = matches.isNotEmpty
              ? (matches.first['georeferencia']?.toString() ?? 'Não informada')
              : 'Não informada';
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          temFalha
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle,
                          color: temFalha ? Colors.red : Colors.green,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Semáforo Nº ${vistoria['semaforo_id']}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(thickness: 2, height: 32),

                    _buildInfoRow('Vistoriador', nomeVistoriador),
                    _buildInfoRow('Endereço', vistoria['semaforo_endereco']),
                    _buildInfoRow(
                      'Início da vistoria',
                      vistoria['data_hora_inicio'],
                    ),
                    _buildInfoRow('Fim da vistoria', vistoria['data_hora_fim']),
                    _buildInfoRow('Coordenadas do Semáforo', coordOriginal),
                    _buildInfoRow(
                      'Coordenadas da Vistoria',
                      vistoria['gps_coordenadas'],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.playlist_add_check,
                            color: Colors.blue,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              vistoria['resumo_checklist'] ??
                                  'Checklist não registrado.',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: temFalha
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: temFalha ? Colors.red : Colors.green,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            temFalha ? 'FALHA REGISTRADA:' : 'STATUS:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: temFalha ? Colors.red : Colors.green,
                            ),
                          ),
                          Text(
                            vistoria['falha_registrada'] ?? 'NENHUMA FALHA',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Detalhes:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: temFalha ? Colors.red : Colors.green,
                            ),
                          ),
                          Text(
                            vistoria['detalhes_ocorrencia'] ?? 'Sem detalhes',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                    if (fotos.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Fotos da Ocorrência:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: fotos
                            .map(
                              (url) => GestureDetector(
                                onTap: () => _mostrarImagemExpandida(
                                  context,
                                  NetworkImage(url),
                                ),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey),
                                    image: DecorationImage(
                                      image: NetworkImage(url),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: const Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.zoom_in,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text(
                          'Exportar PDF Desta Vistoria',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () =>
                            _exportarPDFIndividual(vistoria, nomeVistoriador),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Fechar Ficha',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            TextSpan(text: value ?? '-'),
          ],
        ),
      ),
    );
  }

  Future<void> _encerrarTurno(
    String turnoId,
    String veiculoId,
    String rotaId,
    int falta,
    List<QueryDocumentSnapshot> vistoriasConcluidas,
    String rotaNumero,
    String nomeVistoriador,
  ) async {
    final kmFinalController = TextEditingController();
    bool carregando = false;
    bool confirmouTermo = false;

    bool? sucessoEncerramento = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text(
              'Encerrar Expediente',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (falta > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Atenção! Faltam $falta semáforos para concluir a meta da rota.',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Parabéns! Você concluiu 100% da sua rota hoje.',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Text(
                    'Para liberar a moto e gerar o relatório PDF, informe a quilometragem final:',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kmFinalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'KM Final',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.speed),
                      suffixText: 'km',
                    ),
                  ),

                  const SizedBox(height: 16),

                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.red,
                    title: const Text(
                      'Confirmo que os dados coletados são verdadeiros e concordo em gerar o relatório final do dia.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                    value: confirmouTermo,
                    onChanged: (val) {
                      setStateDialog(() => confirmouTermo = val ?? false);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              if (!carregando)
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: carregando
                    ? null
                    : () async {
                        if (kmFinalController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Digite o KM Final!'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        if (!confirmouTermo) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Você precisa marcar a caixa de confirmação!',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        setStateDialog(() => carregando = true);
                        Navigator.pop(context, true);
                      },
                child: carregando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Encerrar Turno'),
              ),
            ],
          );
        },
      ),
    );

    if (sucessoEncerramento == true) {
      try {
        await FirebaseFirestore.instance
            .collection('turnos')
            .doc(turnoId)
            .update({
              'status': 'finalizado',
              'data_fim': FieldValue.serverTimestamp(),
              'km_final': kmFinalController.text.trim(),
            });
        await FirebaseFirestore.instance
            .collection('veiculos')
            .doc(veiculoId)
            .update({'em_uso': false});

        if (!mounted) return;
        if (_isAdmin) {
          setState(() => _turnoSelecionadoAdmin = null);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno encerrado! Gerando Relatório PDF...'),
            backgroundColor: Colors.green,
          ),
        );
        await _gerarEMostrarPDF(
          vistoriasConcluidas,
          rotaNumero,
          nomeVistoriador,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao encerrar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

Widget _buildVisaoListaAdmin() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monitoramento de Rotas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange.shade400,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Column(
              children: [
                Icon(
                  Icons.dashboard_customize,
                  size: 48,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Panorama de todas as rotas do Acervo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: _carregandoRotas
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('turnos')
                        .where('status', isEqualTo: 'ativo')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return const Center(child: CircularProgressIndicator());

                      Map<String, DocumentSnapshot> rotasAtivasMap = {};
                      if (snapshot.hasData) {
                        for (var t in snapshot.data!.docs) {
                          rotasAtivasMap[t['rota_numero'].toString()] = t;
                        }
                      }

                      if (_todasAsRotasAcervo.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 60,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'O Acervo não tem rotas cadastradas.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      // ==== AQUI COMEÇA O NOVO LAYOUT DO CARD ====
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _todasAsRotasAcervo.length,
                        itemBuilder: (context, index) {
                          String rota = _todasAsRotasAcervo[index];
                          bool estaEmUso = rotasAtivasMap.containsKey(rota);
                          
                          var turnoDoc = estaEmUso ? rotasAtivasMap[rota]! : null;
                          var t = estaEmUso ? turnoDoc!.data() as Map<String, dynamic> : null;

                          String horaInicio = (t != null && t['data_inicio'] != null)
                              ? DateFormat('dd/MM/yy - HH:mm').format(
                                  (t['data_inicio'] as Timestamp).toDate(),
                                )
                              : '';

                          String? fotoUrl = t != null
                              ? (t['vistoriador_foto_url'] ??
                                      t['foto_url'] ??
                                      t['vistoriador_foto'])
                                  ?.toString()
                              : null;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            color: estaEmUso ? Colors.white : Colors.green.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: estaEmUso
                                    ? Colors.orange
                                    : Colors.green.shade200,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              // Transforma o card inteiro no botão de "Acompanhar"
                              onTap: estaEmUso
                                  ? () {
                                      setState(() => _turnoSelecionadoAdmin = turnoDoc);
                                    }
                                  : null, 
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 1. FOTO DO VISTORIADOR OU ÍCONE
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: estaEmUso ? Colors.orange.shade100 : Colors.green.shade100,
                                      backgroundImage: (estaEmUso && fotoUrl != null && fotoUrl.isNotEmpty) ? NetworkImage(fotoUrl) : null,
                                      child: (estaEmUso && fotoUrl != null && fotoUrl.isNotEmpty)
                                          ? null // Esconde o texto/ícone se tiver foto
                                          : Text(
                                              estaEmUso ? '' : rota,
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 18),
                                            ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // 2. TEXTOS E PERCENTUAL
                                    Expanded(
                                      child: estaEmUso
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'ROTA $rota EM ANDAMENTO - ${t!['vistoriador_nome']?.toString().toUpperCase() ?? 'DESCONHECIDO'}',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Placa da moto: ${t['placa'] ?? 'S/P'} | Início: $horaInicio',
                                                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                                                ),
                                                const SizedBox(height: 4),
                                                // CÁLCULO DO PERCENTUAL EM TEMPO REAL
                                                StreamBuilder<QuerySnapshot>(
                                                  stream: FirebaseFirestore.instance.collection('vistorias').where('turno_id', isEqualTo: turnoDoc!.id).snapshots(),
                                                  builder: (context, snapVistorias) {
                                                    if (snapVistorias.connectionState == ConnectionState.waiting) {
                                                      return const Text('Percentual de rota concluída: Calculando...', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold));
                                                    }

                                                    String rotaNumerica = rota.replaceAll(RegExp(r'[^0-9]'), '');
                                                    int meta = _todosSemaforosAcervo.where((s) {
                                                      String r = (s['rota'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
                                                      return r == rotaNumerica && r.isNotEmpty;
                                                    }).length;

                                                    if (meta == 0) return Text('Percentual de rota concluída: 0%', style: TextStyle(color: Colors.orange.shade900, fontSize: 13, fontWeight: FontWeight.bold));

                                                    Set<String> vistoriados = snapVistorias.data?.docs.map((d) => (d.data() as Map<String, dynamic>)['semaforo_id'].toString()).toSet() ?? {};
                                                    double perc = (vistoriados.length / meta) * 100;
                                                    if (perc > 100) perc = 100;

                                                    return Text(
                                                      'Percentual de rota concluída: ${perc.toStringAsFixed(0)}%', 
                                                      style: TextStyle(color: Colors.orange.shade900, fontSize: 13, fontWeight: FontWeight.bold)
                                                    );
                                                  }
                                                ),
                                              ],
                                            )
                                          : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('ROTA $rota LIVRE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green.shade700)),
                                                const SizedBox(height: 4),
                                                const Text('Disponível para os vistoriadores.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                              ],
                                            ),
                                    ),
                                    
                                    // 3. SETA OU STATUS FINAL
                                    estaEmUso 
                                      ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
                                      : const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisaoDetalheTurno(DocumentSnapshot turnoDoc) {
    var turnoData = turnoDoc.data() as Map<String, dynamic>;
    String rotaNumero = turnoData['rota_numero'] ?? 'S/N';

    String rotaTurnoNumerica = rotaNumero.replaceAll(RegExp(r'[^0-9]'), '');
    String nomeDoVistoriadorDesteTurno =
        turnoData['vistoriador_nome'] ?? 'Desconhecido';

    return Scaffold(
      appBar: AppBar(
        leading: _isAdmin
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _turnoSelecionadoAdmin = null),
              )
            : null,
        title: Text(
          _isAdmin ? 'Vistoriando Rota $rotaNumero' : 'Vistoria em Campo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange.shade300,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.orange.shade900,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Em Andamento'),
            Tab(icon: Icon(Icons.checklist), text: 'Concluídos'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vistorias')
            .where('turno_id', isEqualTo: turnoDoc.id)
            .snapshots(),
        builder: (context, snapshotVistoria) {
          if (!snapshotVistoria.hasData)
            return const Center(child: CircularProgressIndicator());

          List<QueryDocumentSnapshot> vistoriasConcluidas =
              snapshotVistoria.data!.docs;
          Set<String> vistoriadosIds = vistoriasConcluidas
              .map((doc) => doc['semaforo_id'].toString())
              .toSet();

          List<Map<String, dynamic>> semaforosDaRota = _todosSemaforosAcervo
              .where((item) {
                String rotaDoItemNumerica = (item['rota'] ?? '')
                    .toString()
                    .replaceAll(RegExp(r'[^0-9]'), '');
                return rotaDoItemNumerica == rotaTurnoNumerica &&
                    rotaTurnoNumerica.isNotEmpty;
              })
              .toList();

          int meta = semaforosDaRota.length;
          int concluidos = semaforosDaRota
              .where((item) => vistoriadosIds.contains(item['id'].toString()))
              .length;
          int falta = meta - concluidos;
          double percentual = meta == 0 ? 0.0 : (concluidos / meta);

          List<Map<String, dynamic>> semaforosPendentes = semaforosDaRota.where(
            (item) {
              String id = item['id'].toString();
              return !vistoriadosIds.contains(id);
            },
          ).toList();

          var semaforosFiltradosPesquisa = semaforosPendentes.where((data) {
            if (_textoPesquisaAndamento.isEmpty) return true;
            String id = (data['id'] ?? '').toString().toLowerCase();
            String end = (data['endereco'] ?? '').toString().toLowerCase();
            return id.contains(_textoPesquisaAndamento) ||
                end.contains(_textoPesquisaAndamento);
          }).toList();

          semaforosFiltradosPesquisa.sort((a, b) {
            int ordemA = int.tryParse((a['ordem'] ?? '').toString()) ?? 9999;
            int ordemB = int.tryParse((b['ordem'] ?? '').toString()) ?? 9999;
            return ordemA.compareTo(ordemB);
          });

          return TabBarView(
            controller: _tabController,
            children: [
              // ==== ABA 1: EM ANDAMENTO ====
              Column(
                children: [
                  Container(
                    color: Colors.orange.shade50,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rota $rotaNumero',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                                const Text(
                                  'Progresso da Rota',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.stop_circle, size: 18),
                              label: const Text(
                                'Encerrar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _encerrarTurno(
                                turnoDoc.id,
                                turnoData['veiculo_id'] ?? '',
                                turnoData['rota_id'] ?? '',
                                falta,
                                vistoriasConcluidas,
                                rotaNumero,
                                nomeDoVistoriadorDesteTurno,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _isAdmin ? Icons.person : Icons.motorcycle,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isAdmin
                                  ? 'Vistoriador: $nomeDoVistoriadorDesteTurno'
                                  : 'Moto: ${turnoData['placa'] ?? ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progresso: $concluidos de $meta',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                            Text(
                              'Faltam: $falta',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: percentual,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade300,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(percentual * 100).toStringAsFixed(1)}% Concluído',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: Colors.white,
                    child: TextField(
                      controller: _pesquisaAndamentoController,
                      decoration: InputDecoration(
                        hintText: 'Pesquisar nº ou endereço...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _textoPesquisaAndamento.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    _pesquisaAndamentoController.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  Expanded(
                    child: semaforosFiltradosPesquisa.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  falta == 0 && meta > 0
                                      ? Icons.emoji_events
                                      : Icons.search_off,
                                  size: 80,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  falta == 0 && meta > 0
                                      ? '🎉 Rota Finalizada!'
                                      : 'Nenhum semáforo encontrado nesta rota.',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: semaforosFiltradosPesquisa.length,
                            itemBuilder: (context, index) {
                              var semaforo = semaforosFiltradosPesquisa[index];
                              String idSemaforo =
                                  semaforo['id']?.toString() ?? 'S/N';
                              String enderecoSemaforo =
                                  semaforo['endereco'] ??
                                  'Sem endereço cadastrado';
                              String rotaRaw =
                                  semaforo['rota']?.toString() ?? rotaNumero;

                              Color corDaRota = _obterCorDaRota(rotaRaw);
                              String bairro =
                                  semaforo['bairro']?.toString() ?? '';

                              String titulo = bairro.isNotEmpty
                                  ? "$idSemaforo - $enderecoSemaforo ($bairro)"
                                  : "$idSemaforo - $enderecoSemaforo";

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _abrirVistoriaSemaforo(
                                    semaforo,
                                    turnoDoc.id,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: corDaRota,
                                          radius: 24,
                                          child: Text(
                                            idSemaforo,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            titulo,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),

              // ==== ABA 2: CONCLUÍDOS ====
              Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Baixar PDF de Hoje'),
                          onPressed: () => _gerarEMostrarPDF(
                            vistoriasConcluidas,
                            rotaNumero,
                            nomeDoVistoriadorDesteTurno,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.grid_on),
                          label: const Text('Exportar Excel'),
                          onPressed: () => _exportarExcelConcluidos(
                            vistoriasConcluidas,
                            rotaNumero,
                            nomeDoVistoriadorDesteTurno,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.white,
                    child: TextField(
                      controller: _pesquisaConcluidosController,
                      decoration: InputDecoration(
                        hintText: 'Pesquisar na lista...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _textoPesquisaConcluidos.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    _pesquisaConcluidosController.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  Expanded(
                    child: vistoriasConcluidas.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhuma vistoria finalizada ainda.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              // ==== ORDENAÇÃO: DO MAIS RECENTE PARA O MAIS ANTIGO ====
                              List<QueryDocumentSnapshot> vistoriasOrdenadas =
                                  List.from(vistoriasConcluidas);
                              vistoriasOrdenadas.sort((a, b) {
                                Timestamp? tA =
                                    (a.data()
                                            as Map<
                                              String,
                                              dynamic
                                            >)['criado_em']
                                        as Timestamp?;
                                Timestamp? tB =
                                    (b.data()
                                            as Map<
                                              String,
                                              dynamic
                                            >)['criado_em']
                                        as Timestamp?;
                                if (tA == null && tB == null) return 0;
                                if (tA == null) return 1;
                                if (tB == null) return -1;
                                return tB.compareTo(
                                  tA,
                                ); // B comparado com A = Decrescente
                              });

                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: vistoriasOrdenadas.length,
                                itemBuilder: (context, index) {
                                  var vistoria =
                                      vistoriasOrdenadas[index].data()
                                          as Map<String, dynamic>;
                                  String idSemaforo =
                                      vistoria['semaforo_id']?.toString() ?? '';
                                  String endSemaforo =
                                      vistoria['semaforo_endereco']
                                          ?.toString() ??
                                      '';

                                  if (_textoPesquisaConcluidos.isNotEmpty &&
                                      !idSemaforo.toLowerCase().contains(
                                        _textoPesquisaConcluidos,
                                      ) &&
                                      !endSemaforo.toLowerCase().contains(
                                        _textoPesquisaConcluidos,
                                      ))
                                    return const SizedBox.shrink();

                                  bool temFalha =
                                      vistoria['teve_anormalidade'] == true;
                                  Color corFundo = temFalha
                                      ? Colors.red.shade50
                                      : Colors.grey.shade200;
                                  Color corIcone = temFalha
                                      ? Colors.red.shade700
                                      : Colors.grey.shade600;

                                  return Card(
                                    color: corFundo,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: corIcone,
                                        child: Text(
                                          idSemaforo,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      // ==== NOVO LAYOUT DO CARD (Nº - Endereço) e (INÍCIO - FIM) ====
                                      title: Text(
                                        '$idSemaforo - $endSemaforo',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: corIcone,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
                                        child: Text(
                                          'INÍCIO: ${vistoria['data_hora_inicio'] ?? '-'} - FIM: ${vistoria['data_hora_fim'] ?? '-'}',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),

                                      trailing: Icon(
                                        temFalha
                                            ? Icons.warning_amber_rounded
                                            : Icons.check_circle,
                                        color: corIcone,
                                      ),
                                      onTap: () => _mostrarDetalhesVistoria(
                                        vistoria,
                                        rotaNumero,
                                        nomeDoVistoriadorDesteTurno,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoPerfil || _carregandoRotas)
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );

    // Se for admin e não escolheu rota, mostra a lista de rotas ativas
    if (_isAdmin && _turnoSelecionadoAdmin == null) {
      return _buildVisaoListaAdmin();
    }

    // Se for admin e escolheu uma rota, mostra os detalhes dela
    if (_isAdmin && _turnoSelecionadoAdmin != null) {
      return _buildVisaoDetalheTurno(_turnoSelecionadoAdmin!);
    }

    // Se for Vistoriador, puxa o turno ativo dele
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('turnos')
          .where('vistoriador_uid', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'ativo')
          .limit(1)
          .snapshots(),
      builder: (context, snapshotTurno) {
        if (snapshotTurno.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          );
        }

        if (!snapshotTurno.hasData || snapshotTurno.data!.docs.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Vistoria em Campo'),
              backgroundColor: Colors.orange.shade300,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 80, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum turno ativo.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar ao Início'),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildVisaoDetalheTurno(snapshotTurno.data!.docs.first);
      },
    );
  }
}
