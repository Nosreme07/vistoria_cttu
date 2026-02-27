import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IniciarTurnoPage extends StatefulWidget {
  const IniciarTurnoPage({super.key});

  @override
  State<IniciarTurnoPage> createState() => _IniciarTurnoPageState();
}

class _IniciarTurnoPageState extends State<IniciarTurnoPage> {
  final _kmController = TextEditingController();
  final _nomeController = TextEditingController(text: 'Carregando...');
  
  String? _veiculoSelecionadoId;
  String? _veiculoSelecionadoPlaca;
  
  String? _rotaSelecionadaId;
  String? _rotaSelecionadaNumero;

  String _nomeVistoriador = '';
  bool _confirmouIdentidade = false; // Controle da caixinha de confirmação
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _buscarNomeVistoriador();
  }

  @override
  void dispose() {
    _kmController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _buscarNomeVistoriador() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _nomeVistoriador = doc.data()?['nome_completo'] ?? doc.data()?['nome'] ?? user.email!;
          _nomeController.text = _nomeVistoriador; // Preenche o campo na tela
        });
      }
    }
  }

  Future<void> _salvarTurno() async {
    // 1. Valida se confirmou a identidade
    if (!_confirmouIdentidade) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, marque a caixa confirmando sua identidade!'), backgroundColor: Colors.orange));
      return;
    }

    // 2. Valida se preencheu o resto
    if (_veiculoSelecionadoId == null || _rotaSelecionadaId == null || _kmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos obrigatórios!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _carregando = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // 3. Cria o registro do Turno Ativo no Firestore
      await FirebaseFirestore.instance.collection('turnos').add({
        'vistoriador_uid': user.uid,
        'vistoriador_nome': _nomeVistoriador,
        'veiculo_id': _veiculoSelecionadoId,
        'placa': _veiculoSelecionadoPlaca,
        'km_inicial': _kmController.text.trim(),
        'km_final': null, // Preparado para receber o KM na hora de concluir o turno
        'rota_id': _rotaSelecionadaId,
        'rota_numero': _rotaSelecionadaNumero,
        'status': 'ativo', 
        'data_inicio': FieldValue.serverTimestamp(),
      });

      // 4. Bloqueia o Veículo e a Rota
      await FirebaseFirestore.instance.collection('veiculos').doc(_veiculoSelecionadoId).update({'em_uso': true});
      await FirebaseFirestore.instance.collection('rotas').doc(_rotaSelecionadaId).update({'em_uso': true});

      if (mounted) {
        Navigator.pop(context); // Fecha a tela
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turno Iniciado com sucesso! Boa vistoria.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao iniciar turno: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Expediente'),
        backgroundColor: Colors.teal.shade200,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mudou para o ícone de Moto
            const Icon(Icons.motorcycle, size: 60, color: Colors.teal),
            const SizedBox(height: 24),

            // ==== NOVO: CAMPO DE VISTORIADOR COM CONFIRMAÇÃO ====
            const Text('Vistoriador Responsável:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nomeController,
              readOnly: true, // Usuário não pode digitar/alterar
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
                filled: true,
                fillColor: Colors.grey.shade200, // Dá a aparência de bloqueado
              ),
            ),
            CheckboxListTile(
              title: const Text('Confirmo que sou o vistoriador acima e estou assumindo esta rota.'),
              value: _confirmouIdentidade,
              activeColor: Colors.teal,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (bool? value) {
                setState(() {
                  _confirmouIdentidade = value ?? false;
                });
              },
            ),
            const SizedBox(height: 20),
            
            // ==== CAMPO: VEÍCULO ====
            const Text('Selecione a Moto Disponível:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('veiculos').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Erro ao carregar veículos: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                // Filtro Inteligente: Aceita se for false OU se o campo nem existir (null)
                var veiculos = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return data['em_uso'] != true; 
                }).toList();
                
                if (veiculos.isEmpty) return const Text('Todas as motos estão em uso no momento.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));

                // Ordenação Alfabética local
                veiculos.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  return (dataA['placa'] ?? '').toString().compareTo((dataB['placa'] ?? '').toString());
                });

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.motorcycle)),
                  hint: const Text('Escolha uma placa...'),
                  value: _veiculoSelecionadoId,
                  items: veiculos.map((doc) {
                    var v = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text("${v['placa']} - ${v['modelo'] ?? ''}"),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _veiculoSelecionadoId = val;
                      _veiculoSelecionadoPlaca = (veiculos.firstWhere((d) => d.id == val).data() as Map<String, dynamic>)['placa'];
                    });
                  },
                );
              }
            ),
            const SizedBox(height: 20),

            // ==== CAMPO: KM INICIAL ====
            const Text('Quilometragem (KM) Inicial:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _kmController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.speed),
                hintText: 'Ex: 12500',
                suffixText: 'km'
              ),
            ),
            const SizedBox(height: 20),

            // ==== CAMPO: ROTA ====
            const Text('Selecione a Rota Disponível:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('rotas').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Erro ao carregar rotas: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                // Filtro Inteligente: Aceita se for false OU se o campo nem existir (null)
                var rotas = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return data['em_uso'] != true; 
                }).toList();
                
                if (rotas.isEmpty) return const Text('Todas as rotas estão em uso no momento.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));

                // Ordenação numérica local
                rotas.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  return (dataA['numero'] ?? '').toString().compareTo((dataB['numero'] ?? '').toString());
                });

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.route)),
                  hint: const Text('Escolha uma rota...'),
                  value: _rotaSelecionadaId,
                  items: rotas.map((doc) {
                    var r = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text("Rota ${r['numero'] ?? 'S/N'}"),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _rotaSelecionadaId = val;
                      _rotaSelecionadaNumero = (rotas.firstWhere((d) => d.id == val).data() as Map<String, dynamic>)['numero'];
                    });
                  },
                );
              }
            ),
            const SizedBox(height: 40),

            // ==== BOTÃO SALVAR ====
            SizedBox(
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                onPressed: _carregando ? null : _salvarTurno,
                child: _carregando 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('INICIAR VISTORIA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}