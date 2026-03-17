import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  
  bool _ocultarSenha = true;
  bool _estaCarregando = false; // Controla a bolinha de carregamento

  // Máscara para o telefone (igual a do cadastro)
  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  Future<void> _fazerLogin() async {
    if (_telefoneController.text.isEmpty || _senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o telefone e a senha.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _estaCarregando = true;
    });

    try {
      // 1. Pega o telefone limpo (só os números)
      final telefoneLimpo = telefoneFormatter.getUnmaskedText();
      
      // 2. Monta aquele e-mail fictício que usamos no cadastro
      final emailFicticio = "$telefoneLimpo@cttu.com";

      // 3. Tenta fazer o login no Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailFicticio,
        password: _senhaController.text,
      );
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }

    } on FirebaseAuthException catch (e) {
      // Trata os erros comuns (senha errada, usuário não existe)
      String mensagemErro = 'Erro ao fazer login.';
      if (e.code == 'user-not-found' || e.code == 'invalid-email' || e.code == 'invalid-credential') {
        mensagemErro = 'Telefone ou senha incorretos.';
      } else if (e.code == 'wrong-password') {
        mensagemErro = 'Senha incorreta.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemErro), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _estaCarregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade700,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ==========================================
                  // IMAGEM SUBSTITUÍDA AQUI
                  // ==========================================
                  Image.asset(
                    'assets/images/login.png',
                    height: 150, // Ajuste a altura se achar que ficou muito grande ou pequeno
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text('Vistoria Semafórica', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  const Text('Faça login para continuar', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 32),
                  
                  // Campo de Telefone
                  TextField(
                    controller: _telefoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [telefoneFormatter],
                    decoration: InputDecoration(
                      labelText: 'Telefone',
                      hintText: '(81) 99999-9999',
                      prefixIcon: const Icon(Icons.phone_android_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo Senha
                  TextField(
                    controller: _senhaController,
                    obscureText: _ocultarSenha,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _ocultarSenha = !_ocultarSenha;
                          });
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Botão de Entrar (Com animação de carregamento)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _estaCarregando ? null : _fazerLogin,
                      child: _estaCarregando
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('ENTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}