import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  // ---------------- Звички користувача ----------------
  final Map<String, bool> habits = {
    'Випити воду': false,
    'Зробити перерву': false,
    'Вправа для очей': false,
  };

  // ---------------- Таймер ----------------
  Timer? _breakTimer;
  Duration _duration = const Duration(seconds: 20);
  Duration _initialDuration = const Duration(seconds: 20);
  bool _isRunning = false;

  TextEditingController hoursController = TextEditingController(text: '0');
  TextEditingController minutesController = TextEditingController(text: '0');
  TextEditingController secondsController = TextEditingController(text: '20');

  // ---------------- Поради для очей ----------------
  List<String> eyeNews = [
    'Регулярно моргайте і міняйте фокус очей.',
    'Встаньте і розімніться раз на годину.',
    'Пийте достатньо води протягом дня.',
  ];
  int currentNewsIndex = 0;

  List<Map<String, dynamic>> eyeExercises = [];

  // ---------------- Повідомлення ----------------
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadEyeExercises();
  }

  @override
  void dispose() {
    _breakTimer?.cancel();
    hoursController.dispose();
    minutesController.dispose();
    secondsController.dispose();
    super.dispose();
  }

  // ---------------- HTTP для завантаження JSON ----------------
  Future<void> _loadEyeExercises() async {
    try {
      final url = Uri.parse(
          'https://raw.githubusercontent.com/Viktoriia-Strilets/eye-exercises/main/exercises.json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          eyeExercises = List<Map<String, dynamic>>.from(data['exercises']);
        });
      } else {
        debugPrint('Помилка завантаження JSON: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Помилка завантаження JSON: $e');
    }
  }

  // ---------------- Логіка таймера ----------------
  void _startTimer() {
    if (_duration.inSeconds <= 0) return;
    _breakTimer?.cancel();
    setState(() => _isRunning = true);

    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_duration.inSeconds <= 0) {
        _showBreakNotification();
        _nextNews();
        _resetTimer();
        _startTimer();
      } else {
        setState(() => _duration -= const Duration(seconds: 1));
      }
    });
  }

  void _pauseTimer() {
    _breakTimer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _breakTimer?.cancel();
    setState(() {
      _duration = _initialDuration;
      _isRunning = false;
    });
  }

  // Застосування нового часу, введеного користувачем
  void _applyNewTime() {
    final h = int.tryParse(hoursController.text) ?? 0;
    final m = int.tryParse(minutesController.text) ?? 0;
    final s = int.tryParse(secondsController.text) ?? 0;
    setState(() {
      _duration = Duration(hours: h, minutes: m, seconds: s);
      _initialDuration = _duration;
      _isRunning = false;
    });
    _breakTimer?.cancel();
  }

  void _nextNews() {
    if (eyeNews.isEmpty) return;
    setState(() {
      currentNewsIndex = (currentNewsIndex + 1) % eyeNews.length;
    });
  }

  // ---------------- Повідомлення ----------------
  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
    InitializationSettings(android: androidSettings, iOS: iosSettings);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _startTimer();
      },
    );
  }

  Future<void> _showBreakNotification() async {
    final tip =
    eyeNews.isNotEmpty ? eyeNews[currentNewsIndex] : 'Зробіть перерву для очей, води та руху';
    _nextNews();

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Час перерви!'),
          content: Text(tip),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetTimer();
                _startTimer();
              },
              child: const Text('Старт/Повтор'),
            ),
          ],
        ),
      );
    }

    // Показ локального повідомлення
    const androidDetails = AndroidNotificationDetails(
      'break_channel', 'Перерви',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      ticker: 'Час перерви',
    );
    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
        android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Час перерви!',
      tip,
      notificationDetails,
      payload: 'start_timer',
    );
  }

  // ---------------- Форматування таймера ----------------
  String get _formattedTimer {
    final h = _duration.inHours;
    final m = _duration.inMinutes % 60;
    final s = _duration.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health & Focus')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // ---------------- Панель вводу часу ----------------
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Години'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Хвилини'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: secondsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Секунди'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _applyNewTime, child: const Text('Застосувати')),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // ---------------- Відображення таймера ----------------
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _formattedTimer,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Colors.red[400] : Colors.green[400],
                  ),
                  child: Text(_isRunning ? 'Пауза' : 'Старт'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _resetTimer,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[600]),
                  child: const Text('Скинути'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    _resetTimer();
                    _startTimer();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[400]),
                  child: const Text('Повтор'),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text('Сьогоднішні звички:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...habits.keys.map(
                  (habit) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: CheckboxListTile(
                  title: Text(habit),
                  value: habits[habit],
                  onChanged: (value) {
                    setState(() {
                      habits[habit] = value!;
                    });
                  },
                  activeColor: Colors.green[400],
                  controlAffinity: ListTileControlAffinity.trailing,
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text('Вправи для очей:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...eyeExercises.map(
                  (exercise) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Text(exercise['name'] ?? 'Без назви'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(exercise['instructions']?.join('\n') ?? 'Немає опису'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
