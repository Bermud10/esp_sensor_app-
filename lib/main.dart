import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
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
    bool isLoading = false;

   String getlocation(String location) {

      if(location == "street"){
        return "Температура улицы";
      }

      return "Температура";
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
          });
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
            const SizedBox(height: 30),
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
