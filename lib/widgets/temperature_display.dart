import 'package:esp_sensor_app/screens/mqtt_service.dart';
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
            Expanded(
              child: ListView(
                children: [
                  _buildSensorCard('Улица', _mqttService.streetTempStream, Icons.ac_unit, Colors.blue),
                  const SizedBox(height: 12),
                  _buildSensorCard('Балкон', _mqttService.balconyTempStream, Icons.balcony, Colors.cyan),
                  const SizedBox(height: 12),
                  _buildSensorCard('Комната (Темп.)', _mqttService.roomTempStream, Icons.home, Colors.orange),
                  const SizedBox(height: 12),
                  _buildSensorCard('Комната (Влажность)', _mqttService.roomHumidityStream, Icons.water_drop, Colors.teal),
                  const SizedBox(height: 12),
                  _buildSensorCard('Комната (Давление)', _mqttService.roomPressureStream, Icons.compress, Colors.purple),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(String title, Stream<SensorReading> dataStream, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: StreamBuilder<SensorReading>(
        stream: dataStream,
        initialData: SensorReading(displayValue: '--', timestamp: DateTime.now()),
        builder: (context, snapshot) {
          final data = snapshot.data!;
          
          // Форматируем время (ЧЧ:ММ:СС)
          final timeStr = "${data.timestamp.hour.toString().padLeft(2, '0')}:"
                          "${data.timestamp.minute.toString().padLeft(2, '0')}:"
                          "${data.timestamp.second.toString().padLeft(2, '0')}";

          // Создаем виджет разницы температур (если это не первое значение)
          Widget? diffWidget;
          if (data.difference != null) {
            final diffVal = data.difference!.toStringAsFixed(1);
            final arrowIcon = data.isIncreasing ? Icons.arrow_upward : Icons.arrow_downward;
            // Красный если растет, синий если падает
            final diffColor = data.isIncreasing ? Colors.red.shade700 : Colors.blue.shade700;

            diffWidget = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(arrowIcon, size: 20, color: diffColor),
                const SizedBox(width: 4),
                Text(
                  '$diffVal',
                  style: TextStyle(fontSize: 16, color: diffColor, fontWeight: FontWeight.bold),
                ),
              ],
            );
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: Icon(icon, size: 40, color: color),
            title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (diffWidget != null) ...[
                  const SizedBox(height: 4),
                  diffWidget,
                ],
                const SizedBox(height: 4),
                Text(
                  'Обновлено: $timeStr',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: Text(
              data.displayValue,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
          );
        },
      ),
    );
  }
}