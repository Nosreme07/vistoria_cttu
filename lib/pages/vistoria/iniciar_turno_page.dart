import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class IniciarTurnoPage extends StatefulWidget {
  const IniciarTurnoPage({super.key});

  @override
  State<IniciarTurnoPage> createState() => _IniciarTurnoPageState();
}

class _IniciarTurnoPageState extends State<IniciarTurnoPage> {
  // Controles Iniciar Turno
  final _kmInicialController = TextEditingController();
  
  // Controles Encerrar Turno
  final _kmFinalController = TextEditingController();

  String? _veiculoSelecionadoId;
  String? _veiculoSelecionadoPlaca;
  String? _rotaSelecionada; 

  String _nomeVistoriador = '';
  String? _fotoUrlVistoriador; // Guarda a URL da foto de perfil do vistoriador logado
  bool _confirmouIdentidade = false; 
  
  // Gerenciamento de Estado da Tela
  bool _carregandoInicial = true;
  bool _processando = false; 
  bool _isAdmin = false;
  
  // Dados do Turno Ativo (se o vistoriador já tiver um)
  String? _turnoAtivoId;
  Map<String, dynamic>? _turnoAtivoData;

  // Variáveis para carregar o acervo mestre de rotas via Planilha
  List<String> _todasAsRotasDaPlanilha = [];
  
  // ==== ADICIONADO: Lista para guardar o acervo e conseguir calcular as Metas (%) ====
  List<Map<String, dynamic>> _todosSemaforosAcervo = [];
  
  bool _carregandoRotas = true;

  // Filtros da aba administrativa (Concluídos)
  DateTime? _dataInicioFiltro;
  DateTime? _dataFimFiltro;
  String _rotaFiltro = 'Todas';
  bool _filtrosAplicadosConcluidos = false;

  // Cache em memória RAM para evitar leituras repetidas de fotos no Firebase
  final Map<String, String?> _cacheFotos = {};

  @override
  void initState() {
    super.initState();
    _buscarDadosIniciais();
  }

  @override
  void dispose() {
    _kmInicialController.dispose();
    _kmFinalController.dispose();
    super.dispose();
  }

  // ========================================================================
  // BUSCA DE FOTO INTELIGENTE (COLEÇÃO USUÁRIOS OU HISTÓRICO DO TURNO)
  // ========================================================================
  Future<String?> _buscarFotoVistoriador(String uid, Map<String, dynamic> turnoData) async {
    String? fotoTurno = (turnoData['vistoriador_foto_url'] ?? turnoData['foto_url'])?.toString();
    if (fotoTurno != null && fotoTurno.isNotEmpty) return fotoTurno;

    if (uid.isEmpty) return null;
    if (_cacheFotos.containsKey(uid)) return _cacheFotos[uid];

    try {
      var doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        String? url = doc.data()!['foto_url']?.toString();
        _cacheFotos[uid] = url; 
        return url;
      }
    } catch (e) {
      debugPrint('Erro ao recuperar foto de usuário: $e');
    }
    _cacheFotos[uid] = null;
    return null;
  }

  // ========================================================================
  // CARREGAMENTO DOS DADOS INICIAIS DO USUÁRIO E ROTAS DISPONÍVEIS
  // ========================================================================
  Future<void> _buscarDadosIniciais() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docUser = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (docUser.exists) {
        final dataUser = docUser.data()!;
        _nomeVistoriador = dataUser['nome_completo'] ?? dataUser['nome'] ?? user.email!;
        _fotoUrlVistoriador = dataUser['foto_url'] as String?;
        
        String perfil = (dataUser['perfil'] ?? '').toString().toLowerCase(); 
        if (perfil.contains('administrador') || perfil.contains('admin')) {
          _isAdmin = true;
        }
      }

      if (!_isAdmin) {
        final turnoAtivoQuery = await FirebaseFirestore.instance
            .collection('turnos')
            .where('vistoriador_uid', isEqualTo: user.uid)
            .where('status', isEqualTo: 'ativo')
            .limit(1)
            .get();

        if (turnoAtivoQuery.docs.isNotEmpty) {
          _turnoAtivoId = turnoAtivoQuery.docs.first.id;
          _turnoAtivoData = turnoAtivoQuery.docs.first.data();
        }
      }

      const url = 'https://docs.google.com/spreadsheets/d/1fUpL6AOxFmk_RI66E09asktSYi4vyoRQ2P8ivcfiivI/export?format=tsv&gid=1606226965';
      final resposta = await http.get(Uri.parse(url));
      
      Set<String> rotasExtraidas = {};
      List<Map<String, dynamic>> acervoTemporario = []; // Auxiliar para popular o Acervo

      if (resposta.statusCode == 200) {
        final tsvString = utf8.decode(resposta.bodyBytes);
        List<String> linhas = tsvString.split('\n');
        
        if (linhas.length > 1) {
          List<String> cabecalhos = linhas.first.split('\t').map((c) => c.trim().toLowerCase()).toList();
          for (int i = 1; i < linhas.length; i++) {
            String linhaAtual = linhas[i].trim();
            if (linhaAtual.isEmpty) continue;

            List<String> valores = linhaAtual.split('\t');
            Map<String, dynamic> item = {};
            for (int j = 0; j < cabecalhos.length; j++) {
              if (j < valores.length) item[cabecalhos[j]] = valores[j].trim();
            }

            acervoTemporario.add(item); // Salva o item para calcular % depois

            String rotaLimpa = (item['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
            if (rotaLimpa.isNotEmpty && rotaLimpa != 'S/R') {
              rotasExtraidas.add(rotaLimpa);
            }
          }
        }
      }

      List<String> listaRotas = rotasExtraidas.toList();
      listaRotas.sort((a, b) {
        int numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        int numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        int comparacao = numA.compareTo(numB);
        if (comparacao == 0) return a.compareTo(b);
        return comparacao;
      });

      if (mounted) {
        setState(() {
          _todasAsRotasDaPlanilha = listaRotas;
          _todosSemaforosAcervo = acervoTemporario; // Atualiza o Acervo Mestre
          _carregandoRotas = false;
          _carregandoInicial = false;
        });
      }
      
    } catch (e) {
      debugPrint('Erro ao carregar dados iniciais: $e');
      if (mounted) {
        setState(() {
          _carregandoRotas = false;
          _carregandoInicial = false;
        });
      }
    }
  }

  // ==========================================
  // INICIALIZAÇÃO E PERSISTÊNCIA DO EXPEDIENTE
  // ==========================================
  Future<void> _salvarTurno() async {
    if (!_confirmouIdentidade) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, marque a caixa confirmando sua identidade!'), backgroundColor: Colors.orange));
      return;
    }

    if (_veiculoSelecionadoId == null || _rotaSelecionada == null || _kmInicialController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos obrigatórios!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _processando = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      final novoTurnoRef = await FirebaseFirestore.instance.collection('turnos').add({
        'vistoriador_uid': user.uid,
        'vistoriador_nome': _nomeVistoriador,
        'vistoriador_foto_url': _fotoUrlVistoriador, 
        'veiculo_id': _veiculoSelecionadoId,
        'placa': _veiculoSelecionadoPlaca,
        'km_inicial': _kmInicialController.text.trim(),
        'km_final': null,
        'rota_numero': _rotaSelecionada, 
        'status': 'ativo', 
        'data_inicio': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('veiculos').doc(_veiculoSelecionadoId).update({'em_uso': true});

      final turnoCriado = await novoTurnoRef.get();
      setState(() {
        _turnoAtivoId = turnoCriado.id;
        _turnoAtivoData = turnoCriado.data();
        _processando = false;
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turno Iniciado com sucesso! Boa vistoria.'), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _processando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao iniciar turno: $e'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // FINALIZAÇÃO DO TURNO EM CAMPO
  // ==========================================
  Future<void> _encerrarTurno() async {
    if (_kmFinalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a Quilometragem (KM) Final!'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _processando = true);

    try {
      await FirebaseFirestore.instance.collection('turnos').doc(_turnoAtivoId).update({
        'status': 'concluido',
        'km_final': _kmFinalController.text.trim(),
        'data_fim': FieldValue.serverTimestamp(),
      });

      String idVeiculo = _turnoAtivoData!['veiculo_id'];
      await FirebaseFirestore.instance.collection('veiculos').doc(idVeiculo).update({'em_uso': false});

      setState(() {
        _turnoAtivoId = null; _turnoAtivoData = null; _veiculoSelecionadoId = null; _rotaSelecionada = null;
        _kmInicialController.clear(); _kmFinalController.clear(); _confirmouIdentidade = false; _processando = false;
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turno Encerrado com sucesso! Excelente trabalho.'), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _processando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao encerrar turno: $e'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // CONFIGURAÇÃO DOS DATEPICKERS FILTROS ADMINISTRATIVOS
  // ==========================================
  Future<void> _selecionarData(BuildContext context, bool isInicio) async {
    DateTime initial = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context, initialDate: initial, firstDate: DateTime(2024), lastDate: DateTime.now(),
      helpText: isInicio ? 'SELECIONE A DATA INICIAL' : 'SELECIONE A DATA FINAL',
    );

    if (picked != null) {
      setState(() {
        if (isInicio) _dataInicioFiltro = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        else _dataFimFiltro = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  Widget _buildBotaoData(String label, DateTime? data, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.teal.shade200), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: Colors.teal.shade700), const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data == null ? label.toUpperCase() : DateFormat('dd/MM/yyyy').format(data),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: data == null ? Colors.grey : Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ==== ADICIONADO: FUNÇÃO PARA CALCULAR O PERCENTUAL DURANTE A EXPORTAÇÃO ====
  Future<String> _calcularPercentualExportacao(String turnoId, String rotaNumero) async {
    String rotaNumerica = rotaNumero.replaceAll(RegExp(r'[^0-9]'), '');
    int meta = _todosSemaforosAcervo.where((s) {
      String r = (s['rota'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
      return r == rotaNumerica && r.isNotEmpty;
    }).length;
    
    if (meta == 0) return '0%';

    var snap = await FirebaseFirestore.instance.collection('vistorias').where('turno_id', isEqualTo: turnoId).get();
    Set<String> vistoriados = snap.docs.map((d) => (d.data() as Map<String, dynamic>)['semaforo_id'].toString()).toSet();
    
    double perc = (vistoriados.length / meta) * 100;
    if (perc > 100) perc = 100; // Evita passar de 100% se houver vistorias extras
    return '${perc.toStringAsFixed(0)}%';
  }

  // ========================================================================
  // EXPORTAÇÃO COMPLETA EM PDF GLOBAL DOS TURNOS FINALIZADOS (ADMIN)
  // ========================================================================
  Future<void> _exportarPDFTurnos(List<DocumentSnapshot> turnos) async {
    if (turnos.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GERANDO EXPEDIENTES EM PDF...'), backgroundColor: Colors.teal));
    
    try {
      // Ordena a listagem da tabela do início mais antigo para o mais recente (Cronológica Crescente)
      List<DocumentSnapshot> turnosOrdenados = List.from(turnos);
      turnosOrdenados.sort((a, b) {
        var dataA = a.data() as Map<String, dynamic>; var dataB = b.data() as Map<String, dynamic>;
        Timestamp? tempoA = dataA['data_inicio'] as Timestamp?; Timestamp? tempoB = dataB['data_inicio'] as Timestamp?;
        if (tempoA == null && tempoB == null) return 0;
        if (tempoA == null) return 1; if (tempoB == null) return -1;
        return tempoA.compareTo(tempoB);
      });

      // Busca o percentual de todos os itens antes de gerar o PDF
      List<List<String>> dadosDaTabela = [];
      for (var doc in turnosOrdenados) {
        var t = doc.data() as Map<String, dynamic>;
        String inicio = t['data_inicio'] != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format((t['data_inicio'] as Timestamp).toDate()) : '-';
        String fim = t['data_fim'] != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format((t['data_fim'] as Timestamp).toDate()) : '-';
        
        // Chama a nova função para pegar a porcentagem exata deste turno
        String perc = await _calcularPercentualExportacao(doc.id, t['rota_numero']?.toString() ?? '');

        dadosDaTabela.add([
          (t['rota_numero'] ?? '-').toString().toUpperCase(),
          (t['vistoriador_nome'] ?? '-').toString().toUpperCase(),
          (t['placa'] ?? '-').toString().toUpperCase(),
          (t['km_inicial'] ?? '-').toString().toUpperCase(),
          (t['km_final'] ?? '-').toString().toUpperCase(),
          inicio, 
          fim,
          perc // Adiciona a porcentagem na linha
        ]);
      }

      final pdf = pw.Document();
      String dataHoraAtual = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()).toUpperCase();
      
      // Formatação e tratamento de filtros aplicados
      String deStr = _dataInicioFiltro != null ? DateFormat('dd/MM/yyyy').format(_dataInicioFiltro!) : '-';
      String ateStr = _dataFimFiltro != null ? DateFormat('dd/MM/yyyy').format(_dataFimFiltro!) : '-';
      String filtroPeriodo = "PERÍODO: $deStr ATÉ $ateStr";
      String filtroRota = _rotaFiltro == 'Todas' ? 'TODAS AS ROTAS' : 'ROTA $_rotaFiltro';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.center, margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Divider(thickness: 0.5, color: PdfColors.grey400), pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.SizedBox(width: 100),
                    pw.Text('RELATÓRIO GERADO PELO APLICATIVO VISTORIA CTTU ($dataHoraAtual)', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.Container(width: 100, alignment: pw.Alignment.centerRight, child: pw.Text('PÁG. ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))),
                  ],
                ),
              ],
            ),
          ),
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('RELATÓRIO DE EXPEDIENTE CONCLUÍDO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 4),
                pw.Text('$filtroRota  |  $filtroPeriodo', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              ])),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                context: context,
                // ==== MODIFICADO: COLUNA DE CONCLUSÃO ADICIONADA AO CABEÇALHO ====
                headers: ['ROTA', 'VISTORIADOR', 'MOTO', 'KM INICIAL', 'KM FINAL', 'INÍCIO', 'FIM', 'CONCLUÍDO'],
                data: dadosDaTabela,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.center,     
                headerAlignment: pw.Alignment.center,   
              ),
            ];
          }
        )
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'RELATORIO_EXPEDIENTES_CONCLUIDOS.pdf');
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERRO AO GERAR ARQUIVO PDF!'), backgroundColor: Colors.red));
    }
  }

  // ========================================================================
  // EXPORTAÇÃO EM CSV/EXCEL COMPATÍVEL COM WEB DA TABELA DE TURNOS
  // ========================================================================
  Future<void> _exportarXLSTurnos(List<DocumentSnapshot> turnos) async {
    if (turnos.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GERANDO PLANILHA EXCEL...'), backgroundColor: Colors.green));
    try {
      
      // Ordena também para o Excel
      List<DocumentSnapshot> turnosOrdenados = List.from(turnos);
      turnosOrdenados.sort((a, b) {
        var dataA = a.data() as Map<String, dynamic>; var dataB = b.data() as Map<String, dynamic>;
        Timestamp? tempoA = dataA['data_inicio'] as Timestamp?; Timestamp? tempoB = dataB['data_inicio'] as Timestamp?;
        if (tempoA == null && tempoB == null) return 0;
        if (tempoA == null) return 1; if (tempoB == null) return -1;
        return tempoA.compareTo(tempoB);
      });

      StringBuffer excelBuffer = StringBuffer();
      excelBuffer.write('<!DOCTYPE html><html><head><meta charset="utf-8"></head><body><table border="1">');
      // ==== MODIFICADO: COLUNA DE CONCLUSÃO ADICIONADA AO CABEÇALHO ====
      excelBuffer.write('<tr style="background-color: #00796B; color: white; font-weight: bold; text-align: center;"><td>ROTA</td><td>VISTORIADOR</td><td>MOTO</td><td>KM INICIAL</td><td>KM FINAL</td><td>INÍCIO</td><td>FIM</td><td>CONCLUÍDO</td></tr>');
      
      for (var doc in turnosOrdenados) {
        var t = doc.data() as Map<String, dynamic>;
        String inicio = t['data_inicio'] != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format((t['data_inicio'] as Timestamp).toDate()) : '-';
        String fim = t['data_fim'] != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format((t['data_fim'] as Timestamp).toDate()) : '-';
        
        // Chama a nova função para calcular
        String perc = await _calcularPercentualExportacao(doc.id, t['rota_numero']?.toString() ?? '');
        
        excelBuffer.write('<tr>');
        excelBuffer.write('<td style="text-align: center; vertical-align: middle;">${(t['rota_numero'] ?? '-').toString().toUpperCase()}</td>');
        excelBuffer.write('<td style="text-align: center; vertical-align: middle;">${(t['vistoriador_nome'] ?? '-').toString().toUpperCase()}</td>');
        excelBuffer.write('<td style="text-align: center; vertical-align: middle;">${(t['placa'] ?? '-').toString().toUpperCase()}</td>');
        excelBuffer.write('<td style="text-align: center; vertical-align: middle;">${(t['km_inicial'] ?? '-').toString().toUpperCase()}</td>');
        excelBuffer.write('<td style="text-align: center; vertical-align: middle;">${(t['km_final'] ?? '-').toString().toUpperCase()}</td>');
        excelBuffer.write('<td style="text-align: center; vertical-align: middle;">$inicio</td>');
        excelBuffer.write('<td style="text-align: center; vertical-align: middle;">$fim</td>');
        // ==== MODIFICADO: ADICIONADA CÉLULA COM A PORCENTAGEM ====
        excelBuffer.write('<td style="text-align: center; vertical-align: middle; color: green; font-weight: bold;">$perc</td>');
        excelBuffer.write('</tr>');
      }
      excelBuffer.write('</table></body></html>');
      
      final Uint8List bytes = Uint8List.fromList(utf8.encode(excelBuffer.toString()));
      final xFile = XFile.fromData(bytes, mimeType: 'application/vnd.ms-excel', name: 'TURNOS_CONCLUIDOS.XLS');
      await Share.shareXFiles([xFile], text: 'PLANILHA DE EXPEDIENTES CONCLUÍDOS');
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERRO AO GERAR PLANILHA EXCEL!'), backgroundColor: Colors.red));
    }
  }

  // ========================================================================
  // MODAL BOTTOM SHEET DE DETALHES GERAIS DO TURNO (VISÃO ADMIN COMPLETA)
  // ========================================================================
  void _mostrarDetalhesTurnoAdmin(Map<String, dynamic> t, String statusTurno, String? fotoUrl) {
    String horaInicio = t['data_inicio'] != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format((t['data_inicio'] as Timestamp).toDate()) : '-';
    String horaFim = t['data_fim'] != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format((t['data_fim'] as Timestamp).toDate()) : '-';
    String kmInicial = t['km_inicial']?.toString() ?? '-';
    String kmFinal = t['km_final']?.toString() ?? '-';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65, minChildSize: 0.5, maxChildSize: 0.9, expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: statusTurno == 'EM ANDAMENTO' ? Colors.teal.shade100 : Colors.green.shade100,
                      backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                      child: fotoUrl == null || fotoUrl.isEmpty 
                        ? Icon(Icons.person, size: 60, color: statusTurno == 'EM ANDAMENTO' ? Colors.teal : Colors.green) 
                        : null,
                    ),
                    const SizedBox(height: 16),
                    Text(t['vistoriador_nome']?.toString().toUpperCase() ?? 'DESCONHECIDO', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey), textAlign: TextAlign.center),
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 24), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: statusTurno == 'EM ANDAMENTO' ? Colors.orange.shade100 : Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Text(statusTurno, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusTurno == 'EM ANDAMENTO' ? Colors.orange.shade900 : Colors.green.shade800)),
                    ),
                    const Divider(), const SizedBox(height: 16),
                    _buildLinhaDetalheAdmin(Icons.route, 'Rota Assumida', 'ROTA ${t['rota_numero'] ?? '-'}'),
                    _buildLinhaDetalheAdmin(Icons.motorcycle, 'Veículo (Placa)', t['placa'] ?? '-'),
                    _buildLinhaDetalheAdmin(Icons.play_circle_fill, 'Início do Turno', horaInicio),
                    if (statusTurno == 'CONCLUÍDO') _buildLinhaDetalheAdmin(Icons.stop_circle, 'Fim do Turno', horaFim),
                    _buildLinhaDetalheAdmin(Icons.speed, 'KM Inicial', '$kmInicial km'),
                    if (statusTurno == 'CONCLUÍDO') _buildLinhaDetalheAdmin(Icons.flag, 'KM Final', '$kmFinal km'),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('FECHAR', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildLinhaDetalheAdmin(IconData icone, String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Icon(icone, color: Colors.blueGrey, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 1 DO ADMIN: EM ANDAMENTO
  // ==========================================
  Widget _buildAbaEmAndamento() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.teal.shade50,
          child: const Column(
            children: [
              Icon(Icons.directions_run, size: 48, color: Colors.teal),
              SizedBox(height: 8),
              Text('Vistoriadores em Rota', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              Text('Acompanhamento em tempo real', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('turnos').where('status', isEqualTo: 'ativo').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final turnos = snapshot.data!.docs.toList();
              
              turnos.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;
                Timestamp? tempoA = dataA['data_inicio'] as Timestamp?;
                Timestamp? tempoB = dataB['data_inicio'] as Timestamp?;
                if (tempoA == null && tempoB == null) return 0;
                if (tempoA == null) return 1;
                if (tempoB == null) return -1;
                return tempoB.compareTo(tempoA); 
              });

              if (turnos.isEmpty) return const Center(child: Text('Nenhum vistoriador em campo no momento.', style: TextStyle(color: Colors.grey, fontSize: 16)));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: turnos.length,
                itemBuilder: (context, index) {
                  final turnoDoc = turnos[index];
                  final t = turnoDoc.data() as Map<String, dynamic>;
                  String uidVistoriador = t['vistoriador_uid']?.toString() ?? '';
                  String horaInicio = t['data_inicio'] != null ? DateFormat('dd/MM/yy - HH:mm').format((t['data_inicio'] as Timestamp).toDate()) : 'Aguardando...';

                  return FutureBuilder<String?>(
                    future: _buscarFotoVistoriador(uidVistoriador, t),
                    builder: (context, snapshotFoto) {
                      String? fotoUrl = snapshotFoto.data;

                      return Card(
                        elevation: 2, margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => _mostrarDetalhesTurnoAdmin(t, 'EM ANDAMENTO', fotoUrl),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 35,
                                  backgroundColor: Colors.teal.shade100, 
                                  backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                                  child: fotoUrl == null || fotoUrl.isEmpty ? const Icon(Icons.person, color: Colors.teal, size: 35) : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t['vistoriador_nome']?.toString().toUpperCase() ?? 'DESCONHECIDO', 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Rota ${t['rota_numero'] ?? 'S/R'} | Placa da moto: ${t['placa'] ?? 'S/P'}', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text('Início: $horaInicio', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      
                                      // Calcula a porcentagem em tempo real de forma segura
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance.collection('vistorias').where('turno_id', isEqualTo: turnoDoc.id).snapshots(),
                                        builder: (context, snapVistorias) {
                                          if (snapVistorias.connectionState == ConnectionState.waiting) {
                                            return const Text('Percentual de rota concluída: Calculando...', style: TextStyle(color: Colors.grey, fontSize: 13));
                                          }
                                          if (snapVistorias.hasError || !snapVistorias.hasData) {
                                            return const Text('Percentual de rota concluída: N/A', style: TextStyle(color: Colors.grey, fontSize: 13));
                                          }

                                          String rotaNumerica = (t['rota_numero']?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                                          int meta = _todosSemaforosAcervo.where((s) {
                                            String r = (s['rota'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
                                            return r == rotaNumerica && r.isNotEmpty;
                                          }).length;

                                          if (meta == 0) return Text('Percentual de rota concluída: 0%', style: TextStyle(color: Colors.teal.shade700, fontSize: 13, fontWeight: FontWeight.bold));

                                          Set<String> vistoriados = snapVistorias.data!.docs.map((d) => (d.data() as Map<String, dynamic>)['semaforo_id'].toString()).toSet();
                                          double perc = (vistoriados.length / meta) * 100;
                                          if (perc > 100) perc = 100;

                                          return Text('Percentual de rota concluída: ${perc.toStringAsFixed(0)}%', style: TextStyle(color: Colors.teal.shade700, fontSize: 13, fontWeight: FontWeight.bold));
                                        }
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ABA 2 DO ADMIN: CONCLUÍDOS
  // ==========================================
  Widget _buildAbaConcluidos() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _buildBotaoData('Data Inicial', _dataInicioFiltro, () => _selecionarData(context, true)),
                  const SizedBox(width: 8),
                  _buildBotaoData('Data Final', _dataFimFiltro, () => _selecionarData(context, false)),
                ],
              ),
              const SizedBox(height: 12),
              
              InputDecorator(
                decoration: InputDecoration(labelText: 'Filtrar por Rota', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _todasAsRotasDaPlanilha.contains(_rotaFiltro) ? _rotaFiltro : 'Todas',
                    items: [
                      const DropdownMenuItem(value: 'Todas', child: Text('Todas as Rotas')),
                      ..._todasAsRotasDaPlanilha.map((r) => DropdownMenuItem(value: r, child: Text('Rota $r')))
                    ],
                    onChanged: (val) => setState(() => _rotaFiltro = val!),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700, 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 12)
                  ),
                  onPressed: () { 
                    setState(() => _filtrosAplicadosConcluidos = true); 
                  },
                  child: const Text('APLICAR FILTROS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),

              if (_dataInicioFiltro != null || _dataFimFiltro != null || _rotaFiltro != 'Todas' || _filtrosAplicadosConcluidos) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Limpar Filtros', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => setState(() { 
                      _dataInicioFiltro = null; 
                      _dataFimFiltro = null; 
                      _rotaFiltro = 'Todas'; 
                      _filtrosAplicadosConcluidos = false; 
                    }),
                  ),
                ),
              ]
            ],
          ),
        ),
        
        Expanded(
          child: !_filtrosAplicadosConcluidos 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('Preencha os filtros acima e clique em Aplicar.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ]
                )
              )
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('turnos').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  var turnosFiltrados = snapshot.data!.docs.where((doc) {
                    var t = doc.data() as Map<String, dynamic>;
                    
                    String status = (t['status'] ?? '').toString().toLowerCase().trim();
                    if (status != 'finalizado' && status != 'concluido') return false;
                    
                    String rotaDb = (t['rota_numero'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
                    String filtroLimpo = _rotaFiltro.replaceFirst(RegExp(r'^0+'), '');
                    if (_rotaFiltro != 'Todas' && rotaDb != filtroLimpo) return false;
                    
                    if (_dataInicioFiltro != null || _dataFimFiltro != null) {
                      if (t['data_fim'] == null) return false;
                      DateTime dataFim = (t['data_fim'] as Timestamp).toDate();
                      
                      if (_dataInicioFiltro != null && dataFim.isBefore(_dataInicioFiltro!)) return false;
                      if (_dataFimFiltro != null && dataFim.isAfter(_dataFimFiltro!)) return false;
                    }
                    return true;
                  }).toList();

                  turnosFiltrados.sort((a, b) {
                    Timestamp? tempoA = (a.data() as Map)['data_fim'] as Timestamp?;
                    Timestamp? tempoB = (b.data() as Map)['data_fim'] as Timestamp?;
                    if (tempoA == null && tempoB == null) return 0;
                    if (tempoA == null) return 1;
                    if (tempoB == null) return -1;
                    return tempoB.compareTo(tempoA); 
                  });

                  return Column(
                    children: [
                      Container(
                        color: Colors.grey.shade200, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total: ${turnosFiltrados.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), tooltip: 'Exportar PDF', onPressed: turnosFiltrados.isEmpty ? null : () => _exportarPDFTurnos(turnosFiltrados)),
                                IconButton(icon: const Icon(Icons.grid_on, color: Colors.green), tooltip: 'Exportar Excel', onPressed: turnosFiltrados.isEmpty ? null : () => _exportarXLSTurnos(turnosFiltrados)),
                              ],
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        child: turnosFiltrados.isEmpty
                          ? const Center(child: Text('Nenhum turno concluído encontrado com estes filtros.', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: turnosFiltrados.length,
                              itemBuilder: (context, index) {
                                final turnoDoc = turnosFiltrados[index];
                                final t = turnoDoc.data() as Map<String, dynamic>;
                                String uidVistoriador = t['vistoriador_uid']?.toString() ?? '';
                                String horaInicio = t['data_inicio'] != null ? DateFormat('dd/MM/yy - HH:mm').format((t['data_inicio'] as Timestamp).toDate()) : '-';
                                String horaFim = t['data_fim'] != null ? DateFormat('dd/MM/yy - HH:mm').format((t['data_fim'] as Timestamp).toDate()) : '-';
                                String kmRodado = 'N/A';
                                
                                try {
                                  if (t['km_inicial'] != null && t['km_final'] != null) {
                                    double kI = double.parse(t['km_inicial'].toString());
                                    double kF = double.parse(t['km_final'].toString());
                                    kmRodado = '${(kF - kI).toStringAsFixed(1)} km rodados';
                                  }
                                } catch (_) {}

                                return FutureBuilder<String?>(
                                  future: _buscarFotoVistoriador(uidVistoriador, t),
                                  builder: (context, snapshotFoto) {
                                    String? fotoUrl = snapshotFoto.data;

                                    return Card(
                                      elevation: 1, margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: InkWell(
                                        onTap: () => _mostrarDetalhesTurnoAdmin(t, 'CONCLUÍDO', fotoUrl),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              CircleAvatar(
                                                radius: 35,
                                                backgroundColor: Colors.green.shade100, 
                                                backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                                                child: fotoUrl == null || fotoUrl.isEmpty ? const Icon(Icons.check, color: Colors.green, size: 35) : null,
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      t['vistoriador_nome']?.toString().toUpperCase() ?? 'DESCONHECIDO', 
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text('Rota ${t['rota_numero'] ?? 'S/R'} | Placa da moto: ${t['placa'] ?? 'S/P'}', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                                    const SizedBox(height: 2),
                                                    Text('Início: $horaInicio', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                                    const SizedBox(height: 2),
                                                    // CÁLCULO SEGURO E EM TEMPO REAL
                                                    StreamBuilder<QuerySnapshot>(
                                                      stream: FirebaseFirestore.instance.collection('vistorias').where('turno_id', isEqualTo: turnoDoc.id).snapshots(),
                                                      builder: (context, snapVistorias) {
                                                        if (snapVistorias.connectionState == ConnectionState.waiting) {
                                                          return const Text('Percentual de rota concluída: Calculando...', style: TextStyle(color: Colors.grey, fontSize: 13));
                                                        }
                                                        if (snapVistorias.hasError || !snapVistorias.hasData) {
                                                          return const Text('Percentual de rota concluída: N/A', style: TextStyle(color: Colors.grey, fontSize: 13));
                                                        }

                                                        String rotaNumerica = (t['rota_numero']?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                                                        int meta = _todosSemaforosAcervo.where((s) {
                                                          String r = (s['rota'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
                                                          return r == rotaNumerica && r.isNotEmpty;
                                                        }).length;

                                                        if (meta == 0) return Text('Percentual de rota concluída: 0%', style: TextStyle(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.bold));

                                                        Set<String> vistoriados = snapVistorias.data!.docs.map((d) => (d.data() as Map<String, dynamic>)['semaforo_id'].toString()).toSet();
                                                        double perc = (vistoriados.length / meta) * 100;
                                                        if (perc > 100) perc = 100;

                                                        return Text('Percentual de rota concluída: ${perc.toStringAsFixed(0)}%', style: TextStyle(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.bold));
                                                      }
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                );
                              },
                            ),
                      ),
                    ],
                  );
                },
              ),
        ),
      ],
    );
  }

  // ==========================================
  // OPERADOR: TELA DE ABERTURA DE EXPEDIENTE
  // ==========================================
  Widget _buildVisaoIniciarTurno() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.motorcycle, size: 60, color: Colors.teal), const SizedBox(height: 24),
          const Text('Vistoriador Responsável:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  backgroundImage: _fotoUrlVistoriador != null && _fotoUrlVistoriador!.isNotEmpty ? NetworkImage(_fotoUrlVistoriador!) : null,
                  child: _fotoUrlVistoriador == null || _fotoUrlVistoriador!.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(_nomeVistoriador, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))),
              ],
            ),
          ),
          CheckboxListTile(
            title: const Text('Confirmo que sou o vistoriador acima e estou assumindo esta rota.', style: TextStyle(fontSize: 13)),
            value: _confirmouIdentidade, activeColor: Colors.teal, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
            onChanged: (bool? value) { setState(() { _confirmouIdentidade = value ?? false; }); },
          ),
          const SizedBox(height: 24),
          const Text('Selecione a Moto Disponível:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('veiculos').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Erro ao carregar veículos: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              if (!snapshot.hasData) return const LinearProgressIndicator(color: Colors.teal);
              
              var veiculos = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>; return data['em_uso'] != true; 
              }).toList();
              
              if (veiculos.isEmpty) return const Text('Todas as motos estão em uso no momento.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));

              veiculos.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>; var dataB = b.data() as Map<String, dynamic>;
                return (dataA['placa'] ?? '').toString().compareTo((dataB['placa'] ?? '').toString());
              });

              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.motorcycle)),
                hint: const Text('Escolha uma placa...'), value: _veiculoSelecionadoId,
                items: veiculos.map((doc) {
                  var v = doc.data() as Map<String, dynamic>; return DropdownMenuItem(value: doc.id, child: Text("${v['placa']} - ${v['modelo'] ?? ''}"));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _veiculoSelecionadoId = val;
                    _veiculoSelecionadoPlaca = (veiculos.firstWhere((d) => d.id == val).data() as Map<String, dynamic>)['placa'];
                  });
                },
              );
            }
          ),
          const SizedBox(height: 24),
          const Text('Quilometragem (KM) Inicial:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          TextField(
            controller: _kmInicialController, keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.speed), hintText: 'Ex: 12500', suffixText: 'km'),
          ),
          const SizedBox(height: 24),
          const Text('Selecione a Rota Disponível:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('turnos').where('status', isEqualTo: 'ativo').snapshots(),
            builder: (context, snapshotTurnos) {
              if (!snapshotTurnos.hasData || _carregandoRotas) return const LinearProgressIndicator(color: Colors.teal);
              
              Set<String> rotasEmUso = snapshotTurnos.data!.docs.map((doc) => (doc.data() as Map<String, dynamic>)['rota_numero'].toString()).toSet();
              List<String> rotasLivres = _todasAsRotasDaPlanilha.where((r) => !rotasEmUso.contains(r)).toList();
              
              if (rotasLivres.isEmpty) return const Text('Todas as rotas da planilha estão em uso no momento.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));
              if (_rotaSelecionada != null && !rotasLivres.contains(_rotaSelecionada)) _rotaSelecionada = null;

              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.route)),
                hint: const Text('Escolha uma rota...'), value: _rotaSelecionada,
                items: rotasLivres.map((r) => DropdownMenuItem(value: r, child: Text("Rota $r"))).toList(),
                onChanged: (val) { setState(() { _rotaSelecionada = val; }); },
              );
            }
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _processando ? null : _salvarTurno,
              child: _processando ? const CircularProgressIndicator(color: Colors.white) : const Text('INICIAR VISTORIA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // OPERADOR: TELA DE EXPEDIENTE ATIVO E FECHAMENTO
  // ==========================================
  Widget _buildVisaoEncerrarTurno() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, size: 60, color: Colors.green), const SizedBox(height: 16),
          const Text('Você possui um turno em andamento!', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 32),
          Card(
            color: Colors.green.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal,
                      backgroundImage: _fotoUrlVistoriador != null && _fotoUrlVistoriador!.isNotEmpty ? NetworkImage(_fotoUrlVistoriador!) : null,
                      child: _fotoUrlVistoriador == null || _fotoUrlVistoriador!.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    title: const Text('Vistoriador', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(_turnoAtivoData!['vistoriador_nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.route, color: Colors.teal), title: const Text('Rota Assumida', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text('Rota ${_turnoAtivoData!['rota_numero']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.motorcycle, color: Colors.teal), title: const Text('Veículo (Placa)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(_turnoAtivoData!['placa'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.speed, color: Colors.teal), title: const Text('KM Inicial', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text('${_turnoAtivoData!['km_inicial']} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Para concluir seu expediente, informe a quilometragem atual da moto:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          TextField(
            controller: _kmFinalController, keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.speed), labelText: 'KM Final', hintText: 'Ex: 12550', suffixText: 'km'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: _processando ? const SizedBox.shrink() : const Icon(Icons.stop_circle),
              label: _processando ? const CircularProgressIndicator(color: Colors.white) : const Text('ENCERRAR EXPEDIENTE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: _processando ? null : _encerrarTurno,
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoInicial || _carregandoRotas) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal)));

    if (_isAdmin) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Monitoramento de Turnos', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.teal.shade500, foregroundColor: Colors.white,
            bottom: const TabBar(
              indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70,
              tabs: [ Tab(icon: Icon(Icons.directions_run), text: 'Em Andamento'), Tab(icon: Icon(Icons.history), text: 'Concluídos') ],
            ),
          ),
          body: TabBarView(children: [ _buildAbaEmAndamento(), _buildAbaConcluidos() ]),
        ),
      );
    } 
    else {
      return Scaffold(
        appBar: AppBar(title: const Text('Meu Expediente'), backgroundColor: Colors.teal.shade400, foregroundColor: Colors.white),
        body: _turnoAtivoId != null ? _buildVisaoEncerrarTurno() : _buildVisaoIniciarTurno(), 
      );
    }
  }
}