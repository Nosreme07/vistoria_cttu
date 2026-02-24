import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CadastroVeiculo extends StatefulWidget {
  const CadastroVeiculo({super.key});

  @override
  State<CadastroVeiculo> createState() => _CadastroVeiculoState();
}

class _CadastroVeiculoState extends State<CadastroVeiculo> {
  // Controladores para capturar o que o usuário digita
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _placaController = TextEditingController();
  final _empresaController = TextEditingController(); // Novo controlador

  bool _estaCarregando = false; // Controle do botão de salvar

  // Função para abrir o formulário de cadastro (Bottom Sheet)
  void _abrirFormularioCadastro() {
    // Limpa os campos sempre que abrir
    _marcaController.clear();
    _modeloController.clear();
    _placaController.clear();
    _empresaController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder( // Necessário para a bolinha de carregamento do botão funcionar
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
                    const Text('Cadastrar Veículo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

                    // Novo Campo: Empresa
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
                        onPressed: _estaCarregando ? null : () => _salvarVeiculo(setModalState),
                        child: _estaCarregando
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Salvar Veículo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // Função assíncrona para salvar no Firebase
  Future<void> _salvarVeiculo(StateSetter setModalState) async {
    if (_marcaController.text.isEmpty || 
        _modeloController.text.isEmpty || 
        _placaController.text.isEmpty || 
        _empresaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos!')));
      return;
    }

    setModalState(() => _estaCarregando = true);

    try {
      // Salvando os dados na coleção 'veiculos' do Firestore
      await FirebaseFirestore.instance.collection('veiculos').add({
        'marca': _marcaController.text.toUpperCase().trim(),
        'modelo': _modeloController.text.toUpperCase().trim(),
        'placa': _placaController.text.toUpperCase().trim(),
        'empresa': _empresaController.text.toUpperCase().trim(),
        'criado_em': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Fecha o modal
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veículo salvo com sucesso!'), backgroundColor: Colors.green));
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

  // Função para deletar o veículo do Firebase
  Future<void> _deletarVeiculo(String id) async {
    await FirebaseFirestore.instance.collection('veiculos').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veículos'),
        backgroundColor: Colors.indigo.shade100,
      ),
      // Substituindo a lista local pelo StreamBuilder do Firebase
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('veiculos').orderBy('marca').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar veículos.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final veiculos = snapshot.data!.docs;

          if (veiculos.isEmpty) {
            return const Center(child: Text('Nenhum veículo cadastrado.'));
          }

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
                  isThreeLine: true, // Permite que o subtítulo ocupe duas linhas sem cortar
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deletarVeiculo(veiculoDoc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormularioCadastro,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}