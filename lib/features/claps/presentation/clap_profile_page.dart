import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/app_config.dart';
import '../../../../core/contracts/clap_repository.dart';
import '../../../../core/contracts/habitante_repository.dart';

class ClapProfilePage extends StatefulWidget {
  final Clap clap;

  const ClapProfilePage({
    super.key,
    required this.clap,
  });

  @override
  State<ClapProfilePage> createState() => _ClapProfilePageState();
}

class _ClapProfilePageState extends State<ClapProfilePage> {
  Clap? _clapCompleto;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  
  ClapRepository? _repo;
  HabitanteRepository? _habitanteRepo;
  bool _repoInicializado = false;
  
  final _formKey = GlobalKey<FormState>();
  final _nombreClapController = TextEditingController();
  final _cedulaJefeController = TextEditingController();
  
  Habitante? _jefeEncontrado;
  bool _isBuscandoJefe = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInicializado) {
      final config = AppConfigScope.of(context);
      _repo = config.clapRepository;
      _habitanteRepo = config.habitanteRepository;
      _repoInicializado = true;
      _cargarDatosCompletos();
    }
  }

  Future<void> _cargarDatosCompletos() async {
    final repo = _repo;
    if (repo == null) return;
    final clap = await repo.buscarPorId(widget.clap.id);
    
    if (clap != null) {
      await clap.jefeComunidad.load();
      
      setState(() {
        _clapCompleto = clap;
        _nombreClapController.text = clap.nombreClap;
        _jefeEncontrado = clap.jefeComunidad.value;
        if (_jefeEncontrado != null) {
          _cedulaJefeController.text = _jefeEncontrado!.cedula.toString();
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _clapCompleto = widget.clap;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nombreClapController.dispose();
    _cedulaJefeController.dispose();
    super.dispose();
  }

  Future<void> _buscarJefe() async {
    final cedulaTexto = _cedulaJefeController.text.trim();
    if (cedulaTexto.isEmpty) {
      setState(() => _jefeEncontrado = null);
      return;
    }

    final cedulaInt = int.tryParse(cedulaTexto);
    if (cedulaInt == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Cédula inválida"),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isBuscandoJefe = true);

    try {
      final habitanteRepo = _habitanteRepo;
      if (habitanteRepo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Configuración no disponible")),
          );
        }
        setState(() => _isBuscandoJefe = false);
        return;
      }
      final habitante = await habitanteRepo.getHabitanteByCedula(cedulaInt);
      setState(() {
        _jefeEncontrado = habitante;
        _isBuscandoJefe = false;
      });

      if (habitante == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No se encontró el habitante"),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      setState(() => _isBuscandoJefe = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = _repo;
    if (repo == null) return;

    setState(() => _isSaving = true);
    try {
      final clapActualizado = await repo.buscarPorId(widget.clap.id);
      
      if (clapActualizado != null) {
        clapActualizado.nombreClap = _nombreClapController.text.trim();
        clapActualizado.jefeComunidad.value = _jefeEncontrado;
        await repo.actualizarClap(clapActualizado);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ CLAP actualizado con éxito"),
              backgroundColor: AppColors.success,
            ),
          );
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
          _cargarDatosCompletos();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar: $e"),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _eliminarClap() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: const Text("¿Está seguro de que desea eliminar este CLAP?"),
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
        final repo = _repo;
        if (repo == null) return;
        
        final clap = await repo.buscarPorId(widget.clap.id);
        if (clap != null) {
          await repo.eliminarClap(clap.id);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("✅ CLAP eliminado"),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.pop(context, true);
          }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Perfil del CLAP")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final c = _clapCompleto ?? widget.clap;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil del CLAP"),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: "Editar",
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _isEditing = false);
                _cargarDatosCompletos();
              },
              tooltip: "Cancelar",
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _eliminarClap,
              tooltip: "Eliminar",
            ),
        ],
      ),
      body: _isEditing ? _buildEditView() : _buildProfileView(c),
    );
  }

  Widget _buildProfileView(Clap c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(c),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: "Información General",
            icon: Icons.info,
            children: [
              _buildInfoRow("Nombre del CLAP", c.nombreClap),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: "Jefe de Comunidad",
            icon: Icons.person,
            children: [
              if (c.jefeComunidad.value != null)
                _buildInfoRow("Nombre", c.jefeComunidad.value!.nombreCompleto)
              else
                _buildInfoRow("Jefe", "No asignado", valueColor: AppColors.textTertiary),
              if (c.jefeComunidad.value != null)
                _buildInfoRow(
                  "Cédula",
                  "${c.jefeComunidad.value!.nacionalidad.toString().split('.').last}-${c.jefeComunidad.value!.cedula}",
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: "Estado",
            icon: Icons.cloud,
            children: [
              _buildInfoRow(
                "Sincronización",
                c.isSynced ? "Sincronizado" : "Pendiente",
                valueColor: c.isSynced ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditView() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nombreClapController,
              decoration: const InputDecoration(
                labelText: "Nombre del CLAP *",
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? "Requerido" : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cedulaJefeController,
                    decoration: const InputDecoration(
                      labelText: "Cédula del Jefe de Comunidad",
                      border: OutlineInputBorder(),
                      hintText: "Ej: 12345678",
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isBuscandoJefe
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  onPressed: _isBuscandoJefe ? null : _buscarJefe,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_jefeEncontrado != null) ...[
              const SizedBox(height: 16),
              Card(
                color: AppColors.success.withValues(alpha: 0.1),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.success,
                    child: Text(
                      _jefeEncontrado!.nombreCompleto.substring(0, 1),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(_jefeEncontrado!.nombreCompleto),
                  subtitle: Text(
                    "C.I: ${_jefeEncontrado!.nacionalidad.toString().split('.').last}-${_jefeEncontrado!.cedula}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _jefeEncontrado = null;
                        _cedulaJefeController.clear();
                      });
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _guardarCambios,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("GUARDAR CAMBIOS"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Clap c) {
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
            child: const Icon(
              Icons.store,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.nombreClap,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
  }) {
    return Card(
      child: Padding(
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
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
