import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/consejo_repository.dart';
import 'add_consejo_page.dart';
import 'bulk_upload_consejos_page.dart';
import 'consejo_profile_page.dart';
import 'search_consejo_page.dart';

class ConsejosListPage extends StatefulWidget {
  const ConsejosListPage({super.key});

  @override
  State<ConsejosListPage> createState() => _ConsejosListPageState();
}

class _ConsejosListPageState extends State<ConsejosListPage> {
  ConsejoRepository? _repo;
  List<ConsejoComunal> _consejos = [];
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
      _repo = ConsejoRepository(isar);
      _repoInicializado = true;
    });
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!_repoInicializado || _repo == null) {
      await _inicializarRepositorio();
    }
    final datos = await _repo!.getAllConsejosComunales();
    // Cargar relaciones
    for (var c in datos) {
      await c.comuna.load();
    }
    if (!mounted) return;
    setState(() {
      _consejos = datos;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Consejos Comunales"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Buscar consejos",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchConsejoPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: "Carga masiva",
            onPressed: () async {
              final resultado = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BulkUploadConsejosPage()),
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
            MaterialPageRoute(builder: (context) => const AddConsejoPage()),
          );
          _cargarDatos();
        },
        label: const Text("Nuevo Consejo"),
        icon: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _consejos.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _consejos.length,
                  itemBuilder: (context, index) {
                    final c = _consejos[index];
                    return _buildConsejoCard(c);
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
            Icons.groups_outlined,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "No hay consejos comunales registrados",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsejoCard(ConsejoComunal c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConsejoProfilePage(consejo: c),
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
              Icons.groups,
              color: AppColors.primary,
            ),
          ),
          title: Text(
            c.nombreConsejo,
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
                if (c.comuna.value != null)
                  Text(
                    "Comuna: ${c.comuna.value!.nombreComuna}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                if (c.comunidades.isNotEmpty)
                  Text(
                    "${c.comunidades.length} comunidad(es)",
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
