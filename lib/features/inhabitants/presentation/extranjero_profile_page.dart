import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/user_role_service.dart';
import '../data/repositories/extranjero_repository.dart';
import '../../../../database/db_helper.dart';

class ExtranjeroProfilePage extends StatefulWidget {
  final Extranjero extranjero;

  const ExtranjeroProfilePage({super.key, required this.extranjero});

  @override
  State<ExtranjeroProfilePage> createState() => _ExtranjeroProfilePageState();
}

class _ExtranjeroProfilePageState extends State<ExtranjeroProfilePage> {
  ExtranjeroRepository? _repo;
  bool _repoInicializado = false;
  bool _canDelete = false;
  final UserRoleService _roleService = UserRoleService();

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
    _roleService.getNivelUsuario().then((n) {
      if (mounted) setState(() => _canDelete = _roleService.canDelete(n));
    });
  }

  Future<void> _inicializarRepositorio() async {
    final isar = await DbHelper().db;
    setState(() {
      _repo = ExtranjeroRepository(isar);
      _repoInicializado = true;
    });
  }

  Future<void> _eliminarExtranjero() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar eliminación"),
        content: const Text(
          "¿Está seguro de que desea eliminar este registro de extranjero?",
        ),
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
        await _repo!.eliminarExtranjero(widget.extranjero.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Extranjero eliminado"),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "—" : value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editarDatosPersonales() {
    final e = widget.extranjero;
    final nombreCtrl = TextEditingController(text: e.nombreCompleto);
    final ccCtrl = TextEditingController(text: e.cedulaColombiana.toString());
    final telCtrl = TextEditingController(text: e.telefono);
    bool esNac = e.esNacionalizado;
    final cvCtrl = TextEditingController(
      text: e.cedulaVenezolana?.toString() ?? '',
    );
    final dirCtrl = TextEditingController(text: e.direccion ?? '');
    final emailCtrl = TextEditingController(text: e.email ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text("Editar Datos Personales"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: "Nombre Completo",
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ccCtrl,
                  decoration: const InputDecoration(
                    labelText: "Cédula Colombiana",
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: telCtrl,
                  decoration: const InputDecoration(labelText: "Teléfono"),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text("¿Es Nacionalizado?"),
                  value: esNac,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setStateDialog(() => esNac = v),
                ),
                if (esNac) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: cvCtrl,
                    decoration: const InputDecoration(
                      labelText: "Cédula Venezolana",
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: dirCtrl,
                  decoration: const InputDecoration(labelText: "Dirección"),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: "Correo Electrónico",
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                final cc = int.tryParse(ccCtrl.text.trim());
                if (nombreCtrl.text.trim().isEmpty || cc == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Nombre y Cédula Colombiana son obligatorios",
                      ),
                    ),
                  );
                  return;
                }
                e.nombreCompleto = nombreCtrl.text.trim().toUpperCase();
                e.cedulaColombiana = cc;
                e.telefono = telCtrl.text.trim();
                e.esNacionalizado = esNac;
                e.cedulaVenezolana = esNac
                    ? int.tryParse(cvCtrl.text.trim())
                    : null;
                e.direccion = dirCtrl.text.trim();
                e.email = emailCtrl.text.trim();
                e.isSynced = false;

                if (_repo != null) await _repo!.guardarExtranjero(e);

                if (mounted) {
                  setState(() {});
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Datos actualizados exitosamente"),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  void _editarUbicacion() {
    final e = widget.extranjero;
    final dptoCtrl = TextEditingController(text: e.departamento);
    final mcpioCtrl = TextEditingController(text: e.municipio);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Ubicación"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dptoCtrl,
              decoration: const InputDecoration(labelText: "Departamento"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mcpioCtrl,
              decoration: const InputDecoration(labelText: "Municipio"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              e.departamento = dptoCtrl.text.trim().toUpperCase();
              e.municipio = mcpioCtrl.text.trim().toUpperCase();
              e.isSynced = false;

              if (_repo != null) await _repo!.guardarExtranjero(e);

              if (mounted) {
                setState(() {});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Ubicación actualizada exitosamente"),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _editarSisben() {
    final e = widget.extranjero;
    bool poseeSisben =
        e.nivelSisben != null &&
        e.nivelSisben!.isNotEmpty &&
        e.nivelSisben!.toUpperCase() != 'NO POSEE';
    final sisbenCtrl = TextEditingController(
      text: poseeSisben ? e.nivelSisben : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text("Información del Sisbén"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text("Posee Sisbén"),
                value: poseeSisben,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  setStateDialog(() => poseeSisben = v);
                },
              ),
              if (poseeSisben) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: sisbenCtrl,
                  decoration: const InputDecoration(
                    labelText: "Clasificación Sisbén",
                    hintText: "Ej. A1, B4, C12",
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (poseeSisben) {
                  if (sisbenCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Indique la clasificación del Sisbén"),
                      ),
                    );
                    return;
                  }
                  e.nivelSisben = sisbenCtrl.text.trim().toUpperCase();
                } else {
                  e.nivelSisben = null;
                }

                e.isSynced = false;
                if (_repo != null) await _repo!.guardarExtranjero(e);

                if (mounted) {
                  setState(() {});
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Sisbén actualizado exitosamente"),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (onEdit != null)
                      Icon(
                        Icons.edit,
                        size: 20,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.extranjero;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil del Extranjero"),
        actions: [
          if (_canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _eliminarExtranjero,
              tooltip: "Eliminar",
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryUltraLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      e.nombreCompleto.isNotEmpty
                          ? e.nombreCompleto.substring(0, 1).toUpperCase()
                          : "?",
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.nombreCompleto,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "C.C ${e.cedulaColombiana} • ${e.departamento}, ${e.municipio}",
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Datos personales
            _buildSection(
              context,
              title: "Datos personales",
              icon: Icons.person,
              onEdit: _editarDatosPersonales,
              children: [
                _buildInfoRow("Nombre completo", e.nombreCompleto),
                _buildInfoRow(
                  "Cédula colombiana",
                  e.cedulaColombiana.toString(),
                ),
                _buildInfoRow("Teléfono", e.telefono),
                _buildInfoRow(
                  "¿Nacionalizado?",
                  e.esNacionalizado ? "Sí" : "No",
                ),
                if (e.esNacionalizado && e.cedulaVenezolana != null)
                  _buildInfoRow(
                    "Cédula venezolana",
                    e.cedulaVenezolana.toString(),
                  ),
                if (e.direccion != null && e.direccion!.isNotEmpty)
                  _buildInfoRow("Dirección", e.direccion!),
                if (e.email != null && e.email!.isNotEmpty)
                  _buildInfoRow("Correo electrónico", e.email!),
              ],
            ),
            const SizedBox(height: 16),

            // Ubicación
            _buildSection(
              context,
              title: "Ubicación en Colombia",
              icon: Icons.location_on,
              onEdit: _editarUbicacion,
              children: [
                _buildInfoRow("Departamento", e.departamento),
                _buildInfoRow("Municipio", e.municipio),
              ],
            ),
            const SizedBox(height: 16),

            // Sisbén
            _buildSection(
              context,
              title: "Programa Sisbén",
              icon: Icons.health_and_safety,
              onEdit: _editarSisben,
              children: [
                _buildInfoRow(
                  "Afiliado al Sisbén",
                  (e.nivelSisben != null &&
                          e.nivelSisben!.isNotEmpty &&
                          e.nivelSisben!.toUpperCase() != 'NO POSEE')
                      ? "Sí"
                      : "No posee",
                ),
                if (e.nivelSisben != null &&
                    e.nivelSisben!.isNotEmpty &&
                    e.nivelSisben!.toUpperCase() != 'NO POSEE')
                  _buildInfoRow("Clasificación", e.nivelSisben!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
