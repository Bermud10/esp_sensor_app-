import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// Модель данных для отображения
class SensorReading {
  final String displayValue;
  final DateTime timestamp;
  final double? difference;
  final bool isIncreasing;

  SensorReading({
    required this.displayValue,
    required this.timestamp,
    this.difference,
    this.isIncreasing = true,
  });
}

class MqttService {
  MqttServerClient? _client;

  // Переменные для хранения последних значений (чтобы считать разницу)
  double? _lastRoomTemp;
  double? _lastStreetTemp;
  double? _lastBalconyTemp;
  double? _lastRoomHumidity;
  double? _lastRoomPressure;

  // ⭐ Теперь потоки передают объекты SensorReading, а не просто String
  final _streetTempController = StreamController<SensorReading>.broadcast();
  final _balconyTempController = StreamController<SensorReading>.broadcast();
  final _roomTempController = StreamController<SensorReading>.broadcast();
  final _roomHumidityController = StreamController<SensorReading>.broadcast();
  final _roomPressureController = StreamController<SensorReading>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<SensorReading> get streetTempStream => _streetTempController.stream;
  Stream<SensorReading> get balconyTempStream => _balconyTempController.stream;
  Stream<SensorReading> get roomTempStream => _roomTempController.stream;
  Stream<SensorReading> get roomHumidityStream => _roomHumidityController.stream;
  Stream<SensorReading> get roomPressureStream => _roomPressureController.stream;
  Stream<String> get statusStream => _statusController.stream;

  Future<void> connect() async {
    final clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient.withPort('srv2.clusterfly.ru', clientId, 9991);
    _client!.useWebSocket = false;
    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.logging(on: false); // Отключаем спам в консоль для чистоты

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs('user_1d18b030', '1bz78-sYP3T8u')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      _statusController.add('Подключение...');
      await _client!.connect();
    } catch (e) {
      _client!.disconnect();
      _statusController.add('Ошибка: $e');
      return;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      _statusController.add('✅ Подключено');
      _client!.subscribe('user_1d18b030/#', MqttQos.atMostOnce);

      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String topic = c[0].topic;
        final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        _handleMessage(topic, payload);
      });
    } else {
      _statusController.add('Ошибка подключения');
    }
  }

  void _handleMessage(String topic, String payload) {
    final now = DateTime.now();
    double? diff;
    bool isIncreasing = true;

    // Вспомогательная функция для обработки числовых данных
    void processNumericData(
      double? lastValue, 
      Function(double?) setLastValue, 
      StreamController<SensorReading> controller, 
      String unit
    ) {
      double newVal = double.tryParse(payload) ?? 0.0;
      if (lastValue != null) {
        diff = newVal - lastValue;
        isIncreasing = diff! >= 0;
      }
      setLastValue(newVal);
      
      controller.add(SensorReading(
        displayValue: '${newVal.toStringAsFixed(1)} $unit',
        timestamp: now,
        difference: diff?.abs(), // Передаем модуль числа для отображения
        isIncreasing: isIncreasing,
      ));
    }

    if (topic == 'user_1d18b030/street/temp') {
      processNumericData(_lastStreetTemp, (val) => _lastStreetTemp = val, _streetTempController, '°C');
    } else if (topic == 'user_1d18b030/balcony/temp') {
      processNumericData(_lastBalconyTemp, (val) => _lastBalconyTemp = val, _balconyTempController, '°C');
    } else if (topic == 'user_1d18b030/room/temp') {
      processNumericData(_lastRoomTemp, (val) => _lastRoomTemp = val, _roomTempController, '°C');
    } else if (topic == 'user_1d18b030/room/humidity') {
      processNumericData(_lastRoomHumidity, (val) => _lastRoomHumidity = val, _roomHumidityController, '%');
    } else if (topic == 'user_1d18b030/room/pressure') {
      processNumericData(_lastRoomPressure, (val) => _lastRoomPressure = val, _roomPressureController, 'гПа');
    }
  }

  void _onConnected() => _statusController.add('✅ Подключено');
  void _onDisconnected() => _statusController.add('❌ Отключено');
  void _onSubscribed(String topic) => print('📡 Подписка: $topic');

  void dispose() {
    _client?.disconnect();
    _streetTempController.close();
    _balconyTempController.close();
    _roomTempController.close();
    _roomHumidityController.close();
    _roomPressureController.close();
    _statusController.close();
  }
}