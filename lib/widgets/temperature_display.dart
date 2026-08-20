import 'package:esp_sensor_app/screens/mqtt_service.dart';
import 'package:flutter/material.dart';


class SensorDashboard extends StatefulWidget {
  const SensorDashboard({super.key});

  @override
  State<SensorDashboard> createState() => _SensorDashboardState();
}

class _SensorDashboardState extends State<SensorDashboard> with WidgetsBindingObserver {
  final MqttService _mqttService = MqttService();

  @override
  void initState() {
    super.initState();
    _mqttService.connect();
    
    // Регистрируемся как наблюдатель за жизненным циклом приложения
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Удаляем наблюдатель при закрытии приложения
    WidgetsBinding.instance.removeObserver(this);
    _mqttService.dispose();
    super.dispose();
  }

  // Автоматически срабатывает при блокировке/разблокировке экрана
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      print('📱 Приложение активно, проверяем соединение...');
      _mqttService.appLifecycleChanged(state);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мониторинг датчиков'),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Статус подключения (просто текст, без кнопок)
            StreamBuilder<String>(
              stream: _mqttService.statusStream,
              initialData: 'Подключение...',
              builder: (context, snapshot) {
                final status = snapshot.data ?? 'Подключение...';
                final isConnected = status.contains('✅');
                
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isConnected ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.sync,
                        color: isConnected ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Статус: $status',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            
            // Карточки датчиков
            Expanded(
              child: ListView(
                children: [
                  // _buildSensorCard('Улица', _mqttService.streetTempStream, Icons.ac_unit, Colors.blue),
                  // const SizedBox(height: 12),
                  // _buildSensorCard('Балкон', _mqttService.balconyTempStream, Icons.balcony, Colors.cyan),
                  // const SizedBox(height: 12),
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
          final timeStr = "${localTime.hour.toString().padLeft(2, '0')}:"
                          "${localTime.minute.toString().padLeft(2, '0')}:"
                          "${localTime.second.toString().padLeft(2, '0')}";

          Widget? diffWidget;
          if (data.difference != null) {
            final diffVal = data.difference!.toStringAsFixed(1);
            final arrowIcon = data.isIncreasing ? Icons.arrow_upward : Icons.arrow_downward;
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
              // ⭐ Показываем время измерения
              Text(
                'Измерено: $timeStr',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              // ⭐ Показываем "возраст" данных
              Builder(
                builder: (context) {
                  final age = DateTime.now().difference(data.timestamp);
                  String ageText;
                  if (age.inSeconds < 60) {
                    ageText = '${age.inSeconds} сек. назад';
                  } else if (age.inMinutes < 60) {
                    ageText = '${age.inMinutes} мин. назад';
                  } else {
                    ageText = '${age.inHours} ч. назад';
                  }
                  
                  final isStale = age.inMinutes > 5;
                  return Text(
                    '🕐 $ageText',
                    style: TextStyle(
                      fontSize: 12, 
                      color: isStale ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
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
