import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ==== FUNÇÃO GLOBAL PARA ABRIR MAPS OU WAZE ====
void _mostrarOpcoesGPS(BuildContext context, String georeferencia) {
  if (georeferencia.trim().isEmpty || !georeferencia.contains(' ')) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semáforo sem coordenadas cadastradas!'), backgroundColor: Colors.orange));
    return;
  }

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Como deseja chegar ao semáforo?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade400, 
                        foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(vertical: 16), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      icon: const Icon(Icons.directions_car, size: 28),
                      label: const Text('Waze', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(context);
                        _abrirAppNavegacao(context, georeferencia, 'waze');
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      icon: const Icon(Icons.map, size: 28),
                      label: const Text('Maps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(context);
                        _abrirAppNavegacao(context, georeferencia, 'maps');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  );
}

Future<void> _abrirAppNavegacao(BuildContext context, String georeferencia, String app) async {
  try {
    String geoLimpa = georeferencia.replaceAll(',', ' ').trim();
    List<String> partes = geoLimpa.split(RegExp(r'\s+'));

    if (partes.length < 2) {
      throw 'Formato de coordenada inválido.';
    }

    String lat = partes[0];
    String lng = partes[1];

    Uri url;
    if (app == 'waze') {
      url = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
    } else {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'); // Se usar a api directions, mude para: http://maps.google.com/maps?daddr=$lat,$lng
    }

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Não foi possível abrir o aplicativo.';
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir o $app. Verifique se ele está instalado!'), backgroundColor: Colors.red));
    }
  }
}


class AcervoPage extends StatefulWidget {
  const AcervoPage({super.key});

  @override
  State<AcervoPage> createState() => _AcervoPageState();
}

class _AcervoPageState extends State<AcervoPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _pesquisaController = TextEditingController();
  String _textoPesquisa = '';

  String _filtroRotaLista = 'Todas';
  String _filtroRota = 'Todas';
  String _filtroGrupo = 'Todos';

  late Stream<QuerySnapshot> _semaforosStream;

  final List<String> _todosOsCampos = [
    'id', 'endereco', 'bairro', 'empresa', 'georeferencia', 'rota', 'grupo',
    'tipo_do_controlador', 'id_do_controlador', 'subareas',
    'grupo_focal_veicular_tipo_i', 'grupo_focal_veicular_tipo_t',
    'grupo_focal_pedestre_simples', 'grupo_focal_pedestre_com_cronometro',
    'grupo_focal_faixa_reversivel', 'grupo_focal_ciclista_com_tres_focos',
    'grupo_focal_ciclista_com_dois_focos', 'anteparo_tipo_i',
    'veicular_com_sequencial', 'veicular_com_cronometro', 'sirene',
    'horario_de_funcionamente_das_sirenes', 'botoeira_com_dispositivo_sonoro',
    'botoeira_simples', 'nobreak', 'kit_bateria', 'numero_do_nobreak',
    'medidor', 'numero_do_medidor', 'kit_de_comunicacao', 'modo_de_funcionamento',
    'semiportico_conico', 'semiportico_simples', 'semiportico_estruturado',
    'portico_simples', 'portico_estruturado', 'coluna_conica', 'coluna_simples',
    'placa_adesiva_para_botoeira', 'conjunto_entrada_de_energia_padrao_celpe_instalado',
    'conjunto_aterramento_para_colunas', 'cabo_2x1mm', 'cabo_3x1mm', 'cabo_4x1mm',
    'cabo_7x1mm', 'luminarias', 'placa_de_identificacao_de_semaforo',
    'fotossensor_equipamento', 'conta_contrato', 'link_da_programacao',
    'observacoes', 'observacoes_2', 'historico', 'data_de_implantacao'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _semaforosStream = FirebaseFirestore.instance.collection('semaforos').orderBy('id').snapshots();

    _pesquisaController.addListener(() {
      setState(() {
        _textoPesquisa = _pesquisaController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pesquisaController.dispose();
    super.dispose();
  }

  Future<void> _exportarAcervoPDF(List<Map<String, dynamic>> semaforos) async {
    if (semaforos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum semáforo para exportar.'), backgroundColor: Colors.orange));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando PDF do Acervo...'), backgroundColor: Colors.teal));

    try {
      String rotaStr = _filtroRotaLista == 'Todas' ? 'Todas as Rotas' : 'Rota $_filtroRotaLista';
      String dataHoraAtual = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

      await Printing.layoutPdf(
        name: 'Acervo_$rotaStr.pdf',
        onLayout: (PdfPageFormat format) async {
          final pdf = pw.Document();

          pdf.addPage(
            pw.MultiPage(
              pageFormat: format, 
              margin: const pw.EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 20),
              footer: (pw.Context context) {
                return pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Relatório gerado pelo aplicativo Vistoria CTTU ($dataHoraAtual)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('Pág. ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ]
                    )
                  ]
                );
              },
              build: (pw.Context context) {
                return [
                  pw.Header(
                    level: 0, 
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Relatório do Acervo de Semáforos', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Filtro: $rotaStr | Total: ${semaforos.length} semáforos', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      ]
                    )
                  ),
                  pw.SizedBox(height: 16),
                  pw.TableHelper.fromTextArray(
                    context: context,
                    headers: ['Semáforo', 'Endereço', 'Bairro', 'Empresa', 'Rota'],
                    data: semaforos.map((s) {
                      String rotaDoSem = (s['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
                      return [ 
                        s['id']?.toString() ?? '', 
                        s['endereco']?.toString() ?? '', 
                        s['bairro']?.toString() ?? '', 
                        s['empresa']?.toString() ?? '', 
                        rotaDoSem.isEmpty ? 'S/R' : rotaDoSem
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                    cellAlignment: pw.Alignment.centerLeft, 
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    columnWidths: { 
                      0: const pw.FlexColumnWidth(1), 
                      1: const pw.FlexColumnWidth(3), 
                      2: const pw.FlexColumnWidth(1.5), 
                      3: const pw.FlexColumnWidth(1.5), 
                      4: const pw.FlexColumnWidth(1) 
                    }
                  ),
                ];
              }
            )
          );
          
          return pdf.save();
        }
      );
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao gerar PDF!'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportarAcervoExcel(List<Map<String, dynamic>> semaforos) async {
    if (semaforos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum semáforo para exportar.'), backgroundColor: Colors.orange));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando Planilha Excel...'), backgroundColor: Colors.green));

    try {
      String csv = '\uFEFF'; 
      csv += 'SEMAFORO;ENDERECO;BAIRRO;EMPRESA;ROTA;COORDENADAS\n';
      
      for (var s in semaforos) {
        String id = s['id']?.toString() ?? '';
        String endereco = s['endereco']?.toString().replaceAll(';', ',') ?? ''; 
        String bairro = s['bairro']?.toString() ?? '';
        String empresa = s['empresa']?.toString() ?? '';
        String rota = (s['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
        if (rota.isEmpty) rota = 'S/R';
        String coords = s['georeferencia']?.toString() ?? '';

        csv += '$id;$endereco;$bairro;$empresa;$rota;$coords\n';
      }

      String rotaStr = _filtroRotaLista == 'Todas' ? 'Todas' : _filtroRotaLista;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/Acervo_Rota_$rotaStr.xls';
      final file = File(path);
      await file.writeAsBytes(utf8.encode(csv));
      await Share.shareXFiles([XFile(path)], text: 'Acervo de Semáforos - Rota $rotaStr.');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao gerar Excel!'), backgroundColor: Colors.red));
    }
  }

  void _mostrarFichaTecnica(Map<String, dynamic> data) {
    String georef = (data['georeferencia'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Ficha Técnica - Semáforo Nº ${data['id'] ?? ''}', 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange.shade800)
                    )
                  ),
                  const Divider(thickness: 2, height: 32),

                  // BOTÃO DE COMO CHEGAR DENTRO DA FICHA
                  if (georef.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          icon: const Icon(Icons.directions),
                          label: const Text('COMO CHEGAR (GPS)', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _mostrarOpcoesGPS(context, georef),
                        ),
                      ),
                    ),

                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _todosOsCampos.length,
                      itemBuilder: (context, index) {
                        String campo = _todosOsCampos[index];
                        String titulo = campo.replaceAll('_', ' ').toUpperCase();
                        String valor = (data[campo] ?? '').toString().trim();
                        
                        if (valor.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black87, fontSize: 15),
                              children: [
                                TextSpan(text: '$titulo: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                TextSpan(text: valor),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar Ficha', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _abrirMapaDaRota(String titulo, List<Map<String, dynamic>> semaforosParaMapa) {
    if (semaforosParaMapa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum semáforo encontrado com estes filtros.'), backgroundColor: Colors.orange));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TelaMapaRota(titulo: titulo, semaforosDaRota: semaforosParaMapa)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acervo de Semáforos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade400,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Lista Geral'),
            Tab(icon: Icon(Icons.map_outlined), text: 'Mapa / Filtros'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _semaforosStream, 
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar o acervo.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          var todosSemaforos = snapshot.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();

          Set<String> rotasSet = {};
          for (var s in todosSemaforos) {
            String rota = (s['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
            if (rota.isNotEmpty) rotasSet.add(rota);
          }
          List<String> listaRotas = rotasSet.toList()..sort();

          return TabBarView(
            controller: _tabController,
            children: [
              // ================= ABA 1: LISTA GERAL =================
              Builder(
                builder: (context) {
                  var semaforosFiltradosPesquisa = todosSemaforos;

                  if (_filtroRotaLista != 'Todas') {
                    semaforosFiltradosPesquisa = semaforosFiltradosPesquisa.where((data) {
                      return (data['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '') == _filtroRotaLista;
                    }).toList();
                  }

                  if (_textoPesquisa.isNotEmpty) {
                    semaforosFiltradosPesquisa = semaforosFiltradosPesquisa.where((data) {
                      final endereco = (data['endereco'] ?? '').toString().toLowerCase();
                      final id = (data['id'] ?? '').toString().toLowerCase();
                      return endereco.contains(_textoPesquisa) || id.contains(_textoPesquisa);
                    }).toList();
                  }

                  return Column(
                    children: [
                      Container(
                        color: Colors.orange.shade50,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Rota',
                                      filled: true, fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: listaRotas.contains(_filtroRotaLista) ? _filtroRotaLista : 'Todas',
                                        items: [
                                          const DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                                          ...listaRotas.map((r) => DropdownMenuItem(value: r, child: Text('Rota $r')))
                                        ],
                                        onChanged: (val) => setState(() => _filtroRotaLista = val!),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 5,
                                  child: TextField(
                                    controller: _pesquisaController,
                                    decoration: InputDecoration(
                                      labelText: 'Pesquisar...',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon: _textoPesquisa.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _pesquisaController.clear()) : null,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      filled: true, fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade700, 
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                    ),
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: Text('PDF (${semaforosFiltradosPesquisa.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () => _exportarAcervoPDF(semaforosFiltradosPesquisa),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700, 
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                    ),
                                    icon: const Icon(Icons.grid_on),
                                    label: Text('Excel (${semaforosFiltradosPesquisa.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () => _exportarAcervoExcel(semaforosFiltradosPesquisa),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        child: semaforosFiltradosPesquisa.isEmpty 
                          ? const Center(child: Text('Nenhum semáforo encontrado.', style: TextStyle(fontSize: 16, color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: semaforosFiltradosPesquisa.length,
                              itemBuilder: (context, index) {
                                final data = semaforosFiltradosPesquisa[index];
                                String rota = (data['rota'] ?? 'S/R').toString().replaceFirst(RegExp(r'^0+'), '');
                                String georef = (data['georeferencia'] ?? '').toString();

                                return Card(
                                  elevation: 2, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: InkWell(
                                    onTap: () => _mostrarFichaTecnica(data),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(radius: 28, backgroundColor: Colors.orange.shade100, child: Text(data['id']?.toString() ?? '', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 16))),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(data['endereco'] ?? 'Sem endereço', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.route, size: 14, color: Colors.grey.shade600), const SizedBox(width: 4), Text('Rota $rota', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold)),
                                                    const SizedBox(width: 12),
                                                    Icon(Icons.location_city, size: 14, color: Colors.grey.shade600), const SizedBox(width: 4), Expanded(child: Text(data['bairro'] ?? '-', style: TextStyle(color: Colors.grey.shade700, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.directions, color: georef.isNotEmpty ? Colors.blue.shade700 : Colors.grey, size: 28),
                                            tooltip: 'Como Chegar',
                                            onPressed: () => _mostrarOpcoesGPS(context, georef),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                      ),
                    ],
                  );
                }
              ),

              // ================= ABA 2: MAPA E FILTROS =================
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Visualizar Semáforos no Mapa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 8),
                    const Text('Filtre a rota e o grupo desejado para criar uma visualização customizada no mapa.', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 32),

                    InputDecorator(
                      decoration: InputDecoration(labelText: 'Filtrar por Rota', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: listaRotas.contains(_filtroRota) ? _filtroRota : 'Todas',
                          items: [
                            const DropdownMenuItem(value: 'Todas', child: Text('Todas as Rotas')),
                            ...listaRotas.map((r) => DropdownMenuItem(value: r, child: Text('Rota $r')))
                          ],
                          onChanged: (val) => setState(() => _filtroRota = val!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    InputDecorator(
                      decoration: InputDecoration(labelText: 'Filtrar por Grupo', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _filtroGrupo,
                          items: const [
                            DropdownMenuItem(value: 'Todos', child: Text('Todos os Grupos')),
                            DropdownMenuItem(value: 'A', child: Text('Grupo A')),
                            DropdownMenuItem(value: 'B', child: Text('Grupo B')),
                          ],
                          onChanged: (val) => setState(() => _filtroGrupo = val!),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48),

                    SizedBox(
                      height: 60,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.map, size: 28),
                        label: const Text('ABRIR MAPA COM FILTROS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          List<Map<String, dynamic>> listaFiltradaParaMapa = todosSemaforos.where((sem) {
                            String rotaLimpa = (sem['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
                            String grupo = (sem['grupo'] ?? '').toString().toUpperCase();

                            bool passaRota = _filtroRota == 'Todas' || rotaLimpa == _filtroRota;
                            bool passaGrupo = _filtroGrupo == 'Todos' || grupo == _filtroGrupo;

                            return passaRota && passaGrupo;
                          }).toList();

                          String tituloMapa = 'Mapa: ${_filtroRota == 'Todas' ? 'Todas Rotas' : 'Rota $_filtroRota'} - Grupo $_filtroGrupo';
                          _abrirMapaDaRota(tituloMapa, listaFiltradaParaMapa);
                        },
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

// =======================================================================
// TELA NOVA: MAPA INTERNO PARA VISUALIZAR OS SEMÁFOROS
// =======================================================================
class TelaMapaRota extends StatelessWidget {
  final String titulo;
  final List<Map<String, dynamic>> semaforosDaRota;

  const TelaMapaRota({super.key, required this.titulo, required this.semaforosDaRota});

  @override
  Widget build(BuildContext context) {
    List<Marker> marcadores = [];
    LatLng centroDoMapa = const LatLng(-8.05428, -34.8813); 

    for (var semaforo in semaforosDaRota) {
      String geoStr = (semaforo['georeferencia'] ?? '').toString().trim();
      String empresa = (semaforo['empresa'] ?? '').toString().toUpperCase();

      String iconeCaminho = 'assets/images/semaforo.png';
      if (empresa.contains('SERTTEL')) {
        iconeCaminho = 'assets/images/serttel.png';
      } else if (empresa.contains('SINALVIDA')) {
        iconeCaminho = 'assets/images/sinalvida.png';
      }

      if (geoStr.isNotEmpty && geoStr.contains(' ')) {
        var partes = geoStr.split(' ');
        if (partes.length >= 2) {
          double lat = double.tryParse(partes[0]) ?? 0;
          double lng = double.tryParse(partes[1]) ?? 0;

          if (lat != 0 && lng != 0) {
            LatLng posicao = LatLng(lat, lng);
            centroDoMapa = posicao;

            final String caminhoIcone = iconeCaminho;
            final Map<String, dynamic> semaforoAtual = semaforo;

            marcadores.add(
              Marker(
                point: posicao,
                width: 30,
                height: 30,
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Semáforo Nº ${semaforoAtual['id']}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                        content: Text('${semaforoAtual['endereco']}\n\nBairro: ${semaforoAtual['bairro']}\nGrupo: ${semaforoAtual['grupo'] ?? '-'}\nEmpresa: ${semaforoAtual['empresa']}'),
                        actions: [
                          TextButton.icon(
                            icon: const Icon(Icons.directions, color: Colors.blue),
                            label: const Text('Traçar Rota', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            onPressed: () => _mostrarOpcoesGPS(context, geoStr),
                          ),
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar', style: TextStyle(color: Colors.grey))),
                        ],
                      ),
                    );
                  },
                  child: Image.asset(caminhoIcone, width: 30, height: 30),
                ),
              ),
            );
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.orange.shade300,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: centroDoMapa,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.vistoria.cttu',
          ),
          MarkerLayer(markers: marcadores),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
        label: Text('Voltar (${marcadores.length} Pinos)'),
      ),
    );
  }
}