import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CadastroRotas extends StatefulWidget {
  const CadastroRotas({super.key});

  @override
  State<CadastroRotas> createState() => _CadastroRotasState();
}

class _CadastroRotasState extends State<CadastroRotas> {
  final _numeroRotaController = TextEditingController();
  bool _estaCarregando = false;
  
  // Variável para guardar a cor que o usuário tocou
  Color? _corSelecionada; 

  // Nova paleta expandida com 12 cores diferentes
  final List<Color> _paletaExpandida = [
    Colors.blue,               // Azul
    Colors.purple,             // Roxo
    Colors.amber.shade700,     // Amarelo escuro (melhor contraste)
    Colors.orange,             // Laranja
    Colors.green,              // Verde
    Colors.red,                // Vermelho
    Colors.pink,               // Rosa
    Colors.teal,               // Verde-água
    Colors.indigo,             // Azul escuro/Índigo
    Colors.brown,              // Marrom
    Colors.cyan.shade700,      // Ciano escuro
    Colors.deepOrange,         // Laranja escuro / Ferrugem
  ];

  void _abrirFormulario() {
    _numeroRotaController.clear();
    _corSelecionada = null; 

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Cadastrar Nova Rota', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _numeroRotaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Número da Rota', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Escolha a cor da Rota:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),

                  // Paleta de cores com as 12 opções
                  Wrap(
                    spacing: 12, // Espaço horizontal
                    runSpacing: 12, // Espaço vertical
                    alignment: WrapAlignment.center, // Centraliza as bolinhas
                    children: _paletaExpandida.map((cor) {
                      bool isSelecionada = _corSelecionada == cor;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            _corSelecionada = cor; 
                          });
                        },
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: cor,
                          child: isSelecionada ? const Icon(Icons.check, color: Colors.white, size: 28) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _estaCarregando ? null : () => _salvarRota(setModalState),
                      child: _estaCarregando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Salvar Rota', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Future<void> _salvarRota(StateSetter setModalState) async {
    if (_numeroRotaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha o número da rota!')));
      return;
    }
    if (_corSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, escolha uma cor!')));
      return;
    }

    setModalState(() => _estaCarregando = true);

    try {
      // Verifica se a rota já existe
      var rotasExistentes = await FirebaseFirestore.instance
          .collection('rotas')
          .where('numero', isEqualTo: _numeroRotaController.text.trim())
          .get();

      if (rotasExistentes.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta rota já está cadastrada!'), backgroundColor: Colors.red));
          setModalState(() => _estaCarregando = false);
        }
        return;
      }

      // Salva a nova rota
      await FirebaseFirestore.instance.collection('rotas').add({
        'numero': _numeroRotaController.text.trim(),
        'cor': _corSelecionada!.value,
        'criado_em': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota salva com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar rota.'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setModalState(() => _estaCarregando = false);
      }
    }
  }

  Future<void> _deletarRota(String id) async {
    await FirebaseFirestore.instance.collection('rotas').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rotas'), backgroundColor: Colors.brown.shade100),
      body: StreamBuilder<QuerySnapshot>(
        // Tentamos ordenar por número (lembrando que como salvamos String, o 10 vem antes do 2, mas no Firestore podemos corrigir isso depois se for necessário)
        stream: FirebaseFirestore.instance.collection('rotas').orderBy('numero').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar rotas.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rotas = snapshot.data!.docs;

          if (rotas.isEmpty) {
            return const Center(child: Text('Nenhuma rota cadastrada.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rotas.length,
            itemBuilder: (context, index) {
              final rotaDoc = rotas[index];
              final data = rotaDoc.data() as Map<String, dynamic>;

              Color corDaRota = data['cor'] != null ? Color(data['cor']) : Colors.grey;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: corDaRota.withOpacity(0.5), width: 1.5), 
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: corDaRota,
                    child: const Icon(Icons.route, color: Colors.white),
                  ),
                  title: Text(
                    'Rota ${data['numero']}', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: corDaRota.withOpacity(0.9)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deletarRota(rotaDoc.id),
                  ),
                ),
              );
            },
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