import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cadastro_page.dart';
import 'login_page.dart'; // Importado para podermos voltar à tela de login ao sair

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Pega o usuário que está logado atualmente no aplicativo
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Controle', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Botão de Sair (Logout) para facilitar os testes de perfis
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            },
          )
        ],
      ),
      // O FutureBuilder vai no banco de dados ler o documento do usuário antes de desenhar a tela
      body: user == null
          ? const Center(child: Text('Usuário não autenticado.'))
          : FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get(),
              builder: (context, snapshot) {
                // Enquanto busca os dados, mostra uma bolinha de carregamento
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Se houver algum erro de conexão
                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Erro ao carregar dados do usuário.'));
                }

                // Extrai os dados do Firebase para um Map do Dart
                var userData = snapshot.data!.data() as Map<String, dynamic>;
                String perfil = userData['perfil'] ?? '';

                // A Regra de Ouro: Só é verdadeiro se for um dos dois administradores
                bool podeCadastrar = (perfil == 'Administrador' || perfil == 'Administrador CTTU');

                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Botão de Vistoria (Visível para todos)
                      _buildMenuButton(
                        context: context,
                        title: 'Vistoria',
                        icon: Icons.fact_check_outlined,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(height: 20),
                      
                      // O Botão de Cadastro CONDICIONAL (Só aparece se a regra for verdadeira)
                      if (podeCadastrar) ...[
                        _buildMenuButton(
                          context: context,
                          title: 'Cadastro',
                          icon: Icons.add_location_alt_outlined,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(height: 20), // O espaçamento também fica condicionado
                      ],

                      // Botão de Acervo (Visível para todos)
                      _buildMenuButton(
                        context: context,
                        title: 'Acervo',
                        icon: Icons.folder_copy_outlined,
                        color: Colors.orange.shade600,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // Função auxiliar para criar os botões com design padronizado
  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 24),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: Icon(icon, size: 36),
      label: Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      onPressed: () {
        if (title == 'Cadastro') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CadastroPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Página em construção: $title'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
    );
  }
}