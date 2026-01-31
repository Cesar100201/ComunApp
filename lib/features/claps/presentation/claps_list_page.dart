import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/app_config.dart';
import '../../../../core/contracts/clap_repository.dart';
import 'add_clap_page.dart';
import 'clap_profile_page.dart';

class ClapsListPage extends StatefulWidget {
  const ClapsListPage({super.key});

  @override
  State<ClapsListPage> createState() => _ClapsListPageState();
}

class _ClapsListPageState extends State<ClapsListPage> {
  ClapRepository? _repo;
  List<Clap> _claps = [];
  bool _isLoading = true;
  bool _repoInicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInicializado) {
      _repo = AppConfigScope.of(context).clapRepository;
      _repoInicializado = true;
      _cargarDatos();
    }
  }

  Future<void> _cargarDatos() async {
    final repo = _repo;
    if (repo == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final datos = await repo.obtenerTodos();
    // Cargar relaciones
    for (var c in datos) {
      await c.jefeComunidad.load();
    }
    if (!mounted) return;
    setState(() {
      _claps = datos;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CLAPs"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddClapPage()),
          );
          _cargarDatos();
        },
        label: const Text("Nuevo CLAP"),
        icon: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _claps.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _claps.length,
                  itemBuilder: (context, index) {
                    final c = _claps[index];
                    return _buildClapCard(c);
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
            Icons.store_outlined,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "No hay CLAPs registrados",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildClapCard(Clap c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClapProfilePage(clap: c),
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
              Icons.store,
              color: AppColors.primary,
            ),
          ),
          title: Text(
            c.nombreClap,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: c.jefeComunidad.value != null
                ? Text(
                    "Jefe: ${c.jefeComunidad.value!.nombreCompleto}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  )
                : Text(
                    "Sin jefe asignado",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
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
