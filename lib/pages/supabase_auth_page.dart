import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/widgets/app_input_decoration.dart';

class SupabaseAuthPage extends StatefulWidget {
  const SupabaseAuthPage({super.key});

  @override
  State<SupabaseAuthPage> createState() => _SupabaseAuthPageState();
}

class _SupabaseAuthPageState extends State<SupabaseAuthPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _message;

  Future<void> _signUp() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      if (email.isEmpty || password.isEmpty) throw Exception('Preencha email e senha');

      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null) {
        setState(() => _message = 'Usuário criado. Você está logado.');
      } else {
        setState(() => _message = 'Verifique seu email para confirmação (se aplicado).');
      }
    } catch (e) {
      setState(() => _message = 'Erro: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      if (email.isEmpty || password.isEmpty) throw Exception('Preencha email e senha');

      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
        setState(() => _message = 'Logado como ${res.user!.email}');
      } else {
        setState(() => _message = 'Login não retornou usuário (verifique credenciais)');
      }
    } catch (e) {
      setState(() => _message = 'Erro: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    setState(() => _message = 'Desconectado');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Login Supabase')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (user != null) ...[
              Text('Logado como ${user.email}'),
              const SizedBox(height: 8),
              FilledButton(onPressed: _signOut, child: const Text('Sair')),
            ],
            if (user == null) ...[
              TextField(
                controller: _emailCtrl,
                decoration: AppInputDecoration.build(context, labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                decoration: AppInputDecoration.build(context, labelText: 'Senha'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Entrar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _signUp,
                      child: const Text('Criar conta'),
                    ),
                  ),
                ],
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }
}
