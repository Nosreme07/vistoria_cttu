import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importações para o PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CadastroTiposFalha extends StatefulWidget {
  const CadastroTiposFalha({super.key});

  @override
  State<CadastroTiposFalha> createState() => _CadastroTiposFalhaState();
}

class _CadastroTiposFalhaState extends State<CadastroTiposFalha> {
  final _falhaController = TextEditingController();
  final _prazoController = TextEditingController();
  final _pesquisaController = TextEditingController(); 

  String _textoPesquisa = '';
  bool _estaCarregando = false;

  @override
  void initState() {
    super.initState();
    _pesquisaController.addListener(() {
      setState(() {
        _textoPesquisa = _pesquisaController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    _falhaController.dispose();
    _prazoController.dispose();
    super.dispose();
  }

  // ==== FORMULÁRIO (CRIAR E EDITAR) ====
  void _abrirFormulario({String? falhaId, String? falhaAtual, int? prazoAtual}) {
    _falhaController.text = falhaAtual ?? '';
    _prazoController.text = prazoAtual != null ? prazoAtual.toString() : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24, left: 24, right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(falhaId == null ? 'Nova Falha' : 'Editar Falha', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _falhaController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Descrição da Falha', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _prazoController,
                    keyboardType: TextInputType.number, 
                    decoration: const InputDecoration(
                      labelText: 'Prazo (em minutos)', 
                      hintText: 'Ex: 240',
                      border: OutlineInputBorder(),
                      suffixText: 'min',
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _estaCarregando ? null : () => _salvarFalha(setModalState, falhaId),
                      child: _estaCarregando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(falhaId == null ? 'Salvar Falha' : 'Atualizar Falha', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Future<void> _salvarFalha(StateSetter setModalState, String? falhaId) async {
    if (_falhaController.text.isEmpty || _prazoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos!')));
      return;
    }

    setModalState(() => _estaCarregando = true);

    try {
      String nomeDigitado = _falhaController.text.toUpperCase().trim();

      // Trava de Segurança: Checa se a falha já existe
      var falhaExistente = await FirebaseFirestore.instance
          .collection('tipos_falha')
          .where('falha', isEqualTo: nomeDigitado)
          .get();

      bool isDuplicado = false;
      for (var doc in falhaExistente.docs) {
        if (falhaId == null || doc.id != falhaId) {
          isDuplicado = true; 
          break;
        }
      }

      if (isDuplicado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta falha já está cadastrada!'), backgroundColor: Colors.red));
          setModalState(() => _estaCarregando = false);
        }
        return;
      }

      final dadosFalha = {
        'falha': nomeDigitado,
        'prazo': int.tryParse(_prazoController.text.trim()) ?? 0, 
        if (falhaId == null) 'criado_em': FieldValue.serverTimestamp(),
      };

      if (falhaId != null) {
        await FirebaseFirestore.instance.collection('tipos_falha').doc(falhaId).update(dadosFalha);
      } else {
        await FirebaseFirestore.instance.collection('tipos_falha').add(dadosFalha);
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar.'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setModalState(() => _estaCarregando = false);
    }
  }

  Future<void> _deletarFalha(String id) async {
    await FirebaseFirestore.instance.collection('tipos_falha').doc(id).delete();
  }

  // ==== GERADOR DE PDF ====
  Future<void> _gerarPDF() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando PDF... Aguarde!'), backgroundColor: Colors.orange));

    try {
      final snapshot = await FirebaseFirestore.instance.collection('tipos_falha').orderBy('falha').get();
      final falhas = snapshot.docs;

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tipos de Falhas e Prazos - CTTU', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Total: ${falhas.length}', style: pw.TextStyle(fontSize: 14)),
                  ]
                )
              ),
              pw.SizedBox(height: 16),
              
              pw.Table.fromTextArray(
                context: context,
                headers: ['Descrição da Falha', 'Prazo de Atendimento'],
                data: falhas.map((doc) {
                  final data = doc.data();
                  return [
                    data['falha'] ?? '',
                    '${data['prazo'] ?? 0} minutos'
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                },
              ),
            ];
          }
        )
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Tabela_Falhas_CTTU.pdf',
      );

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao gerar PDF!'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipos de Falhas'),
        backgroundColor: Colors.orange.shade100,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _pesquisaController,
              decoration: InputDecoration(
                labelText: 'Pesquisar falha...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _textoPesquisa.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _pesquisaController.clear())
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('tipos_falha').orderBy('falha').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Erro ao carregar dados.'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                var falhas = snapshot.data!.docs;

                if (_textoPesquisa.isNotEmpty) {
                  falhas = falhas.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final descricao = (data['falha'] ?? '').toString().toLowerCase();
                    return descricao.contains(_textoPesquisa);
                  }).toList();
                }

                if (falhas.isEmpty) return const Center(child: Text('Nenhuma falha encontrada.'));

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80), 
                  itemCount: falhas.length,
                  itemBuilder: (context, index) {
                    final doc = falhas[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                        ),
                        title: Text(data['falha'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Prazo de atendimento: ${data['prazo']} minutos'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _abrirFormulario(
                                falhaId: doc.id,
                                falhaAtual: data['falha'],
                                prazoAtual: data['prazo'],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deletarFalha(doc.id),
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
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'btnPdfFalha',
            onPressed: _gerarPDF,
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.picture_as_pdf, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'btnAddFalha',
            onPressed: () => _abrirFormulario(),
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}