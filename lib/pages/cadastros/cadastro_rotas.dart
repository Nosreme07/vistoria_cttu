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
  
  Color? _corSelecionada; 

  final List<Color> _paletaExpandida = [
    Colors.blue,
    Colors.purple,
    Colors.amber.shade700,
    Colors.orange,
    Colors.green,
    Colors.red,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
    Colors.cyan.shade700,
    Colors.deepOrange,
  ];

  // A função agora aceita parâmetros opcionais. Se vier com dados, é modo Edição!
  void _abrirFormulario({String? rotaId, String? numeroAtual, Color? corAtual}) {
    // Se for edição, preenche com os dados antigos. Se for nova, limpa tudo.
    _numeroRotaController.text = numeroAtual ?? '';
    _corSelecionada = corAtual; 

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
                  // Muda o título dependendo se está editando ou criando
                  Text(
                    rotaId == null ? 'Cadastrar Nova Rota' : 'Editar Rota', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
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

                  Wrap(
                    spacing: 12, 
                    runSpacing: 12, 
                    alignment: WrapAlignment.center, 
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
                      onPressed: _estaCarregando ? null : () => _salvarRota(setModalState, rotaId),
                      child: _estaCarregando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(rotaId == null ? 'Salvar Rota' : 'Atualizar Rota', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // Recebe o ID da rota se for uma edição
  Future<void> _salvarRota(StateSetter setModalState, String? rotaId) async {
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
      // Verifica se o número da rota já existe no banco
      var rotasExistentes = await FirebaseFirestore.instance
          .collection('rotas')
          .where('numero', isEqualTo: _numeroRotaController.text.trim())
          .get();

      // Se achou uma rota com esse número, precisamos ver se não é a própria rota que estamos editando!
      bool isDuplicado = false;
      for (var doc in rotasExistentes.docs) {
        if (rotaId == null || doc.id != rotaId) {
          isDuplicado = true; // Achou uma rota DIFERENTE com o MESMO número
          break;
        }
      }

      if (isDuplicado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta rota já está cadastrada!'), backgroundColor: Colors.red));
          setModalState(() => _estaCarregando = false);
        }
        return;
      }

      // Prepara os dados
      final dadosDaRota = {
        'numero': _numeroRotaController.text.trim(),
        'cor': _corSelecionada!.value,
        if (rotaId == null) 'criado_em': FieldValue.serverTimestamp(), // Só coloca a data de criação se for nova
      };

      // Se for edição (tem ID), faz o UPDATE. Se for nova, faz o ADD.
      if (rotaId != null) {
        await FirebaseFirestore.instance.collection('rotas').doc(rotaId).update(dadosDaRota);
      } else {
        await FirebaseFirestore.instance.collection('rotas').add(dadosDaRota);
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rotaId == null ? 'Rota salva com sucesso!' : 'Rota atualizada com sucesso!'), 
            backgroundColor: Colors.green
          )
        );
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
                  // Colocamos o Editar e o Excluir juntos dentro de uma Row
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _abrirFormulario(
                          rotaId: rotaDoc.id,
                          numeroAtual: data['numero'],
                          corAtual: corDaRota,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deletarRota(rotaDoc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(), // Sem parâmetros = Criação de nova rota
        backgroundColor: Colors.brown,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}