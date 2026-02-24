import 'package:flutter/material.dart';

class CadastroRotas extends StatefulWidget {
  const CadastroRotas({super.key});

  @override
  State<CadastroRotas> createState() => _CadastroRotasState();
}

class _CadastroRotasState extends State<CadastroRotas> {
  final List<String> _rotas = [];
  final _numeroRotaController = TextEditingController();

  void _abrirFormulario() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24, left: 24, right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cadastrar Nova Rota', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _numeroRotaController,
                keyboardType: TextInputType.number, // Abre o teclado numérico
                decoration: const InputDecoration(labelText: 'Número da Rota', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _salvarRota,
                  child: const Text('Salvar Rota'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _salvarRota() {
    if (_numeroRotaController.text.isEmpty) return;
    setState(() {
      _rotas.add(_numeroRotaController.text);
    });
    _numeroRotaController.clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rotas'), backgroundColor: Colors.brown.shade100),
      body: _rotas.isEmpty
          ? const Center(child: Text('Nenhuma rota cadastrada.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rotas.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.brown, child: Icon(Icons.route, color: Colors.white)),
                    title: Text('Rota ${_rotas[index]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _rotas.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormulario,
        backgroundColor: Colors.brown,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}