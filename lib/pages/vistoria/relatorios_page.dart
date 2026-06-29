import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  DateTime? _deConsulta;
  DateTime? _ateConsulta;
  String _rotaConsulta = 'Todas';
  final TextEditingController _semaforoController = TextEditingController();
  bool _filtrosAplicadosConsulta = false;

  DateTime? _deExport;
  DateTime? _ateExport;
  String _rotaExport = 'Todas';

  DateTime _mesPendencia = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  String _rotaPendencia = 'Todas';

  final Map<String, String> _cacheNomes = {};

  String up(dynamic val) => (val?.toString() ?? '-').toUpperCase();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    DateTime agora = DateTime.now();
    _deConsulta = DateTime(agora.year, agora.month, 1);
    _ateConsulta = DateTime(agora.year, agora.month + 1, 0, 23, 59, 59);
    _deExport = DateTime(agora.year, agora.month, 1);
    _ateExport = DateTime(agora.year, agora.month + 1, 0, 23, 59, 59);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _semaforoController.dispose();
    super.dispose();
  }

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
        final List<Color> cores = [
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
        return cores[r.hashCode.abs() % cores.length];
    }
  }

  Future<String> _getNomeVistoriador(String uid) async {
    if (_cacheNomes.containsKey(uid)) return _cacheNomes[uid]!;
    try {
      var doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        String nome =
            doc.data()!['nome'] ??
            doc.data()!['nome_completo'] ??
            'Vistoriador';
        _cacheNomes[uid] = nome;
        return nome;
      }
    } catch (e) {
      /* Error */
    }
    return 'DESCONHECIDO';
  }

  Future<void> _selecionarData(
    BuildContext context, {
    bool isDe = true,
    required String tipoAba,
  }) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: isDe ? 'SELECIONE A DATA INICIAL' : 'SELECIONE A DATA FINAL',
    );
    if (picked != null) {
      setState(() {
        if (tipoAba == 'Consulta') {
          if (isDe)
            _deConsulta = DateTime(
              picked.year,
              picked.month,
              picked.day,
              0,
              0,
              0,
            );
          else
            _ateConsulta = DateTime(
              picked.year,
              picked.month,
              picked.day,
              23,
              59,
              59,
            );
          _filtrosAplicadosConsulta = false;
        }
      });
    }
  }

  Future<void> _selecionarMesAnoDialog(BuildContext context) async {
    int mesSel = _mesPendencia.month;
    int anoSel = _mesPendencia.year;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'SELECIONE O MÊS E ANO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  DropdownButton<int>(
                    value: mesSel,
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text((index + 1).toString().padLeft(2, '0')),
                      ),
                    ),
                    onChanged: (val) => setStateDialog(() => mesSel = val!),
                  ),
                  const Text('/', style: TextStyle(fontSize: 20)),
                  DropdownButton<int>(
                    value: anoSel,
                    items: List.generate(
                      10,
                      (index) => DropdownMenuItem(
                        value: 2024 + index,
                        child: Text((2024 + index).toString()),
                      ),
                    ),
                    onChanged: (val) => setStateDialog(() => anoSel = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _mesPendencia = DateTime(anoSel, mesSel, 1);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('CONFIRMAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _limparFiltrosConsulta() {
    setState(() {
      DateTime agora = DateTime.now();
      _deConsulta = DateTime(agora.year, agora.month, 1);
      _ateConsulta = DateTime(agora.year, agora.month + 1, 0, 23, 59, 59);
      _rotaConsulta = 'Todas';
      _semaforoController.clear();
      _filtrosAplicadosConsulta = false;
    });
  }

  Widget _buildBotaoData(
    String label,
    DateTime? data,
    VoidCallback onTap, {
    String formato = 'dd/MM/yy',
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data == null
                      ? '$label: SELECIONE'.toUpperCase()
                      : '$label: ${DateFormat(formato).format(data)}'
                            .toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: data == null ? Colors.grey : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirFotoTelaCheia(String url) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black87,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
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
              text: '${label.toUpperCase()}: ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            TextSpan(text: up(value)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildRodapePDF(pw.Context context, String dataHora) {
    return pw.Container(
      alignment: pw.Alignment.bottomCenter,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.SizedBox(width: 50),
              pw.Expanded(
                child: pw.Text(
                  'RELATÓRIO GERADO PELO APLICATIVO VISTORIA CTTU ($dataHora)'
                      .toUpperCase(),
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
                  'PÁG. ${context.pageNumber} / ${context.pagesCount}'
                      .toUpperCase(),
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
    String coordOriginal,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('BAIXANDO FOTOS E GERANDO PDF...'),
        backgroundColor: Colors.teal,
      ),
    );
    try {
      bool temFalha = vistoria['teve_anormalidade'] == true;
      List<dynamic> urlsFotos = vistoria['fotos'] ?? [];
      List<pw.ImageProvider> imagensPdf = [];
      for (String url in urlsFotos) {
        try {
          imagensPdf.add(await networkImage(url));
        } catch (e) {
          debugPrint('Erro foto pdf: $e');
        }
      }

      String gpsVist = up(vistoria['gps_coordenadas']);
      String dHora = DateFormat(
        'dd/MM/yyyy HH:mm:ss',
      ).format(DateTime.now()).toUpperCase();

      await Printing.layoutPdf(
        name: 'FICHA_SEMAFORO_${vistoria['semaforo_id']}.pdf'.toUpperCase(),
        onLayout: (PdfPageFormat format) async {
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
              footer: (pw.Context context) => _buildRodapePDF(context, dHora),
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
                        'SEMÁFORO Nº ${up(vistoria['semaforo_id'])}',
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
                    'VISTORIADOR: ${up(nomeVistoriador)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'ENDEREÇO: ${up(vistoria['semaforo_endereco'])}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'INÍCIO: ${up(vistoria['data_hora_inicio'])} | FIM: ${up(vistoria['data_hora_fim'])}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'LOCAL DO SEMÁFORO (ACERVO): ${up(coordOriginal)}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'LOCAL DA VISTORIA (GPS): $gpsVist',
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
                      up(vistoria['resumo_checklist']),
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
                          up(vistoria['falha_registrada']),
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'DETALHES:',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: temFalha ? PdfColors.red : PdfColors.green,
                          ),
                        ),
                        pw.Text(
                          up(vistoria['detalhes_ocorrencia']),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (imagensPdf.isNotEmpty) ...[
                    pw.SizedBox(height: 24),
                    pw.Text(
                      'FOTOS:',
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
          return pdf.save();
        },
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ERRO AO GERAR PDF INDIVIDUAL!'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  void _mostrarDetalhesVistoriaAnterior(
    Map<String, dynamic> vistoria,
    String rotaExibicao,
    String nomeVistoriador,
    String coordOriginal,
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
        String gpsVistoriador = up(vistoria['gps_coordenadas']);
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
                            'SEMÁFORO Nº ${up(vistoria['semaforo_id'])}',
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
                    _buildInfoRow('VISTORIADOR', nomeVistoriador),
                    _buildInfoRow('ENDEREÇO', vistoria['semaforo_endereco']),
                    _buildInfoRow('INÍCIO', vistoria['data_hora_inicio']),
                    _buildInfoRow('FIM', vistoria['data_hora_fim']),
                    _buildInfoRow('LOCAL DO SEMÁFORO (ACERVO)', coordOriginal),
                    _buildInfoRow('LOCAL DA VISTORIA (GPS)', gpsVistoriador),
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
                              up(vistoria['resumo_checklist']),
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
                            up(vistoria['falha_registrada']),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'DETALHES:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: temFalha ? Colors.red : Colors.green,
                            ),
                          ),
                          Text(
                            up(vistoria['detalhes_ocorrencia']),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    if (fotos.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'FOTOS:',
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
                                onTap: () => _abrirFotoTelaCheia(url),
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
                          'EXPORTAR PDF DESTA VISTORIA',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _exportarPDFIndividual(
                          vistoria,
                          nomeVistoriador,
                          coordOriginal,
                        ),
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
                          'FECHAR FICHA',
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

  // ==== PROCESSA E FILTRA AS VISTORIAS DA ABA CONSULTA ====
  Future<void> _exportarConsulta(
    String tipo,
    Map<String, String> mapaRotas,
    List<Map<String, dynamic>> todosSemaforosData,
  ) async {
    Query query = FirebaseFirestore.instance
        .collection('vistorias')
        .orderBy('criado_em', descending: true);
    if (_deConsulta != null && _ateConsulta != null) {
      query = query.where(
        'criado_em',
        isGreaterThanOrEqualTo: _deConsulta,
        isLessThanOrEqualTo: _ateConsulta,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PREPARANDO EXPORTAÇÃO EM $tipo...'),
        backgroundColor: Colors.blue,
      ),
    );

    try {
      QuerySnapshot snapshot = await query.get();
      List<Map<String, dynamic>> vistoriasFiltradas = [];

      String textoPesquisa = _semaforoController.text.trim().toLowerCase();
      String idFiltro = textoPesquisa.split(' - ')[0].trim();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String idSem = (data['semaforo_id'] ?? '').toString();

        if (idFiltro.isNotEmpty && !idSem.toLowerCase().contains(idFiltro))
          continue;

        String rotaDesteSemaforo = mapaRotas[idSem] ?? '';
        if (_rotaConsulta != 'Todas') {
          String rotaLimpa = _rotaConsulta.replaceFirst(RegExp(r'^0+'), '');
          if (rotaDesteSemaforo != rotaLimpa) continue;
        }

        data['nome_vistoriador'] = await _getNomeVistoriador(
          data['vistoriador_uid'] ?? '',
        );
        vistoriasFiltradas.add(data);
      }

      if (tipo == 'PDF') {
        await _exportarPDFGlobalConsulta(
          vistoriasFiltradas,
          _rotaConsulta,
          todosSemaforosData,
        );
      } else {
        await _exportarExcelGlobalConsulta(
          vistoriasFiltradas,
          _rotaConsulta,
          todosSemaforosData,
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ERRO AO EXPORTAR CONSULTA!'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // ==== GERA O PDF DA ABA CONSULTA ====
  Future<void> _exportarPDFGlobalConsulta(
    List<Map<String, dynamic>> vistorias,
    String rotaNumero,
    List<Map<String, dynamic>> todosSemaforosData,
  ) async {
    String dataHoraAtual = DateFormat(
      'dd/MM/yyyy HH:mm:ss',
    ).format(DateTime.now()).toUpperCase();
    String deStr = _deConsulta != null
        ? DateFormat('dd/MM/yyyy').format(_deConsulta!)
        : '-';
    String ateStr = _ateConsulta != null
        ? DateFormat('dd/MM/yyyy').format(_ateConsulta!)
        : '-';
    String filtroPeriodo = "PERÍODO: $deStr ATÉ $ateStr";

    String filtroSemaforo = _semaforoController.text.trim().isEmpty
        ? "TODOS"
        : _semaforoController.text.trim().toUpperCase();
    String filtroRota = rotaNumero == "Todas"
        ? "TODAS AS ROTAS"
        : "ROTA $rotaNumero";

    await Printing.layoutPdf(
      name: 'RELATORIO_CONSULTA_ROTA$rotaNumero.pdf'.toUpperCase(),
      onLayout: (PdfPageFormat format) async {
        final pdf = pw.Document();
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.only(
              left: 16,
              right: 16,
              top: 24,
              bottom: 20,
            ),
            footer: (pw.Context context) =>
                _buildRodapePDF(context, dataHoraAtual),
            build: (pw.Context context) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RELATÓRIO DE VISTORIAS GERENCIAIS (CONSULTA)',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        '$filtroRota  |  $filtroPeriodo  |  BUSCA: $filtroSemaforo',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey800,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // ==== CORREÇÃO DO BORDER AQUI ====
                vistorias.isEmpty
                    ? pw.Container(
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.all(24),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColors.red700,
                            width: 1,
                          ),
                        ),
                        child: pw.Text(
                          'NENHUMA VISTORIA ENCONTRADA PARA ESTES FILTROS.',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red700,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : pw.TableHelper.fromTextArray(
                        context: context,
                        headers: [
                          'SEMÁFORO',
                          'ENDEREÇO',
                          'VISTORIADOR',
                          'INÍCIO',
                          'FIM',
                          'GEORREFERÊNCIA',
                          'FALHA',
                          'DETALHES',
                          'FOTOS (LINKS)',
                        ],
                        data: vistorias.map((v) {
                          String coordOriginal =
                              v['coordenadas_cadastro']?.toString() ?? '-';
                          if (coordOriginal == '-' || coordOriginal.isEmpty) {
                            var match = todosSemaforosData.where(
                              (s) =>
                                  s['id'].toString() ==
                                  v['semaforo_id'].toString(),
                            );
                            coordOriginal = match.isNotEmpty
                                ? (match.first['georeferencia']?.toString() ??
                                      '-')
                                : '-';
                          }
                          String gpsVistoriador =
                              v['gps_coordenadas']?.toString() ?? '-';
                          List<dynamic> fotos = v['fotos'] ?? [];
                          return [
                            up(v['semaforo_id']),
                            up(v['semaforo_endereco']),
                            up(v['nome_vistoriador']),
                            up(v['data_hora_inicio']),
                            up(v['data_hora_fim']),
                            pw.Container(
                              alignment: pw.Alignment.center,
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'SEMÁFORO: $coordOriginal'.toUpperCase(),
                                    style: pw.TextStyle(
                                      color: PdfColors.green,
                                      fontSize: 6,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    'VISTORIA: $gpsVistoriador'.toUpperCase(),
                                    style: pw.TextStyle(
                                      color: PdfColors.red,
                                      fontSize: 6,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            up(v['falha_registrada']),
                            up(v['detalhes_ocorrencia']).replaceAll('\n', ' '),
                            fotos.join('\n\n'),
                          ];
                        }).toList(),
                        cellAlignment: pw.Alignment.center,
                        headerAlignment: pw.Alignment.center,
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          fontSize: 7.5,
                        ),
                        headerDecoration: const pw.BoxDecoration(
                          color: PdfColors.teal700,
                        ),
                        cellStyle: const pw.TextStyle(fontSize: 6.5),
                        columnWidths: {
                          0: const pw.FixedColumnWidth(45),
                          1: const pw.FixedColumnWidth(110),
                          2: const pw.FixedColumnWidth(65),
                          3: const pw.FixedColumnWidth(45),
                          4: const pw.FixedColumnWidth(45),
                          5: const pw.FixedColumnWidth(95),
                          6: const pw.FixedColumnWidth(70),
                          7: const pw.FixedColumnWidth(100),
                          8: const pw.FixedColumnWidth(100),
                        },
                      ),
              ];
            },
          ),
        );
        return pdf.save();
      },
    );
  }

  // ==== GERA O EXCEL DA ABA CONSULTA ====
  Future<void> _exportarExcelGlobalConsulta(
    List<Map<String, dynamic>> vistorias,
    String rotaNumero,
    List<Map<String, dynamic>> todosSemaforosData,
  ) async {
    try {
      StringBuffer excelBuffer = StringBuffer();
      excelBuffer.write(
        '<!DOCTYPE html><html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40"><head><meta charset="utf-8"></head><body><table border="1">',
      );
      excelBuffer.write(
        '<tr style="background-color: #00796B; color: white; font-weight: bold; text-align: center;"><td>SEMÁFORO</td><td>ENDEREÇO</td><td>VISTORIADOR</td><td>INÍCIO</td><td>FIM</td><td>GEORREFERÊNCIA</td><td>FALHA</td><td>DETALHES</td><td>FOTOS</td></tr>',
      );

      if (vistorias.isEmpty) {
        excelBuffer.write(
          '<tr><td colspan="9" style="text-align: center; color: #FF5722; font-weight: bold; padding: 16px;">NENHUMA VISTORIA ENCONTRADA PARA ESTES FILTROS.</td></tr>',
        );
      } else {
        for (var v in vistorias) {
          String coordOriginal = v['coordenadas_cadastro']?.toString() ?? '';
          if (coordOriginal.isEmpty || coordOriginal == '-') {
            var match = todosSemaforosData.where(
              (s) => s['id'].toString() == v['semaforo_id'].toString(),
            );
            coordOriginal = match.isNotEmpty
                ? (match.first['georeferencia']?.toString() ?? '-')
                : '-';
          }
          String gpsVistoriador = v['gps_coordenadas']?.toString() ?? '-';
          List<dynamic> fotos = v['fotos'] ?? [];

          excelBuffer.write('<tr>');
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['semaforo_id'])}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['semaforo_endereco'])}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['nome_vistoriador'])}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['data_hora_inicio'])}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['data_hora_fim'])}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle; white-space: nowrap;"><span style="color: green; font-weight: bold;">SEMÁFORO: ${coordOriginal.toUpperCase()}</span><br/><span style="color: red; font-weight: bold;">VISTORIA: ${gpsVistoriador.toUpperCase()}</span></td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['falha_registrada'])}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['detalhes_ocorrencia']).replaceAll('\n', ' ')}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${fotos.isNotEmpty ? fotos.map((f) => '<a href="$f">FOTO</a>').join(' | ') : '-'}</td></tr>',
          );
        }
      }
      excelBuffer.write('</table></body></html>');

      final Uint8List bytes = Uint8List.fromList(
        utf8.encode(excelBuffer.toString()),
      );
      final xFile = XFile.fromData(
        bytes,
        mimeType: 'application/vnd.ms-excel',
        name: 'RELATORIO_CONSULTA.XLS',
      );
      await Share.shareXFiles([xFile], text: 'PLANILHA DE VISTORIAS.');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ERRO AO GERAR EXCEL!'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _exportarRotaDoDiaCompleta(
    Map<String, String> mapaRotas,
    List<Map<String, dynamic>> todosSemaforosData,
    DateTime dataEscolhida,
    String rotaEscolhida,
    String formatoExportacao,
  ) async {
    if (todosSemaforosData.isEmpty) return;
    DateTime inicioDia = DateTime(
      dataEscolhida.year,
      dataEscolhida.month,
      dataEscolhida.day,
      0,
      0,
      0,
    );
    DateTime fimDia = DateTime(
      dataEscolhida.year,
      dataEscolhida.month,
      dataEscolhida.day,
      23,
      59,
      59,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('GERANDO RELATÓRIO EM $formatoExportacao...'),
        backgroundColor: Colors.teal,
      ),
    );

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('vistorias')
          .where('criado_em', isGreaterThanOrEqualTo: inicioDia)
          .where('criado_em', isLessThanOrEqualTo: fimDia)
          .get();
      String rotaSelecionadaLimpa = rotaEscolhida.replaceFirst(
        RegExp(r'^0+'),
        '',
      );

      List<Map<String, dynamic>> semaforosDaRotaAcervo = todosSemaforosData
          .where(
            (item) =>
                (item['rota'] ?? '').toString().trim().replaceFirst(
                  RegExp(r'^0+'),
                  '',
                ) ==
                rotaSelecionadaLimpa,
          )
          .toList();
      Map<String, Map<String, dynamic>> vistoriasDoDiaMap = {};
      String nomeDoVistoriadorDoDia = '-';

      for (var doc in snapshot.docs) {
        var v = doc.data() as Map<String, dynamic>;
        String idSem = v['semaforo_id']?.toString() ?? '';
        String uidVist = v['vistoriador_uid'] ?? '';
        if (nomeDoVistoriadorDoDia == '-' && uidVist.isNotEmpty)
          nomeDoVistoriadorDoDia = await _getNomeVistoriador(uidVist);
        if (idSem.isNotEmpty &&
            (mapaRotas[idSem] ?? '') == rotaSelecionadaLimpa)
          vistoriasDoDiaMap[idSem] = v;
      }

      List<Map<String, dynamic>> baseFinalRelatorio = [];
      List<Map<String, dynamic>> naoFeitosNoDia = [];

      for (var semMestre in semaforosDaRotaAcervo) {
        String idSem = semMestre['id']?.toString() ?? '';
        if (vistoriasDoDiaMap.containsKey(idSem)) {
          var v = vistoriasDoDiaMap[idSem]!;
          v['nome_vistoriador'] = nomeDoVistoriadorDoDia;
          baseFinalRelatorio.add(v);
        } else {
          naoFeitosNoDia.add({
            'semaforo_id': idSem,
            'semaforo_endereco': semMestre['endereco'] ?? 'SEM ENDEREÇO',
            'nome_vistoriador': '-',
            'data_hora_inicio': '-',
            'data_hora_fim': '-',
            'gps_coordenadas': '-',
            'teve_anormalidade': null,
            'falha_registrada': '-',
            'detalhes_ocorrencia': 'SEMÁFORO NÃO VISTORIADO',
            'fotos': [],
            'isNaoVistoriado': true,
            'criado_em': null,
          });
        }
      }

      baseFinalRelatorio.sort((a, b) {
        Timestamp? tA = a['criado_em'] as Timestamp?;
        Timestamp? tB = b['criado_em'] as Timestamp?;
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tA.compareTo(tB);
      });

      naoFeitosNoDia.sort(
        (a, b) =>
            (int.tryParse(
                      a['semaforo_id'].toString().replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      ),
                    ) ??
                    9999)
                .compareTo(
                  int.tryParse(
                        b['semaforo_id'].toString().replaceAll(
                          RegExp(r'[^0-9]'),
                          '',
                        ),
                      ) ??
                      9999,
                ),
      );
      baseFinalRelatorio.addAll(naoFeitosNoDia);

      String dFiltroFormatada = DateFormat(
        'dd/MM/yyyy',
      ).format(dataEscolhida).toUpperCase();
      String dHoraAtual = DateFormat(
        'dd/MM/yyyy HH:mm:ss',
      ).format(DateTime.now()).toUpperCase();

      if (formatoExportacao == 'PDF') {
        await Printing.layoutPdf(
          name:
              'ROTA_${rotaEscolhida}_DIA_${dFiltroFormatada.replaceAll('/', '_')}.pdf',
          onLayout: (PdfPageFormat format) async {
            final pdf = pw.Document();
            pdf.addPage(
              pw.MultiPage(
                pageFormat: PdfPageFormat.a4.landscape,
                margin: const pw.EdgeInsets.all(16),
                footer: (pw.Context context) =>
                    _buildRodapePDF(context, dHoraAtual),
                build: (pw.Context context) {
                  return [
                    pw.Header(
                      level: 0,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RELATÓRIO BASE DE ROTA DIÁRIA CONCLUÍDA',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'ROTA SELECIONADA: ROTA $rotaEscolhida  |  DIA: $dFiltroFormatada',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.TableHelper.fromTextArray(
                      context: context,
                      headers: [
                        'SEMÁFORO',
                        'ENDEREÇO',
                        'VISTORIADOR',
                        'INÍCIO',
                        'FIM',
                        'GEORREFERÊNCIA',
                        'FALHA',
                        'DETALHES',
                        'FOTOS',
                      ],
                      data: baseFinalRelatorio.map((v) {
                        String status = v['isNaoVistoriado'] == true
                            ? 'NÃO VISTORIADO'
                            : (v['teve_anormalidade'] == true
                                  ? 'COM FALHA'
                                  : 'OK');
                        String coordOriginal =
                            v['coordenadas_cadastro']?.toString() ?? '';
                        if (coordOriginal.isEmpty || coordOriginal == '-') {
                          var match = todosSemaforosData.where(
                            (s) =>
                                s['id'].toString() ==
                                v['semaforo_id'].toString(),
                          );
                          coordOriginal = match.isNotEmpty
                              ? (match.first['georeferencia']?.toString() ??
                                    '-')
                              : '-';
                        }
                        String gpsVistoriador =
                            v['gps_coordenadas']?.toString() ?? '-';
                        List<dynamic> fotos = v['fotos'] ?? [];
                        return [
                          up(v['semaforo_id']),
                          up(v['semaforo_endereco']),
                          v['isNaoVistoriado'] == true
                              ? '-'
                              : up(
                                  v['nome_vistoriador'] ??
                                      nomeDoVistoriadorDoDia,
                                ),
                          up(v['data_hora_inicio']),
                          up(v['data_hora_fim']),
                          pw.Container(
                            alignment: pw.Alignment.center,
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'SEMÁFORO: $coordOriginal'.toUpperCase(),
                                  style: pw.TextStyle(
                                    color: PdfColors.green,
                                    fontSize: 6,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  status == 'NÃO VISTORIADO'
                                      ? 'VISTORIA: -'
                                      : 'VISTORIA: $gpsVistoriador'
                                            .toUpperCase(),
                                  style: pw.TextStyle(
                                    color: PdfColors.red,
                                    fontSize: 6,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          up(v['falha_registrada']),
                          status == 'NÃO VISTORIADO'
                              ? pw.Text(
                                  'SEMÁFORO NÃO VISTORIADO',
                                  style: pw.TextStyle(
                                    color: PdfColors.orange,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 6.5,
                                  ),
                                )
                              : up(v['detalhes_ocorrencia']),
                          fotos.join('\n\n'),
                        ];
                      }).toList(),
                      cellAlignment: pw.Alignment.center,
                      headerAlignment: pw.Alignment.center,
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        fontSize: 7.5,
                      ),
                      headerDecoration: const pw.BoxDecoration(
                        color: PdfColors.teal700,
                      ),
                      cellStyle: const pw.TextStyle(fontSize: 6.5),
                      columnWidths: {
                        0: const pw.FixedColumnWidth(45),
                        1: const pw.FixedColumnWidth(110),
                        2: const pw.FixedColumnWidth(65),
                        3: const pw.FixedColumnWidth(45),
                        4: const pw.FixedColumnWidth(45),
                        5: const pw.FixedColumnWidth(95),
                        6: const pw.FixedColumnWidth(70),
                        7: const pw.FixedColumnWidth(100),
                        8: const pw.FixedColumnWidth(100),
                      },
                    ),
                  ];
                },
              ),
            );
            return pdf.save();
          },
        );
      } else {
        StringBuffer excelBuffer = StringBuffer();
        excelBuffer.write(
          '<!DOCTYPE html><html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40"><head><meta charset="utf-8"></head><body><table border="1">',
        );
        excelBuffer.write(
          '<tr style="background-color: #00796B; color: white; font-weight: bold; text-align: center;"><td>SEMÁFORO</td><td>ENDEREÇO</td><td>VISTORIADOR</td><td>INÍCIO</td><td>FIM</td><td>GEORREFERÊNCIA</td><td>FALHA</td><td>DETALHES</td><td>FOTOS</td></tr>',
        );

        for (var v in baseFinalRelatorio) {
          bool isNaoVist = v['isNaoVistoriado'] == true;
          String coordOriginal = v['coordenadas_cadastro']?.toString() ?? '';
          if (coordOriginal.isEmpty || coordOriginal == '-') {
            var match = todosSemaforosData.where(
              (s) => s['id'].toString() == v['semaforo_id'].toString(),
            );
            coordOriginal = match.isNotEmpty
                ? (match.first['georeferencia']?.toString() ?? '-')
                : '-';
          }
          String gpsVistoriador = v['gps_coordenadas']?.toString() ?? '-';
          List<dynamic> fotos = v['fotos'] ?? [];

          excelBuffer.write('<tr>');
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['semaforo_id'])}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['semaforo_endereco'])}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${isNaoVist ? '-' : up(v['nome_vistoriador'] ?? nomeDoVistoriadorDoDia)}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['data_hora_inicio'])}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['data_hora_fim'])}</td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle; white-space: nowrap;"><span style="color: green; font-weight: bold;">SEMÁFORO: ${coordOriginal.toUpperCase()}</span><br/><span style="color: red; font-weight: bold;">VISTORIA: ${isNaoVist ? '-' : gpsVistoriador.toUpperCase()}</span></td>',
          );
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${up(v['falha_registrada'])}</td>',
          );

          if (isNaoVist) {
            excelBuffer.write(
              '<td style="text-align: center; vertical-align: middle; color: #FF9800; font-weight: bold;">SEMÁFORO NÃO VISTORIADO</td>',
            );
          } else {
            excelBuffer.write(
              '<td style="text-align: center; vertical-align: middle;">${up(v['detalhes_ocorrencia']).replaceAll('\n', ' ')}</td>',
            );
          }
          excelBuffer.write(
            '<td style="text-align: center; vertical-align: middle;">${fotos.isNotEmpty ? fotos.map((f) => '<a href="$f">FOTO</a>').join(' | ') : '-'}</td></tr>',
          );
        }
        excelBuffer.write('</table></body></html>');

        final Uint8List bytes = Uint8List.fromList(
          utf8.encode(excelBuffer.toString()),
        );
        final xFile = XFile.fromData(
          bytes,
          mimeType: 'application/vnd.ms-excel',
          name:
              'ROTA_${rotaEscolhida}_DIA_${dFiltroFormatada.replaceAll('/', '_')}.XLS',
        );
        await Share.shareXFiles([xFile], text: 'RELATÓRIO DE VISTORIAS.');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ERRO AO PROCESSAR ROTA DIÁRIA.'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _exportarPendenciasPDF(
    Map<String, Map<int, Set<String>>> vistoriasDiarias,
    Map<String, int> totaisPorRota,
    String mesFiltro,
    int daysInMonth,
  ) async {
    if (vistoriasDiarias.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GERANDO PDF DE ACOMPANHAMENTO DIÁRIO...'),
        backgroundColor: Colors.red,
      ),
    );
    try {
      String dataHoraAtual = DateFormat(
        'dd/MM/yyyy HH:mm:ss',
      ).format(DateTime.now()).toUpperCase();
      await Printing.layoutPdf(
        name: 'ACOMPANHAMENTO_DIARIO_${mesFiltro.replaceAll('/', '_')}.pdf',
        onLayout: (PdfPageFormat format) async {
          final pdf = pw.Document();
          var rotasOrdenadas = vistoriasDiarias.keys.toList()
            ..sort(
              (a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0),
            );

          for (String r in rotasOrdenadas) {
            int meta = totaisPorRota[r] ?? 0;
            Color corFlutter = _obterCorDaRota(r);
            PdfColor corPdfRota = PdfColor.fromInt(corFlutter.value);
            List<pw.TableRow> linhasTabela = [];
            linhasTabela.add(
              pw.TableRow(
                decoration: pw.BoxDecoration(color: corPdfRota),
                children: ['DATA', 'VISTORIADOS', 'PENDENTES', 'CONCLUÍDO']
                    .map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6),
                        child: pw.Text(
                          h,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );

            for (int d = 1; d <= daysInMonth; d++) {
              int vistoriados = vistoriasDiarias[r]![d]?.length ?? 0;
              int pendentes = meta - vistoriados;
              double perc = meta == 0 ? 0.0 : (vistoriados / meta) * 100;
              PdfColor corLinha = vistoriados == 0
                  ? PdfColors.grey500
                  : (pendentes > 0 ? PdfColors.red700 : PdfColors.green700);
              PdfColor corZebra = d % 2 == 0
                  ? PdfColors.white
                  : PdfColors.grey100;
              linhasTabela.add(
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: corZebra),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        '${d.toString().padLeft(2, '0')}/$mesFiltro',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: corLinha,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        '$vistoriados',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: corLinha,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        '$pendentes',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: corLinha,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        '${perc.toStringAsFixed(0)}%',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: corLinha,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            pdf.addPage(
              pw.MultiPage(
                pageFormat: format,
                margin: const pw.EdgeInsets.only(
                  left: 32,
                  right: 32,
                  top: 32,
                  bottom: 20,
                ),
                footer: (pw.Context context) =>
                    _buildRodapePDF(context, dataHoraAtual),
                build: (pw.Context context) => [
                  pw.Header(
                    level: 0,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'RELATÓRIO DE ACOMPANHAMENTO DIÁRIO',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'MÊS DE REFERÊNCIA: $mesFiltro',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'ROTA $r (META: $meta SEMÁFOROS)',
                    style: pw.TextStyle(
                      color: corPdfRota,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.5,
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(2),
                    },
                    children: linhasTabela,
                  ),
                ],
              ),
            );
          }
          return pdf.save();
        },
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ERRO AO GERAR PDF DE PENDÊNCIAS!'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _exportarPendenciasExcel(
    Map<String, Map<int, Set<String>>> vistoriasDiarias,
    Map<String, int> totaisPorRota,
    String mesFiltro,
    int daysInMonth,
  ) async {
    if (vistoriasDiarias.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GERANDO PLANILHA DIÁRIA...'),
        backgroundColor: Colors.green,
      ),
    );
    try {
      StringBuffer excelBuffer = StringBuffer();
      excelBuffer.write(
        '<!DOCTYPE html><html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40"><head><meta charset="utf-8"></head><body>',
      );
      excelBuffer.write(
        '<h2>ACOMPANHAMENTO DIÁRIO - MÊS: ${mesFiltro.toUpperCase()}</h2><br/>',
      );

      var rotasOrdenadas = vistoriasDiarias.keys.toList()
        ..sort(
          (a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0),
        );
      for (String r in rotasOrdenadas) {
        int meta = totaisPorRota[r] ?? 0;
        Color corDaRota = _obterCorDaRota(r);
        String hexColor =
            '#${corDaRota.value.toRadixString(16).substring(2, 8)}';
        excelBuffer.write(
          '<h3 style="color: $hexColor;">ROTA ${r.toUpperCase()} (META: $meta)</h3><table border="1">',
        );
        excelBuffer.write(
          '<tr style="background-color: $hexColor; color: white; text-align: center; font-weight: bold;"><td>DATA</td><td>VISTORIADOS</td><td>PENDENTES</td><td>CONCLUÍDO</td></tr>',
        );

        for (int d = 1; d <= daysInMonth; d++) {
          int vistoriados = vistoriasDiarias[r]![d]?.length ?? 0;
          int pendentes = meta - vistoriados;
          double perc = meta == 0 ? 0.0 : (vistoriados / meta) * 100;
          String corLinha = vistoriados == 0
              ? 'grey'
              : (pendentes > 0 ? 'red' : 'green');
          String corZebra = d % 2 == 0 ? '#FFFFFF' : '#F5F5F5';
          excelBuffer.write(
            '<tr style="background-color: $corZebra;"><td style="text-align: center; color: $corLinha; font-weight: bold;">${d.toString().padLeft(2, '0')}/$mesFiltro</td><td style="text-align: center; color: $corLinha; font-weight: bold;">$vistoriados</td><td style="text-align: center; color: $corLinha; font-weight: bold;">$pendentes</td><td style="text-align: center; color: $corLinha; font-weight: bold;">${perc.toStringAsFixed(1)}%</td></tr>',
          );
        }
        excelBuffer.write('</table><br/><br/>');
      }
      excelBuffer.write('</body></html>');

      final Uint8List bytes = Uint8List.fromList(
        utf8.encode(excelBuffer.toString()),
      );
      final xFile = XFile.fromData(
        bytes,
        mimeType: 'application/vnd.ms-excel',
        name: 'ACOMPANHAMENTO_DIARIO_${mesFiltro.replaceAll('/', '_')}.XLS',
      );
      await Share.shareXFiles([
        xFile,
      ], text: 'ACOMPANHAMENTO DIÁRIO DE SEMÁFOROS - $mesFiltro.');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ERRO AO EXPORTAR PENDÊNCIAS!'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    Query queryConsulta = FirebaseFirestore.instance
        .collection('vistorias')
        .orderBy('criado_em', descending: true);
    if (_deConsulta != null && _ateConsulta != null)
      queryConsulta = queryConsulta.where(
        'criado_em',
        isGreaterThanOrEqualTo: _deConsulta,
        isLessThanOrEqualTo: _ateConsulta,
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RELATÓRIOS E EXPORTAÇÕES',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade500,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'CONSULTA'),
            Tab(icon: Icon(Icons.download), text: 'EXPORTAÇÃO'),
            Tab(icon: Icon(Icons.warning_amber_rounded), text: 'PENDÊNCIAS'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('semaforos').snapshots(),
        builder: (context, snapshotSemaforos) {
          if (!snapshotSemaforos.hasData)
            return const Center(child: CircularProgressIndicator());
          Map<String, String> mapaRotasSemaforos = {};
          List<Map<String, dynamic>> todosSemaforosData = [];
          Set<String> rotasSet = {};

          for (var doc in snapshotSemaforos.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            String rotaStr = (data['rota'] ?? '').toString().replaceFirst(
              RegExp(r'^0+'),
              '',
            );
            mapaRotasSemaforos[data['id'].toString()] = rotaStr;
            todosSemaforosData.add(data);
            if (rotaStr.isNotEmpty) rotasSet.add(rotaStr);
          }

          List<String> listaRotasOptions = ['Todas'];
          List<String> rotasOrdenadas = rotasSet.toList()
            ..sort(
              (a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0),
            );
          listaRotasOptions.addAll(rotasOrdenadas);

          List<String> listaIdsEEnderecos = todosSemaforosData
              .map(
                (s) =>
                    "${s['id'] ?? ''} - ${s['endereco'] ?? ''}".toUpperCase(),
              )
              .toSet()
              .toList();
          listaIdsEEnderecos.sort(
            (a, b) => (int.tryParse(a.split(' - ')[0]) ?? 0).compareTo(
              int.tryParse(b.split(' - ')[0]) ?? 0,
            ),
          );

          return TabBarView(
            controller: _tabController,
            children: [
              // ================= ABA 1: CONSULTA =================
              Column(
                children: [
                  Container(
                    color: Colors.blue.shade50,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildBotaoData(
                              'DE',
                              _deConsulta,
                              () => _selecionarData(
                                context,
                                isDe: true,
                                tipoAba: 'Consulta',
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildBotaoData(
                              'ATÉ',
                              _ateConsulta,
                              () => _selecionarData(
                                context,
                                isDe: false,
                                tipoAba: 'Consulta',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'ROTA',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value:
                                        listaRotasOptions.contains(
                                          _rotaConsulta,
                                        )
                                        ? _rotaConsulta
                                        : 'Todas',
                                    items: listaRotasOptions
                                        .map(
                                          (r) => DropdownMenuItem(
                                            value: r,
                                            child: Text(
                                              r == 'Todas'
                                                  ? 'TODAS ROTAS'
                                                  : 'ROTA ' + r,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) => setState(() {
                                      _rotaConsulta = val!;
                                      _filtrosAplicadosConsulta = false;
                                    }),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: Autocomplete<String>(
                                optionsBuilder: (TextEditingValue textValue) {
                                  if (textValue.text.isEmpty)
                                    return const Iterable<String>.empty();
                                  return listaIdsEEnderecos.where(
                                    (item) => item.toLowerCase().contains(
                                      textValue.text.toLowerCase(),
                                    ),
                                  );
                                },
                                onSelected: (String selecao) {
                                  _semaforoController.text = selecao
                                      .toUpperCase();
                                  setState(
                                    () => _filtrosAplicadosConsulta = false,
                                  );
                                },
                                fieldViewBuilder:
                                    (
                                      context,
                                      controller,
                                      focusNode,
                                      onEditingComplete,
                                    ) {
                                      if (controller.text !=
                                              _semaforoController.text &&
                                          !focusNode.hasFocus)
                                        controller.text =
                                            _semaforoController.text;
                                      controller.addListener(() {
                                        _semaforoController.text = controller
                                            .text
                                            .toUpperCase();
                                      });
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        onChanged: (val) => setState(
                                          () =>
                                              _filtrosAplicadosConsulta = false,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Nº OU ENDEREÇO',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                        ),
                                      );
                                    },
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: SizedBox(
                                            width: 250,
                                            height: 250,
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              itemCount: options.length,
                                              itemBuilder: (context, index) {
                                                return ListTile(
                                                  title: Text(
                                                    options.elementAt(index),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  onTap: () => onSelected(
                                                    options.elementAt(index),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              setState(() => _filtrosAplicadosConsulta = true);
                            },
                            child: const Text(
                              'APLICAR FILTROS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        if (_filtrosAplicadosConsulta) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 45,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.picture_as_pdf,
                                      size: 20,
                                    ),
                                    label: const Text(
                                      'PDF',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    onPressed: () => _exportarConsulta(
                                      'PDF',
                                      mapaRotasSemaforos,
                                      todosSemaforosData,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 45,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(Icons.grid_on, size: 20),
                                    label: const Text(
                                      'EXCEL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    onPressed: () => _exportarConsulta(
                                      'EXCEL',
                                      mapaRotasSemaforos,
                                      todosSemaforosData,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (_deConsulta != null ||
                            _ateConsulta != null ||
                            _rotaConsulta != 'Todas' ||
                            _semaforoController.text.isNotEmpty) ...[
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            icon: const Icon(Icons.clear),
                            label: const Text(
                              'LIMPAR FILTROS',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _limparFiltrosConsulta,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: !_filtrosAplicadosConsulta
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.manage_search,
                                  size: 80,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'PREENCHA OS FILTROS ACIMA E CLIQUE EM APLICAR.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : StreamBuilder<QuerySnapshot>(
                            stream: queryConsulta.snapshots(),
                            builder: (context, snapshotVistorias) {
                              if (snapshotVistorias.connectionState ==
                                  ConnectionState.waiting)
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              var vistorias = snapshotVistorias.data!.docs;
                              String idFiltro = _semaforoController.text
                                  .split(' - ')[0]
                                  .trim();
                              if (idFiltro.isNotEmpty)
                                vistorias = vistorias
                                    .where(
                                      (doc) => doc['semaforo_id']
                                          .toString()
                                          .contains(idFiltro),
                                    )
                                    .toList();
                              if (_rotaConsulta != 'Todas') {
                                String rotaLimpa = _rotaConsulta.replaceFirst(
                                  RegExp(r'^0+'),
                                  '',
                                );
                                vistorias = vistorias
                                    .where(
                                      (doc) =>
                                          (mapaRotasSemaforos[doc['semaforo_id']
                                                  .toString()] ??
                                              '') ==
                                          rotaLimpa,
                                    )
                                    .toList();
                              }
                              if (vistorias.isEmpty)
                                return const Center(
                                  child: Text(
                                    'NENHUMA VISTORIA ENCONTRADA PARA ESTES FILTROS.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: vistorias.length,
                                itemBuilder: (context, index) {
                                  var vist =
                                      vistorias[index].data()
                                          as Map<String, dynamic>;
                                  String idSemaforo = up(vist['semaforo_id']);
                                  String endSemaforo = up(
                                    vist['semaforo_endereco'],
                                  );
                                  bool temFalha =
                                      vist['teve_anormalidade'] == true;
                                  String rotaExibicao =
                                      mapaRotasSemaforos[idSemaforo] ??
                                      'SEM ROTA';
                                  String coordOriginal =
                                      vist['coordenadas_cadastro']
                                          ?.toString() ??
                                      '';
                                  if (coordOriginal.isEmpty) {
                                    var match = todosSemaforosData.where(
                                      (s) => s['id'].toString() == idSemaforo,
                                    );
                                    coordOriginal = match.isNotEmpty
                                        ? (match.first['georeferencia']
                                                  ?.toString() ??
                                              '-')
                                        : '-';
                                  }
                                  return FutureBuilder<String>(
                                    future: _getNomeVistoriador(
                                      vist['vistoriador_uid'] ?? '',
                                    ),
                                    builder: (context, snapshotNome) {
                                      String nome =
                                          snapshotNome.data ?? 'CARREGANDO...';
                                      return Card(
                                        color: temFalha
                                            ? Colors.red.shade50
                                            : Colors.grey.shade200,
                                        elevation: 1,
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: temFalha
                                                ? Colors.red.shade700
                                                : Colors.grey.shade600,
                                            child: Text(
                                              idSemaforo,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            '$idSemaforo - $endSemaforo',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: temFalha
                                                  ? Colors.red.shade700
                                                  : Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'INÍCIO: ${up(vist['data_hora_inicio'])} - FIM: ${up(vist['data_hora_fim'])}',
                                                  style: const TextStyle(
                                                    color: Colors.black87,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'VISTORIADOR: ${nome.toUpperCase()}',
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          trailing: Icon(
                                            temFalha
                                                ? Icons.warning_amber_rounded
                                                : Icons.check_circle,
                                            color: temFalha
                                                ? Colors.red.shade700
                                                : Colors.grey.shade600,
                                          ),
                                          onTap: () =>
                                              _mostrarDetalhesVistoriaAnterior(
                                                vist,
                                                rotaExibicao,
                                                nome,
                                                coordOriginal,
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),

              // ================= ABA 2: EXPORTAÇÃO =================
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.route,
                          size: 64,
                          color: Colors.teal.shade800,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'EXPORTAR ROTA DO DIA',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'SELECIONE O DIA EXATO E A ROTA PARA GERAR O RELATÓRIO (INCLUINDO OS NÃO VISTORIADOS).',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _deExport ?? DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null)
                              setState(() => _deExport = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 24,
                                  color: Colors.teal.shade800,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'DATA: ${DateFormat('dd/MM/yyyy').format(_deExport ?? DateTime.now())}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'ROTA',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value:
                                  listaRotasOptions.contains(_rotaExport) &&
                                      _rotaExport != 'Todas'
                                  ? _rotaExport
                                  : 'Selecione',
                              items: [
                                const DropdownMenuItem(
                                  value: 'Selecione',
                                  child: Text('SELECIONE UMA ROTA...'),
                                ),
                                ...listaRotasOptions
                                    .where((r) => r != 'Todas')
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text('ROTA ' + r),
                                      ),
                                    ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _rotaExport = val!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),

                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 60,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    size: 28,
                                  ),
                                  label: const Text(
                                    'PDF',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  onPressed:
                                      _rotaExport != 'Selecione' &&
                                          _rotaExport != 'Todas'
                                      ? () => _exportarRotaDoDiaCompleta(
                                          mapaRotasSemaforos,
                                          todosSemaforosData,
                                          _deExport ?? DateTime.now(),
                                          _rotaExport,
                                          'PDF',
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SizedBox(
                                height: 60,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.grid_on, size: 28),
                                  label: const Text(
                                    'EXCEL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  onPressed:
                                      _rotaExport != 'Selecione' &&
                                          _rotaExport != 'Todas'
                                      ? () => _exportarRotaDoDiaCompleta(
                                          mapaRotasSemaforos,
                                          todosSemaforosData,
                                          _deExport ?? DateTime.now(),
                                          _rotaExport,
                                          'EXCEL',
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ================= ABA 3: PENDÊNCIAS =================
              Column(
                children: [
                  Container(
                    color: Colors.red.shade50,
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ACOMPANHAMENTO DIÁRIO POR ROTA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'SELECIONE O MÊS PARA VER A PRODUTIVIDADE DIA A DIA DE CADA ROTA.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildBotaoData(
                                  'MÊS',
                                  _mesPendencia,
                                  () => _selecionarMesAnoDialog(context),
                                  formato: 'MM/yyyy',
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'ROTA',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value:
                                            listaRotasOptions.contains(
                                              _rotaPendencia,
                                            )
                                            ? _rotaPendencia
                                            : 'Todas',
                                        items: listaRotasOptions
                                            .map(
                                              (r) => DropdownMenuItem(
                                                value: r,
                                                child: Text(
                                                  r == 'Todas'
                                                      ? 'TODAS ROTAS'
                                                      : 'ROTA ' + r,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) => setState(() {
                                          _rotaPendencia = val!;
                                        }),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('vistorias')
                          .where(
                            'criado_em',
                            isGreaterThanOrEqualTo: DateTime(
                              _mesPendencia.year,
                              _mesPendencia.month,
                              1,
                            ),
                          )
                          .where(
                            'criado_em',
                            isLessThanOrEqualTo: DateTime(
                              _mesPendencia.year,
                              _mesPendencia.month + 1,
                              0,
                              23,
                              59,
                              59,
                            ),
                          )
                          .snapshots(),
                      builder: (context, snapshotVistoriasDoMes) {
                        if (snapshotVistoriasDoMes.connectionState ==
                            ConnectionState.waiting)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        int daysInMonth = DateTime(
                          _mesPendencia.year,
                          _mesPendencia.month + 1,
                          0,
                        ).day;
                        String rotaFiltro = _rotaPendencia.replaceFirst(
                          RegExp(r'^0+'),
                          '',
                        );

                        Map<String, int> totalSemaforosPorRota = {};
                        for (var sem in todosSemaforosData) {
                          String rotaSem = (sem['rota'] ?? '')
                              .toString()
                              .replaceFirst(RegExp(r'^0+'), '');
                          if (rotaSem.isNotEmpty)
                            totalSemaforosPorRota[rotaSem] =
                                (totalSemaforosPorRota[rotaSem] ?? 0) + 1;
                        }

                        Map<String, Map<int, Set<String>>> vistoriasDiarias =
                            {};
                        for (String r in totalSemaforosPorRota.keys) {
                          if (_rotaPendencia == 'Todas' || r == rotaFiltro) {
                            vistoriasDiarias[r] = {};
                            for (int d = 1; d <= daysInMonth; d++)
                              vistoriasDiarias[r]![d] = {};
                          }
                        }

                        for (var doc in snapshotVistoriasDoMes.data!.docs) {
                          var v = doc.data() as Map<String, dynamic>;
                          Timestamp? t = v['criado_em'] as Timestamp?;
                          if (t != null) {
                            DateTime dt = t.toDate();
                            String idSem = v['semaforo_id']?.toString() ?? '';
                            String rotaDoSem = mapaRotasSemaforos[idSem] ?? '';
                            if (rotaDoSem.isNotEmpty &&
                                vistoriasDiarias.containsKey(rotaDoSem))
                              vistoriasDiarias[rotaDoSem]![dt.day]!.add(idSem);
                          }
                        }

                        var rotasOrd = vistoriasDiarias.keys.toList()
                          ..sort(
                            (a, b) => (int.tryParse(a) ?? 0).compareTo(
                              int.tryParse(b) ?? 0,
                            ),
                          );
                        String mesFormatado = DateFormat(
                          'MM/yyyy',
                        ).format(_mesPendencia).toUpperCase();

                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: Column(
                              children: [
                                Expanded(
                                  child: rotasOrd.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'NENHUMA ROTA ENCONTRADA.',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: rotasOrd.length,
                                          itemBuilder: (context, index) {
                                            String rota = rotasOrd[index];
                                            int totalMeta =
                                                totalSemaforosPorRota[rota] ??
                                                0;
                                            var diasMap =
                                                vistoriasDiarias[rota]!;
                                            Color corDaRota = _obterCorDaRota(
                                              rota,
                                            );
                                            return Card(
                                              margin: const EdgeInsets.only(
                                                bottom: 16,
                                              ),
                                              elevation: 3,
                                              shadowColor: corDaRota
                                                  .withOpacity(0.3),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                side: BorderSide(
                                                  color: corDaRota.withOpacity(
                                                    0.5,
                                                  ),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: ExpansionTile(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                collapsedShape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                leading: CircleAvatar(
                                                  backgroundColor: corDaRota
                                                      .withOpacity(0.15),
                                                  child: Text(
                                                    rota.toUpperCase(),
                                                    style: TextStyle(
                                                      color: corDaRota,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  'ROTA $rota',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: corDaRota,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  'META DIÁRIA: $totalMeta SEMÁFOROS',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                                children: [
                                                  Container(
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.vertical(
                                                            bottom:
                                                                Radius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 16,
                                                                vertical: 12,
                                                              ),
                                                          decoration:
                                                              BoxDecoration(
                                                                color: corDaRota
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                              ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                flex: 2,
                                                                child: Text(
                                                                  'DATA',
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                    color:
                                                                        corDaRota,
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 3,
                                                                child: Text(
                                                                  'VISTORIADOS',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                    color:
                                                                        corDaRota,
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 3,
                                                                child: Text(
                                                                  'PENDENTES',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                    color:
                                                                        corDaRota,
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Text(
                                                                  '%',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .right,
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                    color:
                                                                        corDaRota,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        ...List.generate(daysInMonth, (
                                                          i,
                                                        ) {
                                                          int dia = i + 1;
                                                          int vistoriados =
                                                              diasMap[dia]
                                                                  ?.length ??
                                                              0;
                                                          int pendentes =
                                                              totalMeta -
                                                              vistoriados;
                                                          double perc =
                                                              totalMeta == 0
                                                              ? 0.0
                                                              : (vistoriados /
                                                                        totalMeta) *
                                                                    100;
                                                          Color corLinha =
                                                              vistoriados == 0
                                                              ? Colors
                                                                    .grey
                                                                    .shade500
                                                              : (pendentes > 0
                                                                    ? Colors
                                                                          .red
                                                                          .shade600
                                                                    : Colors
                                                                          .green
                                                                          .shade700);
                                                          return Container(
                                                            color: i % 2 == 0
                                                                ? Colors.white
                                                                : Colors
                                                                      .grey
                                                                      .shade100,
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical:
                                                                      10.0,
                                                                  horizontal:
                                                                      16.0,
                                                                ),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  flex: 2,
                                                                  child: Text(
                                                                    '${dia.toString().padLeft(2, '0')}/${_mesPendencia.month.toString().padLeft(2, '0')}',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      color:
                                                                          corLinha,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  flex: 3,
                                                                  child: Text(
                                                                    '$vistoriados',
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      color:
                                                                          corLinha,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  flex: 3,
                                                                  child: Text(
                                                                    '$pendentes',
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      color:
                                                                          corLinha,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  flex: 2,
                                                                  child: Text(
                                                                    '${perc.toStringAsFixed(0)}%',
                                                                    textAlign:
                                                                        TextAlign
                                                                            .right,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      color:
                                                                          corLinha,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                                if (rotasOrd.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.orange.shade700,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                            ),
                                            icon: const Icon(
                                              Icons.picture_as_pdf,
                                            ),
                                            label: const Text(
                                              'EXPORTAR PDF GERAL',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _exportarPendenciasPDF(
                                                  vistoriasDiarias,
                                                  totalSemaforosPorRota,
                                                  mesFormatado,
                                                  daysInMonth,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green.shade700,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                            ),
                                            icon: const Icon(Icons.grid_on),
                                            label: const Text(
                                              'EXPORTAR EXCEL GERAL',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _exportarPendenciasExcel(
                                                  vistoriasDiarias,
                                                  totalSemaforosPorRota,
                                                  mesFormatado,
                                                  daysInMonth,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
}
