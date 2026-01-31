import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/app_config.dart';
import '../../../../core/contracts/habitante_repository.dart';
import '../../../../core/contracts/vinculacion_repository.dart';
import 'edit_habitante_info_personal_page.dart';
import 'edit_habitante_direccion_page.dart';
import 'edit_habitante_caracterizacion_page.dart';
import 'edit_habitante_nucleo_familiar_page.dart';
import 'habitante_vinculaciones_page.dart';

class HabitanteProfilePage extends StatefulWidget {
  final Habitante habitante;

  const HabitanteProfilePage({
    super.key,
    required this.habitante,
  });

  @override
  State<HabitanteProfilePage> createState() => _HabitanteProfilePageState();
}

class _HabitanteProfilePageState extends State<HabitanteProfilePage> {
  Habitante? _habitanteCompleto;
  bool _isLoading = true;
  HabitanteRepository? _repo;
  VinculacionRepository? _vinculacionRepo;
  bool _repoInicializado = false;
  List<Vinculacion> _vinculaciones = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInicializado) {
      final config = AppConfigScope.of(context);
      _repo = config.habitanteRepository;
      _vinculacionRepo = config.vinculacionRepository;
      _repoInicializado = true;
      _cargarDatosCompletos();
    }
  }

  Future<void> _inicializarRepositorio() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final config = AppConfigScope.of(context);
    setState(() {
      _repo = config.habitanteRepository;
      _vinculacionRepo = config.vinculacionRepository;
      _repoInicializado = true;
    });
  }

  Future<void> _cargarDatosCompletos() async {
    if (!_repoInicializado || _repo == null || _vinculacionRepo == null) return;
    final habitante = await _repo!.getHabitanteByCedula(widget.habitante.cedula);

    if (habitante != null) {
      try {
        await habitante.consejoComunal.load();
        await habitante.clap.load();
        await habitante.jefeDeFamilia.load();
      } catch (_) {}
      final vinculaciones = await _vinculacionRepo!.getVinculacionesPorHabitante(habitante.id);

      if (mounted) {
        setState(() {
          _habitanteCompleto = habitante;
          _vinculaciones = vinculaciones;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _habitanteCompleto = widget.habitante;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _eliminarHabitante() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: const Text("¿Está seguro de que desea eliminar este habitante?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      try {
        if (!_repoInicializado || _repo == null) {
          await _inicializarRepositorio();
        }
        await _repo!.eliminarHabitante(widget.habitante.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Habitante eliminado"),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error al eliminar: $e"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  int _calcularEdad() {
    if (_habitanteCompleto == null) return 0;
    final ahora = DateTime.now();
    int edad = ahora.year - _habitanteCompleto!.fechaNacimiento.year;
    if (ahora.month < _habitanteCompleto!.fechaNacimiento.month ||
        (ahora.month == _habitanteCompleto!.fechaNacimiento.month &&
         ahora.day < _habitanteCompleto!.fechaNacimiento.day)) {
      edad--;
    }
    return edad;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Perfil")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final h = _habitanteCompleto ?? widget.habitante;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil del Habitante"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _eliminarHabitante,
            tooltip: "Eliminar",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con foto/avatar
            _buildHeader(h),
            const SizedBox(height: 24),

            // Información Personal
            _buildSection(
              context,
              title: "Información Personal",
              icon: Icons.person,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditHabitanteInfoPersonalPage(habitante: h),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: [
                _buildInfoRow("Nombre Completo", h.nombreCompleto),
                _buildInfoRow(
                  "Cédula de Identidad",
                  "${h.nacionalidad.toString().split('.').last}-${h.cedula}",
                ),
                _buildInfoRow("Teléfono", h.telefono),
                _buildInfoRow(
                  "Género",
                  h.genero.toString().split('.').last,
                ),
                _buildInfoRow(
                  "Fecha de Nacimiento",
                  "${h.fechaNacimiento.day.toString().padLeft(2, '0')}/${h.fechaNacimiento.month.toString().padLeft(2, '0')}/${h.fechaNacimiento.year}",
                ),
                _buildInfoRow("Edad", "${_calcularEdad()} años"),
              ],
            ),
            const SizedBox(height: 16),

            // Dirección
            _buildSection(
              context,
              title: "Dirección",
              icon: Icons.home,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditHabitanteDireccionPage(habitante: h),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: [
                _buildInfoRow("Dirección Completa", h.direccion),
                if (h.consejoComunal.value != null)
                  _buildInfoRow(
                    "Consejo Comunal",
                    h.consejoComunal.value!.nombreConsejo,
                  ),
                if (h.clap.value != null)
                  _buildInfoRow("CLAP", h.clap.value!.nombreClap),
              ],
            ),
            const SizedBox(height: 16),

            // Caracterización Política
            _buildSection(
              context,
              title: "Caracterización Política",
              icon: Icons.how_to_vote,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditHabitanteCaracterizacionPage(habitante: h),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: [
                _buildInfoRow(
                  "Estatus Político",
                  h.estatusPolitico.toString().split('.').last,
                ),
                _buildInfoRow(
                  "Nivel de Voto",
                  h.nivelVoto.toString().split('.').last,
                ),
                _buildInfoRow("Nivel de Usuario", "${h.nivelUsuario}"),
              ],
            ),
            const SizedBox(height: 16),

            // Núcleo Familiar
            _buildSection(
              context,
              title: "Núcleo Familiar",
              icon: Icons.family_restroom,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditHabitanteNucleoFamiliarPage(habitante: h),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: [
                if (h.jefeDeFamilia.value == null)
                  _buildInfoRow("Rol", "Jefe de Familia")
                else
                  _buildInfoRow(
                    "Jefe de Familia",
                    h.jefeDeFamilia.value!.nombreCompleto,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Vinculaciones
            _buildSection(
              context,
              title: "Vinculaciones",
              icon: Icons.group_work,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HabitanteVinculacionesPage(habitante: h),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: _vinculaciones.isEmpty
                  ? [
                      _buildInfoRow(
                        "Organizaciones vinculadas",
                        "Sin vinculaciones",
                        valueColor: AppColors.textSecondary,
                      ),
                    ]
                  : _vinculaciones.map((vinculacion) {
                      final organizacion = vinculacion.organizacion.value;
                      final nombreOrganizacion = organizacion?.nombreLargo ?? 
                          organizacion?.abreviacion ?? 
                          "Organización desconocida";
                      final cargo = vinculacion.cargo;
                      final activo = vinculacion.activo;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: activo 
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.textTertiary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                activo ? "Activo" : "Inactivo",
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: activo ? AppColors.success : AppColors.textTertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombreOrganizacion,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Cargo: $cargo",
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
            ),
            const SizedBox(height: 16),

            // Estado de Sincronización
            _buildSection(
              context,
              title: "Estado",
              icon: Icons.cloud,
              children: [
                _buildInfoRow(
                  "Sincronización",
                  h.isSynced ? "Sincronizado" : "Pendiente",
                  valueColor: h.isSynced ? AppColors.success : AppColors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Habitante h) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadowMedium,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            child: Text(
              h.nombreCompleto.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.nombreCompleto,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "C.I: ${h.nacionalidad.toString().split('.').last}-${h.cedula}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    VoidCallback? onEdit,
  }) {
    Widget cardContent = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryUltraLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (onEdit != null)
                Icon(
                  Icons.edit,
                  color: AppColors.primary,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );

    // Si hay onEdit, hacer toda la tarjeta presionable
    if (onEdit != null) {
      return Card(
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: cardContent,
        ),
      );
    } else {
      return Card(
        child: cardContent,
      );
    }
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
