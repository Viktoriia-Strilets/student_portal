import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'profile.dart';
import '../widgets/input_field.dart';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = false;
  bool isRegister = false;

  // Контролери для текстових полів
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final fullNameController = TextEditingController();
  final groupController = TextEditingController();
  final specialtyController = TextEditingController();
  final studentIdController = TextEditingController();
  final descriptionController = TextEditingController();

  // FocusNode для керування фокусом у полях
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();

  File? selectedImage;

  String? emailError, passwordError, fullNameError, studentIdError, groupError, specialtyError;

  // Очистка форми та всіх помилок
  void resetForm() {
    emailController.clear();
    passwordController.clear();
    fullNameController.clear();
    groupController.clear();
    specialtyController.clear();
    studentIdController.clear();
    descriptionController.clear();
    selectedImage = null;
    emailError = passwordError = fullNameError = studentIdError = groupError = specialtyError = null;
  }

  // Вибір фото з камери або галереї
  Future<void> pickImage(StateSetter setStateDialog) async {
    final picker = ImagePicker();

    // Діалог для вибору джерела
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Оберіть джерело фото'),
        children: [
          SimpleDialogOption(
            child: const Text('Камера'),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          SimpleDialogOption(
            child: const Text('Галерея'),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
          SimpleDialogOption(
            child: const Text('Скасувати'),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      ),
    );

    if (source == null) return;

    final image = await picker.pickImage(source: source);
    if (image != null) setStateDialog(() => selectedImage = File(image.path));
  }

  // Збереження фото локально на пристрої
  Future<String?> saveImageLocally(File image, String uid) async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      final String imagePath = '${directory.path}/avatar_$uid.jpg';

      final File savedImage = await image.copy(imagePath);

      return savedImage.path;
    } catch (e) {
      debugPrint('Помилка збереження фото: $e');
      return null;
    }
  }

  // Перевірка, чи користувач вже авторизований
  Future<void> checkAuth() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      return;
    }

    goToProfile();
  }


  // Відкриття діалогу авторизації (вхід / реєстрація)
  Future<void> showAuthDialog() async {
    isRegister = false;
    resetForm();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: Colors.grey[200],
          title: Text(isRegister ? 'Реєстрація студента' : 'Вхід'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRegister)
                  GestureDetector(
                    onTap: () => pickImage(setStateDialog),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundImage: selectedImage != null ? FileImage(selectedImage!) : null,
                      child: selectedImage == null ? const Icon(Icons.camera_alt, size: 30) : null,
                    ),
                  ),
                if (isRegister) const SizedBox(height: 16),
                InputField(
                  controller: emailController,
                  label: 'Email',
                  focusNode: emailFocus,
                  errorText: emailError,
                  onChanged: (_) { if (emailError != null) setStateDialog(() => emailError = null); },
                ),
                InputField(
                  controller: passwordController,
                  label: 'Пароль',
                  obscure: true,
                  focusNode: passwordFocus,
                  errorText: passwordError,
                  onChanged: (_) { if (passwordError != null) setStateDialog(() => passwordError = null); },
                ),
                if (isRegister) ...[
                  InputField(controller: fullNameController, label: 'Повне імʼя *', errorText: fullNameError),
                  InputField(controller: studentIdController, label: '№ студентського квитка *', errorText: studentIdError),
                  InputField(controller: groupController, label: 'Група *', errorText: groupError),
                  InputField(controller: specialtyController, label: 'Спеціальність *', errorText: specialtyError),
                  InputField(controller: descriptionController, label: 'Короткий опис (інтереси, навички)'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () { resetForm(); Navigator.pop(context); },
              child: const Text('Скасувати', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () { setStateDialog(() { isRegister = !isRegister; resetForm(); }); },
              child: Text(isRegister ? 'Маю акаунт' : 'Створити акаунт', style: const TextStyle(color: Colors.blue)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              onPressed: loading ? null : () async {
                if (isRegister) { await register(setStateDialog); }
                else { await signIn(setStateDialog); }
              },
              child: Text(isRegister ? 'Зареєструватись' : 'Увійти'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Валідація полів ----------------
  bool validate(StateSetter setStateDialog) {
    bool valid = true;
    emailError = passwordError = fullNameError = studentIdError = groupError = specialtyError = null;
    final emailPattern = RegExp(r'^[^@]+@[^@]+\.[^@]+');

    if (emailController.text.isEmpty) { emailError = 'Email обовʼязковий'; valid = false; }
    else if (!emailPattern.hasMatch(emailController.text.trim())) { emailError = 'Невірний формат email'; valid = false; }

    if (passwordController.text.isEmpty) { passwordError = 'Пароль обовʼязковий'; valid = false; }
    else if (passwordController.text.length < 6) { passwordError = 'Пароль мінімум 6 символів'; valid = false; }

    if (isRegister) {
      if (fullNameController.text.isEmpty) { fullNameError = 'Обовʼязкове поле'; valid = false; }
      if (studentIdController.text.isEmpty) { studentIdError = 'Обовʼязкове поле'; valid = false; }
      if (groupController.text.isEmpty) { groupError = 'Обовʼязкове поле'; valid = false; }
      if (specialtyController.text.isEmpty) { specialtyError = 'Обовʼязкове поле'; valid = false; }
    }

    setStateDialog(() {});
    return valid;
  }

  // ---------------- Авторизація ----------------
  Future<void> signIn(StateSetter setStateDialog) async {
    if (!validate(setStateDialog)) return;

    setStateDialog(() => loading = true);

    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        setStateDialog(() {
          emailError = 'Профіль не знайдено. Зареєструйтесь знову';
        });
        return;
      }

      goToProfile();
    } on FirebaseAuthException catch (_) {
      setStateDialog(() {
        emailError = 'Невірний email або пароль';
        passwordError = 'Невірний email або пароль';
      });
    } finally {
      setStateDialog(() => loading = false);
    }
  }

  // ---------------- Реєстрація ----------------
  Future<void> register(StateSetter setStateDialog) async {
    if (!validate(setStateDialog)) return;
    setStateDialog(() => loading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String? localPhotoPath;

      if (selectedImage != null) {
        localPhotoPath = await saveImageLocally(
          selectedImage!,
          cred.user!.uid,
        );
      }


      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'fullName': fullNameController.text.trim(),
        'studentId': studentIdController.text.trim(),
        'group': groupController.text.trim(),
        'specialty': specialtyController.text.trim(),
        'email': emailController.text.trim(),
        'description': descriptionController.text.trim(),
        'photoUrl': localPhotoPath,
      });

      goToProfile();
    } on FirebaseAuthException catch (e) {
      setStateDialog(() {
        if (e.code == 'email-already-in-use') emailError = 'Email вже використовується';
        else if (e.code == 'invalid-email') emailError = 'Невірний формат email';
        else if (e.code == 'weak-password') passwordError = 'Пароль занадто короткий';
        else emailError = e.message;
      });
    } catch (e) {
      setStateDialog(() {
        emailError = 'Помилка реєстрації. Спробуйте ще раз';
      });
      debugPrint('Unknown error: $e');
    } finally {
      setStateDialog(() => loading = false);
    }
  }

  // Перехід на екран профілю
  void goToProfile() {
    setState(() => loading = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Студентський портал')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 80, color: Colors.grey[800]),
            const SizedBox(height: 16),
            const Text('Ласкаво просимо!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Мобільний додаток для студентів з відстеженням завдань, профілю користувача та підтримкою здорових звичок, включаючи таймер і вправи для очей.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : showAuthDialog,
        icon: const Icon(Icons.login, color: Colors.white),
        label: const Text('Увійти / Реєстрація', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[800],
      ),
    );
  }
}
