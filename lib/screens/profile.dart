import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/student_profile.dart';
import '../widgets/input_field.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'home.dart';
import 'tasks.dart';
import 'health.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = true;
  bool editing = false;
  bool changingPassword = false;
  bool deleting = false;
  StudentProfile? profile;
  File? newImage;

  final fullNameController = TextEditingController();
  final groupController = TextEditingController();
  final specialtyController = TextEditingController();
  final studentIdController = TextEditingController();
  final descriptionController = TextEditingController();
  final passwordController = TextEditingController();
  final currentPasswordController = TextEditingController();

  String? passwordError;
  String? deleteError;

  final fullNameFocus = FocusNode();
  final groupFocus = FocusNode();
  final specialtyFocus = FocusNode();
  final studentIdFocus = FocusNode();
  final descriptionFocus = FocusNode();
  final passwordFocus = FocusNode();
  final currentPasswordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  // ---------------- Завантаження профілю ----------------
  Future<void> loadProfile() async {
    setState(() => loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _goToHome();

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return _goToHome();

    profile = StudentProfile.fromMap(doc.data()!);

    fullNameController.text = profile!.fullName;
    groupController.text = profile!.group;
    specialtyController.text = profile!.specialty;
    studentIdController.text = profile!.studentId;
    descriptionController.text = profile!.description;

    setState(() => loading = false);
  }

  // ---------------- Вибір фото профілю ----------------
  Future<void> pickImage() async {
    final picker = ImagePicker();

    // Показуємо користувачу вибір: камера чи галерея
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Оберіть джерело фото'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Камера'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Галерея'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final image = await picker.pickImage(source: source);
    if (image == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'profile_${FirebaseAuth.instance.currentUser!.uid}.jpg';
    final savedImage = await File(image.path).copy(p.join(directory.path, fileName));

    setState(() {
      newImage = savedImage;
    });
  }

  // ---------------- Методи для редагування профілю ----------------
  void cancelEdit() {
    setState(() {
      editing = false;
      changingPassword = false;
      passwordError = null;
      newImage = null;
      passwordController.clear();
      currentPasswordController.clear();

      if (profile != null) {
        fullNameController.text = profile!.fullName;
        groupController.text = profile!.group;
        specialtyController.text = profile!.specialty;
        studentIdController.text = profile!.studentId;
        descriptionController.text = profile!.description;
      }
    });
  }

  void startEdit() {
    Navigator.pop(context);
    setState(() {
      editing = true;
      deleting = false;
      changingPassword = false;
      passwordError = null;
    });
  }

  void startChangePassword() {
    setState(() {
      changingPassword = true;
      passwordError = null;
      passwordController.clear();
      currentPasswordController.clear();
    });
  }


  // ---------------- Навігація на Home ----------------
  void _goToHome() {
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
      );
    }
  }

  // ---------------- Показ повідомлення ----------------
  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- Збереження змін профілю ----------------
  Future<void> saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (fullNameController.text.isEmpty ||
        groupController.text.isEmpty ||
        specialtyController.text.isEmpty ||
        studentIdController.text.isEmpty) {
      showSnack('Заповніть всі обов’язкові поля');
      return;
    }


    String? photoPath = profile!.localPhotoPath;

    if (newImage != null) {
      photoPath = newImage!.path;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fullName': fullNameController.text.trim(),
        'group': groupController.text.trim(),
        'specialty': specialtyController.text.trim(),
        'studentId': studentIdController.text.trim(),
        'description': descriptionController.text.trim(),
        'localPhotoPath': photoPath,
      });

      if (changingPassword) {
        if (passwordController.text.isEmpty ||
            currentPasswordController.text.isEmpty) {
          setState(() => passwordError = 'Заповніть обидва поля');
          return;
        }

        final cred = EmailAuthProvider.credential(
            email: profile!.email, password: currentPasswordController.text);

        try {
          await user.reauthenticateWithCredential(cred);
          await user.updatePassword(passwordController.text);
        } catch (e) {
          setState(() => passwordError = 'Неправильний пароль або помилка: $e');
          return;
        }
      }

      await loadProfile();
      cancelEdit();

      showSnack('Зміни збережено!');
    } catch (e) {
      setState(() => passwordError = 'Помилка: ${e.toString()}');
    }
  }

  // ---------------- Видалення акаунту ----------------
  Future<void> requestDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? enteredPassword;
    // Діалог введення пароля для підтвердження
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        String? errorText;

        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Видалення акаунта'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Введіть пароль для підтвердження видалення акаунта:'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Скасувати'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                onPressed: () async {
                  try {
                    final cred = EmailAuthProvider.credential(
                      email: user.email!,
                      password: controller.text,
                    );
                    await user.reauthenticateWithCredential(cred);
                    enteredPassword = controller.text;
                    Navigator.pop(context);
                  } on FirebaseAuthException catch (e) {
                    setStateDialog(() {
                      errorText = 'Невірний пароль';
                    });
                  }
                },
                child: const Text('Підтвердити'),
              ),
            ],
          );
        });
      },
    );
    // Підтвердження видалення акаунту
    if (enteredPassword != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Останній шанс'),
          content: const Text(
              'Ви впевнені, що хочете видалити акаунт? Всі ваші дані будуть безповоротно видалені.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Видалити'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        currentPasswordController.text = enteredPassword!;
        confirmDeleteAccount();
      }
    }
  }

  // Реалізація видалення акаунту
  Future<void> confirmDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (currentPasswordController.text.isEmpty) {
      setState(() => deleteError = 'Введіть пароль');
      return;
    }

    try {
      // Перевіряємо, чи користувач увійшов через email/password
      if (user.providerData.any((p) => p.providerId == 'password')) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPasswordController.text,
        );

        // Реавторизація
        await user.reauthenticateWithCredential(cred);
      } else {
        setState(() => deleteError =
        'Неможливо видалити акаунт: увійшов через сторонній провайдер');
        return;
      }

      // Видалення всіх завдань користувача
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('userId', isEqualTo: user.uid)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Видалення локального фото
      if (profile?.localPhotoPath != null) {
        final file = File(profile!.localPhotoPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Акаунт успішно видалено!'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      _goToHome();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        setState(() => deleteError = 'Неправильний пароль');
      } else if (e.code == 'requires-recent-login') {
        setState(() =>
        deleteError = 'Необхідно повторно увійти для видалення акаунта');
      } else {
        setState(() =>
        deleteError = 'Помилка: ${e.code} - ${e.message}');
      }
    } catch (e) {
      setState(() => deleteError = 'Інша помилка: $e');
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Цифрова картка студента')),
      drawer: Drawer(
        backgroundColor: Colors.grey[300],
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _drawerButton('Редагувати профіль', startEdit),
                    const SizedBox(height: 8),
                    _drawerButton('Tasks', () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const TasksScreen()));
                    }),
                    const SizedBox(height: 8),
                    _drawerButton('Health', () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const HealthScreen()));
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _drawerButton('Видалити акаунт', requestDeleteAccount,
                      color: Colors.red[700]!),
                  const SizedBox(height: 8),
                  _drawerButton('Вийти з акаунту', () async {
                    await FirebaseAuth.instance.signOut();
                    _goToHome();
                  }, color: Colors.grey[600]!),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: editing ? pickImage : null,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: newImage != null
                    ? FileImage(newImage!)
                    : (profile!.localPhotoPath != null &&
                    File(profile!.localPhotoPath!).existsSync())
                    ? FileImage(File(profile!.localPhotoPath!))
                    : const AssetImage('assets/avatar_placeholder.png')
                as ImageProvider,
              ),
            ),
            const SizedBox(height: 16),
            // ---------------- Відображення інформації ----------------
            if (!editing && !deleting) ...[
              _infoCard('Повне імʼя', profile!.fullName),
              _infoCard('Email', profile!.email),
              _infoCard('№ студентського квитка', profile!.studentId),
              _infoCard('Група', profile!.group),
              _infoCard('Спеціальність', profile!.specialty),
              _infoCard('Короткий опис', profile!.description),
            ],
            // ---------------- Режим редагування ----------------
            if (editing) ...[
              InputField(
                  controller: fullNameController,
                  label: 'Повне імʼя',
                  focusNode: fullNameFocus,
                  errorText: fullNameController.text.isEmpty
                      ? 'Обов’язкове поле'
                      : null),
              InputField(
                  controller: studentIdController,
                  label: '№ студентського квитка',
                  focusNode: studentIdFocus,
                  errorText: studentIdController.text.isEmpty
                      ? 'Обов’язкове поле'
                      : null),
              InputField(
                  controller: groupController,
                  label: 'Група',
                  focusNode: groupFocus,
                  errorText:
                  groupController.text.isEmpty ? 'Обов’язкове поле' : null),
              InputField(
                  controller: specialtyController,
                  label: 'Спеціальність',
                  focusNode: specialtyFocus,
                  errorText: specialtyController.text.isEmpty
                      ? 'Обов’язкове поле'
                      : null),
              InputField(
                  controller: descriptionController,
                  label: 'Короткий опис',
                  focusNode: descriptionFocus),
              const SizedBox(height: 16),
              if (!changingPassword)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: startChangePassword,
                      child: const Text('Змінити пароль')),
                ),
              if (changingPassword) ...[
                InputField(
                    controller: passwordController,
                    label: 'Новий пароль',
                    obscure: true,
                    focusNode: passwordFocus),
                InputField(
                    controller: currentPasswordController,
                    label: 'Поточний пароль',
                    obscure: true,
                    focusNode: currentPasswordFocus,
                    errorText: passwordError),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child:
                      ElevatedButton(onPressed: saveChanges, child: const Text('Зберегти зміни'))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.grey[500]),
                      onPressed: cancelEdit,
                      child: const Text('Скасувати'),
                    ),
                  ),
                ],
              ),
            ],
            // ---------------- Режим видалення ----------------
            if (deleting) ...[
              InputField(
                  controller: currentPasswordController,
                  label: 'Пароль',
                  obscure: true,
                  focusNode: currentPasswordFocus,
                  errorText: deleteError),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                  onPressed: confirmDeleteAccount,
                  child: const Text('Підтвердити видалення'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _drawerButton(String text, VoidCallback onPressed, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.grey[300],
          foregroundColor: Colors.grey[900],
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: onPressed,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ),
    );
  }

  // ---------------- Відображення інформації у картці ----------------
  Widget _infoCard(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          text: '$label: ',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                  fontWeight: FontWeight.normal,
                  color: Colors.black87,
                  fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
