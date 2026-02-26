import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importações novas para o PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CadastroVeiculo extends StatefulWidget {
  const CadastroVeiculo({super.key});

  @override
  State<CadastroVeiculo> createState() => _CadastroVeiculoState();
}

class _CadastroVeiculoState extends State<CadastroVeiculo> {
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _placaController = TextEditingController();
  final _empresaController = TextEditingController();

  bool _estaCarregando = false; 

  void _abrirFormularioCadastro({String? veiculoId, String? marcaAtual, String? modeloAtual, String? placaAtual, String? empresaAtual}) {
    _marcaController.text = marcaAtual ?? '';
    _modeloController.text = modeloAtual ?? '';
    _placaController.text = placaAtual ?? '';
    _empresaController.text = empresaAtual ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24, left: 24, right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      veiculoId == null ? 'Cadastrar Veículo' : 'Editar Veículo', 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _marcaController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Marca (Ex: FIAT)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _modeloController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Modelo (Ex: UNO)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _placaController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Placa (Ex: ABC-1234)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _empresaController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Empresa', 
                        hintText: 'Ex: SERTTEL',
                        border: OutlineInputBorder()
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _estaCarregando ? null : () => _salvarVeiculo(setModalState, veiculoId),
                        child: _estaCarregando
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(veiculoId == null ? 'Salvar Veículo' : 'Atualizar Veículo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _salvarVeiculo(StateSetter setModalState, String? veiculoId) async {
    if (_marcaController.text.isEmpty || 
        _modeloController.text.isEmpty || 
        _placaController.text.isEmpty || 
        _empresaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos!')));
      return;
    }

    setModalState(() => _estaCarregando = true);

    try {
      String placaDigitada = _placaController.text.toUpperCase().trim();

      var placaExistente = await FirebaseFirestore.instance
          .collection('veiculos')
          .where('placa', isEqualTo: placaDigitada)
          .get();

      bool isDuplicado = false;
      for (var doc in placaExistente.docs) {
        if (veiculoId == null || doc.id != veiculoId) {
          isDuplicado = true; 
          break;
        }
      }

      if (isDuplicado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta placa já está cadastrada!'), backgroundColor: Colors.red));
          setModalState(() => _estaCarregando = false);
        }
        return;
      }

      final dadosVeiculo = {
        'marca': _marcaController.text.toUpperCase().trim(),
        'modelo': _modeloController.text.toUpperCase().trim(),
        'placa': placaDigitada,
        'empresa': _empresaController.text.toUpperCase().trim(),
        if (veiculoId == null) 'criado_em': FieldValue.serverTimestamp(),
      };

      if (veiculoId != null) {
        await FirebaseFirestore.instance.collection('veiculos').doc(veiculoId).update(dadosVeiculo);
      } else {
        await FirebaseFirestore.instance.collection('veiculos').add(dadosVeiculo);
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(veiculoId == null ? 'Veículo salvo com sucesso!' : 'Veículo atualizado!'), 
            backgroundColor: Colors.green
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar veículo.'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setModalState(() => _estaCarregando = false);
      }
    }
  }

  Future<void> _deletarVeiculo(String id) async {
    await FirebaseFirestore.instance.collection('veiculos').doc(id).delete();
  }

  // ==== FUNÇÃO PARA GERAR O PDF DOS VEÍCULOS ====
  Future<void> _gerarPDF() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando PDF... Aguarde!'), backgroundColor: Colors.indigo));

    try {
      // 1. Busca os veículos no banco de dados
      final snapshot = await FirebaseFirestore.instance.collection('veiculos').orderBy('marca').get();
      final veiculos = snapshot.docs;

      // 2. Agrupa os veículos por empresa
      Map<String, List<Map<String, dynamic>>> veiculosPorEmpresa = {};
      
      for (var doc in veiculos) {
        final data = doc.data();
        final empresa = (data['empresa'] ?? 'NÃO INFORMADA').toString().toUpperCase();
        
        if (!veiculosPorEmpresa.containsKey(empresa)) {
          veiculosPorEmpresa[empresa] = [];
        }
        veiculosPorEmpresa[empresa]!.add(data);
      }

      // 3. Cria o documento PDF
      final pdf = pw.Document();

      // 4. Desenha a folha A4
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Cabeçalho
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Relatório de Frota CTTU', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Total de Veículos: ${veiculos.length}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ]
                )
              ),
              pw.SizedBox(height: 24),

              if (veiculosPorEmpresa.isEmpty) pw.Text('Nenhum veículo cadastrado no sistema.'),

              // Laço para desenhar a lista separada por empresa
              ...veiculosPorEmpresa.entries.map((entry) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 16),
                    pw.Text('EMPRESA: ${entry.key}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF3949AB))), // Cor índigo no título
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    ...entry.value.map((veiculo) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6, left: 8),
                      child: pw.Bullet(
                        text: '${veiculo['marca']} ${veiculo['modelo']} | Placa: ${veiculo['placa']}', 
                        style: const pw.TextStyle(fontSize: 14)
                      ),
                    )),
                  ]
                );
              }),
            ];
          }
        )
      );

      // 5. Exibe a pré-visualização para imprimir/salvar
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Relatorio_Frota_CTTU.pdf',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao gerar PDF!'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veículos'),
        backgroundColor: Colors.indigo.shade100,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('veiculos').orderBy('marca').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar veículos.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final veiculos = snapshot.data!.docs;

          if (veiculos.isEmpty) return const Center(child: Text('Nenhum veículo cadastrado.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: veiculos.length,
            itemBuilder: (context, index) {
              final veiculoDoc = veiculos[index];
              final veiculoData = veiculoDoc.data() as Map<String, dynamic>;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.directions_car, color: Colors.white),
                  ),
                  title: Text('${veiculoData['marca']} ${veiculoData['modelo']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Placa: ${veiculoData['placa']}\nEmpresa: ${veiculoData['empresa']}'),
                  isThreeLine: true, 
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _abrirFormularioCadastro(
                          veiculoId: veiculoDoc.id,
                          marcaAtual: veiculoData['marca'],
                          modeloAtual: veiculoData['modelo'],
                          placaAtual: veiculoData['placa'],
                          empresaAtual: veiculoData['empresa'],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deletarVeiculo(veiculoDoc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // Adicionado a coluna para termos os 2 botões flutuantes!
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'btnPdfVeiculo', // Tag única para não dar erro
            onPressed: _gerarPDF,
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.picture_as_pdf, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'btnAddVeiculo', // Tag única para não dar erro
            onPressed: () => _abrirFormularioCadastro(),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}