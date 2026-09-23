import 'package:flutter/material.dart';

import '../services/admin_api_repository.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final repo = AdminApiRepository();

  List<Map<String, dynamic>> users = [];
  bool loading = true;
  bool busy = false;
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

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;

    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      _message('İşlem tamamlanamadı: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _create() async {
    final result = await showDialog<_NewUser>(
      context: context,
      builder: (_) => const _NewUserDialog(),
    );
    if (result == null) return;

    await _run(() async {
      await repo.createUser(
        email: result.email,
        password: result.password,
        fullName: result.fullName,
        role: result.role,
      );
      _message('Kullanıcı oluşturuldu.');
      await _load();
    });
  }

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final current = user['role']?.toString() ?? 'viewer';

    final role = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Kullanıcı Rolü'),
        children: [
          for (final value in ['admin', 'staff', 'viewer'])
            ListTile(
              leading: Icon(
                current == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: current == value
                    ? SifaBrand.deepGold
                    : SifaBrand.textGrey,
              ),
              title: Text(
                _roleLabel(value),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () => Navigator.pop(context, value),
            ),
        ],
      ),
    );

    if (role == null || role == current) return;

    await _run(() async {
      await repo.setRole(user['id'].toString(), role);
      _message('Kullanıcı rolü güncellendi.');
      await _load();
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final currentlyActive = user['active'] == true;
    final targetActive = !currentlyActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          targetActive ? 'Hesabı Aktif Et' : 'Hesabı Pasif Yap',
        ),
        content: Text(
          targetActive
              ? 'Bu kullanıcı yeniden sisteme giriş yapabilecek.'
              : 'Bu kullanıcı pasifken sisteme giriş yapamayacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              targetActive ? 'Aktif Et' : 'Pasif Yap',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _run(() async {
      await repo.setActive(
        user['id'].toString(),
        targetActive,
      );
      _message(
        targetActive
            ? 'Kullanıcı hesabı aktif edildi.'
            : 'Kullanıcı hesabı pasif yapıldı.',
      );
      await _load();
    });
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final controller = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${user['full_name'] ?? 'Kullanıcı'} • Şifre Yenile',
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Yeni şifre',
            hintText: 'En az 8 karakter',
            prefixIcon: Icon(
              Icons.lock_reset_outlined,
              color: SifaBrand.deepGold,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Şifre en az 8 karakter olmalı.'),
                  ),
                );
                return;
              }
              Navigator.pop(context, controller.text);
            },
            child: const Text('Şifreyi Değiştir'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (password == null) return;

    await _run(() async {
      await repo.resetPassword(user['id'].toString(), password);
      _message('Kullanıcı şifresi yenilendi.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        users.where((user) => user['active'] == true).length;
    final adminCount = users
        .where((user) => user['role']?.toString() == 'admin')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kullanıcı Yönetimi',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: SifaBrand.gold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : _create,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Kullanıcı Ekle'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: SifaBrand.charcoal,
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.manage_accounts_outlined,
                          color: SifaBrand.gold,
                          size: 28,
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Erişim Yönetimi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Rolleri, erişimi ve kullanıcı hesaplarını yönet.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        Expanded(
                          child: _UserMetric(
                            label: 'Toplam',
                            value: users.length,
                            icon: Icons.people_outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _UserMetric(
                            label: 'Aktif',
                            value: activeCount,
                            icon: Icons.person_outline,
                            success: activeCount > 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _UserMetric(
                            label: 'Yönetici',
                            value: adminCount,
                            icon: Icons.admin_panel_settings_outlined,
                            emphasize: adminCount > 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (loading || busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kullanıcılar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                StatusPill(
                  label: '${users.length} hesap',
                  tone: AppStatusTone.neutral,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (!loading && users.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Text(
                    'Kullanıcı kaydı bulunamadı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              )
            else
              ...users.map(
                (user) {
                  final active = user['active'] == true;
                  final role =
                      user['role']?.toString() ?? 'viewer';
                  final fullName =
                      user['full_name']?.toString() ?? 'Kullanıcı';
                  final initial = fullName.trim().isNotEmpty
                      ? fullName.trim()[0].toUpperCase()
                      : '?';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: active
                                ? SifaBrand.goldBg
                                : SifaBrand.ivory,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active
                                  ? SifaBrand.gold.withOpacity(0.35)
                                  : SifaBrand.softGrey,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: active
                                  ? SifaBrand.deepGold
                                  : SifaBrand.textGrey,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            StatusPill(
                              label: active ? 'Aktif' : 'Pasif',
                              tone: active
                                  ? AppStatusTone.success
                                  : AppStatusTone.neutral,
                              compact: true,
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${user['email'] ?? ''} • ${_roleLabel(role)}',
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'role') {
                              await _changeRole(user);
                            } else if (action == 'toggle') {
                              await _toggleActive(user);
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
                                active
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
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static String _roleLabel(String role) => switch (role) {
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fullName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Geçici şifre',
                  hintText: 'En az 8 karakter',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.badge_outlined),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Ad soyad, e-posta ve en az 8 karakter şifre gir.',
                  ),
                ),
              );
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

class _UserMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final bool emphasize;
  final bool success;

  const _UserMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = success
        ? SifaBrand.success
        : emphasize
            ? SifaBrand.deepGold
            : SifaBrand.charcoal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: success
            ? SifaBrand.successBg
            : emphasize
                ? SifaBrand.goldBg
                : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: success
              ? SifaBrand.success.withOpacity(0.25)
              : emphasize
                  ? SifaBrand.gold.withOpacity(0.35)
                  : SifaBrand.softGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(height: 6),
          Text(
            value.toString(),
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: SifaBrand.textGrey,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
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
