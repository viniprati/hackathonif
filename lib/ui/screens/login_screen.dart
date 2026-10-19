import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cpf = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _cpf.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 28),
                      const NativaBrand(large: true),
                      const SizedBox(height: 20),
                      const Text(
                        'Bem-vindo ao Nativa',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Protótipo de acesso • use qualquer CPF e senha',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: NativaColors.gray),
                      ),
                      const SizedBox(height: 32),
                      const Text('CPF'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cpf,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.badge_outlined),
                          hintText: '00000000000',
                        ),
                        validator: (value) =>
                            value?.length == 11 ? null : 'Informe 11 dígitos.',
                      ),
                      const SizedBox(height: 16),
                      const Text('Senha'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          hintText: 'Sua senha',
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        validator: (value) => value?.isNotEmpty == true
                            ? null
                            : 'Informe uma senha.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            widget.onSignIn();
                          }
                        },
                        child: const Text('Entrar'),
                      ),
                      TextButton(
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Recuperação de senha estará disponível após integrar o serviço de acesso.',
                            ),
                          ),
                        ),
                        child: const Text(
                          'Esqueci minha senha',
                          style: TextStyle(
                            color: NativaColors.earth,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: NativaColors.lightGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dúvidas ou problemas?',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Entre em contato com a equipe da Aprovista para obter acesso.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
