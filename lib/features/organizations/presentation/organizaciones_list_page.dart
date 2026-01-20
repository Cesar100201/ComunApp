import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/repositories/organizacion_repository.dart';
import 'add_organizacion_page.dart';
import 'organizacion_profile_page.dart';

class OrganizacionesListPage extends StatefulWidget {
  const OrganizacionesListPage({super.key});

  @override
  State<OrganizacionesListPage> createState() => _OrganizacionesListPageState();
}

class _OrganizacionesListPageState extends State<OrganizacionesListPage> {
  final _repo = OrganizacionRepository();
  List<Organizacion> _organizaciones = [];
  bool _isLoading = true;
  bool _repoInicializado = false;

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
  }

  Future<void> _inicializarRepositorio() async {
    if (!mounted) return;
    setState(() {
      _repoInicializado = true;
    });
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!_repoInicializado) {
      await _inicializarRepositorio();
    }
    final datos = await _repo.obtenerTodas();
    if (!mounted) return;
    setState(() {
      _organizaciones = datos;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Organizaciones"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddOrganizacionPage()),
          );
          _cargarDatos();
        },
        label: const Text("Nueva Organización"),
        icon: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _organizaciones.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _organizaciones.length,
                  itemBuilder: (context, index) {
                    final o = _organizaciones[index];
                    return _buildOrganizacionCard(o);
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
            Icons.business_outlined,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "No hay organizaciones registradas",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizacionCard(Organizacion o) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrganizacionProfilePage(organizacion: o),
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
              Icons.business,
              color: AppColors.primary,
            ),
          ),
          title: Text(
            o.nombreLargo,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (o.abreviacion != null)
                  Text(
                    "Abrev: ${o.abreviacion}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                Text(
                  "Tipo: ${o.tipo.toString().split('.').last}",
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
                o.isSynced ? Icons.cloud_done : Icons.cloud_off,
                color: o.isSynced ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                o.isSynced ? "En Línea" : "Pendiente",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: o.isSynced ? AppColors.success : AppColors.warning,
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
