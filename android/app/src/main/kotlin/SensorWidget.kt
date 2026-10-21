package com.example.esp_sensor_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
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
        private const val KEY_TIME_STREET = "time_street"

        private const val MQTT_BROKER = "tcp://srv2.clusterfly.ru:9991"
        private const val MQTT_USER = "user_1d18b030"
        private const val MQTT_PASSWORD = "1bz78-sYP3T8u"

        private const val TOPIC_ROOM = "user_1d18b030/room/data"
        private const val TOPIC_OUTSIDE = "user_1d18b030/street/data"

        private const val ACTION_TOGGLE = "com.example.esp_sensor_app.ACTION_TOGGLE" // ⭐ Одно действие для переключения
        private const val ACTION_REFRESH = "com.example.esp_sensor_app.ACTION_REFRESH"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, isLoading = false)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_TOGGLE -> {
                Log.d(TAG, "🔄 Тап по виджету: переключение экрана")
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val currentPage = prefs.getInt(KEY_CURRENT_PAGE, 0)
                // Переключаем: если 0, то станет 1. Если 1, то станет 0.
                prefs.edit().putInt(KEY_CURRENT_PAGE, if (currentPage == 0) 1 else 0).apply()
                updateAllWidgets(context, isLoading = false)
            }
            ACTION_REFRESH -> {
                Log.d(TAG, "🔴 Нажата кнопка обновления!")
                updateAllWidgets(context, isLoading = true)
                fetchMqttData(context)
            }
        }
    }

    private fun updateAllWidgets(context: Context, isLoading: Boolean) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, SensorWidget::class.java)
        )
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, isLoading)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, isLoading: Boolean) {
        val views = RemoteViews(context.packageName, R.layout.sensor_widget)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentPage = prefs.getInt(KEY_CURRENT_PAGE, 0)

        // Обновляем текст
        views.setTextViewText(R.id.temp_room, "${prefs.getString(KEY_TEMP_ROOM, "--")}°C")
        views.setTextViewText(R.id.humidity_room, "${prefs.getString(KEY_HUMIDITY_ROOM, "--")}%")
        views.setTextViewText(R.id.time_room, prefs.getString(KEY_TIME_ROOM, "--") ?: "--")
        views.setTextViewText(R.id.temp_street, "${prefs.getString(KEY_TEMP_STREET, "--")}°C")
        views.setTextViewText(R.id.temp_balcony, "${prefs.getString(KEY_TEMP_BALCONY, "--")}°C")
        views.setTextViewText(R.id.time_street, prefs.getString(KEY_TIME_STREET, "--") ?: "--")

        // ⭐ Переключение экранов через видимость контейнеров
        if (currentPage == 0) {
            views.setViewVisibility(R.id.screen_room, View.VISIBLE)
            views.setViewVisibility(R.id.screen_outside, View.GONE)
        } else {
            views.setViewVisibility(R.id.screen_room, View.GONE)
            views.setViewVisibility(R.id.screen_outside, View.VISIBLE)
        }

        // Управление анимацией загрузки
        val visibilityBtn = if (isLoading) View.GONE else View.VISIBLE
        val visibilityProgress = if (isLoading) View.VISIBLE else View.GONE

        views.setViewVisibility(R.id.btn_refresh_room, visibilityBtn)
        views.setViewVisibility(R.id.progress_room, visibilityProgress)
        views.setViewVisibility(R.id.btn_refresh_outside, visibilityBtn)
        views.setViewVisibility(R.id.progress_outside, visibilityProgress)

        // Назначаем клики только если НЕ идет загрузка
        if (!isLoading) {
            // ⭐ Тап по всему контейнеру экрана переключает вид
            val toggleIntent = Intent(context, SensorWidget::class.java).apply { action = ACTION_TOGGLE }
            val togglePendingIntent = android.app.PendingIntent.getBroadcast(
                context, 3, toggleIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.screen_room, togglePendingIntent)
            views.setOnClickPendingIntent(R.id.screen_outside, togglePendingIntent)

            // Кнопка обновления работает как раньше
            val refreshIntent = Intent(context, SensorWidget::class.java).apply { action = ACTION_REFRESH }
            val refreshPendingIntent = android.app.PendingIntent.getBroadcast(
                context, 2, refreshIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_refresh_room, refreshPendingIntent)
            views.setOnClickPendingIntent(R.id.btn_refresh_outside, refreshPendingIntent)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun fetchMqttData(context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            var client: MqttClient? = null
            try {
                Log.d(TAG, "🟢 1. Вход в fetchMqttData")
                val uniqueClientId = "widget_cmd_${System.currentTimeMillis()}"

                client = MqttClient(MQTT_BROKER, uniqueClientId, MemoryPersistence())
                val options = MqttConnectOptions().apply {
                    userName = MQTT_USER
                    password = MQTT_PASSWORD.toCharArray()
                    isCleanSession = true
                    connectionTimeout = 10
                    keepAliveInterval = 60
                }

                client.connect(options)
                Log.d(TAG, "🟢 2. Подключено к MQTT")

                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                var roomUpdated = false
                var streetUpdated = false

                client.setCallback(object : MqttCallback {
                    override fun connectionLost(cause: Throwable?) {
                        Log.e(TAG, "❌ Соединение потеряно: $cause")
                    }

                    override fun messageArrived(topic: String, message: MqttMessage) {
                        val payload = String(message.payload)
                        Log.d(TAG, "📩 ПОЛУЧЕНЫ СВЕЖИЕ ДАННЫЕ: Топик=$topic")

                        when (topic) {
                            TOPIC_ROOM -> {
                                try {
                                    val json = JSONObject(payload)
                                    prefs.edit()
                                        .putString(KEY_TEMP_ROOM, "%.1f".format(json.getDouble("temp")))
                                        .putString(KEY_HUMIDITY_ROOM, "%.1f".format(json.getDouble("hum")))
                                        .putString(KEY_TIME_ROOM, formatTimestamp(json.getLong("ts")))
                                        .apply()
                                    roomUpdated = true
                                } catch (e: Exception) {
                                    Log.e(TAG, "❌ Ошибка парсинга комнаты: $e")
                                }
                            }
                            TOPIC_OUTSIDE -> {
                                try {
                                    val json = JSONObject(payload)
                                    prefs.edit()
                                        .putString(KEY_TEMP_STREET, "%.1f".format(json.getDouble("street_temp")))
                                        .putString(KEY_TEMP_BALCONY, "%.1f".format(json.getDouble("balcony_temp")))
                                        .putString(KEY_TIME_STREET, formatTimestamp(json.getLong("ts")))
                                        .apply()
                                    streetUpdated = true
                                } catch (e: Exception) {
                                    Log.e(TAG, "❌ Ошибка парсинга улицы: $e")
                                }
                            }
                        }
                    }

                    override fun deliveryComplete(token: IMqttDeliveryToken?) {}
                })

                client.subscribe(TOPIC_ROOM, 1)
                client.subscribe(TOPIC_OUTSIDE, 1)
                Log.d(TAG, "🟢 3. Подписки оформлены")

                val cmdMessage = MqttMessage("update".toByteArray())
                cmdMessage.qos = 1

                Log.d(TAG, "🟢 4. Отправка команды 'update' на платы...")
                client.publish("user_1d18b030/room/command", cmdMessage)
                client.publish("user_1d18b030/street/command", cmdMessage)

                Log.d(TAG, "🟢 5. Ожидание ответа от плат (до 6 сек)...")
                var waitTime = 0
                while (waitTime < 60 && (!roomUpdated || !streetUpdated)) {
                    delay(100)
                    waitTime++
                }

                Log.d(TAG, "🟢 6. Отключаемся от MQTT...")
                client.disconnect()

                withContext(Dispatchers.Main) {
                    Log.d(TAG, "🟢 7. Обновляем UI виджета!")
                    updateAllWidgets(context, isLoading = false)
                }

            } catch (e: Exception) {
                Log.e(TAG, "❌ КРИТИЧЕСКАЯ ОШИБКА MQTT: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    updateAllWidgets(context, isLoading = false)
                }
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