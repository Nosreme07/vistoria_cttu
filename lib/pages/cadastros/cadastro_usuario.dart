import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; // Necessário para o truque da segunda instância

class CadastroUsuario extends StatefulWidget {
  const CadastroUsuario({super.key});

  @override
  State<CadastroUsuario> createState() => _CadastroUsuarioState();
}

class _CadastroUsuarioState extends State<CadastroUsuario> {
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _empresaController = TextEditingController();
  
  bool _ocultarSenha = true;
  bool _estaCarregando = false; // Para mostrar a bolinha girando enquanto salva no Firebase
  String? _perfilSelecionado;

  final List<String> _opcoesPerfil = [
    'Administrador',
    'Administrador CTTU',
    'Vistoriador'
  ];

  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  void _abrirFormulario() {
    _perfilSelecionado = null;
    _nomeController.clear();
    _telefoneController.clear();
    _empresaController.clear();
    _senhaController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                    const Text('Novo Usuário', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                      decoration: const InputDecoration(
                        labelText: 'Telefone (Login)', 
                        hintText: '(81) 99999-9999',
                        border: OutlineInputBorder()
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
                    const SizedBox(height: 24),

                    // Botão Salvar (Muda para bolinha girando se estiver carregando)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _estaCarregando ? null : () => _salvarUsuario(setModalState),
                        child: _estaCarregando 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Salvar Usuário', style: TextStyle(fontSize: 16)),
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

  // A mágica acontece aqui (Integração real com Firebase)
  Future<void> _salvarUsuario(StateSetter setModalState) async {
    if (_nomeController.text.isEmpty || _telefoneController.text.isEmpty || 
        _senhaController.text.isEmpty || _perfilSelecionado == null || _empresaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos!')));
      return;
    }
    
    final telefoneLimpo = telefoneFormatter.getUnmaskedText();
    if (telefoneLimpo.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telefone inválido!')));
      return;
    }

    if (_senhaController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A senha deve ter pelo menos 6 caracteres!')));
      return;
    }

    setModalState(() => _estaCarregando = true);

    try {
      // 1. O TRUQUE: Cria um e-mail fictício usando o telefone
      String emailFicticio = "$telefoneLimpo@cttu.com";

      // 2. Cria um app secundário temporário para não deslogar o administrador atual
      FirebaseApp appSecundario = await Firebase.initializeApp(
        name: 'CadastroTemporario',
        options: Firebase.app().options,
      );

      // 3. Cria a conta no Firebase Authentication usando o app secundário
      UserCredential userCredential = await FirebaseAuth.instanceFor(app: appSecundario)
          .createUserWithEmailAndPassword(email: emailFicticio, password: _senhaController.text);

      // 4. Salva os detalhes do usuário no Cloud Firestore (Banco de Dados)
      await FirebaseFirestore.instance.collection('usuarios').doc(userCredential.user!.uid).set({
        'nome': _nomeController.text.toUpperCase(),
        'telefone': _telefoneController.text,
        'telefone_limpo': telefoneLimpo,
        'perfil': _perfilSelecionado,
        'empresa': _empresaController.text.toUpperCase(),
        'criado_em': FieldValue.serverTimestamp(), // Salva a data e hora exata
      });

      // Deleta o app secundário para limpar a memória
      await appSecundario.delete();

      if (mounted) {
        Navigator.pop(context); // Fecha o modal
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário cadastrado com sucesso!'), backgroundColor: Colors.green));
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

  // Função para deletar usuário do banco de dados
  Future<void> _deletarUsuario(String userId) async {
    await FirebaseFirestore.instance.collection('usuarios').doc(userId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuários'), backgroundColor: Colors.deepPurple.shade100),
      // O StreamBuilder "ouve" o banco de dados em tempo real. Se alguém adicionar um usuário lá no site do Firebase, aparece aqui na hora!
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').orderBy('nome').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar usuários.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final usuarios = snapshot.data!.docs;

          if (usuarios.isEmpty) {
            return const Center(child: Text('Nenhum usuário cadastrado.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final user = usuarios[index];
              final data = user.data() as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.deepPurple, child: Icon(Icons.person, color: Colors.white)),
                  title: Text(data['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Login: ${data['telefone'] ?? ''}\nPerfil: ${data['perfil'] ?? ''} | Empresa: ${data['empresa'] ?? ''}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deletarUsuario(user.id), // Deleta pelo ID único do Firebase
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormulario,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}