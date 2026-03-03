import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GerenciadorSemaforosRotaPage extends StatefulWidget {
  final String rotaNumero;
  final Color corRota;

  const GerenciadorSemaforosRotaPage({super.key, required this.rotaNumero, required this.corRota});

  @override
  State<GerenciadorSemaforosRotaPage> createState() => _GerenciadorSemaforosRotaPageState();
}

class _GerenciadorSemaforosRotaPageState extends State<GerenciadorSemaforosRotaPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Função para abrir modal listando APENAS OS SEMÁFOROS DESTA ROTA
  void _abrirModalAdicionarSemaforo(String grupoDesejado) {
    String minhaRotaLimpa = widget.rotaNumero.replaceFirst(RegExp(r'^0+'), '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Distribuir Semáforos da Rota ${widget.rotaNumero} - Grupo $grupoDesejado', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),

              // Lista de Semáforos DESTA ROTA
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('semaforos').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    // FILTRA APENAS OS SEMÁFOROS QUE JÁ PERTENCEM A ESTA ROTA
                    var semaforosDaRota = snapshot.data!.docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      String rotaDb = (data['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
                      return rotaDb == minhaRotaLimpa;
                    }).toList();

                    semaforosDaRota.sort((a, b) => ((a.data() as Map)['id'] ?? '').toString().compareTo(((b.data() as Map)['id'] ?? '').toString()));

                    if (semaforosDaRota.isEmpty) {
                      return const Center(child: Text('Nenhum semáforo cadastrado nesta rota ainda. Vá no Menu de Semáforos para vincular.'));
                    }

                    return ListView.builder(
                      itemCount: semaforosDaRota.length,
                      itemBuilder: (context, index) {
                        var semaforo = semaforosDaRota[index];
                        var data = semaforo.data() as Map<String, dynamic>;
                        String id = data['id']?.toString() ?? 'S/N';
                        String grupoAtual = data['grupo'] ?? '';
                        
                        bool jaNesteGrupo = grupoAtual == grupoDesejado;

                        return ListTile(
                          leading: CircleAvatar(backgroundColor: jaNesteGrupo ? widget.corRota : Colors.grey.shade300, child: Text(id, style: TextStyle(color: jaNesteGrupo ? Colors.white : Colors.black87, fontSize: 12))),
                          title: Text('Semáforo $id'),
                          subtitle: Text(grupoAtual.isEmpty ? 'Sem grupo definido' : 'Atualmente no Grupo $grupoAtual', style: TextStyle(color: jaNesteGrupo ? Colors.green : Colors.grey)),
                          trailing: jaNesteGrupo 
                            ? const Icon(Icons.check_circle, color: Colors.green) 
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: widget.corRota, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0)),
                                onPressed: () async {
                                  // ATUALIZA O GRUPO DO SEMÁFORO
                                  await FirebaseFirestore.instance.collection('semaforos').doc(semaforo.id).update({
                                    'grupo': grupoDesejado
                                  });
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Semáforo $id movido para o Grupo $grupoDesejado!'), backgroundColor: Colors.green));
                                },
                                child: Text(grupoAtual.isEmpty ? 'Adicionar' : 'Mover para $grupoDesejado'),
                              ),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black), onPressed: () => Navigator.pop(context), child: const Text('Concluído')))
            ],
          ),
        );
      }
    );
  }

  // Função para limpar o grupo de um semáforo (Ele continua na Rota, mas sem grupo)
  Future<void> _removerSemaforoDoGrupo(String idDocSemaforo) async {
    await FirebaseFirestore.instance.collection('semaforos').doc(idDocSemaforo).update({
      'grupo': ''
    });
  }

  // Widget para construir a lista de cada Aba
  Widget _buildAbaGrupo(String grupo) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: widget.corRota, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            icon: const Icon(Icons.compare_arrows),
            label: Text('DISTRIBUIR SEMÁFOROS (GRUPO $grupo)', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _abrirModalAdicionarSemaforo(grupo),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('semaforos').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              String minhaRotaLimpa = widget.rotaNumero.replaceFirst(RegExp(r'^0+'), '');

              // Filtra só os que são DESTA ROTA e DESTE GRUPO
              var semaforosDesteGrupo = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String rotaDb = (data['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
                String grupoDb = data['grupo'] ?? '';
                return rotaDb == minhaRotaLimpa && grupoDb == grupo;
              }).toList();

              semaforosDesteGrupo.sort((a, b) => ((a.data() as Map)['id'] ?? '').toString().compareTo(((b.data() as Map)['id'] ?? '').toString()));

              if (semaforosDesteGrupo.isEmpty) {
                return Center(child: Text('Nenhum semáforo no Grupo $grupo desta rota.', style: const TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                itemCount: semaforosDesteGrupo.length,
                itemBuilder: (context, index) {
                  var docSemaforo = semaforosDesteGrupo[index];
                  var data = docSemaforo.data() as Map<String, dynamic>;
                  String id = data['id']?.toString() ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: widget.corRota, child: Text(id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      title: Text('Semáforo $id', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(data['endereco'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Remover do Grupo',
                        onPressed: () => _removerSemaforoDoGrupo(docSemaforo.id),
                      ),
                    ),
                  );
                },
              );
            }
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestão Rota ${widget.rotaNumero}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: widget.corRota.withOpacity(0.8),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'DIA A (GRUPO A)'),
            Tab(text: 'DIA B (GRUPO B)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbaGrupo('A'),
          _buildAbaGrupo('B'),
        ],
      ),
    );
  }
}