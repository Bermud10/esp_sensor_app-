import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/temperature_display.dart';

class FirstScreen extends StatefulWidget {
  const FirstScreen({super.key});

  @override
  State<FirstScreen> createState() => FirstScreenState();
}

class FirstScreenState extends State<FirstScreen> {
  String _info = '';
  String _temperature = '***';
  String _location = '';
  String _unit = '';
  DateTime? _lastUpdated;
  bool isLoading = false;

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTemp = prefs.getString('temperature');
    final cachedLocation = prefs.getString('location');
    final cachedUnit = prefs.getString('unit');
    final cachedTime = prefs.getString('lastUpdated');

    if (cachedTemp != null && mounted) {
      setState(() {
        _temperature = cachedTemp;
        _location = cachedLocation ?? '';
        _unit = cachedUnit ?? '';
        _lastUpdated = cachedTime != null ? DateTime.tryParse(cachedTime) : null;
      });
    }
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('temperature', _temperature);
    await prefs.setString('location', _location);
    await prefs.setString('unit', _unit);
    if (_lastUpdated != null) {
      await prefs.setString('lastUpdated', _lastUpdated!.toIso8601String());
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> getTemperature() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('http://192.168.0.182'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _temperature = data['temperature'].toString();
          _location = data['location'];
          _unit = data['unit'];
          _lastUpdated = DateTime.now();
        });
        await _saveToCache();
        _info = "";
      } else {
        setState(() {
          _info = "Ошибка: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _info = "Ошибка подключения";
      });
      print("$e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TemperatureDisplay(
      location: _location,
      temperature: _temperature,
      unit: _unit,
      lastUpdated: _lastUpdated,
      info: _info,
      isLoading: isLoading,
      onRefresh: getTemperature,
    );
  }
}