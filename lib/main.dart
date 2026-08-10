import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:intl/date_symbol_data_local.dart';

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
      home: const SensorScreen(),
    );
  }
}

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => SensorScreenState();
}

class SensorScreenState extends State<SensorScreen> {
  String _info = '';
  String _temperature = '***';
  String _location = '';
  String _unit = '';
  DateTime? _lastUpdated; 
  bool isLoading = false;

   Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTemp = prefs.getString('temperature');
    final cachedLocation = prefs.getString('location');
    final cachedUnit = prefs.getString('unit');
    final cachedTime = prefs.getString('lastUpdated');

    if (cachedTemp != null && mounted) {
      setState(() {
        _temperature = cachedTemp;
        _location = cachedLocation ?? '';
        _unit = cachedUnit ?? '';
        _lastUpdated = cachedTime != null ? DateTime.tryParse(cachedTime) : null;
      });
    }
  }

  // Сохранение данных в SharedPreferences
  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('temperature', _temperature);
    await prefs.setString('location', _location);
    await prefs.setString('unit', _unit);
    if (_lastUpdated != null) {
      await prefs.setString('lastUpdated', _lastUpdated!.toIso8601String());
    }
  }

   String getlocation(String location) {

    if(location == "street"){
      return "Температура улицы";
    }

    return "Температура";
  }

  String _formatTime(DateTime time) {
    return DateFormat('d MMM  HH:mm', "ru").format(time);
  }

   @override
  void initState() {
    super.initState();
    _loadCachedData(); // ← загрузка последнего измерения при старте
  }

    Future<void> getTemperature() async {
      setState(() {
        isLoading = true;
      });

      try{

        final response = await http.get(Uri.parse('http://192.168.0.182'));

        if(response.statusCode == 200){

          final data = jsonDecode(response.body);

          setState(() {
            _temperature = data['temperature'].toString();
            _location = data['location'];
            _unit = data['unit'];
            _lastUpdated = DateTime.now();
          });
           await _saveToCache();
           _info = "";
        }else{
          setState(() {
            _info = "Ошибка: ${response.statusCode}";
          });
        }
      }
      catch(e){
        setState(() {
          _info = "Ошибка подключения";
        });
        print("$e");
      }
      finally{
        setState(() {
          isLoading = false;
        });
      }
    }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Термометр'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_location.isNotEmpty) ...[
              Text(
                getlocation(_location),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
            ],
            Text(
              _temperature == '***'
                  ? _temperature
                  : '$_temperature $_unit',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 10),

            if (_lastUpdated != null) ... [
              Text(
                'Обновлено: ${_formatTime(_lastUpdated!)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],

            if (_info.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _info,
                style: const TextStyle(color: Colors.red),
              ),
            ],
        
          ],
          
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FloatingActionButton.extended(
                    onPressed: isLoading ? null : getTemperature,
                    label: Text(isLoading ? 'Загрузка...' : 'Обновить'),
                    icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                  ),
      ),
    );
    
  }
}
