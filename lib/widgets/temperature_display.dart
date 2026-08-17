import 'package:esp_sensor_app/screens/first_screen.dart';
import 'package:flutter/material.dart';

class SensorDashboard extends StatefulWidget {
  const SensorDashboard({super.key});

  @override
  State<SensorDashboard> createState() => _SensorDashboardState();
}

class _SensorDashboardState extends State<SensorDashboard> {
  final MqttService _mqttService = MqttService();

  @override
  void initState() {
    super.initState();
    _mqttService.connect();
  }

  @override
  void dispose() {
    _mqttService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мониторинг датчиков'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Статус подключения
            StreamBuilder<String>(
              stream: _mqttService.statusStream,
              initialData: 'Отключено',
              builder: (context, snapshot) {
                final status = snapshot.data ?? 'Отключено';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: status.contains('✅') ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: status.contains('✅') ? Colors.green : Colors.red),
                  ),
                  child: Text(
                    'Статус сети: $status',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            
            // Карточки датчиков
            _buildSensorCard(
              'Улица',
              _mqttService.streetTempStream,
              Icons.ac_unit,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildSensorCard(
              'Балкон',
              _mqttService.balconyTempStream,
              Icons.balcony,
              Colors.cyan,
            ),
            const SizedBox(height: 12),
            _buildSensorCard(
              'Комната (Темп.)',
              _mqttService.roomTempStream,
              Icons.home,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildSensorCard(
              'Комната (Влажность)',
              _mqttService.roomHumidityStream,
              Icons.water_drop,
              Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  // Виджет карточки датчика со StreamBuilder
  Widget _buildSensorCard(String title, Stream<String> dataStream, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: StreamBuilder<String>(
        stream: dataStream,
        initialData: '--',
        builder: (context, snapshot) {
          final value = snapshot.data ?? '--';
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: Icon(icon, size: 40, color: color),
            title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            trailing: Text(
              value,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
            ),
          );
        },
      ),
    );
  }
}