import 'package:flutter/material.dart';

import '../services/admin_api_repository.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final repo = AdminApiRepository();
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await repo.users();
      if (mounted) setState(() => users = data);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    final result = await showDialog<_NewUser>(
      context: context,
      builder: (_) => const _NewUserDialog(),
    );
    if (result == null) return;

    await repo.createUser(
      email: result.email,
      password: result.password,
      fullName: result.fullName,
      role: result.role,
    );
    await _load();
  }

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final current = user['role']?.toString() ?? 'viewer';

    final role = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Kullanıcı rolü'),
        children: [
          for (final r in ['admin', 'staff', 'viewer'])
            ListTile(
              leading: Icon(
                current == r
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(_roleLabel(r)),
              onTap: () => Navigator.pop(context, r),
            ),
        ],
      ),
    );

    if (role == null || role == current) return;
    await repo.setRole(user['id'].toString(), role);
    await _load();
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final controller = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user['full_name']} • Şifre Yenile'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Yeni şifre, en az 8 karakter',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.length >= 8) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Şifreyi Değiştir'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (password == null) return;
    await repo.resetPassword(user['id'].toString(), password);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı şifresi yenilendi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı Yönetimi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Kullanıcı Ekle'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error!),
                ),
              ),
            ...users.map(
              (user) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (user['full_name']?.toString().isNotEmpty == true)
                            ? user['full_name'].toString()[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(
                      user['full_name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${user['email']} • ${_roleLabel(user['role']?.toString() ?? '')}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'role') {
                          await _changeRole(user);
                        } else if (action == 'toggle') {
                          await repo.setActive(
                            user['id'].toString(),
                            !(user['active'] == true),
                          );
                          await _load();
                        } else if (action == 'password') {
                          await _resetPassword(user);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'role',
                          child: Text('Rolü Değiştir'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            user['active'] == true
                                ? 'Hesabı Pasif Yap'
                                : 'Hesabı Aktif Yap',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'password',
                          child: Text('Şifreyi Yenile'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'admin' => 'Yönetici',
        'staff' => 'Personel',
        _ => 'Görüntüleme',
      };
}

class _NewUserDialog extends StatefulWidget {
  const _NewUserDialog();

  @override
  State<_NewUserDialog> createState() => _NewUserDialogState();
}

class _NewUserDialogState extends State<_NewUserDialog> {
  final fullName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  String role = 'staff';

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Kullanıcı'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fullName,
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Geçici şifre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(
                labelText: 'Rol',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'admin',
                  child: Text('Yönetici'),
                ),
                DropdownMenuItem(
                  value: 'staff',
                  child: Text('Personel'),
                ),
                DropdownMenuItem(
                  value: 'viewer',
                  child: Text('Görüntüleme'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => role = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            if (fullName.text.trim().isEmpty ||
                email.text.trim().isEmpty ||
                password.text.length < 8) {
              return;
            }

            Navigator.pop(
              context,
              _NewUser(
                fullName: fullName.text.trim(),
                email: email.text.trim(),
                password: password.text,
                role: role,
              ),
            );
          },
          child: const Text('Kullanıcıyı Oluştur'),
        ),
      ],
    );
  }
}

class _NewUser {
  final String fullName;
  final String email;
  final String password;
  final String role;

  const _NewUser({
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
  });
}
