import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

import '../models/task.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final tasksRef = FirebaseFirestore.instance.collection('tasks');

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  DateTime? selectedDate;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // ---------------- ADD / EDIT TASK ----------------
  Future<void> _showAddTaskDialog([Task? task]) async {
    titleController.text = task?.title ?? '';
    descriptionController.text = task?.description ?? '';
    selectedDate = task?.deadline;

    final _formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(task == null ? 'Нове завдання' : 'Редагувати'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Назва *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Це поле обов\'язкове';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Опис',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    selectedDate == null
                        ? 'Дедлайн *'
                        : DateFormat('dd.MM.yyyy').format(selectedDate!),
                    style: TextStyle(
                      color: selectedDate == null ? Colors.red : Colors.grey[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.calendar_month),
                    color: Colors.grey[800],
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate() || selectedDate == null) {
                setState(() {});
                return;
              }

              final data = Task(
                id: task?.id,
                title: titleController.text.trim(),
                description: descriptionController.text.trim(),
                deadline: selectedDate!,
                userId: user!.uid,
                done: task?.done ?? false,
              );

              if (task == null) {
                await tasksRef.add(data.toMap());

                Add2Calendar.addEvent2Cal(Event(
                  title: data.title,
                  description: data.description,
                  startDate: data.deadline,
                  endDate: data.deadline.add(const Duration(hours: 1)),
                ));
              } else {
                await tasksRef.doc(task.id).update(data.toMap());
              }

              Navigator.pop(context);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
  }

  // ---------- HELPERS ----------
  // Перевірка, чи два дні однакові
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Користувач не авторизований')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мої завдання'),
        backgroundColor: Colors.grey[800],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(),
        backgroundColor: Colors.grey[800],
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: tasksRef
            .where('userId', isEqualTo: user!.uid)
            .orderBy('deadline')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Помилка: ${snapshot.error}'));
          }

          final allTasks =
          snapshot.data!.docs.map((d) => Task.fromDocument(d)).toList();

          final filteredTasks = _selectedDay == null
              ? allTasks
              : allTasks
              .where((t) => _sameDay(t.deadline, _selectedDay!))
              .toList();

          final markedDays = allTasks
              .map((t) =>
              DateTime(t.deadline.year, t.deadline.month, t.deadline.day))
              .toSet();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2100),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (d) =>
                  _selectedDay != null && _sameDay(d, _selectedDay!),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  headerVisible: false,
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, _) {
                      final isMarked = markedDays.contains(
                        DateTime(day.year, day.month, day.day),
                      );
                      return Container(
                        alignment: Alignment.center,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isMarked ? Colors.green[400] : Colors.grey[300],
                          shape: BoxShape.circle,
                          boxShadow: isMarked
                              ? [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.5),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ]
                              : null,
                        ),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isMarked ? Colors.white : Colors.grey[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: filteredTasks.isEmpty
                    ? const Center(
                  child: Text(
                    'Немає завдань',
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredTasks.length,
                  itemBuilder: (_, i) {
                    final t = filteredTasks[i];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        title: Text(
                          t.title,
                          style: TextStyle(
                            fontSize: 18,
                            decoration: t.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('dd.MM.yyyy').format(t.deadline),
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: t.done,
                              onChanged: (_) => tasksRef
                                  .doc(t.id)
                                  .update({'done': !t.done}),
                              activeColor: Colors.green[400],
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              color: Colors.grey[800],
                              onPressed: () => _showAddTaskDialog(t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: t.done
                                  ? () => tasksRef.doc(t.id).delete()
                                  : null,
                              color: t.done ? Colors.red[700] : Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
