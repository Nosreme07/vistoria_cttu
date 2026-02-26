import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Importações para o PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CadastroSemaforos extends StatefulWidget {
  const CadastroSemaforos({super.key});

  @override
  State<CadastroSemaforos> createState() => _CadastroSemaforosState();
}

class _CadastroSemaforosState extends State<CadastroSemaforos> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _pesquisaController = TextEditingController(); 

  String _textoPesquisa = '';
  bool _estaCarregando = false;

  // ==== TODOS OS 54 CAMPOS ====
  final List<String> _todosOsCampos = [
    'id', 'endereco', 'bairro', 'empresa', 'georeferencia', 'rota',
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

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {})); 
    
    _pesquisaController.addListener(() {
      setState(() { _textoPesquisa = _pesquisaController.text.toLowerCase(); });
    });

    for (var campo in _todosOsCampos) {
      _controllers[campo] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pesquisaController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ==== FORMULÁRIO DINÂMICO (CRIAR E EDITAR) ====
  void _abrirFormulario({String? docId, Map<String, dynamic>? dadosAtuais}) {
    for (var campo in _todosOsCampos) {
      _controllers[campo]!.text = dadosAtuais?[campo]?.toString() ?? '';
    }

    bool isEdicao = docId != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24, left: 24, right: 24,
              ),
              height: MediaQuery.of(context).size.height * 0.85, 
              child: Column(
                children: [
                  Text(isEdicao ? 'Editar Semáforo ${dadosAtuais?['id']}' : 'Novo Semáforo', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: _todosOsCampos.length,
                      itemBuilder: (context, index) {
                        String chave = _todosOsCampos[index];
                        String titulo = chave.replaceAll('_', ' ').toUpperCase();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: _controllers[chave],
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: titulo,
                              border: const OutlineInputBorder(),
                              filled: (isEdicao && chave == 'id'), 
                              fillColor: (isEdicao && chave == 'id') ? Colors.grey.shade200 : null,
                            ),
                            enabled: !(isEdicao && chave == 'id'), 
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _estaCarregando ? null : () => _salvarSemaforo(setModalState, docId),
                      child: _estaCarregando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isEdicao ? 'Atualizar Semáforo' : 'Salvar Semáforo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _salvarSemaforo(StateSetter setModalState, String? docId) async {
    if (_controllers['id']!.text.isEmpty || _controllers['endereco']!.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha pelo menos o ID e o Endereço!')));
      return;
    }

    setModalState(() => _estaCarregando = true);

    try {
      Map<String, dynamic> dadosSemaforo = {};
      
      for (var campo in _todosOsCampos) {
        dadosSemaforo[campo] = _controllers[campo]!.text.trim().toUpperCase();
      }
      dadosSemaforo['atualizado_em'] = FieldValue.serverTimestamp();

      if (docId != null) {
        await FirebaseFirestore.instance.collection('semaforos').doc(docId).set(dadosSemaforo, SetOptions(merge: true));
      } else {
        dadosSemaforo['criado_em'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('semaforos').doc(_controllers['id']!.text.trim()).set(dadosSemaforo);
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setModalState(() => _estaCarregando = false);
    }
  }

  Future<void> _deletarSemaforo(String id) async {
    await FirebaseFirestore.instance.collection('semaforos').doc(id).delete();
  }

  // ==== GERAR PDF INDIVIDUAL ====
  Future<void> _gerarPDFIndividual(Map<String, dynamic> data) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando PDF do Semáforo...'), backgroundColor: Colors.teal));

    try {
      final pdf = pw.Document();

      List<List<String>> dadosTabela = [];
      for (var campo in _todosOsCampos) {
        String titulo = campo.replaceAll('_', ' ').toUpperCase();
        String valor = data[campo]?.toString() ?? '-';
        dadosTabela.add([titulo, valor]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Ficha Técnica - Semáforo Nº ${data['id'] ?? ''}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800))
              ),
              pw.SizedBox(height: 16),
              
              pw.Table.fromTextArray(
                context: context,
                headers: ['CARACTERÍSTICA', 'INFORMAÇÃO'],
                data: dadosTabela,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                cellAlignments: { 0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft },
                columnWidths: { 0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3) }
              ),
            ];
          }
        )
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Semaforo_${data['id']}.pdf',
      );

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao gerar PDF!'), backgroundColor: Colors.red));
    }
  }

  // ==== EXPORTAR PARA EXCEL (CSV) ====
  Future<void> _exportarExcel() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando planilha Excel...'), backgroundColor: Colors.green));
    
    try {
      final snapshot = await FirebaseFirestore.instance.collection('semaforos').orderBy('id').get();
      
      String csvContent = '\uFEFF'; 
      csvContent += '${_todosOsCampos.map((c) => c.toUpperCase()).join(';')}\n';

      for (var doc in snapshot.docs) {
        var data = doc.data();
        List<String> linha = _todosOsCampos.map((campo) {
          String valor = (data[campo] ?? '').toString().replaceAll(';', ',').replaceAll('\n', ' ');
          return valor;
        }).toList();
        
        csvContent += '${linha.join(';')}\n';
      }

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/Relatorio_Semaforos_CTTU.csv';
      final file = File(path);
      await file.writeAsString(csvContent);

      await Share.shareXFiles([XFile(path)], text: 'Segue a planilha de Semáforos atualizada.');

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao gerar Excel!'), backgroundColor: Colors.red));
    }
  }

  // ==== VISUALIZAR DETALHES (SOMENTE LEITURA) ====
  void _mostrarDetalhesSemaforo(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, 
          minChildSize: 0.4,
          maxChildSize: 0.9, 
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text('Ficha do Semáforo Nº ${data['id'] ?? ''}', 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade800)
                    ),
                  ),
                  const Divider(thickness: 2, height: 32),
                  
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController, 
                      itemCount: _todosOsCampos.length,
                      itemBuilder: (context, index) {
                        String campo = _todosOsCampos[index];
                        String titulo = campo.replaceAll('_', ' ').toUpperCase();
                        String valor = (data[campo] ?? '').toString().trim();

                        if (valor.isEmpty) valor = 'NÃO INFORMADO';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black87, fontSize: 16),
                              children: [
                                TextSpan(text: '$titulo: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
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
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Semáforos'),
        backgroundColor: Colors.teal.shade100,
        // BOTÃO DA NUVEM FOI REMOVIDO DAQUI!
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbaLista(),
          _buildAbaDashboard(),
        ],
      ),
      bottomNavigationBar: Material(
        color: Colors.teal.shade100,
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.teal.shade900,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.teal.shade900,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Lista'),
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0 
        ? FloatingActionButton(
            onPressed: () => _abrirFormulario(),
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          )
        : null, 
    );
  }

  // ==== ABA 1: LISTA ====
  Widget _buildAbaLista() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _pesquisaController,
            decoration: InputDecoration(
              labelText: 'Pesquisar por número ou endereço...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _textoPesquisa.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _pesquisaController.clear()) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        
        if (_estaCarregando) const LinearProgressIndicator(color: Colors.teal),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('semaforos').orderBy('id').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Erro ao carregar dados.'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              var semaforos = snapshot.data!.docs;

              if (_textoPesquisa.isNotEmpty) {
                semaforos = semaforos.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final endereco = (data['endereco'] ?? '').toString().toLowerCase();
                  final id = (data['id'] ?? '').toString().toLowerCase();
                  return endereco.contains(_textoPesquisa) || id.contains(_textoPesquisa);
                }).toList();
              }

              if (semaforos.isEmpty) return const Center(child: Text('Nenhum semáforo encontrado.'));

              return ListView.builder(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80), 
                itemCount: semaforos.length,
                itemBuilder: (context, index) {
                  final doc = semaforos[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _mostrarDetalhesSemaforo(data), 
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade700,
                        child: Text(data['id']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      title: Text(data['endereco'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                            onPressed: () => _gerarPDFIndividual(data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            onPressed: () => _abrirFormulario(docId: doc.id, dadosAtuais: data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deletarSemaforo(doc.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==== ABA 2: DASHBOARD ====
  Widget _buildAbaDashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('semaforos').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final semaforos = snapshot.data!.docs;
        int totalSerttel = 0;
        int totalSinalvida = 0;
        int comNobreak = 0;

        for (var doc in semaforos) {
          var data = doc.data() as Map<String, dynamic>;
          String emp = (data['empresa'] ?? '').toString().toUpperCase();
          String nb = (data['nobreak'] ?? '').toString().toUpperCase();
          
          if (emp.contains('SERTTEL')) totalSerttel++;
          if (emp.contains('SINALVIDA')) totalSinalvida++;
          if (nb == 'SIM') comNobreak++;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.grid_on, size: 28),
                label: const Text('EXPORTAR PLANILHA EXCEL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: _exportarExcel,
              ),
              const SizedBox(height: 24),

              Card(
                color: Colors.teal.shade700,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(Icons.traffic, color: Colors.white, size: 48),
                      const SizedBox(height: 8),
                      Text('${semaforos.length}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Text('Total de Semáforos', style: TextStyle(fontSize: 16, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _buildDashCard('Serttel', totalSerttel, Icons.business, Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDashCard('SinalVida', totalSinalvida, Icons.business, Colors.orange)),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _buildDashCard('Com Nobreak', comNobreak, Icons.battery_charging_full, Colors.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDashCard('Sem Nobreak', semaforos.length - comNobreak, Icons.battery_alert, Colors.redAccent)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashCard(String titulo, int valor, IconData icone, Color cor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icone, color: cor, size: 32),
            const SizedBox(height: 8),
            Text('$valor', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cor)),
            Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}