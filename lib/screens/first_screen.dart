import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  MqttServerClient? _client;
  
  // Stream-контроллеры для каждой темы
  final _streetTempController = StreamController<String>.broadcast();
  final _balconyTempController = StreamController<String>.broadcast();
  final _roomTempController = StreamController<String>.broadcast();
  final _roomHumidityController = StreamController<String>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  // Публичные streams для UI
  Stream<String> get streetTempStream => _streetTempController.stream;
  Stream<String> get balconyTempStream => _balconyTempController.stream;
  Stream<String> get roomTempStream => _roomTempController.stream;
  Stream<String> get roomHumidityStream => _roomHumidityController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // Подключение к MQTT брокеру
  Future<void> connect() async {
    final clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient('broker.hivemq.com', clientId);
    
    _client!.port = 1883;
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      _statusController.add('Подключение к брокеру...');
      await _client!.connect();
    } catch (e) {
      print('❌ Ошибка подключения: $e');
      _client!.disconnect();
      _statusController.add('Ошибка подключения');
      return;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      print('✅ Успешно подключено к MQTT');
      
      // Подписываемся на все темы с нашим префиксом
      _client!.subscribe('bermud10_test/#', MqttQos.atMostOnce);

      // Слушаем входящие сообщения
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String topic = c[0].topic;
        final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        print(' Получено: Тема=$topic, Значение=$payload');
        _handleMessage(topic, payload);
      });
    } else {
      print(' Подключение не удалось');
      _statusController.add('Ошибка подключения');
    }
  }

  // Обработка входящих сообщений
  void _handleMessage(String topic, String payload) {
    if (topic == 'bermud10_test/street/temp') {
      _streetTempController.add('$payload °C');
    } else if (topic == 'bermud10_test/balcony/temp') {
      _balconyTempController.add('$payload °C');
    } else if (topic == 'bermud10_test/room/temp') {
      _roomTempController.add('$payload °C');
    } else if (topic == 'bermud10_test/room/humidity') {
      _roomHumidityController.add('$payload %');
    }
  }

  void _onConnected() {
    _statusController.add('✅ Подключено к MQTT');
  }

  void _onDisconnected() {
    _statusController.add('❌ Отключено');
  }

  void _onSubscribed(String topic) {
    print('📡 Подписались на тему: $topic');
  }

  // Отключение от брокера
  void disconnect() {
    _client?.disconnect();
  }

  // Очистка ресурсов
  void dispose() {
    _client?.disconnect();
    _streetTempController.close();
    _balconyTempController.close();
    _roomTempController.close();
    _roomHumidityController.close();
    _statusController.close();
  }
}