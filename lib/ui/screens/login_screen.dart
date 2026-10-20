import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../view_models/auth_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.viewModel});
  final AuthViewModel viewModel;

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

  void _submit() {
    if (widget.viewModel.busy || !validateAccessibleForm(_formKey)) return;
    FocusScope.of(context).unfocus();
    widget.viewModel.signIn(_cpf.text, _password.text);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) => Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                        child: FocusTraversalGroup(
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
                          'Entre com o CPF e a senha da sua conta',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: NativaColors.gray),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _cpf,
                          enabled: !widget.viewModel.busy,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.badge_outlined),
                            labelText: 'CPF (obrigatório)',
                            hintText: '00000000000',
                            helperText:
                                'Digite os 11 números, sem pontos ou traços.',
                          ),
                          validator: (value) => value?.length == 11
                              ? null
                              : 'Informe 11 dígitos.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          enabled: !widget.viewModel.busy,
                          obscureText: _hidePassword,
                          autofillHints: const [AutofillHints.password],
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            labelText: 'Senha (obrigatório)',
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
                              onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword),
                            ),
                          ),
                          validator: (value) => value?.isNotEmpty == true
                              ? null
                              : 'Informe uma senha.',
                        ),
                        const SizedBox(height: 16),
                        if (widget.viewModel.error != null)
                          GuidanceMessage(widget.viewModel.error!),
                        FilledButton(
                          onPressed: widget.viewModel.busy ? null : _submit,
                          child: Text(
                              widget.viewModel.busy ? 'Entrando…' : 'Entrar'),
                        ),
                        TextButton(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Para recuperar sua senha, entre em contato com a equipe da Aprovista.',
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
                    ))),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
