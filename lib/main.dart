
import 'package:esp_sensor_app/screens/first_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

//https://docs.flutter.dev/install/archive

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP street sensor',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const FirstScreen(),
    );
  }
}

class FirstScreen extends StatefulWidget {
  const FirstScreen({super.key});

  @override
  FirstScreenState createState() => FirstScreenState();
}


