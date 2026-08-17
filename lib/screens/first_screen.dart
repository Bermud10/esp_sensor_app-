import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  MqttServerClient? _client;

  // ⭐ Stream-контроллеры для каждой темы (все объявлены!)
  final _streetTempController = StreamController<String>.broadcast();
  final _balconyTempController = StreamController<String>.broadcast();
  final _roomTempController = StreamController<String>.broadcast();
  final _roomHumidityController = StreamController<String>.broadcast();
  final _roomPressureController = StreamController<String>.broadcast(); // ← Давление
  final _statusController = StreamController<String>.broadcast();

  // ⭐ Публичные streams для UI
  Stream<String> get streetTempStream => _streetTempController.stream;
  Stream<String> get balconyTempStream => _balconyTempController.stream;
  Stream<String> get roomTempStream => _roomTempController.stream;
  Stream<String> get roomHumidityStream => _roomHumidityController.stream;
  Stream<String> get roomPressureStream => _roomPressureController.stream; // ← Давление
  Stream<String> get statusStream => _statusController.stream;

  // Подключение к MQTT брокеру Clusterfly
  Future<void> connect() async {
    final clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';

    // Clusterfly: порт 9991, обычный MQTT
    _client = MqttServerClient.withPort('srv2.clusterfly.ru', clientId, 9991);
    _client!.useWebSocket = false;

    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.logging(on: true);

    // Авторизация через connectionMessage
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs('user_1d18b030', '1bz78-sYP3T8u') // Ваш username и пароль
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      print('🔄 Подключение к srv2.clusterfly.ru:9991...');
      _statusController.add('Подключение...');
      await _client!.connect();
    } catch (e) {
      print('❌ Ошибка подключения: $e');
      _client!.disconnect();
      _statusController.add('Ошибка: $e');
      return;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      print('✅ Успешно подключено к MQTT');
      _statusController.add('✅ Подключено');

      // Подписываемся на все топики с префиксом user_id
      _client!.subscribe('user_1d18b030/#', MqttQos.atMostOnce);

      // Слушаем входящие сообщения
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String topic = c[0].topic;
        final String payload =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print('📩 Получено: $topic = $payload');
        _handleMessage(topic, payload);
      });
    } else {
      print('❌ Подключение не удалось: ${_client!.connectionStatus!.returnCode}');
      _statusController.add('Ошибка: ${_client!.connectionStatus!.returnCode}');
    }
  }

  // Обработка входящих сообщений
  void _handleMessage(String topic, String payload) {
    if (topic == 'user_1d18b030/street/temp') {
      _streetTempController.add('$payload °C');
    } else if (topic == 'user_1d18b030/balcony/temp') {
      _balconyTempController.add('$payload °C');
    } else if (topic == 'user_1d18b030/room/temp') {
      _roomTempController.add('$payload °C');
    } else if (topic == 'user_1d18b030/room/humidity') {
      _roomHumidityController.add('$payload %');
    } else if (topic == 'user_1d18b030/room/pressure') {
      _roomPressureController.add('$payload гПа'); // ← Обработка давления
    }
  }

  void _onConnected() {
    _statusController.add('✅ Подключено');
  }

  void _onDisconnected() {
    _statusController.add('❌ Отключено');
  }

  void _onSubscribed(String topic) {
    print('📡 Подписались на тему: $topic');
  }

  // Очистка ресурсов
  void dispose() {
    _client?.disconnect();
    _streetTempController.close();
    _balconyTempController.close();
    _roomTempController.close();
    _roomHumidityController.close();
    _roomPressureController.close(); // ← Закрываем контроллер давления
    _statusController.close();
  }
}