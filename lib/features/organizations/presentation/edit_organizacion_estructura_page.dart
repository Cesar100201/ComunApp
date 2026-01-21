import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';

class EditOrganizacionEstructuraPage extends StatefulWidget {
  final Organizacion organizacion;

  const EditOrganizacionEstructuraPage({
    super.key,
    required this.organizacion,
  });

  @override
  State<EditOrganizacionEstructuraPage> createState() => _EditOrganizacionEstructuraPageState();
}

class _EditOrganizacionEstructuraPageState extends State<EditOrganizacionEstructuraPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cargoController;
  
  List<Cargo> _cargos = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _cargoController = TextEditingController();
    _cargos = List<Cargo>.from(widget.organizacion.cargos);
  }

  @override
  void dispose() {
    _cargoController.dispose();
    super.dispose();
  }

  void _agregarCargo(bool esUnico) {
    final nombreCargo = _cargoController.text.trim();
    if (nombreCargo.isEmpty) return;
    
    if (_cargos.any((c) => c.nombreCargo.toLowerCase() == nombreCargo.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Este cargo ya existe"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    
    setState(() {
      _cargos.add(Cargo()
        ..nombreCargo = nombreCargo
        ..esUnico = esUnico);
      _cargoController.clear();
    });
  }

  void _eliminarCargo(int index) {
    setState(() {
      _cargos.removeAt(index);
    });
  }

  Future<void> _mostrarDialogoAgregarCargo() async {
    final nombreCargo = _cargoController.text.trim();
    if (nombreCargo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Escriba el nombre del cargo primero"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final esUnico = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tipo de Cargo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("¿Cuántas personas pueden ocupar el cargo \"$nombreCargo\"?"),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.person, color: AppColors.warning),
              title: const Text("Cargo Único"),
              subtitle: const Text("Solo una persona puede ocuparlo"),
              onTap: () => Navigator.pop(context, true),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.warning),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.groups, color: AppColors.info),
              title: const Text("Cargo Múltiple"),
              subtitle: const Text("Varias personas pueden ocuparlo"),
              onTap: () => Navigator.pop(context, false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.info),
              ),
            ),
          ],
        ),
      ),
    );

    if (esUnico != null) {
      _agregarCargo(esUnico);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final isar = await DbHelper().db;
      
      await isar.writeTxn(() async {
        final org = await isar.organizacions.get(widget.organizacion.id);
        
        if (org != null) {
          org.cargos = _cargos.map((cargo) {
            return Cargo()
              ..nombreCargo = cargo.nombreCargo
              ..esUnico = cargo.esUnico;
          }).toList();
          org.isSynced = false;
          
          await isar.organizacions.put(org);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("✅ Cargos actualizados"),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Estructura Organizativa"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Gestión de Cargos",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "Define los cargos de la estructura organizativa.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cargoController,
                      decoration: const InputDecoration(
                        labelText: "Nombre del Cargo",
                        prefixIcon: Icon(Icons.work),
                        hintText: "Ej: Presidente, Secretario, etc.",
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _mostrarDialogoAgregarCargo,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Agregar"),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_cargos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textTertiary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.business_center_outlined,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No hay cargos definidos",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Agrega cargos para definir la estructura organizativa",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cargos.length,
                  itemBuilder: (context, index) {
                    final cargo = _cargos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (cargo.esUnico ? AppColors.warning : AppColors.info).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            cargo.esUnico ? Icons.person : Icons.groups,
                            color: cargo.esUnico ? AppColors.warning : AppColors.info,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          cargo.nombreCargo,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        subtitle: Text(
                          cargo.esUnico ? "Cargo Único" : "Cargo Múltiple",
                          style: TextStyle(
                            color: cargo.esUnico ? AppColors.warning : AppColors.info,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: AppColors.error),
                          onPressed: () => _eliminarCargo(index),
                          tooltip: "Eliminar cargo",
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "🟡 Cargo Único: solo una persona puede ocuparlo\n🔵 Cargo Múltiple: varias personas pueden ocuparlo",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardar,
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
      ),
    );
  }
}
