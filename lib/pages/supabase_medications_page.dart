import 'package:flutter/material.dart';

import '../core/data/medication_repository.dart';
import '../core/widgets/app_input_decoration.dart';

class SupabaseMedicationsPage extends StatefulWidget {
  const SupabaseMedicationsPage({super.key});

  @override
  State<SupabaseMedicationsPage> createState() =>
      _SupabaseMedicationsPageState();
}

class _SupabaseMedicationsPageState extends State<SupabaseMedicationsPage> {
  final repo = MedicationRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = repo.getAll();
    // trigger rebuild
    setState(() {});
  }

  Future<void> _showEditDialog({Map<String, dynamic>? item}) async {
    final nameController = TextEditingController(text: item?['name'] ?? '');
    final brandController = TextEditingController(text: item?['brand'] ?? '');
    final stockController = TextEditingController(
      text: (item?['stock'] ?? '').toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          item == null ? 'Adicionar medicamento' : 'Editar medicamento',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: AppInputDecoration.build(ctx, labelText: 'Nome'),
            ),
            TextField(
              controller: brandController,
              decoration: AppInputDecoration.build(ctx, labelText: 'Marca'),
            ),
            TextField(
              controller: stockController,
              decoration: AppInputDecoration.build(
                ctx,
                labelText: 'Estoque (nº)',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return; // simple validation
              final brand = brandController.text.trim();
              final stock = int.tryParse(stockController.text) ?? 0;

              try {
                if (item == null) {
                  await repo.createMedication({
                    'name': name,
                    'brand': brand.isEmpty ? null : brand,
                    'stock': stock,
                    'low_stock_threshold': 0,
                  });
                } else {
                  await repo.updateMedication(item['id'] as int, {
                    'name': name,
                    'brand': brand.isEmpty ? null : brand,
                    'stock': stock,
                  });
                }
                Navigator.of(ctx).pop(true);
              } catch (e) {
                Navigator.of(ctx).pop(false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro: ${e.toString()}')),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result == true) _load();
  }

  Future<void> _deleteItem(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('Deseja remover este medicamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final success = await repo.deleteMedication(id);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Removido')));
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível remover')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicamentos (Supabase)')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        tooltip: 'Adicionar medicamento',
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
          final meds = snap.data ?? [];
          if (meds.isEmpty)
            return const Center(child: Text('Nenhum medicamento encontrado'));
          return ListView.separated(
            itemCount: meds.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = meds[i];
              return ListTile(
                title: Text(m['name'] ?? '—'),
                subtitle: Text(m['brand'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text((m['stock'] ?? 0).toString()),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteItem(m['id'] as int),
                    ),
                  ],
                ),
                onTap: () => _showEditDialog(item: m),
              );
            },
          );
        },
      ),
    );
  }
}
