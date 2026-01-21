import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/repositories/consejo_repository.dart';
import '../../../../database/db_helper.dart';
import 'add_consejo_page.dart';
import 'consejo_comunal_profile_page.dart';

class ConsejosComunalesListPage extends StatefulWidget {
  const ConsejosComunalesListPage({super.key});

  @override
  State<ConsejosComunalesListPage> createState() => _ConsejosComunalesListPageState();
}

class _ConsejosComunalesListPageState extends State<ConsejosComunalesListPage> {
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
      return;
    }
    
    final datos = await _repo!.getAllConsejos();
    
    // Cargar relaciones (comuna) para cada consejo
    for (var consejo in datos) {
      await consejo.comuna.load();
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
                    final consejo = _consejos[index];
                    return _buildConsejoCard(consejo);
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

  Widget _buildConsejoCard(ConsejoComunal consejo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConsejoComunalProfilePage(consejo: consejo),
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
            consejo.nombreConsejo,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Código SITUR: ${consejo.codigoSitur}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                if (consejo.comuna.value != null)
                  Text(
                    "Comuna: ${consejo.comuna.value!.nombreComuna}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryUltraLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.business_center,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${consejo.cargos.length} cargo${consejo.cargos.length != 1 ? 's' : ''}",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home_work,
                            size: 12,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${consejo.comunidades.length} comunidad${consejo.comunidades.length != 1 ? 'es' : ''}",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                consejo.isSynced ? Icons.cloud_done : Icons.cloud_off,
                color: consejo.isSynced ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                consejo.isSynced ? "En Línea" : "Pendiente",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: consejo.isSynced ? AppColors.success : AppColors.warning,
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
