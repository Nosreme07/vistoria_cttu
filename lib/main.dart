import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Importante: Pacote do Firebase
import 'firebase_options.dart'; // Importante: Arquivo que o comando mágico criou
import 'pages/login_page.dart';

void main() async {
  // Garante que o Flutter está pronto antes de iniciar o Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o Firebase com as configurações do seu projeto
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vistoria de Semáforos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}