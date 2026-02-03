import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/comuna_repository.dart';
import 'comuna_profile_page.dart';
import '../../consejos/presentation/consejo_comunal_profile_page.dart';

/// Página que muestra los consejos comunales de una comuna y permite
/// seleccionar uno para ver sus datos.
class ComunaConsejosPage extends StatefulWidget {
  final Comuna comuna;

  const ComunaConsejosPage({
    super.key,
    required this.comuna,
  });

  @override
  State<ComunaConsejosPage> createState() => _ComunaConsejosPageState();
}

class _ComunaConsejosPageState extends State<ComunaConsejosPage> {
  ComunaRepository? _repo;
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
      _repo = ComunaRepository(isar);
      _repoInicializado = true;
    });
    _cargarConsejos();
  }

  Future<void> _cargarConsejos() async {
    if (!_repoInicializado || _repo == null) {
      await _inicializarRepositorio();
      return;
    }
    final consejos = await _repo!.getConsejosComunalesByComunaId(widget.comuna.id);
    if (!mounted) return;
    setState(() {
      _consejos = consejos;
      _isLoading = false;
    });
  }

  Future<void> _irADatosComuna() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComunaProfilePage(comuna: widget.comuna),
      ),
    );
    if (result == true && mounted) {
      _cargarConsejos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Consejos comunales"),
            Text(
              widget.comuna.nombreComuna,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.normal,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: "Ver datos de la comuna",
            onPressed: _irADatosComuna,
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              "No hay consejos comunales en esta comuna",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _irADatosComuna,
              icon: const Icon(Icons.location_city),
              label: const Text("Ver datos de la comuna"),
            ),
          ],
        ),
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
          if (result == true && mounted) {
            _cargarConsejos();
          }
        },
        borderRadius: BorderRadius.circular(12),
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
            child: Text(
              "Código SITUR: ${consejo.codigoSitur}",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
