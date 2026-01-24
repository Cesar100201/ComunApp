import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/repositories/vinculacion_repository.dart';
import '../../../../database/db_helper.dart';
import 'habitante_profile_page.dart';

class OrganizacionMiembrosPage extends StatefulWidget {
  final Organizacion? organizacion;
  final ConsejoComunal? consejoComunal;

  const OrganizacionMiembrosPage({
    super.key,
    this.organizacion,
    this.consejoComunal,
  }) : assert(organizacion != null || consejoComunal != null,
          'Debe proporcionar una organización o un consejo comunal');

  @override
  State<OrganizacionMiembrosPage> createState() => _OrganizacionMiembrosPageState();
}

class _OrganizacionMiembrosPageState extends State<OrganizacionMiembrosPage> {
  late final VinculacionRepository _vinculacionRepo;
  List<Vinculacion> _vinculaciones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }

  Future<void> _initializeRepository() async {
    final isar = await DbHelper().db;
    _vinculacionRepo = VinculacionRepository(isar);
    _cargarMiembros();
  }

  Future<void> _cargarMiembros() async {
    setState(() => _isLoading = true);
    
    List<Vinculacion> vinculaciones;
    if (widget.organizacion != null) {
      vinculaciones = await _vinculacionRepo.getVinculacionesPorOrganizacion(widget.organizacion!.id);
    } else {
      vinculaciones = await _vinculacionRepo.getVinculacionesPorConsejoComunal(widget.consejoComunal!.id);
    }
    
    // Cargar relaciones de persona
    for (var v in vinculaciones) {
      await v.persona.load();
    }
    
    if (mounted) {
      setState(() {
        _vinculaciones = vinculaciones;
        _isLoading = false;
      });
    }
  }

  String _getNombreEntidad() {
    if (widget.organizacion != null) {
      return widget.organizacion!.nombreLargo;
    } else {
      return widget.consejoComunal!.nombreConsejo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Miembros"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vinculaciones.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Header con información de la organización
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        boxShadow: AppColors.shadowMedium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                widget.organizacion != null ? Icons.business : Icons.groups,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _getNombreEntidad(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${_vinculaciones.length} miembro${_vinculaciones.length != 1 ? 's' : ''}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Lista de miembros
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _vinculaciones.length,
                        itemBuilder: (context, index) {
                          final v = _vinculaciones[index];
                          return _buildMiembroCard(v);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "Sin miembros",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Esta ${widget.organizacion != null ? 'organización' : 'consejo comunal'} no tiene miembros registrados",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMiembroCard(Vinculacion v) {
    final habitante = v.persona.value;
    if (habitante == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HabitanteProfilePage(habitante: habitante),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryUltraLight,
                child: Text(
                  habitante.nombreCompleto.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habitante.nombreCompleto,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Cargo: ${v.cargo}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: v.activo 
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.textTertiary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            v.activo ? "Activo" : "Inactivo",
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: v.activo ? AppColors.success : AppColors.textTertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "C.I: ${habitante.nacionalidad.toString().split('.').last}-${habitante.cedula}",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
