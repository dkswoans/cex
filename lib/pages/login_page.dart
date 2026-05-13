import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import 'main_navigation_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userIdController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _login() {
    final userId = _userIdController.text.trim();
    final name = _nameController.text.trim();
    if (userId.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('학번이랑 이름 쓰라고요')));
      return;
    }

    context.read<GymProvider>().login(userId: userId, name: name);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.7, -0.7),
              radius: 1.4,
              colors: [greenColor, bgColor, surfaceColor, blueColor],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Transform.rotate(
                  angle: -0.035,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border.all(color: borderColor, width: 6),
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: const [
                        BoxShadow(
                          color: redColor,
                          offset: Offset(10, 10),
                          blurRadius: 0,
                        ),
                        BoxShadow(
                          color: greenColor,
                          offset: Offset(-6, -6),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Transform.rotate(
                          angle: 0.045,
                          child: Container(
                            height: 142,
                            decoration: BoxDecoration(
                              color: bgColor,
                              border: Border.all(color: borderColor, width: 6),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: const [
                                BoxShadow(
                                  color: blueColor,
                                  offset: Offset(7, 7),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/images/alrightt.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '압도정진\n올라잇삼창돌격',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: bgColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 0.9,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(4, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          '기구 예약 시스템 맞음',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: greenColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 26),
                        TextField(
                          controller: _userIdController,
                          decoration: const InputDecoration(
                            labelText: '학번',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 13),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: '이름',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 20),
                        Transform.rotate(
                          angle: 0.025,
                          child: FilledButton(
                            onPressed: _login,
                            child: const Text('입 장 ㄱㄱ'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
