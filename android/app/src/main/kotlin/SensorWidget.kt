package com.example.esp_sensor_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import kotlinx.coroutines.*
import org.eclipse.paho.client.mqttv3.*
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class SensorWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "SensorWidget"
        private const val PREFS_NAME = "sensor_widget_prefs"
        private const val KEY_CURRENT_PAGE = "current_page"
        private const val KEY_TEMP_ROOM = "temp_room"
        private const val KEY_HUMIDITY_ROOM = "humidity_room"
        private const val KEY_TIME_ROOM = "time_room"
        private const val KEY_TEMP_STREET = "temp_street"
        private const val KEY_TEMP_BALCONY = "temp_balcony"

        // MQTT настройки
        private const val MQTT_BROKER = "tcp://srv2.clusterfly.ru:9991"
        private const val MQTT_USER = "user_1d18b030"
        private const val MQTT_PASSWORD = "1bz78-sYP3T8u"

        // Топики
        // Топики
        private const val TOPIC_ROOM = "user_1d18b030/room/data"
        private const val TOPIC_OUTSIDE = "user_1d18b030/street/data"

        // Действия для кнопок
        private const val ACTION_NEXT = "com.example.esp_sensor_app.ACTION_NEXT"
        private const val ACTION_PREV = "com.example.esp_sensor_app.ACTION_PREV"
        private const val ACTION_REFRESH = "com.example.esp_sensor_app.ACTION_REFRESH"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_NEXT -> {
                Log.d(TAG, "Переход на следующий экран")
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putInt(KEY_CURRENT_PAGE, 1).apply()
                updateAllWidgets(context)
            }
            ACTION_PREV -> {
                Log.d(TAG, "Переход на предыдущий экран")
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putInt(KEY_CURRENT_PAGE, 0).apply()
                updateAllWidgets(context)
            }
            ACTION_REFRESH -> {
                Log.d(TAG, "Запрос обновления данных")
                fetchMqttData(context)
            }
        }
    }

    private fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, SensorWidget::class.java)
        )
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.sensor_widget)

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentPage = prefs.getInt(KEY_CURRENT_PAGE, 0)

        val tempRoom = prefs.getString(KEY_TEMP_ROOM, "--") ?: "--"
        val humidityRoom = prefs.getString(KEY_HUMIDITY_ROOM, "--") ?: "--"
        val timeRoom = prefs.getString(KEY_TIME_ROOM, "--") ?: "--"
        val tempStreet = prefs.getString(KEY_TEMP_STREET, "--") ?: "--"
        val tempBalcony = prefs.getString(KEY_TEMP_BALCONY, "--") ?: "--"

        views.setTextViewText(R.id.temp_room, "$tempRoom °C")
        views.setTextViewText(R.id.humidity_room, "$humidityRoom %")
        views.setTextViewText(R.id.time_room, timeRoom)
        views.setTextViewText(R.id.temp_street, "$tempStreet °C")
        views.setTextViewText(R.id.temp_balcony, "$tempBalcony °C")

        // Кнопки
        val nextIntent = Intent(context, SensorWidget::class.java).apply { action = ACTION_NEXT }
        val nextPendingIntent = android.app.PendingIntent.getBroadcast(
            context, 0, nextIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_next, nextPendingIntent)

        val prevIntent = Intent(context, SensorWidget::class.java).apply { action = ACTION_PREV }
        val prevPendingIntent = android.app.PendingIntent.getBroadcast(
            context, 1, prevIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_prev, prevPendingIntent)

        val refreshIntent = Intent(context, SensorWidget::class.java).apply { action = ACTION_REFRESH }
        val refreshPendingIntent = android.app.PendingIntent.getBroadcast(
            context, 2, refreshIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_refresh_room, refreshPendingIntent)
        views.setOnClickPendingIntent(R.id.btn_refresh_outside, refreshPendingIntent)

        views.setDisplayedChild(R.id.viewFlipper, currentPage)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun fetchMqttData(context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            var client: MqttClient? = null
            try {
                val uniqueClientId = "android_widget_${System.currentTimeMillis()}"
                Log.d(TAG, "Подключение к MQTT... ($uniqueClientId)")

                client = MqttClient(MQTT_BROKER, uniqueClientId, MemoryPersistence())
                val options = MqttConnectOptions().apply {
                    userName = MQTT_USER
                    password = MQTT_PASSWORD.toCharArray()
                    isCleanSession = true
                    connectionTimeout = 10
                    keepAliveInterval = 60
                }

                client.connect(options)
                Log.d(TAG, "Подключено. Оформляем подписки...")

                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

                client.setCallback(object : MqttCallback {
                    override fun connectionLost(cause: Throwable?) {
                        Log.e(TAG, "Соединение потеряно: $cause")
                    }

                    override fun messageArrived(topic: String, message: MqttMessage) {
                        val payload = String(message.payload)
                        Log.d(TAG, "📡 Получено: $topic = $payload")

                        when (topic) {
                            // Комната
                            TOPIC_ROOM -> {
                                try {
                                    val json = JSONObject(payload)
                                    prefs.edit()
                                        .putString(KEY_TEMP_ROOM, "%.1f".format(json.getDouble("temp")))
                                        .putString(KEY_HUMIDITY_ROOM, "%.1f".format(json.getDouble("hum")))
                                        .putString(KEY_TIME_ROOM, formatTimestamp(json.getLong("ts")))
                                        .apply()
                                    Log.d(TAG, "✅ Сохранены данные комнаты")
                                } catch (e: Exception) {
                                    Log.e(TAG, "Ошибка парсинга комнаты: $e")
                                }
                            }
                            // Улица и Балкон (в одном JSON)
                            TOPIC_OUTSIDE -> {
                                try {
                                    val json = JSONObject(payload)
                                    prefs.edit()
                                        .putString(KEY_TEMP_STREET, "%.1f".format(json.getDouble("street_temp")))
                                        .putString(KEY_TEMP_BALCONY, "%.1f".format(json.getDouble("balcony_temp")))
                                        .apply()
                                    Log.d(TAG, "✅ Сохранены данные улицы и балкона")
                                } catch (e: Exception) {
                                    Log.e(TAG, "Ошибка парсинга улицы/балкона: $e")
                                }
                            }
                        }
                    }

                    override fun deliveryComplete(token: IMqttDeliveryToken?) {}
                })

                //  Подписываемся только на нужные топики
                client.subscribe(TOPIC_ROOM, 1)
                client.subscribe(TOPIC_OUTSIDE, 1)
                Log.d(TAG, "Подписки оформлены. Ожидаем данные...")

                // Ждем 3 секунды для получения retained сообщений
                delay(3000)

                Log.d(TAG, "Отключение от MQTT...")
                client.disconnect()

                withContext(Dispatchers.Main) {
                    Log.d(TAG, "Обновляем UI виджета")
                    updateAllWidgets(context)
                }

            } catch (e: Exception) {
                Log.e(TAG, "Ошибка MQTT: $e", e)
            } finally {
                try {
                    client?.close()
                } catch (e: Exception) {
                    Log.e(TAG, "Ошибка закрытия клиента: $e")
                }
            }
        }
    }

    private fun formatTimestamp(timestamp: Long): String {
        val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
        return sdf.format(Date(timestamp * 1000))
    }
}