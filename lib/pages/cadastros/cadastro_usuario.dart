import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; 

// Importações novas para o PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CadastroUsuario extends StatefulWidget {
  const CadastroUsuario({super.key});

  @override
  State<CadastroUsuario> createState() => _CadastroUsuarioState();
}

class _CadastroUsuarioState extends State<CadastroUsuario> with SingleTickerProviderStateMixin {
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _empresaController = TextEditingController();
  
  bool _ocultarSenha = true;
  bool _estaCarregando = false; 
  String? _perfilSelecionado;

  late TabController _tabController; 

  final List<String> _opcoesPerfil = [
    'Administrador',
    'Administrador CTTU',
    'Vistoriador'
  ];

  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); 
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _abrirFormulario({String? usuarioId, String? nomeAtual, String? telefoneAtual, String? perfilAtual, String? empresaAtual}) {
    _nomeController.text = nomeAtual ?? '';
    _telefoneController.text = telefoneAtual ?? '';
    _empresaController.text = empresaAtual ?? '';
    _senhaController.text = ''; 
    _perfilSelecionado = perfilAtual;
    
    bool isEdicao = usuarioId != null;

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isEdicao ? 'Editar Usuário' : 'Novo Usuário', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _nomeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _telefoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [telefoneFormatter],
                      enabled: !isEdicao, 
                      decoration: InputDecoration(
                        labelText: isEdicao ? 'Telefone (Login não pode ser alterado)' : 'Telefone (Login)', 
                        hintText: '(81) 99999-9999',
                        border: const OutlineInputBorder(),
                        filled: isEdicao,
                        fillColor: isEdicao ? Colors.grey.shade200 : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Perfil', border: OutlineInputBorder()),
                      value: _perfilSelecionado,
                      items: _opcoesPerfil.map((String perfil) {
                        return DropdownMenuItem<String>(value: perfil, child: Text(perfil));
                      }).toList(),
                      onChanged: (String? novoValor) {
                        setModalState(() => _perfilSelecionado = novoValor);
                      },
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _empresaController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Empresa',
                        hintText: 'Ex: SERTTEL OU SINALVIDA',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!isEdicao)
                      TextField(
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha (Mínimo 6 caracteres)',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility),
                            onPressed: () {
                              setModalState(() => _ocultarSenha = !_ocultarSenha);
                            },
                          ),
                        ),
                      ),
                    if (!isEdicao) const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _estaCarregando ? null : () => _salvarUsuario(setModalState, usuarioId),
                        child: _estaCarregando 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isEdicao ? 'Atualizar Dados' : 'Salvar Usuário', style: const TextStyle(fontSize: 16)),
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

  Future<void> _salvarUsuario(StateSetter setModalState, String? usuarioId) async {
    bool isEdicao = usuarioId != null;

    if (_nomeController.text.isEmpty || _perfilSelecionado == null || _empresaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos obrigatórios!')));
      return;
    }
    
    if (!isEdicao) {
      final telefoneLimpo = telefoneFormatter.getUnmaskedText();
      if (telefoneLimpo.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telefone inválido!')));
        return;
      }
      if (_senhaController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A senha deve ter pelo menos 6 caracteres!')));
        return;
      }
    }

    setModalState(() => _estaCarregando = true);

    try {
      if (isEdicao) {
        await FirebaseFirestore.instance.collection('usuarios').doc(usuarioId).update({
          'nome': _nomeController.text.toUpperCase(),
          'perfil': _perfilSelecionado,
          'empresa': _empresaController.text.toUpperCase(),
        });
      } else {
        final telefoneLimpo = telefoneFormatter.getUnmaskedText();
        String emailFicticio = "$telefoneLimpo@cttu.com";

        FirebaseApp appSecundario = await Firebase.initializeApp(
          name: 'CadastroTemporario',
          options: Firebase.app().options,
        );

        UserCredential userCredential = await FirebaseAuth.instanceFor(app: appSecundario)
            .createUserWithEmailAndPassword(email: emailFicticio, password: _senhaController.text);

        await FirebaseFirestore.instance.collection('usuarios').doc(userCredential.user!.uid).set({
          'nome': _nomeController.text.toUpperCase(),
          'telefone': _telefoneController.text,
          'telefone_limpo': telefoneLimpo,
          'perfil': _perfilSelecionado,
          'empresa': _empresaController.text.toUpperCase(),
          'criado_em': FieldValue.serverTimestamp(),
        });

        await appSecundario.delete();
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdicao ? 'Usuário atualizado com sucesso!' : 'Usuário cadastrado com sucesso!'), 
            backgroundColor: Colors.green
          )
        );
      }

    } on FirebaseAuthException catch (e) {
      String erroMsg = 'Erro ao cadastrar usuário.';
      if (e.code == 'email-already-in-use') {
        erroMsg = 'Este telefone já está cadastrado!';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erroMsg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setModalState(() => _estaCarregando = false);
      }
    }
  }

  Future<void> _deletarUsuario(String userId) async {
    await FirebaseFirestore.instance.collection('usuarios').doc(userId).delete();
  }

  // ==== MAGIA DO PDF ACONTECENDO AQUI ====
  Future<void> _gerarPDF() async {
    // Mostra aviso de carregamento
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando PDF... Aguarde!'), backgroundColor: Colors.blue));

    try {
      // 1. Busca todos os usuários do banco de dados na hora
      final snapshot = await FirebaseFirestore.instance.collection('usuarios').orderBy('nome').get();
      final usuarios = snapshot.docs;

      List<Map<String, dynamic>> admins = [];
      Map<String, List<Map<String, dynamic>>> vistoriadoresPorEmpresa = {};

      // 2. Separa os dados igual no Dashboard
      for (var user in usuarios) {
        final data = user.data();
        final perfil = data['perfil'] ?? '';
        final empresa = (data['empresa'] ?? 'NÃO INFORMADA').toString().toUpperCase();

        if (perfil.contains('Administrador')) {
          admins.add(data);
        } else if (perfil == 'Vistoriador') {
          if (!vistoriadoresPorEmpresa.containsKey(empresa)) {
            vistoriadoresPorEmpresa[empresa] = [];
          }
          vistoriadoresPorEmpresa[empresa]!.add(data);
        }
      }

      // 3. Cria o documento PDF em branco
      final pdf = pw.Document();

      // 4. Desenha a página e o conteúdo
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Cabeçalho
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Relatório de Equipe - CTTU', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Total: ${usuarios.length}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ]
                )
              ),
              pw.SizedBox(height: 24),

              // Bloco de Administradores
              pw.Text('Administradores (${admins.length}):', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 8),
              if (admins.isEmpty) pw.Text('Nenhum administrador cadastrado.'),
              ...admins.map((admin) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Bullet(text: '${admin['nome']} - ${admin['empresa']} (Login: ${admin['telefone']})', style: const pw.TextStyle(fontSize: 14)),
              )),
              
              pw.SizedBox(height: 32),

              // Bloco de Vistoriadores divididos por Empresa
              pw.Text('Vistoriadores por Empresa:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              if (vistoriadoresPorEmpresa.isEmpty) pw.Text('Nenhum vistoriador cadastrado.'),
              ...vistoriadoresPorEmpresa.entries.map((entry) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 16),
                    pw.Text('EMPRESA: ${entry.key}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    ...entry.value.map((vistor) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
                      child: pw.Bullet(text: '${vistor['nome']} - (Login: ${vistor['telefone']})', style: const pw.TextStyle(fontSize: 14)),
                    )),
                  ]
                );
              }),
            ];
          }
        )
      );

      // 5. Abre a tela de visualização/impressão do celular
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Relatorio_Equipe_CTTU.pdf',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao gerar PDF!'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários'), 
        backgroundColor: Colors.deepPurple.shade100,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Lista'),
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').orderBy('nome').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar usuários.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final usuarios = snapshot.data!.docs;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAbaLista(usuarios),
              _buildAbaDashboard(usuarios),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_tabController.index == 1) 
            FloatingActionButton(
              heroTag: 'btnPDF', 
              onPressed: _gerarPDF, // Chama a função real agora
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.picture_as_pdf, color: Colors.white),
            ),
          if (_tabController.index == 1) const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'btnAdd',
            onPressed: () => _abrirFormulario(), 
            backgroundColor: Colors.deepPurple,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildAbaLista(List<QueryDocumentSnapshot> usuarios) {
    if (usuarios.isEmpty) return const Center(child: Text('Nenhum usuário cadastrado.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: usuarios.length,
      itemBuilder: (context, index) {
        final user = usuarios[index];
        final data = user.data() as Map<String, dynamic>;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.deepPurple, child: Icon(Icons.person, color: Colors.white)),
            title: Text(data['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Login: ${data['telefone'] ?? ''}\nPerfil: ${data['perfil'] ?? ''} | Empresa: ${data['empresa'] ?? ''}'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  onPressed: () => _abrirFormulario(
                    usuarioId: user.id,
                    nomeAtual: data['nome'],
                    telefoneAtual: data['telefone'],
                    perfilAtual: data['perfil'],
                    empresaAtual: data['empresa'],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deletarUsuario(user.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAbaDashboard(List<QueryDocumentSnapshot> usuarios) {
    List<Map<String, dynamic>> admins = [];
    Map<String, List<Map<String, dynamic>>> vistoriadoresPorEmpresa = {};

    for (var user in usuarios) {
      final data = user.data() as Map<String, dynamic>;
      final perfil = data['perfil'] ?? '';
      final empresa = (data['empresa'] ?? 'NÃO INFORMADA').toString().toUpperCase();

      if (perfil.contains('Administrador')) {
        admins.add(data);
      } else if (perfil == 'Vistoriador') {
        if (!vistoriadoresPorEmpresa.containsKey(empresa)) {
          vistoriadoresPorEmpresa[empresa] = [];
        }
        vistoriadoresPorEmpresa[empresa]!.add(data);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Toque nos cartões para ver os detalhes', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          
          InkWell(
            onTap: () => _mostrarModalAdmins(admins),
            child: Card(
              color: Colors.blue.shade700,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    Text('${admins.length}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Text('Administradores', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          InkWell(
            onTap: () => _mostrarModalVistoriadores(vistoriadoresPorEmpresa),
            child: Card(
              color: Colors.orange.shade700,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.assignment_ind, color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    Text('${usuarios.length - admins.length}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Text('Vistoriadores', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarModalAdmins(List<Map<String, dynamic>> admins) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Administradores', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
              const Divider(),
              if (admins.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nenhum administrador cadastrado.')),
              ...admins.map((admin) => ListTile(
                leading: const Icon(Icons.security, color: Colors.blue),
                title: Text(admin['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Empresa: ${admin['empresa']} | ${admin['perfil']}'),
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _mostrarModalVistoriadores(Map<String, List<Map<String, dynamic>>> vistorsPorEmpresa) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6, 
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                controller: scrollController,
                children: [
                  const Center(child: Text('Vistoriadores por Empresa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange))),
                  const Divider(),
                  if (vistorsPorEmpresa.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nenhum vistoriador cadastrado.')),
                  
                  ...vistorsPorEmpresa.entries.map((entry) {
                    String empresa = entry.key;
                    List<Map<String, dynamic>> vistoriadores = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(empresa, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        ),
                        ...vistoriadores.map((vistor) => ListTile(
                          leading: const Icon(Icons.person, color: Colors.orange),
                          title: Text(vistor['nome'] ?? ''),
                          subtitle: Text('Login: ${vistor['telefone']}'),
                        )),
                        const Divider(),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}