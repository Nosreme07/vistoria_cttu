import 'dart:io';
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

class FormularioRotaPage extends StatefulWidget {
  const FormularioRotaPage({super.key});

  @override
  State<FormularioRotaPage> createState() => _FormularioRotaPageState();
}

class _FormularioRotaPageState extends State<FormularioRotaPage> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  
  late TabController _tabController;
  final TextEditingController _pesquisaAndamentoController = TextEditingController();
  final TextEditingController _pesquisaConcluidosController = TextEditingController();
  
  String _textoPesquisaAndamento = '';
  String _textoPesquisaConcluidos = '';

  final List<String> itensChecklist = [
    'Funcionamento de botoeiras',
    'Condições da unidade de energia',
    'LED parcialmente queimados ou apagado por completo',
    'Falta total ou parcial de equipamentos ou acessórios',
    'Condições do medidor de energia',
    'Condições da caixa do controlador do semáforo',
    'Caixas porta-focos (grupos focais) danificadas ou fora de posição',
    'Condição de grupos focais veiculares e de pedestres equipados com sequencial gradativo ou cronômetro digital regressivo',
    'Lentes queimadas, quebradas, ou sem coloração',
    'Cobre-Focos danificados',
    'Condições de dispositivo suspenso de iluminação de faixa de travessia de pedestres',
    'Cabos partidos ou sem isolamento',
    'Fiação baixa ou apoiada sobre outras redes',
    'Semipórticos inclinados ou danificados',
    'Condições de sinal sonoro (sirene)',
    'Condição da sinalização horizontal e da vertical associada ao semáforo',
    'Problemas relacionados com a visibilidade do semáforo e que estejam a uma distância de até 50 metros',
    'Condição da placa numérica de identificação',
    'Materiais não pertencentes ao sistema instalados nos semipórticos sem autorização'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _pesquisaAndamentoController.addListener(() {
      setState(() => _textoPesquisaAndamento = _pesquisaAndamentoController.text.toLowerCase());
    });
    
    _pesquisaConcluidosController.addListener(() {
      setState(() => _textoPesquisaConcluidos = _pesquisaConcluidosController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pesquisaAndamentoController.dispose();
    _pesquisaConcluidosController.dispose();
    super.dispose();
  }

  Future<Position> _determinarPosicao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Os serviços de localização estão desativados no celular.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Permissão de localização negada.');
    }
    if (permission == LocationPermission.deniedForever) return Future.error('Permissão negada permanentemente.'); 

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // ==== GERADOR DE PDF (Reaproveitado para mostrar após encerrar turno) ====
  Future<void> _gerarEMostrarPDF(List<QueryDocumentSnapshot> vistorias, String rotaNumero) async {
    if (vistorias.isEmpty) return;
    
    try {
      String nomeVistoriador = 'VISTORIADOR';
      if (user != null) {
        try {
          var docUser = await FirebaseFirestore.instance.collection('usuarios').doc(user!.uid).get();
          if (docUser.exists && docUser.data() != null) {
            var data = docUser.data()!;
            nomeVistoriador = data['nome'] ?? data['nome_completo'] ?? data['usuario'] ?? user!.email?.split('@').first.toUpperCase() ?? 'VISTORIADOR';
          } else {
            var query = await FirebaseFirestore.instance.collection('usuarios').where('email', isEqualTo: user!.email).limit(1).get();
            if (query.docs.isNotEmpty) {
              var data = query.docs.first.data();
              nomeVistoriador = data['nome'] ?? data['nome_completo'] ?? data['usuario'] ?? user!.email?.split('@').first.toUpperCase() ?? 'VISTORIADOR';
            } else {
              nomeVistoriador = user!.displayName ?? user!.email?.split('@').first.toUpperCase() ?? 'VISTORIADOR';
            }
          }
        } catch (e) {
          nomeVistoriador = user!.displayName ?? user!.email?.split('@').first.toUpperCase() ?? 'VISTORIADOR';
        }
      }

      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape, 
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Text('Relatório de Vistorias Concluídas - Rota $rotaNumero', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 16),
              
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Semáforo', 'Endereço', 'Início', 'Fim', 'Coordenadas', 'Status', 'Falha', 'Detalhes'],
                data: vistorias.map((doc) {
                  var v = doc.data() as Map<String, dynamic>;
                  String status = v['teve_anormalidade'] == true ? 'COM FALHA' : 'OK';
                  return [ 
                    v['semaforo_id']?.toString() ?? '', 
                    v['semaforo_endereco']?.toString() ?? '', 
                    v['data_hora_inicio']?.toString() ?? '', 
                    v['data_hora_fim']?.toString() ?? '', 
                    v['gps_coordenadas']?.toString() ?? '', 
                    status, 
                    v['falha_registrada'] ?? '-', 
                    v['detalhes_ocorrencia']?.toString().replaceAll('\n', ' ') ?? '-' 
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),   
                  1: const pw.FlexColumnWidth(2),   
                  2: const pw.FlexColumnWidth(1.5), 
                  3: const pw.FlexColumnWidth(1.5), 
                  4: const pw.FlexColumnWidth(1.5), 
                  5: const pw.FlexColumnWidth(1),   
                  6: const pw.FlexColumnWidth(1.5), 
                  7: const pw.FlexColumnWidth(3),   
                }
              ),

              pw.SizedBox(height: 40),
              
              pw.Text(
                'Declaro que as informações contidas neste relatório refletem a realidade das vistorias realizadas em campo e concordo expressamente com os dados aqui registrados.', 
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)
              ),
              pw.SizedBox(height: 60),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Container(width: 300, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 8),
                    pw.Text(nomeVistoriador.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Text('Assinatura do Vistoriador', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ]
                )
              )
            ];
          }
        )
      );
      // Aqui usamos o Printing para exibir na tela direto!
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Vistorias_Concluidas_Rota$rotaNumero.pdf');
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao gerar PDF!'), backgroundColor: Colors.red));
    }
  }


  // ==== FUNÇÃO DE ABRIR VISTORIA NO SEMÁFORO ====
  void _abrirVistoriaSemaforo(Map<String, dynamic> semaforo, String turnoId) {
    bool vistoriaIniciada = false;
    bool salvando = false;
    String dataHoraInicio = '';
    String coordenadas = '';
    
    List<bool> checkState = List.filled(itensChecklist.length, false);
    bool todasMarcadas = false; 
    
    String temAnormalidade = 'Não';
    String? falhaSelecionada;
    List<Map<String, dynamic>> tiposDeFalhaLista = []; 
    List<File> fotos = []; 
    final ImagePicker picker = ImagePicker();
    final TextEditingController detalhesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            Future<void> carregarFalhas() async {
              if (tiposDeFalhaLista.isEmpty) {
                var snapshot = await FirebaseFirestore.instance.collection('tipos_falha').orderBy('falha').get();
                setModalState(() {
                  tiposDeFalhaLista = snapshot.docs.map((doc) => {'id': doc.id, 'falha': doc['falha']}).toList();
                });
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: Colors.orange.shade800, child: Text(semaforo['id'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Vistoria do Semáforo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              Text(semaforo['endereco'] ?? 'Sem endereço', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
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
                            const Text('Para iniciar o preenchimento do checklist, é necessário registrar o horário exato e sua localização via GPS.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              icon: salvando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.play_arrow, size: 30),
                              label: Text(salvando ? 'Obtendo GPS...' : 'INICIAR VISTORIA NESTE LOCAL', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              onPressed: salvando ? null : () async {
                                setModalState(() => salvando = true);
                                try {
                                  Position pos = await _determinarPosicao();
                                  String dataFormatada = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
                                  setModalState(() {
                                    coordenadas = '${pos.latitude}, ${pos.longitude}';
                                    dataHoraInicio = dataFormatada;
                                    vistoriaIniciada = true;
                                    salvando = false;
                                  });
                                } catch (e) {
                                  setModalState(() => salvando = false);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                                }
                              },
                            )
                          ],

                          if (vistoriaIniciada) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                children: [
                                  Row(children: [const Icon(Icons.access_time, size: 16), const SizedBox(width: 8), Text('Iniciado em: $dataHoraInicio', style: const TextStyle(fontWeight: FontWeight.bold))]),
                                  const SizedBox(height: 4),
                                  Row(children: [const Icon(Icons.gps_fixed, size: 16), const SizedBox(width: 8), Text('GPS: $coordenadas', style: const TextStyle(fontSize: 12))]),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('CHECKLIST DE VERIFICAÇÃO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: Colors.indigo),
                                  icon: Icon(todasMarcadas ? Icons.check_box_outline_blank : Icons.check_box_outlined),
                                  label: Text(todasMarcadas ? 'Desmarcar Todos' : 'Marcar Todos', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    setModalState(() {
                                      todasMarcadas = !todasMarcadas;
                                      for (int i = 0; i < checkState.length; i++) checkState[i] = todasMarcadas;
                                    });
                                  },
                                )
                              ],
                            ),
                            const Divider(thickness: 2),
                            
                            ...List.generate(itensChecklist.length, (index) {
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                activeColor: Colors.indigo,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(itensChecklist[index], style: const TextStyle(fontSize: 14)),
                                value: checkState[index],
                                onChanged: (bool? value) => setModalState(() => checkState[index] = value ?? false),
                              );
                            }),

                            const SizedBox(height: 24),
                            
                            const Text('ANORMALIDADES E REGISTRO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                            const Divider(thickness: 2),
                            const Text('Foi encontrada alguma anormalidade neste semáforo?', style: TextStyle(fontSize: 16)),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: const Text('Não', style: TextStyle(fontWeight: FontWeight.bold)),
                                    value: 'Não', groupValue: temAnormalidade, activeColor: Colors.green,
                                    onChanged: (val) => setModalState(() { temAnormalidade = val!; falhaSelecionada = null; fotos.clear(); detalhesController.clear(); }),
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: const Text('Sim', style: TextStyle(fontWeight: FontWeight.bold)),
                                    value: 'Sim', groupValue: temAnormalidade, activeColor: Colors.red,
                                    onChanged: (val) { setModalState(() { temAnormalidade = val!; }); carregarFalhas(); },
                                  ),
                                ),
                              ],
                            ),

                            if (temAnormalidade == 'Sim') ...[
                              const SizedBox(height: 12),
                              if (tiposDeFalhaLista.isEmpty)
                                const Center(child: CircularProgressIndicator())
                              else
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Selecione a Falha Encontrada', border: OutlineInputBorder()),
                                  value: falhaSelecionada,
                                  items: tiposDeFalhaLista.map((f) => DropdownMenuItem<String>(value: f['falha'], child: Text(f['falha'], overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (val) => setModalState(() => falhaSelecionada = val),
                                ),
                              
                              const SizedBox(height: 16),
                              TextField(
                                controller: detalhesController,
                                maxLines: 3,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(labelText: 'Detalhes da Ocorrência', hintText: 'Descreva a anormalidade...', border: OutlineInputBorder(), alignLabelWithHint: true),
                              ),
                              
                              const SizedBox(height: 24),
                              const Text('FOTOS DO PROBLEMA (Obrigatório, Máx. 4)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12, runSpacing: 12,
                                children: [
                                  ...List.generate(fotos.length, (index) {
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300), image: DecorationImage(image: FileImage(fotos[index]), fit: BoxFit.cover))),
                                        Positioned(right: -8, top: -8, child: GestureDetector(onTap: () => setModalState(() => fotos.removeAt(index)), child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 16))))
                                      ]
                                    );
                                  }),
                                  if (fotos.length < 4)
                                    InkWell(
                                      onTap: () async {
                                        final XFile? fotoTirada = await picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 50);
                                        if (fotoTirada != null) setModalState(() => fotos.add(File(fotoTirada.path)));
                                      },
                                      child: Container(
                                        width: 80, height: 80, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid)),
                                        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, color: Colors.grey, size: 32), Text('Tirar Foto', style: TextStyle(fontSize: 10, color: Colors.grey))]),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            
                            if (temAnormalidade == 'Não') ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(8)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 36),
                                    SizedBox(width: 12),
                                    Expanded(child: Text('Você confirma que o semáforo foi vistoriado por completo e NÃO apresenta defeitos?', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),

                            SizedBox(
                              width: double.infinity, height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                onPressed: salvando ? null : () async {
                                  if (checkState.contains(false)) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você precisa marcar todos os itens do checklist como verificados!'), backgroundColor: Colors.red));
                                    return;
                                  }
                                  
                                  String detalhesFinais = detalhesController.text.trim();

                                  if (temAnormalidade == 'Sim') {
                                    if (falhaSelecionada == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione qual foi a falha encontrada!'), backgroundColor: Colors.red)); return; }
                                    if (fotos.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('É obrigatório tirar pelo menos 1 foto do defeito!'), backgroundColor: Colors.red)); return; }
                                  } else {
                                    detalhesFinais = 'O semáforo foi vistoriado por completo e não foram identificadas anormalidades.';
                                  }

                                  setModalState(() => salvando = true);

                                  try {
                                    List<String> urlsDasFotos = [];
                                    if (fotos.isNotEmpty) {
                                      for (int i = 0; i < fotos.length; i++) {
                                        String nomeArquivo = 'vistoria_${semaforo['id']}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                                        Reference ref = FirebaseStorage.instance.ref().child('vistorias_fotos/$nomeArquivo');
                                        UploadTask uploadTask = ref.putFile(fotos[i]);
                                        TaskSnapshot snapshotDaFoto = await uploadTask;
                                        urlsDasFotos.add(await snapshotDaFoto.ref.getDownloadURL());
                                      }
                                    }

                                    String dataFormatadaFim = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
                                    String resumoChecklist = 'Todos os ${itensChecklist.length} itens do checklist foram verificados e confirmados pelo vistoriador.';

                                    await FirebaseFirestore.instance.collection('vistorias').add({
                                      'turno_id': turnoId,
                                      'vistoriador_uid': user!.uid,
                                      'semaforo_id': semaforo['id'],
                                      'semaforo_endereco': semaforo['endereco'],
                                      'data_hora_inicio': dataHoraInicio,
                                      'data_hora_fim': dataFormatadaFim,
                                      'gps_coordenadas': coordenadas,
                                      'resumo_checklist': resumoChecklist, 
                                      'teve_anormalidade': temAnormalidade == 'Sim',
                                      'falha_registrada': falhaSelecionada ?? 'Nenhuma',
                                      'detalhes_ocorrencia': detalhesFinais, 
                                      'fotos': urlsDasFotos, 
                                      'criado_em': FieldValue.serverTimestamp(),
                                    });

                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vistoria salva com sucesso!'), backgroundColor: Colors.green));
                                    }
                                  } catch (e) {
                                    setModalState(() => salvando = false);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar vistoria! Verifique a conexão.'), backgroundColor: Colors.red));
                                  }
                                },
                                child: salvando 
                                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), SizedBox(width: 12), Text('Enviando dados...', style: TextStyle(fontWeight: FontWeight.bold))])
                                  : const Text('SALVAR E CONCLUIR VISTORIA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  // ==== EXPORTAÇÃO EXCEL DA ABA CONCLUÍDOS ====
  Future<void> _exportarExcelConcluidos(List<QueryDocumentSnapshot> vistorias, String rotaNumero) async {
    if (vistorias.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando Excel...'), backgroundColor: Colors.green));
    try {
      String csv = '\uFEFF'; 
      csv += 'SEMAFORO;ENDERECO;INICIO;FIM;COORDENADAS;STATUS;FALHA;DETALHES\n';
      for (var doc in vistorias) {
        var v = doc.data() as Map<String, dynamic>;
        String status = v['teve_anormalidade'] == true ? 'COM FALHA' : 'OK';
        csv += '${v['semaforo_id']};${v['semaforo_endereco']};${v['data_hora_inicio']};${v['data_hora_fim']};${v['gps_coordenadas']};$status;${v['falha_registrada']};${v['detalhes_ocorrencia']?.toString().replaceAll('\n', ' ')}\n';
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/Vistorias_Rota$rotaNumero.csv';
      final file = File(path);
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(path)], text: 'Planilha de Vistorias Concluídas - Rota $rotaNumero.');
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao gerar Excel!'), backgroundColor: Colors.red));
    }
  }

  void _mostrarDetalhesVistoria(Map<String, dynamic> vistoria) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        bool temFalha = vistoria['teve_anormalidade'] == true;
        List<dynamic> fotos = vistoria['fotos'] ?? [];

        return DraggableScrollableSheet(
          initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
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
                        Icon(temFalha ? Icons.warning_amber_rounded : Icons.check_circle, color: temFalha ? Colors.red : Colors.green, size: 36),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Semáforo Nº ${vistoria['semaforo_id']}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800))),
                      ],
                    ),
                    const Divider(thickness: 2, height: 32),
                    
                    _buildInfoRow('Endereço', vistoria['semaforo_endereco']),
                    _buildInfoRow('Início', vistoria['data_hora_inicio']),
                    _buildInfoRow('Fim', vistoria['data_hora_fim']),
                    _buildInfoRow('Coordenadas GPS', vistoria['gps_coordenadas']),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.playlist_add_check, color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          Expanded(child: Text(vistoria['resumo_checklist'] ?? 'Checklist não registrado.', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12), width: double.infinity,
                      decoration: BoxDecoration(color: temFalha ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: temFalha ? Colors.red : Colors.green)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(temFalha ? 'FALHA REGISTRADA:' : 'STATUS:', style: TextStyle(fontWeight: FontWeight.bold, color: temFalha ? Colors.red : Colors.green)),
                          Text(vistoria['falha_registrada'] ?? 'Nenhuma', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Detalhes:', style: TextStyle(fontWeight: FontWeight.bold, color: temFalha ? Colors.red : Colors.green)),
                          Text(vistoria['detalhes_ocorrencia'] ?? 'Sem detalhes', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),

                    if (fotos.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('Fotos da Ocorrência:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12, runSpacing: 12,
                        children: fotos.map((url) => Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey), image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)),
                        )).toList(),
                      )
                    ],
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fechar Ficha', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 15), children: [
        TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        TextSpan(text: value ?? '-'),
      ])),
    );
  }

  // ==== NOVO: ENCERRAR TURNO COM VALIDAÇÃO DE META, CHECKBOX E PDF ====
  Future<void> _encerrarTurno(String turnoId, String veiculoId, String rotaId, int falta, List<QueryDocumentSnapshot> vistoriasConcluidas, String rotaNumero) async {
    final kmFinalController = TextEditingController();
    bool carregando = false;
    bool confirmouTermo = false;

    bool? sucessoEncerramento = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Encerrar Expediente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AVISO SOBRE A META DO DIA
                  if (falta > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Atenção! Faltam $falta semáforos para concluir a meta de hoje.', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(child: Text('Parabéns! Você concluiu 100% da meta de hoje.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  const Text('Para liberar a moto e gerar seu relatório PDF, informe a quilometragem final:'),
                  const SizedBox(height: 12),
                  TextField(controller: kmFinalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'KM Final', border: OutlineInputBorder(), prefixIcon: Icon(Icons.speed), suffixText: 'km')),
                  
                  const SizedBox(height: 16),
                  
                  // CHECKBOX OBRIGATÓRIO PARA O PDF
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.red,
                    title: const Text('Confirmo que os dados coletados são verdadeiros e concordo em gerar o relatório final do dia.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    value: confirmouTermo,
                    onChanged: (val) {
                      setStateDialog(() => confirmouTermo = val ?? false);
                    },
                  )
                ],
              ),
            ),
            actions: [
              if (!carregando) TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: carregando ? null : () async {
                  if (kmFinalController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite o KM Final!'), backgroundColor: Colors.orange));
                    return;
                  }
                  if (!confirmouTermo) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você precisa marcar a caixa de confirmação!'), backgroundColor: Colors.orange));
                    return;
                  }
                  setStateDialog(() => carregando = true);
                  Navigator.pop(context, true); 
                },
                child: carregando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Encerrar Turno'),
              ),
            ],
          );
        }
      ),
    );

    if (sucessoEncerramento == true) {
      try {
        await FirebaseFirestore.instance.collection('turnos').doc(turnoId).update({'status': 'finalizado', 'data_fim': FieldValue.serverTimestamp(), 'km_final': kmFinalController.text.trim()});
        await FirebaseFirestore.instance.collection('veiculos').doc(veiculoId).update({'em_uso': false});
        await FirebaseFirestore.instance.collection('rotas').doc(rotaId).update({'em_uso': false});
        
        if (mounted) { 
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turno encerrado! Gerando Relatório PDF...'), backgroundColor: Colors.green)); 
          
          // MOSTRA O PDF NA TELA!
          await _gerarEMostrarPDF(vistoriasConcluidas, rotaNumero);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao encerrar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text('Erro: Usuário não logado.')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vistoria em Campo', style: TextStyle(fontWeight: FontWeight.bold)),
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
        stream: FirebaseFirestore.instance.collection('turnos').where('vistoriador_uid', isEqualTo: user!.uid).where('status', isEqualTo: 'ativo').limit(1).snapshots(),
        builder: (context, snapshotTurno) {
          if (snapshotTurno.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshotTurno.hasData || snapshotTurno.data!.docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.block, size: 80, color: Colors.red.shade300), const SizedBox(height: 16), const Text('Nenhum turno ativo.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar ao Início'))]));
          }

          var turnoDoc = snapshotTurno.data!.docs.first;
          var turnoData = turnoDoc.data() as Map<String, dynamic>;
          String rotaNumero = turnoData['rota_numero'] ?? 'S/N';
          String rotaTurnoLimpa = rotaNumero.replaceFirst(RegExp(r'^0+'), ''); 

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('semaforos').snapshots(),
            builder: (context, snapshotSemaforo) {
              if (!snapshotSemaforo.hasData) return const Center(child: CircularProgressIndicator());
              
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('vistorias').where('turno_id', isEqualTo: turnoDoc.id).snapshots(),
                builder: (context, snapshotVistoria) {
                  if (!snapshotVistoria.hasData) return const Center(child: CircularProgressIndicator());

                  List<QueryDocumentSnapshot> vistoriasConcluidas = snapshotVistoria.data!.docs;
                  Set<String> vistoriadosIds = vistoriasConcluidas.map((doc) => doc['semaforo_id'].toString()).toSet();

                  List<DocumentSnapshot> todosDaRota = snapshotSemaforo.data!.docs.where((doc) {
                    return (doc.data() as Map<String, dynamic>)['rota'].toString().replaceFirst(RegExp(r'^0+'), '') == rotaTurnoLimpa;
                  }).toList();

                  // ==== LÓGICA DE DIAS CORRIDOS (DIAS PARES = GRUPO A / DIAS IMPARES = GRUPO B) ====
                  DateTime dataBase = DateTime(2024, 1, 1);
                  int diasPassados = DateTime.now().difference(dataBase).inDays;
                  String grupoDeHoje = (diasPassados % 2 == 0) ? 'A' : 'B';
                  // ==============================================================================

                  List<DocumentSnapshot> semaforosDoGrupo = todosDaRota.where((doc) {
                    String grupoDb = ((doc.data() as Map)['grupo'] ?? '').toString().toUpperCase();
                    return grupoDb == grupoDeHoje;
                  }).toList();

                  int meta = semaforosDoGrupo.length;
                  int concluidos = semaforosDoGrupo.where((doc) => vistoriadosIds.contains((doc.data() as Map)['id'].toString())).length;
                  int falta = meta - concluidos;
                  double percentual = meta == 0 ? 0.0 : (concluidos / meta);

                  List<DocumentSnapshot> semaforosPendentes = semaforosDoGrupo.where((doc) {
                    var semaforo = doc.data() as Map<String, dynamic>;
                    String id = semaforo['id'].toString();
                    return !vistoriadosIds.contains(id); 
                  }).toList();

                  var semaforosFiltradosPesquisa = semaforosPendentes.where((doc) {
                    if (_textoPesquisaAndamento.isEmpty) return true;
                    var data = doc.data() as Map<String, dynamic>;
                    String id = (data['id'] ?? '').toString().toLowerCase();
                    String end = (data['endereco'] ?? '').toString().toLowerCase();
                    return id.contains(_textoPesquisaAndamento) || end.contains(_textoPesquisaAndamento);
                  }).toList();

                  semaforosFiltradosPesquisa.sort((a, b) => (a.data() as Map)['id'].toString().compareTo((b.data() as Map)['id'].toString()));

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      // ==== ABA 1: EM ANDAMENTO ====
                      Column(
                        children: [
                          Container(
                            color: Colors.orange.shade50, padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Rota $rotaNumero', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                        Text('Seu Grupo de Hoje: $grupoDeHoje', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                                      icon: const Icon(Icons.stop_circle, size: 18), 
                                      label: const Text('Encerrar', style: TextStyle(fontWeight: FontWeight.bold)), 
                                      onPressed: () => _encerrarTurno(turnoDoc.id, turnoData['veiculo_id'] ?? '', turnoData['rota_id'] ?? '', falta, vistoriasConcluidas, rotaNumero) // <--- PASSA AS INFOS DA META AQUI
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(children: [const Icon(Icons.motorcycle, size: 18, color: Colors.grey), const SizedBox(width: 8), Text('Moto: ${turnoData['placa'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))]),
                                const SizedBox(height: 12),

                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Progresso: $concluidos de $meta', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)), Text('Faltam: $falta', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700))]),
                                const SizedBox(height: 6),
                                ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: percentual, minHeight: 10, backgroundColor: Colors.grey.shade300, color: Colors.green)),
                                const SizedBox(height: 4),
                                Align(alignment: Alignment.centerRight, child: Text('${(percentual * 100).toStringAsFixed(1)}% Concluído', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), color: Colors.white,
                            child: TextField(controller: _pesquisaAndamentoController, decoration: InputDecoration(hintText: 'Pesquisar nº ou endereço...', prefixIcon: const Icon(Icons.search), suffixIcon: _textoPesquisaAndamento.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _pesquisaAndamentoController.clear()) : null, filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0))),
                          ),
                          Expanded(
                            child: semaforosFiltradosPesquisa.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(falta == 0 && meta > 0 ? Icons.emoji_events : Icons.search_off, size: 80, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      Text(falta == 0 && meta > 0 ? '🎉 Rota Finalizada!' : 'Nenhum semáforo pendente do Grupo $grupoDeHoje.', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  )
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1),
                                  itemCount: semaforosFiltradosPesquisa.length,
                                  itemBuilder: (context, index) {
                                    var semaforo = semaforosFiltradosPesquisa[index].data() as Map<String, dynamic>;
                                    String idSemaforo = semaforo['id']?.toString() ?? 'S/N';
                                    String enderecoSemaforo = semaforo['endereco'] ?? 'Sem endereço cadastrado';
                                    
                                    return Tooltip(
                                      message: enderecoSemaforo, triggerMode: TooltipTriggerMode.longPress,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(100),
                                        onTap: () => _abrirVistoriaSemaforo(semaforo, turnoDoc.id),
                                        child: Container(
                                          decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle, border: Border.all(color: Colors.orange, width: 2), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))]),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(idSemaforo, style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
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
                            color: Colors.white, padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), icon: const Icon(Icons.picture_as_pdf), label: const Text('Baixar PDF de Hoje'), onPressed: () => _gerarEMostrarPDF(vistoriasConcluidas, rotaNumero)),
                                ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), icon: const Icon(Icons.grid_on), label: const Text('Exportar Excel'), onPressed: () => _exportarExcelConcluidos(vistoriasConcluidas, rotaNumero)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.white,
                            child: TextField(controller: _pesquisaConcluidosController, decoration: InputDecoration(hintText: 'Pesquisar na lista...', prefixIcon: const Icon(Icons.search), suffixIcon: _textoPesquisaConcluidos.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _pesquisaConcluidosController.clear()) : null, filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0))),
                          ),
                          Expanded(
                            child: vistoriasConcluidas.isEmpty
                              ? const Center(child: Text('Nenhuma vistoria finalizada ainda.', style: TextStyle(color: Colors.grey)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: vistoriasConcluidas.length,
                                  itemBuilder: (context, index) {
                                    var vistoria = vistoriasConcluidas[index].data() as Map<String, dynamic>;
                                    String idSemaforo = vistoria['semaforo_id']?.toString() ?? '';
                                    String endSemaforo = vistoria['semaforo_endereco']?.toString() ?? '';
                                    
                                    if (_textoPesquisaConcluidos.isNotEmpty && !idSemaforo.toLowerCase().contains(_textoPesquisaConcluidos) && !endSemaforo.toLowerCase().contains(_textoPesquisaConcluidos)) return const SizedBox.shrink();

                                    bool temFalha = vistoria['teve_anormalidade'] == true;
                                    Color corFundo = temFalha ? Colors.red.shade50 : Colors.grey.shade200;
                                    Color corIcone = temFalha ? Colors.red.shade700 : Colors.grey.shade600;

                                    return Card(
                                      color: corFundo,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: CircleAvatar(backgroundColor: corIcone, child: Text(idSemaforo, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                        title: Text('Semáforo $idSemaforo', style: TextStyle(fontWeight: FontWeight.bold, color: corIcone)),
                                        subtitle: Text(endSemaforo, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        trailing: Icon(temFalha ? Icons.warning_amber_rounded : Icons.check_circle, color: corIcone),
                                        onTap: () => _mostrarDetalhesVistoria(vistoria),
                                      ),
                                    );
                                  },
                                )
                          )
                        ],
                      )
                    ],
                  );
                }
              );
            }
          );
        }
      ),
    );
  }
}