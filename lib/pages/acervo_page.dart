import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // NOVO: Para abrir o GPS (Como Chegar)

// Importações para o Mapa Interno
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AcervoPage extends StatefulWidget {
  const AcervoPage({super.key});

  @override
  State<AcervoPage> createState() => _AcervoPageState();
}

class _AcervoPageState extends State<AcervoPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _pesquisaController = TextEditingController();
  String _textoPesquisa = '';

  // Filtros da Aba de Mapa
  String _filtroRota = 'Todas';
  String _filtroGrupo = 'Todos';

  // Lista com todos os campos técnicos para exibição na ficha
  final List<String> _todosOsCampos = [
    'id', 'endereco', 'bairro', 'empresa', 'georeferencia', 'rota', 'grupo',
    'tipo_do_controlador', 'id_do_controlador', 'subareas',
    'grupo_focal_veicular_tipo_i', 'grupo_focal_veicular_tipo_t',
    'grupo_focal_pedestre_simples', 'grupo_focal_pedestre_com_cronometro',
    'grupo_focal_faixa_reversivel', 'grupo_focal_ciclista_com_tres_focos',
    'grupo_focal_ciclista_com_dois_focos', 'anteparo_tipo_i',
    'veicular_com_sequencial', 'veicular_com_cronometro', 'sirene',
    'horario_de_funcionamente_das_sirenes', 'botoeira_com_dispositivo_sonoro',
    'botoeira_simples', 'nobreak', 'kit_bateria', 'numero_do_nobreak',
    'medidor', 'numero_do_medidor', 'kit_de_comunicacao', 'modo_de_funcionamento',
    'semiportico_conico', 'semiportico_simples', 'semiportico_estruturado',
    'portico_simples', 'portico_estruturado', 'coluna_conica', 'coluna_simples',
    'placa_adesiva_para_botoeira', 'conjunto_entrada_de_energia_padrao_celpe_instalado',
    'conjunto_aterramento_para_colunas', 'cabo_2x1mm', 'cabo_3x1mm', 'cabo_4x1mm',
    'cabo_7x1mm', 'luminarias', 'placa_de_identificacao_de_semaforo',
    'fotossensor_equipamento', 'conta_contrato', 'link_da_programacao',
    'observacoes', 'observacoes_2', 'historico', 'data_de_implantacao'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pesquisaController.addListener(() {
      setState(() {
        _textoPesquisa = _pesquisaController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pesquisaController.dispose();
    super.dispose();
  }

  // ==== ABRIR GOOGLE MAPS (COMO CHEGAR) ====
  Future<void> _abrirComoChegarGPS(String georeferencia) async {
    if (georeferencia.trim().isEmpty || !georeferencia.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semáforo sem coordenadas válidas!'), backgroundColor: Colors.orange));
      return;
    }
    
    try {
      var partes = georeferencia.split(' ');
      String lat = partes[0].trim();
      String lng = partes[1].trim();

      // Formato Universal de URL para traçar rota no Maps
      final Uri url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o navegador GPS.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao abrir o mapa do celular.'), backgroundColor: Colors.red));
      }
    }
  }

  // ==== VISUALIZAR DETALHES (FICHA TÉCNICA) ====
  void _mostrarFichaTecnica(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Ficha Técnica - Semáforo Nº ${data['id'] ?? ''}', 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange.shade800)
                    )
                  ),
                  const Divider(thickness: 2, height: 32),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _todosOsCampos.length,
                      itemBuilder: (context, index) {
                        String campo = _todosOsCampos[index];
                        String titulo = campo.replaceAll('_', ' ').toUpperCase();
                        String valor = (data[campo] ?? '').toString().trim();
                        
                        if (valor.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black87, fontSize: 15),
                              children: [
                                TextSpan(text: '$titulo: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                TextSpan(text: valor),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar Ficha', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // ==== ABRIR MAPA INTERNO ====
  void _abrirMapaDaRota(String titulo, List<Map<String, dynamic>> semaforosParaMapa) {
    if (semaforosParaMapa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum semáforo encontrado com estes filtros.'), backgroundColor: Colors.orange));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TelaMapaRota(titulo: titulo, semaforosDaRota: semaforosParaMapa)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acervo de Semáforos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade400,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Lista Geral'),
            Tab(icon: Icon(Icons.map_outlined), text: 'Mapa / Filtros'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('semaforos').orderBy('id').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar o acervo.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          var todosSemaforos = snapshot.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();

          // Extrai rotas únicas para o Dropdown
          Set<String> rotasSet = {};
          for (var s in todosSemaforos) {
            String rota = (s['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
            if (rota.isNotEmpty) rotasSet.add(rota);
          }
          List<String> listaRotas = rotasSet.toList()..sort();

          return TabBarView(
            controller: _tabController,
            children: [
              // ================= ABA 1: LISTA GERAL =================
              Column(
                children: [
                  Container(
                    color: Colors.orange.shade50,
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _pesquisaController,
                      decoration: InputDecoration(
                        labelText: 'Pesquisar por número ou endereço...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _textoPesquisa.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _pesquisaController.clear()) : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true, fillColor: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        var semaforosFiltradosPesquisa = todosSemaforos;
                        if (_textoPesquisa.isNotEmpty) {
                          semaforosFiltradosPesquisa = semaforosFiltradosPesquisa.where((data) {
                            final endereco = (data['endereco'] ?? '').toString().toLowerCase();
                            final id = (data['id'] ?? '').toString().toLowerCase();
                            return endereco.contains(_textoPesquisa) || id.contains(_textoPesquisa);
                          }).toList();
                        }

                        if (semaforosFiltradosPesquisa.isEmpty) return const Center(child: Text('Nenhum semáforo encontrado.', style: TextStyle(fontSize: 16, color: Colors.grey)));

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: semaforosFiltradosPesquisa.length,
                          itemBuilder: (context, index) {
                            final data = semaforosFiltradosPesquisa[index];
                            String rota = (data['rota'] ?? 'S/R').toString().replaceFirst(RegExp(r'^0+'), '');
                            String georef = (data['georeferencia'] ?? '').toString();

                            return Card(
                              elevation: 2, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                onTap: () => _mostrarFichaTecnica(data),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(radius: 28, backgroundColor: Colors.orange.shade100, child: Text(data['id']?.toString() ?? '', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 16))),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(data['endereco'] ?? 'Sem endereço', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.route, size: 14, color: Colors.grey.shade600), const SizedBox(width: 4), Text('Rota $rota', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold)),
                                                const SizedBox(width: 12),
                                                Icon(Icons.location_city, size: 14, color: Colors.grey.shade600), const SizedBox(width: 4), Expanded(child: Text(data['bairro'] ?? '-', style: TextStyle(color: Colors.grey.shade700, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                      // BOTÃO DE COMO CHEGAR (DIREÇÕES)
                                      IconButton(
                                        icon: Icon(Icons.directions, color: georef.isNotEmpty ? Colors.blue.shade700 : Colors.grey, size: 28),
                                        tooltip: 'Como Chegar',
                                        onPressed: () => _abrirComoChegarGPS(georef),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),

              // ================= ABA 2: MAPA E FILTROS =================
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Visualizar Semáforos no Mapa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 8),
                    const Text('Filtre a rota e o grupo desejado para criar uma visualização customizada no mapa.', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 32),

                    InputDecorator(
                      decoration: InputDecoration(labelText: 'Filtrar por Rota', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _filtroRota,
                          items: [
                            const DropdownMenuItem(value: 'Todas', child: Text('Todas as Rotas')),
                            ...listaRotas.map((r) => DropdownMenuItem(value: r, child: Text('Rota $r')))
                          ],
                          onChanged: (val) => setState(() => _filtroRota = val!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    InputDecorator(
                      decoration: InputDecoration(labelText: 'Filtrar por Grupo', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _filtroGrupo,
                          items: const [
                            DropdownMenuItem(value: 'Todos', child: Text('Todos os Grupos')),
                            DropdownMenuItem(value: 'A', child: Text('Grupo A')),
                            DropdownMenuItem(value: 'B', child: Text('Grupo B')),
                          ],
                          onChanged: (val) => setState(() => _filtroGrupo = val!),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48),

                    SizedBox(
                      height: 60,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.map, size: 28),
                        label: const Text('ABRIR MAPA COM FILTROS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          // Aplica os filtros na lista completa antes de mandar pro mapa
                          List<Map<String, dynamic>> listaFiltradaParaMapa = todosSemaforos.where((sem) {
                            String rotaLimpa = (sem['rota'] ?? '').toString().replaceFirst(RegExp(r'^0+'), '');
                            String grupo = (sem['grupo'] ?? '').toString().toUpperCase();

                            bool passaRota = _filtroRota == 'Todas' || rotaLimpa == _filtroRota;
                            bool passaGrupo = _filtroGrupo == 'Todos' || grupo == _filtroGrupo;

                            return passaRota && passaGrupo;
                          }).toList();

                          String tituloMapa = 'Mapa: ${_filtroRota == 'Todas' ? 'Todas Rotas' : 'Rota $_filtroRota'} - Grupo $_filtroGrupo';
                          _abrirMapaDaRota(tituloMapa, listaFiltradaParaMapa);
                        },
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

// =======================================================================
// TELA NOVA: MAPA INTERNO PARA VISUALIZAR OS SEMÁFOROS
// =======================================================================
class TelaMapaRota extends StatelessWidget {
  final String titulo;
  final List<Map<String, dynamic>> semaforosDaRota;

  const TelaMapaRota({super.key, required this.titulo, required this.semaforosDaRota});

  @override
  Widget build(BuildContext context) {
    List<Marker> marcadores = [];
    LatLng centroDoMapa = const LatLng(-8.05428, -34.8813); // Centro de Recife Padrão

    for (var semaforo in semaforosDaRota) {
      String geoStr = (semaforo['georeferencia'] ?? '').toString().trim();
      String empresa = (semaforo['empresa'] ?? '').toString().toUpperCase();

      String iconeCaminho = 'assets/images/semaforo.png';
      if (empresa.contains('SERTTEL')) {
        iconeCaminho = 'assets/images/serttel.png';
      } else if (empresa.contains('SINALVIDA')) {
        iconeCaminho = 'assets/images/sinalvida.png';
      }

      if (geoStr.isNotEmpty && geoStr.contains(' ')) {
        var partes = geoStr.split(' ');
        if (partes.length >= 2) {
          double lat = double.tryParse(partes[0]) ?? 0;
          double lng = double.tryParse(partes[1]) ?? 0;

          if (lat != 0 && lng != 0) {
            LatLng posicao = LatLng(lat, lng);
            centroDoMapa = posicao;

            final String caminhoIcone = iconeCaminho;
            final Map<String, dynamic> semaforoAtual = semaforo;

            marcadores.add(
              Marker(
                point: posicao,
                width: 30,
                height: 30,
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Semáforo Nº ${semaforoAtual['id']}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                        content: Text('${semaforoAtual['endereco']}\n\nBairro: ${semaforoAtual['bairro']}\nGrupo: ${semaforoAtual['grupo'] ?? '-'}\nEmpresa: ${semaforoAtual['empresa']}'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
                        ],
                      ),
                    );
                  },
                  child: Image.asset(caminhoIcone, width: 30, height: 30),
                ),
              ),
            );
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.orange.shade300,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: centroDoMapa,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.vistoria.cttu',
          ),
          MarkerLayer(markers: marcadores),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
        label: Text('Voltar (${marcadores.length} Pinos)'),
      ),
    );
  }
}