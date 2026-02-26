import 'package:flutter/material.dart';
import 'cadastros/cadastro_usuario.dart';
import 'cadastros/cadastro_veiculo.dart';
import 'cadastros/cadastro_rotas.dart';
import 'cadastros/cadastro_falhas.dart';
import 'cadastros/cadastro_semaforos.dart';

class CadastroPage extends StatelessWidget {
  const CadastroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu de Cadastros', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade100,
      ),
      // Usamos GridView.count para criar uma grade com 2 colunas
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        crossAxisSpacing: 16, // Espaço horizontal entre os botões
        mainAxisSpacing: 16, // Espaço vertical entre os botões
        childAspectRatio: 1.1, // Controla a altura do botão (1.0 = quadrado perfeito)
        children: [
          _buildDashboardButton(
            context,
            title: 'Usuários',
            icon: Icons.people_alt,
            color: Colors.deepPurple,
            page: const CadastroUsuario(),
          ),
          _buildDashboardButton(
            context,
            title: 'Veículos',
            icon: Icons.directions_car,
            color: Colors.indigo,
            page: const CadastroVeiculo(),
          ),
          _buildDashboardButton(
            context,
            title: 'Rotas',
            icon: Icons.route,
            color: Colors.brown,
            page: const CadastroRotas(),
          ),
          _buildDashboardButton(
            context,
            title: 'Semáforos',
            icon: Icons.traffic,
            color: Colors.red,
            page: const CadastroSemaforos(),
          ),
          _buildDashboardButton(
            context,
            title: 'Tipos de Falhas',
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            page: const CadastroTiposFalha(),
          ),
        ],
      ),
    );
  }

  // Função para desenhar os botões "quadrados" do dashboard
  Widget _buildDashboardButton(BuildContext context, {required String title, required IconData icon, required Color color, required Widget? page}) {
    return InkWell( // InkWell faz o efeito de "onda" ao tocar
      onTap: () {
        if (page != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => page));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Página de $title em construção!')),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), // Fundo clarinho com a cor do botão
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2), // Bordinha
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color.withBlue(color.blue + 50), // Dá uma escurecida na cor do texto
              ),
            ),
          ],
        ),
      ),
    );
  }
}