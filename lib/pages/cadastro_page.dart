import 'package:flutter/material.dart';
import 'package:vistoria_cttu/pages/cadastros/cadastro_usuario.dart';
import 'package:vistoria_cttu/pages/cadastros/cadastro_veiculo.dart';
import 'package:vistoria_cttu/pages/cadastros/cadastro_rotas.dart';
import 'package:vistoria_cttu/pages/cadastros/cadastro_falhas.dart';
import 'package:vistoria_cttu/pages/cadastros/cadastro_semaforos.dart' as semaforo_page;

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
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        crossAxisSpacing: 16, 
        mainAxisSpacing: 16, 
        childAspectRatio: 1.1, 
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
            page: const semaforo_page.CadastroSemaforos(),
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

  Widget _buildDashboardButton(BuildContext context, {required String title, required IconData icon, required Color color, required Widget? page}) {
    return InkWell( 
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
          color: color.withAlpha(25), 
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(76), width: 2), 
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
                color: color.withBlue((color.blue + 50 > 255) ? 255 : color.blue + 50), 
              ),
            ),
          ],
        ),
      ),
    );
  }
}