import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../data/repositories/habitante_repository.dart';
import 'add_habitante_page.dart';
import 'habitante_profile_page.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';

class HabitantesListPage extends StatefulWidget {
  const HabitantesListPage({super.key});

  @override
  State<HabitantesListPage> createState() => _HabitantesListPageState();
}

class _HabitantesListPageState extends State<HabitantesListPage> {
  HabitanteRepository? _repo;
  List<Habitante> _habitantes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _repoInicializado = false;
  static const int _pageSize = 80;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(HabitantesListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recargar cuando el widget se actualiza
    if (_repoInicializado && _repo != null) {
      _cargarPrimeraPagina();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _repo == null) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _cargarMas();
    }
  }

  Future<void> _inicializarRepositorio() async {
    final isar = await DbHelper().db;
    setState(() {
      _repo = HabitanteRepository(isar);
      _repoInicializado = true;
    });
    _cargarPrimeraPagina();
  }

  /// Carga la primera página (sustituye la lista). Usar al abrir y al volver de Add/Carga masiva.
  Future<void> _cargarPrimeraPagina() async {
    if (!_repoInicializado || _repo == null) {
      await _inicializarRepositorio();
      return;
    }
    setState(() => _isLoading = true);
    final datos = await _repo!.obtenerPaginado(0, _pageSize);
    if (mounted) {
      setState(() {
        _habitantes = datos;
        _hasMore = datos.length >= _pageSize;
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarMas() async {
    if (!_hasMore || _isLoadingMore || _repo == null) return;
    setState(() => _isLoadingMore = true);
    final datos = await _repo!.obtenerPaginado(_habitantes.length, _pageSize);
    if (mounted) {
      setState(() {
        _habitantes = [..._habitantes, ...datos];
        _hasMore = datos.length >= _pageSize;
        _isLoadingMore = false;
      });
    }
  }

  // TODO: Cuando se implementen los campos 'sector' e 'isConflict' en el modelo,
  // descomentar esta función para resolver conflictos con la nube:
  /*
  void _mostrarResolutorConflictos(Habitante local) async {
    final remotoData = await _repo.buscarEnNube(local.cedula);
    if (remotoData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo conectar con la nube para comparar.")),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resolución de Conflicto"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Se encontró una versión diferente en la nube. ¿Cuál desea conservar?"),
              const SizedBox(height: 20),
              _buildConflictOption(
                "VERSIÓN LOCAL (Tuya)",
                local.nombreCompleto,
                local.sector,
                Colors.orange,
                () async {
                  final isar = await DbHelper().db;
                  await FirebaseFirestore.instance
                      .collection('habitantes')
                      .doc(local.cedula.toString())
                      .set(local.toJson());
                  
                  await isar.writeTxn(() async {
                    local.isSynced = true;
                    local.isConflict = false;
                    await isar.habitantes.put(local);
                  });
                  if (mounted) Navigator.pop(context);
                  _cargarDatos();
                },
              ),
              const Divider(height: 30),
              _buildConflictOption(
                "VERSIÓN NUBE (De otro)",
                remotoData['nombreCompleto'] ?? "Sin nombre",
                remotoData['sector'] ?? "Sin sector",
                Colors.green,
                () async {
                  final isar = await DbHelper().db;
                  await isar.writeTxn(() async {
                    local.nombreCompleto = remotoData['nombreCompleto'];
                    local.sector = remotoData['sector'];
                    local.telefono = remotoData['telefono'];
                    local.direccion = remotoData['direccion'];
                    local.isSynced = true;
                    local.isConflict = false;
                    await isar.habitantes.put(local);
                  });
                  if (mounted) Navigator.pop(context);
                  _cargarDatos();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConflictOption(
    String title,
    String nombre,
    String sector,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(10),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text("Nombre: $nombre", style: const TextStyle(fontSize: 13)),
            Text("Sector: $sector", style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            const Text("TAP PARA ELEGIR ESTA", 
                style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Padrón Municipal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _cargarPrimeraPagina();
            },
            tooltip: 'Recargar lista',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddHabitantePage()),
          );
          _cargarPrimeraPagina();
        },
        label: const Text("Nuevo Habitante"),
        icon: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _habitantes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _habitantes.length + ((_hasMore && _isLoadingMore) ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _habitantes.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final p = _habitantes[index];
                    return _buildHabitanteCard(p);
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
            Icons.folder_off_outlined,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "No hay registros locales",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitanteCard(Habitante p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HabitanteProfilePage(habitante: p),
            ),
          );
        },
        // TODO: Cuando se implemente el campo 'isConflict', descomentar:
        // onTap: () {
        //   if (p.isConflict) {
        //     _mostrarResolutorConflictos(p);
        //   } else {
        //     Navigator.push(...);
        //   }
        // },
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryUltraLight,
          // TODO: Cuando se implemente el campo 'isConflict', actualizar:
          // backgroundColor: p.isConflict ? AppColors.error.withOpacity(0.1) : AppColors.primaryUltraLight,
          child: Text(
            p.nombreCompleto.substring(0, 1),
            style: TextStyle(
              color: AppColors.primary,
              // TODO: Cuando se implemente el campo 'isConflict', actualizar:
              // color: p.isConflict ? AppColors.error : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          p.nombreCompleto,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "C.I: ${p.cedula}${p.direccion.isNotEmpty ? '\n${p.direccion}' : ''}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        // TODO: Cuando se implemente el campo 'sector', actualizar:
        // subtitle: Text("C.I: ${p.cedula}\n${p.sector}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              p.isSynced ? Icons.cloud_done : Icons.cloud_off,
              // TODO: Cuando se implemente el campo 'isConflict', actualizar:
              // p.isConflict
              //     ? Icons.warning_rounded
              //     : p.isSynced ? Icons.cloud_done : Icons.cloud_off,
              color: p.isSynced ? AppColors.success : AppColors.warning,
              size: 20,
              // TODO: Cuando se implemente el campo 'isConflict', actualizar:
              // color: p.isConflict
              //     ? AppColors.error
              //     : p.isSynced ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(height: 4),
            Text(
              p.isSynced ? "En Línea" : "Pendiente",
              // TODO: Cuando se implemente el campo 'isConflict', actualizar:
              // p.isConflict
              //     ? "CONFLICTO"
              //     : p.isSynced ? "En Línea" : "Pendiente",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: p.isSynced ? AppColors.success : AppColors.warning,
                    // TODO: Cuando se implemente el campo 'isConflict', actualizar:
                    // color: p.isConflict ? AppColors.error : (p.isSynced ? AppColors.success : AppColors.warning),
                    fontWeight: FontWeight.w500,
                    // TODO: Cuando se implemente el campo 'isConflict', actualizar:
                    // fontWeight: p.isConflict ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
