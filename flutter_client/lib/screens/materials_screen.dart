import 'package:flutter/material.dart';
import '../data/seed_products.dart';
import '../models/models.dart';
import '../widgets/sifa_brand.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  String query = '';
  ProductCategory? selectedCategory;

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((p) {
      final q = query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.category.label.toLowerCase().contains(q);
      final matchesCategory =
          selectedCategory == null || p.category == selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Malzemeler',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: SifaBrand.charcoal,
                  ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Malzemede ara',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('Tümü'),
                  selected: selectedCategory == null,
                  onSelected: (_) => setState(() => selectedCategory = null),
                ),
              ),
              ...ProductCategory.values.map(
                (c) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(c.label),
                    selected: selectedCategory == c,
                    onSelected: (_) => setState(() => selectedCategory = c),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final p = filtered[index];
              return Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: SifaBrand.ivory,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: SifaBrand.softGrey),
                    ),
                    alignment: Alignment.center,
                    child: const SifaBuildingMark(size: 26),
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${p.category.label} • ${p.unit.label} • ${p.tradeMode.label}',
                  ),
                  trailing: const Chip(label: Text('Stok bilinmiyor')),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
