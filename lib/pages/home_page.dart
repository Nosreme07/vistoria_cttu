import 'package:flutter/material.dart';
import 'cadastro_page.dart'; // Importação da página de cadastros

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Controle', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch, // Estica os botões
          children: [
            _buildMenuButton(
              context: context,
              title: 'Vistoria',
              icon: Icons.fact_check_outlined,
              color: Colors.green.shade600,
            ),
            const SizedBox(height: 20),
            _buildMenuButton(
              context: context,
              title: 'Cadastro',
              icon: Icons.add_location_alt_outlined,
              color: Colors.blue.shade600,
            ),
            const SizedBox(height: 20),
            _buildMenuButton(
              context: context,
              title: 'Acervo',
              icon: Icons.folder_copy_outlined,
              color: Colors.orange.shade600,
            ),
          ],
        ),
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
        // Lógica de navegação atualizada
        if (title == 'Cadastro') {
          // Vai para a tela de Menu de Cadastros
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CadastroPage()),
          );
        } else {
          // Mantém o aviso provisório para Vistoria e Acervo
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