import 'package:flutter/material.dart';
import 'package:vistoria_cttu/pages/cadastros/cadastro_usuario.dart';
import 'package:vistoria_cttu/pages/cadastros/cadastro_veiculo.dart';
import 'package:vistoria_cttu/pages/cadastros/cadastro_falhas.dart';
// REMOVIDO: imports de Rotas e Semáforos

class CadastroPage extends StatelessWidget {
  const CadastroPage({super.key});

  @override
  Widget build(BuildContext context) {
    // =========================================================================
    // IDENTIFICAÇÃO DO DISPOSITIVO (CELULAR OU WEB)
    // =========================================================================
    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehWeb = larguraTela > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu de Cadastros', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade100,
      ),
      // =========================================================================
      // GRIDVIEW ADAPTÁVEL SEM ROLAGEM
      // =========================================================================
      body: GridView.count(
        physics: const NeverScrollableScrollPhysics(), // Trava a rolagem da página
        crossAxisCount: ehWeb ? 3 : 2, // 3 colunas na Web (monitor) ou 2 no Celular
        padding: const EdgeInsets.all(16.0),
        crossAxisSpacing: 16, 
        mainAxisSpacing: 16, 
        childAspectRatio: ehWeb ? 1.6 : 1.1, // Adapta o formato do botão para não esticar na Web
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
            title: 'Tipos de Falhas',
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            page: const CadastroTiposFalha(),
          ),
          // REMOVIDO: Botões de Rotas e Semáforos
        ],
      ),
    );
  }

  // MANTIDO: O SEU DESIGN ORIGINAL DO BOTÃO INTACTO
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