import 'package:flutter/material.dart';

class CadastroVistoriadores extends StatefulWidget {
  const CadastroVistoriadores({super.key});

  @override
  State<CadastroVistoriadores> createState() => _CadastroVistoriadoresState();
}

class _CadastroVistoriadoresState extends State<CadastroVistoriadores> {
  final List<String> _vistoriadores = [];
  final _nomeController = TextEditingController();

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
              const Text('Cadastrar Vistoriador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _nomeController,
                textCapitalization: TextCapitalization.words, // Primeira letra maiúscula
                decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _salvarVistoriador,
                  child: const Text('Salvar'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _salvarVistoriador() {
    if (_nomeController.text.isEmpty) return;
    setState(() {
      _vistoriadores.add(_nomeController.text);
    });
    _nomeController.clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vistoriadores'), backgroundColor: Colors.teal.shade100),
      body: _vistoriadores.isEmpty
          ? const Center(child: Text('Nenhum vistoriador cadastrado.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _vistoriadores.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
                    title: Text(_vistoriadores[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _vistoriadores.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormulario,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}