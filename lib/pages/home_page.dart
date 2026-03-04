import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Imports das suas páginas
import 'login_page.dart'; 
import 'cadastro_page.dart';
import 'vistoria/vistoria_page.dart'; 
import 'acervo_page.dart'; // <-- NOVO IMPORT ADICIONADO

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Controle', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
      body: user == null
          ? const Center(child: Text('Usuário não autenticado.'))
          : FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Erro ao carregar dados do usuário.'));
                }

                var userData = snapshot.data!.data() as Map<String, dynamic>;
                String perfil = userData['perfil'] ?? '';

                bool podeCadastrar = (perfil == 'Administrador' || perfil == 'Administrador CTTU');

                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMenuButton(
                        context: context,
                        title: 'Vistoria',
                        icon: Icons.fact_check_outlined,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(height: 20),
                      
                      if (podeCadastrar) ...[
                        _buildMenuButton(
                          context: context,
                          title: 'Cadastro',
                          icon: Icons.add_location_alt_outlined,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(height: 20),
                      ],

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
        // Lógica de navegação baseada no título do botão
        if (title == 'Cadastro') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CadastroPage()),
          );
        } else if (title == 'Vistoria') { 
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VistoriaPage()),
          );
        } else if (title == 'Acervo') { // <-- LÓGICA DE NAVEGAÇÃO DO ACERVO ADICIONADA
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AcervoPage()),
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