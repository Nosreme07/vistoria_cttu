import 'package:flutter/material.dart';

class CadastroVeiculo extends StatefulWidget {
  const CadastroVeiculo({super.key});

  @override
  State<CadastroVeiculo> createState() => _CadastroVeiculoState();
}

class _CadastroVeiculoState extends State<CadastroVeiculo> {
  // Lista temporária para simular o banco de dados (Firebase virá depois)
  final List<Map<String, String>> _veiculos = [];

  // Controladores para capturar o que o usuário digita
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _placaController = TextEditingController();

  // Função para abrir o formulário de cadastro (Bottom Sheet)
  void _abrirFormularioCadastro() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que o modal ocupe mais espaço se necessário
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          // Este padding ajusta o layout quando o teclado do celular sobe
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cadastrar Veículo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _marcaController,
                decoration: const InputDecoration(labelText: 'Marca (Ex: Fiat)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _modeloController,
                decoration: const InputDecoration(labelText: 'Modelo (Ex: Uno)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _placaController,
                decoration: const InputDecoration(labelText: 'Placa (Ex: ABC-1234)', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.characters, // Força a placa a ficar em maiúsculo
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _salvarVeiculo,
                  child: const Text('Salvar Veículo', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // Função para salvar o veículo na lista e fechar o modal
  void _salvarVeiculo() {
    if (_marcaController.text.isEmpty || _modeloController.text.isEmpty || _placaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos!')));
      return;
    }

    setState(() {
      _veiculos.add({
        'marca': _marcaController.text,
        'modelo': _modeloController.text,
        'placa': _placaController.text,
      });
    });

    // Limpa os campos
    _marcaController.clear();
    _modeloController.clear();
    _placaController.clear();

    // Fecha o modal
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veículos'),
        backgroundColor: Colors.indigo.shade100,
      ),
      body: _veiculos.isEmpty
          ? const Center(child: Text('Nenhum veículo cadastrado.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _veiculos.length,
              itemBuilder: (context, index) {
                final veiculo = _veiculos[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.directions_car, color: Colors.white),
                    ),
                    title: Text('${veiculo['marca']} ${veiculo['modelo']}'),
                    subtitle: Text('Placa: ${veiculo['placa']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _veiculos.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
      // Botão flutuante no canto inferior direito para adicionar
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormularioCadastro,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}