import 'dart:typed_data';
import 'dart:io'; // Adicionado para manipulação de arquivos locais
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 
// Novas bibliotecas de suporte para a aba de relatórios
import 'package:pdf/pdf.dart'; 
import 'package:pdf/widgets.dart' as pw; 
import 'package:printing/printing.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:share_plus/share_plus.dart';

class AcervoPage extends StatefulWidget {
  const AcervoPage({super.key});

  @override
  State<AcervoPage> createState() => _AcervoPageState();
}

class _AcervoPageState extends State<AcervoPage> {
  List<dynamic> _todosSemaforos = [];
  List<dynamic> _semaforosFiltrados = [];
  List<String> _listaRotasDisponiveis = ['Todas']; 
  bool _carregando = true;
  bool _sincronizandoComPlanilha = false; 
  String _textoPesquisa = '';
  String _rotaSelecionada = 'Todas'; 
  String _rotaSelecionadaRelatorio = 'Todas'; // Nova variável de estado para a aba de relatórios
  final TextEditingController _pesquisaController = TextEditingController();

  // SEQUÊNCIA EXATA DAS COLUNAS SOLICITADAS PARA EXIBIÇÃO NO POPUP
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
    "Data de implantação"
  ];

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  // FUNÇÃO DE BUSCA INTELIGENTE DE CAMPOS
  String _obterValorCampo(Map<String, dynamic> semaforo, String chaveOriginal) {
    if (semaforo.containsKey(chaveOriginal)) {
      return semaforo[chaveOriginal].toString();
    }
    
    String chaveMinuscula = chaveOriginal.toLowerCase();
    if (semaforo.containsKey(chaveMinuscula)) {
      return semaforo[chaveMinuscula].toString();
    }
    
    for (var entry in semaforo.entries) {
      if (entry.key.trim().toLowerCase() == chaveMinuscula) {
        return entry.value.toString();
      }
    }

    if (chaveMinuscula == 'semáforo' || chaveMinuscula == 'semaforo') {
      return (semaforo['id'] ?? semaforo['semáforo'] ?? semaforo['semaforo'] ?? '').toString();
    }
    if (chaveMinuscula == 'endereço' || chaveMinuscula == 'endereco') {
      return (semaforo['endereco'] ?? semaforo['endereço'] ?? '').toString();
    }
    if (chaveMinuscula == 'observacoes' || chaveMinuscula == 'observaçoes') {
      return (semaforo['observacoes'] ?? semaforo['observacoes_2'] ?? semaforo['observaçoes'] ?? '').toString();
    }
    if (chaveMinuscula == 'sub-área (trafgo)' || chaveMinuscula == 'sub-área (tráfego)') {
      return (semaforo['sub-área (trafgo)'] ?? semaforo['subarea'] ?? semaforo['subareas'] ?? '').toString();
    }

    return '';
  }

  // GERADOR DE CORES DINÂMICAS PARA CADA ROTA
  Color _obterCorDaRota(String rota) {
    String r = rota.trim().toUpperCase().replaceAll('ROTA', '').replaceAll(' ', '');
    if (r.isEmpty) return Colors.grey.shade600;

    switch (r) {
      case '1': case '01': return Colors.blue.shade700;
      case '2': case '02': return Colors.green.shade700;
      case '3': case '03': return Colors.red.shade700;
      case '4': case '04': return Colors.purple.shade700;
      case '5': case '05': return Colors.amber.shade800;
      case '6': case '06': return Colors.teal.shade700;
      case '7': case '07': return Colors.indigo.shade700;
      case '8': case '08': return Colors.pink.shade700;
      case '9': case '09': return Colors.cyan.shade800;
      case '10': return Colors.deepOrange.shade700;
      default:
        final int hash = r.hashCode;
        final List<Color> coresDisponiveis = [
          Colors.blue.shade700, Colors.green.shade700, Colors.red.shade700,
          Colors.purple.shade700, Colors.amber.shade800, Colors.teal.shade700,
          Colors.indigo.shade700, Colors.pink.shade700, Colors.cyan.shade800,
          Colors.deepOrange.shade700, Colors.brown.shade600, Colors.blueGrey.shade700
        ];
        return coresDisponiveis[hash.abs() % coresDisponiveis.length];
    }
  }

  void _atualizarListaDeRotas() {
    Set<String> rotasSet = {};
    for (var semaforo in _todosSemaforos) {
      String rotaRaw = _obterValorCampo(Map<String, dynamic>.from(semaforo), "ROTA").trim();
      if (rotaRaw.isNotEmpty) {
        if (!rotaRaw.toLowerCase().contains('rota')) {
          rotasSet.add('Rota ${rotaRaw.padLeft(2, '0')}');
        } else {
          rotasSet.add(rotaRaw);
        }
      }
    }
    List<String> rotasOrdenadas = rotasSet.toList()..sort();
    
    setState(() {
      _listaRotasDisponiveis = ['Todas', ...rotasOrdenadas];
      if (!_listaRotasDisponiveis.contains(_rotaSelecionada)) {
        _rotaSelecionada = 'Todas';
      }
    });
  }

  // 1. CARREGA O DATASET INICIAL DO ASSET LOCAL
  Future<void> _carregarDadosIniciais() async {
    setState(() => _carregando = true);

    try {
      final String resposta = await rootBundle.loadString('assets/informacoes_gerais.json');
      final List<dynamic> dados = json.decode(resposta);

      setState(() {
        _todosSemaforos = dados;
        _carregando = false;
      });
      _atualizarListaDeRotas();
      _aplicarFiltrosCombinados();
    } catch (e) {
      setState(() => _carregando = false);
      _mostrarSnackBar('Aviso: Iniciado sem dados locais pré-carregados.', Colors.orange);
    }
  }

  // 2. BUSCA AS ATUALIZAÇÕES DIRETO DA PLANILHA
  Future<void> _sincronizarComGoogleDrive() async {
    if (_sincronizandoComPlanilha) return;

    setState(() => _sincronizandoComPlanilha = true);
    _mostrarSnackBar('Buscando atualizações na planilha do Drive...', Colors.blueGrey);

    try {
      final url = Uri.parse(
          'https://docs.google.com/spreadsheets/d/1fUpL6AOxFmk_RI66E09asktSYi4vyoRQ2P8ivcfiivI/export?format=csv&gid=1606226965');

      final resposta = await http.get(url).timeout(const Duration(seconds: 15));

      if (resposta.statusCode == 200) {
        String csvDados = utf8.decode(resposta.bodyBytes);
        List<Map<String, dynamic>> novosDados = _converterCsvParaLista(csvDados);

        if (novosDados.isNotEmpty) {
          setState(() {
            _todosSemaforos = novosDados;
            _sincronizandoComPlanilha = false;
          });
          _atualizarListaDeRotas();
          _aplicarFiltrosCombinados();
          _mostrarSnackBar('Sincronizado! ${_todosSemaforos.length} semáforos atualizados.', Colors.green);
        } else {
          throw Exception('Planilha retornou vazia ou formato inválido.');
        }
      } else {
        throw Exception('Erro de resposta: ${resposta.statusCode}');
      }
    } catch (e) {
      setState(() => _sincronizandoComPlanilha = false);
      _mostrarSnackBar('Falha na sincronização. Verifique a internet!', Colors.red);
    }
  }

  List<Map<String, dynamic>> _converterCsvParaLista(String csvText) {
    List<List<String>> linhas = _parseCsvRobusto(csvText, csvText.contains(';') ? ';' : ',');
    if (linhas.length <= 1) return [];

    List<Map<String, dynamic>> lista = [];
    List<String> cabecalhos = linhas.first.map((h) => h.trim()).toList(); 

    for (int i = 1; i < linhas.length; i++) {
      List<String> colunas = linhas[i];
      if (colunas.isEmpty || (colunas.length == 1 && colunas[0].trim().isEmpty)) continue;

      Map<String, dynamic> mapaSemaforo = {};
      for (int j = 0; j < cabecalhos.length; j++) {
        mapaSemaforo[cabecalhos[j]] = j < colunas.length ? colunas[j].trim() : '';
      }
      
      String idStr = _obterValorCampo(mapaSemaforo, "SEMÁFORO");
      String endStr = _obterValorCampo(mapaSemaforo, "ENDEREÇO");
      if (idStr.isNotEmpty || endStr.isNotEmpty) {
        lista.add(mapaSemaforo);
      }
    }
    return lista;
  }

  List<List<String>> _parseCsvRobusto(String text, String separator) {
    List<List<String>> rows = [];
    List<String> currentRow = [];
    StringBuffer currentCell = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
          currentCell.write('"'); 
          i++; 
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == separator && !inQuotes) {
        currentRow.add(currentCell.toString().trim());
        currentCell.clear();
      } else if (char == '\n' && !inQuotes) {
        currentRow.add(currentCell.toString().trim());
        rows.add(currentRow);
        currentRow = [];
        currentCell.clear();
      } else if (char == '\r' && !inQuotes) {
        // Ignora
      } else {
        currentCell.write(char);
      }
    }
    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString().trim());
      rows.add(currentRow);
    }
    return rows;
  }

  // FILTRAGEM COMBINADA RESTRITA APENAS A NÚMERO, ENDEREÇO E BAIRRO
  void _aplicarFiltrosCombinados() {
    setState(() {
      _semaforosFiltrados = _todosSemaforos.where((item) {
        final Map<String, dynamic> semaforo = Map<String, dynamic>.from(item);
        
        bool passaRota = false;
        if (_rotaSelecionada == 'Todas') {
          passaRota = true;
        } else {
          String rotaRaw = _obterValorCampo(semaforo, "ROTA").trim();
          String rotaFormatadaItem = rotaRaw;
          if (rotaRaw.isNotEmpty && !rotaRaw.toLowerCase().contains('rota')) {
            rotaFormatadaItem = 'Rota ${rotaRaw.padLeft(2, '0')}';
          }
          passaRota = (rotaFormatadaItem.toLowerCase() == _rotaSelecionada.toLowerCase());
        }

        bool passaTexto = false;
        if (_textoPesquisa.isEmpty) {
          passaTexto = true;
        } else {
          String numero = _obterValorCampo(semaforo, "SEMÁFORO").toLowerCase();
          String endereco = _obterValorCampo(semaforo, "ENDEREÇO").toLowerCase();
          String bairro = _obterValorCampo(semaforo, "BAIRRO").toLowerCase();

          passaTexto = numero.contains(_textoPesquisa) || 
                       endereco.contains(_textoPesquisa) || 
                       bairro.contains(_textoPesquisa);
        }

        return passaRota && passaTexto;
      }).toList();
    });
  }

  void _mostrarOpcoesGPS(BuildContext context, String georeferencia) {
    if (georeferencia.trim().isEmpty || !georeferencia.contains(',')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semáforo sem coordenadas válidas!'), backgroundColor: Colors.orange));
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
                const Text('Como deseja chegar ao semáforo?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade400, 
                          foregroundColor: Colors.white, 
                          padding: const EdgeInsets.symmetric(vertical: 14), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        icon: const Icon(Icons.directions_car, size: 24),
                        label: const Text('Waze', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                          padding: const EdgeInsets.symmetric(vertical: 14), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        icon: const Icon(Icons.map, size: 24),
                        label: const Text('Google Maps', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
      String geoLimpa = georeferencia.trim();
      List<String> partes = geoLimpa.split(',');
      if (partes.length < 2) throw 'Formato inválido';

      String lat = partes[0].trim();
      String lng = partes[1].trim();

      Uri url = app == 'waze' 
          ? Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes')
          : Uri.parse('http://maps.google.com/maps?daddr=$lat,$lng'); 

      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Erro ao abrir';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir o $app.'), backgroundColor: Colors.red));
      }
    }
  }

  void _mostrarSnackBar(String mensagem, Color corFundo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: corFundo,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // POPUP MODAL DETALHADO DO SEMÁFORO
  void _mostrarDetalhesSemaforo(Map<String, dynamic> semaforo, String numero, Color corRota) {
    String endereco = _obterValorCampo(semaforo, "ENDEREÇO");
    String bairro = _obterValorCampo(semaforo, "BAIRRO");
    String georef = _obterValorCampo(semaforo, "GEOREFERÊNCIA").trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75, 
          minChildSize: 0.5,
          maxChildSize: 0.95, 
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 5,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: corRota, 
                          radius: 26,
                          child: Text(
                            numero,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                endereco.isNotEmpty ? endereco : 'Semáforo Nº $numero',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.5,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bairro.isNotEmpty ? bairro : 'Bairro não informado',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                  ),
                  const Divider(thickness: 1, height: 20),

                  if (georef.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 12.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: corRota,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.directions, size: 22),
                          label: const Text('COMO CHEGAR (GPS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: () => _mostrarOpcoesGPS(context, georef),
                        ),
                      ),
                    ),

                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      itemCount: _ordemCamposExibicao.length,
                      itemBuilder: (context, index) {
                        final String StringchaveOriginal = _ordemCamposExibicao[index];
                        String valor = _obterValorCampo(semaforo, StringchaveOriginal).trim();

                        if (valor.isEmpty) {
                          valor = "-";
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.label_important_outline, size: 18, color: corRota),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
                                    children: [
                                      TextSpan(
                                        text: '${StringchaveOriginal.toUpperCase()}\n',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: valor,
                                        style: TextStyle(
                                          fontWeight: valor == "-" ? FontWeight.w300 : FontWeight.w400, 
                                          fontSize: 14.5,
                                          color: valor == "-" ? Colors.grey : Colors.black87
                                        ),
                                      ),
                                    ],
                                  ),
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

  // =========================================================================
  // MODIFICADO: NOVAS FUNÇÕES PARA EXPORTAÇÃO EXCLUSIVAS DA ABA DE RELATÓRIOS
  // =========================================================================
  List<dynamic> _filtrarDadosParaRelatorio() {
    if (_rotaSelecionadaRelatorio == 'Todas') {
      return _todosSemaforos;
    }
    return _todosSemaforos.where((item) {
      final Map<String, dynamic> semaforo = Map<String, dynamic>.from(item);
      String rotaRaw = _obterValorCampo(semaforo, "ROTA").trim();
      String rotaFormatadaItem = rotaRaw;
      if (rotaRaw.isNotEmpty && !rotaRaw.toLowerCase().contains('rota')) {
        rotaFormatadaItem = 'Rota ${rotaRaw.padLeft(2, '0')}';
      }
      return (rotaFormatadaItem.toLowerCase() == _rotaSelecionadaRelatorio.toLowerCase());
    }).toList();
  }

Future<void> _exportarRelatorioPDF(List<dynamic> dados) async {
    if (dados.isEmpty) {
      _mostrarSnackBar('Nenhum semáforo encontrado para exportação.', Colors.orange);
      return;
    }
    _mostrarSnackBar('Gerando PDF do Relatório...', Colors.teal);

    try {
      final now = DateTime.now();
      final String dataHoraAtual = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      
      await Printing.layoutPdf(
        name: 'Relatorio_${_rotaSelecionadaRelatorio.replaceAll(' ', '_')}.pdf',
        onLayout: (PdfPageFormat format) async {
          final pdf = pw.Document();
          pdf.addPage(
            pw.MultiPage(
              pageFormat: format, 
              margin: const pw.EdgeInsets.all(24),
              footer: (pw.Context context) {
                return pw.Column(
                  children: [
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Gerado pelo sistema de vistoria da CTTU em $dataHoraAtual', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Pág. ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9)),
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
                        pw.Text('Semáforos da Rota - CTTU', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Filtro: $_rotaSelecionadaRelatorio | Total de registros: ${dados.length}', style: const pw.TextStyle(fontSize: 12)),
                      ]
                    )
                  ),
                  pw.SizedBox(height: 16),
                  pw.TableHelper.fromTextArray(
                    context: context,
                    headers: ['SEMÁFORO', 'ENDEREÇO', 'BAIRRO', 'EMPRESA', 'ROTA'],
                    data: dados.map((item) {
                      final s = Map<String, dynamic>.from(item);
                      return [
                        _obterValorCampo(s, "SEMÁFORO"),
                        _obterValorCampo(s, "ENDEREÇO"),
                        _obterValorCampo(s, "BAIRRO"),
                        _obterValorCampo(s, "EMPRESA"),
                        _obterValorCampo(s, "ROTA"),
                      ];
                    }).toList(),
                    // CENTRALIZAÇÃO HORIZONTAL E VERTICAL NO MEIO DA CÉLULA
                    cellAlignment: pw.Alignment.center,
                    headerAlignment: pw.Alignment.center,
                    // DIMINUIÇÃO DA FONTE PARA EVITAR QUEBRAS DE LINHA
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.orange700),
                    cellStyle: const pw.TextStyle(fontSize: 7),
                  ),
                ];
              }
            )
          );
          return pdf.save();
        }
      );
    } catch (e) {
      _mostrarSnackBar('Erro ao gerar PDF!', Colors.red);
    }
  }

Future<void> _exportarRelatorioExcel(List<dynamic> dados) async {
    if (dados.isEmpty) {
      _mostrarSnackBar('Nenhum semáforo encontrado para exportação.', Colors.orange);
      return;
    }
    _mostrarSnackBar('Gerando Planilha Excel...', Colors.green);

    try {
      // Monta a estrutura da planilha em formato SpreadsheetML/HTML reconhecido nativamente pelo Excel
      StringBuffer excelBuffer = StringBuffer();
      excelBuffer.write('<!DOCTYPE html>');
      excelBuffer.write('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">');
      excelBuffer.write('<head><meta charset="utf-8"></head>');
      excelBuffer.write('<body>');
      excelBuffer.write('<table border="1">');
      
      // Cabeçalho Oficial com estilização de cor
      excelBuffer.write('<tr style="background-color: #E65100; color: white; font-weight: bold; text-align: center;">');
      excelBuffer.write('<td>SEMÁFORO</td>');
      excelBuffer.write('<td>ENDEREÇO</td>');
      excelBuffer.write('<td>BAIRRO</td>');
      excelBuffer.write('<td>EMPRESA</td>');
      excelBuffer.write('<td>ROTA</td>');
      excelBuffer.write('<td>GEOREFERÊNCIA</td>');
      excelBuffer.write('</tr>');

      // Alimentando as linhas da planilha célula por célula
      for (var item in dados) {
        if (item is! Map) continue;
        final s = Map<String, dynamic>.from(item);
        
        String num = _obterValorCampo(s, "SEMÁFORO");
        String endereco = _obterValorCampo(s, "ENDEREÇO"); 
        String bairro = _obterValorCampo(s, "BAIRRO");
        String empresa = _obterValorCampo(s, "EMPRESA");
        String rota = _obterValorCampo(s, "ROTA");
        String coords = _obterValorCampo(s, "GEOREFERÊNCIA");
        
        excelBuffer.write('<tr>');
        excelBuffer.write('<td style="text-align: center;">$num</td>');
        excelBuffer.write('<td>$endereco</td>');
        excelBuffer.write('<td>$bairro</td>');
        excelBuffer.write('<td>$empresa</td>');
        excelBuffer.write('<td style="text-align: center;">$rota</td>');
        excelBuffer.write('<td style="text-align: center;">$coords</td>');
        excelBuffer.write('</tr>');
      }

      excelBuffer.write('</table>');
      excelBuffer.write('</body>');
      excelBuffer.write('</html>');

      // Define o nome correto com a extensão .xls do Excel
      final String nomeArquivo = 'Relatorio_${_rotaSelecionadaRelatorio.replaceAll(' ', '_')}.xls';
      
      // Converte os dados em bytes diretamente na memória (Cross-platform: Web, Android, iOS)
      final bytes = utf8.encode(excelBuffer.toString());
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: nomeArquivo,
        mimeType: 'application/vnd.ms-excel', // Tipo MIME oficial do Excel
      );

      // Dispara o download nativo na Web ou a folha de compartilhamento em dispositivos móveis
      await Share.shareXFiles(
        [xFile], 
        text: 'Relatório CTTU - Rota $_rotaSelecionadaRelatorio'
      );
    } catch (e) {
      debugPrint('Erro detalhado da Planilha: $e');
      _mostrarSnackBar('Erro ao gerar Planilha: $e', Colors.red);
    }
  }

  // WIDGET CONSTRUTOR DA NOVA INTERFACE DE RELATÓRIOS
  Widget _construirAbaRelatorios() {
    final dadosRelatorio = _filtrarDadosParaRelatorio();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exportação de Relatórios Gerenciais',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Selecione uma rota específica ou exporte toda a base de semáforos consolidada.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Seletor de Rota do Relatório
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Selecione a Rota para o Relatório',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _rotaSelecionadaRelatorio,
                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                isExpanded: true,
                items: _listaRotasDisponiveis.map((String rota) {
                  return DropdownMenuItem(value: rota, child: Text(rota));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _rotaSelecionadaRelatorio = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Badge Informativo do volume de dados
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Registros encontrados para exportação: ${dadosRelatorio.length}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 13.5),
                ),
              ],
            ),
          ),
          const Spacer(),
          
          // Botões de Ação de Download/Compartilhamento
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('EXPORTAR PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _exportarRelatorioPDF(dadosRelatorio),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.grid_on),
                  label: const Text('EXPORTAR EXCEL', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _exportarRelatorioExcel(dadosRelatorio),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // MODIFICADO: Inclusão do DefaultTabController englobando o Scaffold
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Acervo de Semáforos', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange.shade500,
          foregroundColor: Colors.white,
          elevation: 2,
          // MODIFICADO: Barra de Abas adicionada na parte inferior da AppBar
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.list), text: 'Lista Geral'),
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Relatórios'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.map, size: 26),
              tooltip: 'Abrir Visão do Mapa',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TelaMapa(
                      todosSemaforos: _todosSemaforos,
                      listaRotasDisponiveis: _listaRotasDisponiveis,
                      ordemCamposExibicao: _ordemCamposExibicao,
                    ),
                  ),
                );
              },
            ),
            _sincronizandoComPlanilha
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.cloud_sync, size: 28),
                    tooltip: 'Sincronizar com Planilha',
                    onPressed: _sincronizarComGoogleDrive,
                  ),
          ],
        ),
        body: _carregando
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 16),
                    Text('Carregando acervo básico...'),
                  ],
                ),
              )
            : TabBarView(
                // MODIFICADO: TabBarView alternando entre a Lista Geral e a Aba de Relatórios
                children: [
                  // ABA 1: LISTA GERAL EXISTENTE
                  Column(
                    children: [
                      Container(
                        color: Colors.orange.shade50,
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: _pesquisaController,
                                onChanged: (busca) {
                                  _textoPesquisa = busca.toLowerCase();
                                  _aplicarFiltrosCombinados();
                                },
                                decoration: InputDecoration(
                                  labelText: 'Pesquisar...',
                                  prefixIcon: const Icon(Icons.search, color: Colors.orange),
                                  suffixIcon: _textoPesquisa.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 20),
                                          onPressed: () {
                                            _pesquisaController.clear();
                                            _textoPesquisa = '';
                                            _aplicarFiltrosCombinados();
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Rota', 
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 4),
                                  isDense: true,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _rotaSelecionada,
                                    style: const TextStyle(color: Colors.black87, fontSize: 13.5, fontWeight: FontWeight.w500),
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    items: _listaRotasDisponiveis.map((String rotaItem) {
                                      return DropdownMenuItem<String>(
                                        value: rotaItem,
                                        child: Text(rotaItem),
                                      );
                                    }).toList(),
                                    onChanged: (novoValor) {
                                      if (novoValor != null) {
                                        _rotaSelecionada = novoValor;
                                        _aplicarFiltrosCombinados();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mostrando ${_semaforosFiltrados.length} semáforos',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            ),
                            Text(
                              'Base: ${_todosSemaforos.length}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: _semaforosFiltrados.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nenhum semáforo encontrado.',
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                itemCount: _semaforosFiltrados.length,
                                itemBuilder: (context, index) {
                                  final Map<String, dynamic> semaforo = Map<String, dynamic>.from(_semaforosFiltrados[index]);
                                  
                                  String numero = _obterValorCampo(semaforo, "SEMÁFORO");
                                  String endereco = _obterValorCampo(semaforo, "ENDEREÇO");
                                  String bairro = _obterValorCampo(semaforo, "BAIRRO");
                                  String empresa = _obterValorCampo(semaforo, "EMPRESA");
                                  String rotaRaw = _obterValorCampo(semaforo, "ROTA");

                                  if (numero.isEmpty) numero = 'N/A';
                                  if (endereco.isEmpty) endereco = 'Sem endereço';
                                  if (empresa.isEmpty) empresa = 'S/E';

                                  String rotaFormatada = rotaRaw;
                                  if (rotaRaw.isNotEmpty && !rotaRaw.toLowerCase().contains('rota')) {
                                    rotaFormatada = 'ROTA ${rotaRaw.padLeft(2, '0')}';
                                  } else if (rotaRaw.isEmpty) {
                                    rotaFormatada = 'SEM ROTA';
                                  }

                                  final Color corDaRota = _obterCorDaRota(rotaRaw);

                                  String tituloCard = "$numero - $endereco${bairro.isNotEmpty ? ' ($bairro)' : ''}";
                                  String subtituloCard = "$empresa - $rotaFormatada";

                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _mostrarDetalhesSemaforo(semaforo, numero, corDaRota),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: corDaRota,
                                              radius: 24,
                                              child: Text(
                                                numero,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    tituloCard,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14.5,
                                                      color: Colors.black87,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    subtituloCard,
                                                    style: TextStyle(
                                                      color: Colors.grey.shade700, 
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w500
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
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
                  
                  // ABA 2: NOVA SEÇÃO DE RELATÓRIOS CONSTRUÍDA
                  _construirAbaRelatorios(),
                ],
              ),
      ),
    );
  }
}

// =========================================================================
// TELA MAPA COMPLETA COM FILTROS DE ROTA E EMPRESA DINÂMICOS
// =========================================================================
class TelaMapa extends StatefulWidget {
  final List<dynamic> todosSemaforos;
  final List<String> listaRotasDisponiveis;
  final List<String> ordemCamposExibicao;

  const TelaMapa({
    super.key, 
    required this.todosSemaforos, 
    required this.listaRotasDisponiveis,
    required this.ordemCamposExibicao
  });

  @override
  State<TelaMapa> createState() => _TelaMapaState();
}

class _TelaMapaState extends State<TelaMapa> {
  List<dynamic> _semaforosFiltradosNoMapa = [];
  List<String> _listaEmpresasDisponiveis = ['Todas']; 
  String _textoPesquisa = '';
  String _rotaSelecionada = 'Todas';
  String _empresaSelecionada = 'Todas'; 
  final TextEditingController _mapPesquisaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _semaforosFiltradosNoMapa = widget.todosSemaforos;
    _atualizarListaDeEmpresas(); 
  }

  @override
  void dispose() {
    _mapPesquisaController.dispose();
    super.dispose();
  }

  String _obterValorCampo(Map<String, dynamic> semaforo, String chaveOriginal) {
    if (semaforo.containsKey(chaveOriginal)) return semaforo[chaveOriginal].toString();
    String chaveMinuscula = chaveOriginal.toLowerCase();
    if (semaforo.containsKey(chaveMinuscula)) return semaforo[chaveMinuscula].toString();
    for (var entry in semaforo.entries) {
      if (entry.key.trim().toLowerCase() == chaveMinuscula) return entry.value.toString();
    }
    if (chaveMinuscula == 'semáforo' || chaveMinuscula == 'semaforo') {
      return (semaforo['id'] ?? semaforo['semáforo'] ?? semaforo['semaforo'] ?? '').toString();
    }
    if (chaveMinuscula == 'endereço' || chaveMinuscula == 'endereco') {
      return (semaforo['endereco'] ?? semaforo['endereço'] ?? '').toString();
    }
    if (chaveMinuscula == 'empresa') {
      return (semaforo['empresa'] ?? '').toString();
    }
    return '';
  }

  Color _obterCorDaRota(String rota) {
    String r = rota.trim().toUpperCase().replaceAll('ROTA', '').replaceAll(' ', '');
    if (r.isEmpty) return Colors.grey.shade600;
    switch (r) {
      case '1': case '01': return Colors.blue.shade700;
      case '2': case '02': return Colors.green.shade700;
      case '3': case '03': return Colors.red.shade700;
      case '4': case '04': return Colors.purple.shade700;
      case '5': case '05': return Colors.amber.shade800;
      case '6': case '06': return Colors.teal.shade700;
      case '7': case '07': return Colors.indigo.shade700;
      case '8': case '08': return Colors.pink.shade700;
      case '9': case '09': return Colors.cyan.shade800;
      case '10': return Colors.deepOrange.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  void _atualizarListaDeEmpresas() {
    Set<String> empresasSet = {};
    for (var item in widget.todosSemaforos) {
      final Map<String, dynamic> s = Map<String, dynamic>.from(item);
      String emp = _obterValorCampo(s, "EMPRESA").trim();
      if (emp.isNotEmpty && emp != "S/E") {
        empresasSet.add(emp);
      }
    }
    List<String> ordenadas = empresasSet.toList()..sort();
    setState(() {
      _listaEmpresasDisponiveis = ['Todas', ...ordenadas];
    });
  }

  void _aplicarFiltrosCombinadosNoMapa() {
    setState(() {
      _semaforosFiltradosNoMapa = widget.todosSemaforos.where((item) {
        final Map<String, dynamic> semaforo = Map<String, dynamic>.from(item);
        
        bool passaRota = false;
        if (_rotaSelecionada == 'Todas') {
          passaRota = true;
        } else {
          String rotaRaw = _obterValorCampo(semaforo, "ROTA").trim();
          String rotaFormatadaItem = rotaRaw;
          if (rotaRaw.isNotEmpty && !rotaRaw.toLowerCase().contains('rota')) {
            rotaFormatadaItem = 'Rota ${rotaRaw.padLeft(2, '0')}';
          }
          passaRota = (rotaFormatadaItem.toLowerCase() == _rotaSelecionada.toLowerCase());
        }

        bool passaEmpresa = false;
        if (_empresaSelecionada == 'Todas') {
          passaEmpresa = true;
        } else {
          String empRaw = _obterValorCampo(semaforo, "EMPRESA").trim();
          passaEmpresa = (empRaw.toLowerCase() == _empresaSelecionada.toLowerCase());
        }

        bool passaTexto = false;
        if (_textoPesquisa.isEmpty) {
          passaTexto = true;
        } else {
          String numero = _obterValorCampo(semaforo, "SEMÁFORO").toLowerCase();
          String endereco = _obterValorCampo(semaforo, "ENDEREÇO").toLowerCase();
          String bairro = _obterValorCampo(semaforo, "BAIRRO").toLowerCase();

          passaTexto = numero.contains(_textoPesquisa) || 
                       endereco.contains(_textoPesquisa) || 
                       bairro.contains(_textoPesquisa);
        }

        return passaRota && passaEmpresa && passaTexto;
      }).toList();
    });
  }

  void _mostrarOpcoesGPS(BuildContext context, String georeferencia) {
    if (georeferencia.trim().isEmpty || !georeferencia.contains(',')) return;
    List<String> partes = georeferencia.split(',');
    String lat = partes[0].trim();
    String lng = partes[1].trim();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade400, foregroundColor: Colors.white),
                    onPressed: () => launchUrl(Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes'), mode: LaunchMode.externalApplication),
                    child: const Text('Waze'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
                    onPressed: () => launchUrl(Uri.parse('http://maps.google.com/maps?daddr=$lat,$lng'), mode: LaunchMode.externalApplication),
                    child: const Text('Google Maps'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _mostrarDetalhesSemaforoNoMapa(Map<String, dynamic> semaforo, String numero, Color corRota) {
    String endereco = _obterValorCampo(semaforo, "ENDEREÇO");
    String bairro = _obterValorCampo(semaforo, "BAIRRO");
    String georef = _obterValorCampo(semaforo, "GEOREFERÊNCIA").trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75, 
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 5, width: 50, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: corRota, radius: 26, child: Text(numero, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(endereco.isNotEmpty ? endereco : 'Semáforo Nº $numero', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text(bairro.isNotEmpty ? bairro : 'Bairro não informado', style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
                        ])),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                      ],
                    ),
                  ),
                  const Divider(thickness: 1, height: 20),
                  if (georef.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 12.0),
                      child: SizedBox(
                        width: double.infinity, height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: corRota, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          icon: const Icon(Icons.directions),
                          label: const Text('COMO CHEGAR (GPS)', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _mostrarOpcoesGPS(context, georef),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: widget.ordemCamposExibicao.length,
                      itemBuilder: (context, index) {
                        final String chaveOriginal = widget.ordemCamposExibicao[index];
                        String valor = _obterValorCampo(semaforo, chaveOriginal).trim();
                        if (valor.isEmpty) valor = "-";

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                          child: Row(
                            children: [
                              Icon(Icons.label_important_outline, size: 18, color: corRota),
                              const SizedBox(width: 10),
                              Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [
                                TextSpan(text: '${chaveOriginal.toUpperCase()}\n', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 11.5)),
                                TextSpan(text: valor, style: TextStyle(color: valor == "-" ? Colors.grey : Colors.black87)),
                              ]))),
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

  List<Marker> _construirMarcadoresDoMapa() {
    List<Marker> marcadores = [];
    for (var item in _semaforosFiltradosNoMapa) {
      final Map<String, dynamic> semaforo = Map<String, dynamic>.from(item);
      String georef = _obterValorCampo(semaforo, "GEOREFERÊNCIA").trim();
      
      if (georef.contains(',')) {
        List<String> partes = georef.split(',');
        double? lat = double.tryParse(partes[0].trim());
        double? lng = double.tryParse(partes[1].trim());

        if (lat != null && lng != null) {
          String numero = _obterValorCampo(semaforo, "SEMÁFORO");
          String rotaRaw = _obterValorCampo(semaforo, "ROTA");
          Color corDaRota = _obterCorDaRota(rotaRaw);

          marcadores.add(
            Marker(
              point: LatLng(lat, lng),
              width: 38,
              height: 38,
              child: GestureDetector(
                onTap: () => _mostrarDetalhesSemaforoNoMapa(semaforo, numero, corDaRota),
                child: Container(
                  decoration: BoxDecoration(
                    color: corDaRota,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Center(
                    child: Text(
                      numero,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }
    return marcadores;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão do Mapa', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade500,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.orange.shade50,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _mapPesquisaController,
                  onChanged: (busca) {
                    _textoPesquisa = busca.toLowerCase();
                    _aplicarFiltrosCombinadosNoMapa();
                  },
                  decoration: InputDecoration(
                    labelText: 'Pesquisar semáforo, endereço ou bairro...',
                    prefixIcon: const Icon(Icons.search, color: Colors.orange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true, fillColor: Colors.white, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Rota', 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true, fillColor: Colors.white, isDense: true,
                          contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _rotaSelecionada,
                            style: const TextStyle(color: Colors.black87, fontSize: 13.5, fontWeight: FontWeight.w500),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            items: widget.listaRotasDisponiveis.map((String rota) => DropdownMenuItem(value: rota, child: Text(rota))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                _rotaSelecionada = val;
                                _aplicarFiltrosCombinadosNoMapa();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Empresa', 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true, fillColor: Colors.white, isDense: true,
                          contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _empresaSelecionada,
                            style: const TextStyle(color: Colors.black87, fontSize: 13.5, fontWeight: FontWeight.w500),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            items: _listaEmpresasDisponiveis.map((String empresa) => DropdownMenuItem(value: empresa, child: Text(empresa))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                _empresaSelecionada = val;
                                _aplicarFiltrosCombinadosNoMapa();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(-8.05428, -34.8813), 
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.vistoria.cttu',
                ),
                MarkerLayer(markers: _construirMarcadoresDoMapa()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}