import 'package:flutter/material.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/repositories/comuna_repository.dart';
import 'add_comuna_page.dart';
import 'bulk_upload_comunas_page.dart';
import 'comuna_profile_page.dart';

class ComunasListPage extends StatefulWidget {
  const ComunasListPage({super.key});

  @override
  State<ComunasListPage> createState() => _ComunasListPageState();
}

class _ComunasListPageState extends State<ComunasListPage> {
  ComunaRepository? _repo;
  List<Comuna> _comunas = [];
  bool _isLoading = true;
  bool _repoInicializado = false;

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
  }

  Future<void> _inicializarRepositorio() async {
    final isar = await DbHelper().db;
    if (!mounted) return;
    setState(() {
      _repo = ComunaRepository(isar);
      _repoInicializado = true;
    });
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!_repoInicializado || _repo == null) {
      await _inicializarRepositorio();
    }
    final datos = await _repo!.getAllComunas();
    if (!mounted) return;
    setState(() {
      _comunas = datos;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Comunas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: "Carga masiva",
            onPressed: () async {
              final resultado = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BulkUploadComunasPage()),
              );
              if (resultado == true) {
                _cargarDatos();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddComunaPage()),
          );
          _cargarDatos();
        },
        label: const Text("Nueva Comuna"),
        icon: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _comunas.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _comunas.length,
                  itemBuilder: (context, index) {
                    final c = _comunas[index];
                    return _buildComunaCard(c);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_city_outlined,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "No hay comunas registradas",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildComunaCard(Comuna c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComunaProfilePage(comuna: c),
            ),
          );
          if (result == true) {
            _cargarDatos();
          }
        },
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryUltraLight,
            child: Icon(
              Icons.location_city,
              color: AppColors.primary,
            ),
          ),
          title: Text(
            c.nombreComuna,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Código SITUR: ${c.codigoSitur}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                Text(
                  "${c.municipio}, ${c.parroquia.toString().split('.').last}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                c.isSynced ? Icons.cloud_done : Icons.cloud_off,
                color: c.isSynced ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                c.isSynced ? "En Línea" : "Pendiente",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: c.isSynced ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
