import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FormularioRotaPage extends StatefulWidget {
  const FormularioRotaPage({super.key});

  @override
  State<FormularioRotaPage> createState() => _FormularioRotaPageState();
}

class _FormularioRotaPageState extends State<FormularioRotaPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  
  // Controladores para a barra de pesquisa
  final TextEditingController _pesquisaController = TextEditingController();
  String _textoPesquisa = '';

  @override
  void initState() {
    super.initState();
    // Atualiza a tela sempre que o usuário digitar algo na pesquisa
    _pesquisaController.addListener(() {
      setState(() {
        _textoPesquisa = _pesquisaController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  // ==== ENCERRAR O TURNO PEDINDO KM FINAL ====
  Future<void> _encerrarTurno(String turnoId, String veiculoId, String rotaId) async {
    final kmFinalController = TextEditingController();
    bool carregando = false;

    bool? confirmou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Encerrar Expediente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Para encerrar a rota e liberar a moto, informe a quilometragem final:'),
                const SizedBox(height: 16),
                TextField(
                  controller: kmFinalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'KM Final',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.speed),
                    suffixText: 'km',
                  ),
                ),
              ],
            ),
            actions: [
              if (!carregando)
                TextButton(
                  onPressed: () => Navigator.pop(context, false), 
                  child: const Text('Cancelar')
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: carregando ? null : () async {
                  if (kmFinalController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite o KM Final!'), backgroundColor: Colors.orange));
                    return;
                  }
                  setStateDialog(() => carregando = true);
                  Navigator.pop(context, true); 
                },
                child: carregando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Encerrar Turno'),
              ),
            ],
          );
        }
      ),
    );

    if (confirmou == true) {
      try {
        await FirebaseFirestore.instance.collection('turnos').doc(turnoId).update({
          'status': 'finalizado',
          'data_fim': FieldValue.serverTimestamp(),
          'km_final': kmFinalController.text.trim(),
        });
        
        await FirebaseFirestore.instance.collection('veiculos').doc(veiculoId).update({'em_uso': false});
        await FirebaseFirestore.instance.collection('rotas').doc(rotaId).update({'em_uso': false});
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turno encerrado com sucesso!'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao encerrar: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text('Erro: Usuário não logado.')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vistoria em Campo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade300,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('turnos')
            .where('vistoriador_uid', isEqualTo: user!.uid)
            .where('status', isEqualTo: 'ativo')
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, size: 80, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    const Text('Nenhum turno ativo.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Inicie o turno primeiro no menu anterior para acessar os semáforos.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Voltar ao Menu'),
                    )
                  ],
                ),
              ),
            );
          }

          var turnoDoc = snapshot.data!.docs.first;
          var turnoData = turnoDoc.data() as Map<String, dynamic>;

          String rotaNumero = turnoData['rota_numero'] ?? 'S/N';
          String placa = turnoData['placa'] ?? 'S/P';
          String veiculoId = turnoData['veiculo_id'] ?? '';
          String rotaId = turnoData['rota_id'] ?? '';

          String rotaTurnoLimpa = rotaNumero.replaceFirst(RegExp(r'^0+'), ''); 

          return Column(
            children: [
              // === CABEÇALHO DO TURNO ATIVO ===
              Container(
                color: Colors.orange.shade50,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rota $rotaNumero', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          icon: const Icon(Icons.stop_circle, size: 18),
                          label: const Text('Encerrar', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _encerrarTurno(turnoDoc.id, veiculoId, rotaId),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.motorcycle, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Moto em uso: $placa', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                  ],
                ),
              ),

              // === BARRA DE PESQUISA ===
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: TextField(
                  controller: _pesquisaController,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar nº do semáforo ou endereço...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _textoPesquisa.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _pesquisaController.clear()) 
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),

              // === LISTA DE SEMÁFOROS (GRID DE BOLINHAS) ===
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('semaforos').snapshots(),
                  builder: (context, semaforoSnapshot) {
                    if (semaforoSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!semaforoSnapshot.hasData || semaforoSnapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Nenhum semáforo cadastrado no banco.', style: TextStyle(color: Colors.grey)));
                    }

                    // FILTRO INFALÍVEL
                    var semaforos = semaforoSnapshot.data!.docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      
                      String rotaSemaforo = (data['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
                      if (rotaSemaforo != rotaTurnoLimpa) return false;

                      String id = (data['id'] ?? '').toString().toLowerCase();
                      String end = (data['endereco'] ?? '').toString().toLowerCase();
                      return id.contains(_textoPesquisa) || end.contains(_textoPesquisa);
                    }).toList();

                    semaforos.sort((a, b) => (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString()));

                    if (semaforos.isEmpty) {
                      return Center(child: Text('Nenhum semáforo encontrado na Rota $rotaNumero.', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, // 4 bolinhas por linha
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1, // Mantém perfeitamente redondo
                      ),
                      itemCount: semaforos.length,
                      itemBuilder: (context, index) {
                        var semaforo = semaforos[index].data() as Map<String, dynamic>;
                        String idSemaforo = semaforo['id']?.toString() ?? 'S/N';
                        String enderecoSemaforo = semaforo['endereco'] ?? 'Sem endereço cadastrado';
                        
                        return Tooltip(
                          message: enderecoSemaforo, // Mostra o endereço se segurar o dedo na bolinha
                          triggerMode: TooltipTriggerMode.longPress,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(100),
                            onTap: () {
                              // AQUI VAMOS ABRIR A TELA FINAL DO FORMULÁRIO
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abrindo formulário do Semáforo $idSemaforo...')));
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.orange, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  )
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  idSemaforo, 
                                  style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 18)
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}