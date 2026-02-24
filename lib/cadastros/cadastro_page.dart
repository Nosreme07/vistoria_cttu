import 'package:flutter/material.dart';

class CadastroPage extends StatelessWidget {
  const CadastroPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista com os dados de cada botão de cadastro
    final List<Map<String, dynamic>> menuItems = [
      {'title': 'Veículos', 'icon': Icons.directions_car_outlined, 'color': Colors.indigo},
      {'title': 'Vistoriadores', 'icon': Icons.badge_outlined, 'color': Colors.teal},
      {'title': 'Rotas', 'icon': Icons.route_outlined, 'color': Colors.brown},
      {'title': 'Semáforos', 'icon': Icons.traffic_outlined, 'color': Colors.red},
      {'title': 'Croquis (PDF)', 'icon': Icons.picture_as_pdf_outlined, 'color': Colors.deepOrange},
      {'title': 'Acervo', 'icon': Icons.inventory_2_outlined, 'color': Colors.blueGrey},
      {'title': 'Usuários', 'icon': Icons.manage_accounts_outlined, 'color': Colors.deepPurple},
      {'title': 'Tipos de Falhas', 'icon': Icons.warning_amber_outlined, 'color': Colors.amber.shade700},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu de Cadastros', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 colunas
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1, // Proporção dos cards
          ),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            return _buildCadastroCard(
              context: context,
              title: item['title'],
              icon: item['icon'],
              color: item['color'],
            );
          },
        ),
      ),
    );
  }

  // Widget customizado para os cards da grade
  Widget _buildCadastroCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        // Alerta provisório para sabermos que o clique funciona
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Abrindo cadastro de $title...')),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.8), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}