import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TemperatureDisplay extends StatelessWidget {
  final String location;
  final String temperature;
  final String unit;
  final DateTime? lastUpdated;
  final String info;
  final bool isLoading;
  final VoidCallback onRefresh;

  const TemperatureDisplay({
    super.key,
    required this.location,
    required this.temperature,
    required this.unit,
    this.lastUpdated,
    required this.info,
    required this.isLoading,
    required this.onRefresh,
  });

  String _getLocationTitle(String location) {
    if (location == "street") {
      return "Температура улицы";
    }
    return "Температура";
  }

  String _formatTime(DateTime time) {
    return DateFormat('d MMM  HH:mm', "ru").format(time);
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
            if (location.isNotEmpty) ...[
              Text(
                _getLocationTitle(location),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
            ],
            Text(
              temperature == '***'
                  ? temperature
                  : '$temperature $unit',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 10),

            if (lastUpdated != null) ...[
              Text(
                'Обновлено: ${_formatTime(lastUpdated!)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],

            if (info.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                info,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FloatingActionButton.extended(
          onPressed: isLoading ? null : onRefresh,
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