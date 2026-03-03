import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gerenciador_semaforos_rota_page.dart'; // NOVA TELA QUE CRIAMOS

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

  void _abrirFormulario({String? rotaId, String? numeroAtual, Color? corAtual}) {
    _numeroRotaController.text = numeroAtual ?? '';
    _corSelecionada = corAtual; 

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
                  Text(rotaId == null ? 'Cadastrar Nova Rota' : 'Editar Rota', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(controller: _numeroRotaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número da Rota', border: OutlineInputBorder())),
                  const SizedBox(height: 24),
                  const Align(alignment: Alignment.centerLeft, child: Text('Escolha a cor da Rota:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, 
                    children: _paletaExpandida.map((cor) {
                      bool isSelecionada = _corSelecionada == cor;
                      return GestureDetector(
                        onTap: () => setModalState(() => _corSelecionada = cor),
                        child: CircleAvatar(radius: 24, backgroundColor: cor, child: isSelecionada ? const Icon(Icons.check, color: Colors.white, size: 28) : null),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _estaCarregando ? null : () => _salvarRota(setModalState, rotaId),
                      child: _estaCarregando ? const CircularProgressIndicator(color: Colors.white) : Text(rotaId == null ? 'Salvar Rota' : 'Atualizar Rota', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Future<void> _salvarRota(StateSetter setModalState, String? rotaId) async {
    if (_numeroRotaController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha o número da rota!'))); return; }
    if (_corSelecionada == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, escolha uma cor!'))); return; }

    setModalState(() => _estaCarregando = true);

    try {
      var rotasExistentes = await FirebaseFirestore.instance.collection('rotas').where('numero', isEqualTo: _numeroRotaController.text.trim()).get();
      bool isDuplicado = false;
      for (var doc in rotasExistentes.docs) {
        if (rotaId == null || doc.id != rotaId) { isDuplicado = true; break; }
      }

      if (isDuplicado) {
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta rota já está cadastrada!'), backgroundColor: Colors.red)); setModalState(() => _estaCarregando = false); }
        return;
      }

      final dadosDaRota = {
        'numero': _numeroRotaController.text.trim(),
        'cor': _corSelecionada!.value,
        if (rotaId == null) 'criado_em': FieldValue.serverTimestamp(), 
      };

      if (rotaId != null) {
        await FirebaseFirestore.instance.collection('rotas').doc(rotaId).update(dadosDaRota);
      } else {
        await FirebaseFirestore.instance.collection('rotas').add(dadosDaRota);
      }

      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(rotaId == null ? 'Rota salva com sucesso!' : 'Rota atualizada com sucesso!'), backgroundColor: Colors.green)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar rota.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setModalState(() => _estaCarregando = false);
    }
  }

  // ==== NOVA FUNÇÃO: DELETAR COM CONFIRMAÇÃO ====
  Future<void> _deletarRota(String id, String numeroRota) async {
    bool? confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir Rota', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text('Tem certeza que deseja excluir a Rota $numeroRota? Esta ação não pode ser desfeita.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Retorna Falso
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true), // Retorna Verdadeiro
              child: const Text('Sim, Excluir'),
            ),
          ],
        );
      }
    );

    // Só apaga do banco se ele tiver clicado no botão VERMELHO "Sim, Excluir"
    if (confirmou == true) {
      try {
        await FirebaseFirestore.instance.collection('rotas').doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota excluída com sucesso!'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir rota!'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rotas e Grupos A/B'), backgroundColor: Colors.brown.shade100),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rotas').orderBy('numero').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar rotas.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final rotas = snapshot.data!.docs;
          if (rotas.isEmpty) return const Center(child: Text('Nenhuma rota cadastrada.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rotas.length,
            itemBuilder: (context, index) {
              final rotaDoc = rotas[index];
              final data = rotaDoc.data() as Map<String, dynamic>;
              String numeroRota = data['numero']?.toString() ?? '';
              Color corDaRota = data['cor'] != null ? Color(data['cor']) : Colors.grey;

              return Card(
                elevation: 2, margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: corDaRota.withOpacity(0.5), width: 1.5)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: corDaRota, child: const Icon(Icons.route, color: Colors.white)),
                  title: Text('Rota $numeroRota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: corDaRota.withOpacity(0.9))),
                  subtitle: const Text('Toque para gerenciar Grupo A e B', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  
                  // ==== NAVEGA PARA A TELA DOS GRUPOS ====
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GerenciadorSemaforosRotaPage(rotaNumero: numeroRota, corRota: corDaRota)
                      )
                    );
                  },

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue), 
                        onPressed: () => _abrirFormulario(rotaId: rotaDoc.id, numeroAtual: data['numero'], corAtual: corDaRota)
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red), 
                        onPressed: () => _deletarRota(rotaDoc.id, numeroRota) // Agora chama com o nome da rota e confirmação
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
        onPressed: () => _abrirFormulario(), 
        backgroundColor: Colors.brown, child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}