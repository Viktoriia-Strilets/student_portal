import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String? id;
  final String title;
  final String description;
  final DateTime deadline;
  bool done;
  final String userId;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.deadline,
    this.done = false,
    required this.userId,
  });

  factory Task.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Task(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      deadline: (data['deadline'] as Timestamp).toDate(),
      done: (data['done'] as bool?) ?? false,
      userId: (data['userId'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'deadline': Timestamp.fromDate(deadline),
      'done': done,
      'userId': userId,
    };
  }
}
