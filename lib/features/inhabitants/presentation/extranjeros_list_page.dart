import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../data/repositories/extranjero_repository.dart';
import 'add_extranjero_page.dart';
import 'extranjero_profile_page.dart';
import 'search_extranjero_page.dart';
import 'bulk_upload_extranjeros_page.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';

class ExtranjerosListPage extends StatefulWidget {
  const ExtranjerosListPage({super.key});

  @override
  State<ExtranjerosListPage> createState() => _ExtranjerosListPageState();
}

class _ExtranjerosListPageState extends State<ExtranjerosListPage> {
  ExtranjeroRepository? _repo;
  List<Extranjero> _extranjeros = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _repoInicializado = false;
  int _totalExtranjeros = 0;
  static const int _pageSize = 80;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ExtranjerosListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    try {
      final isar = await DbHelper().db;
      final repo = ExtranjeroRepository(isar);
      final total = await repo.contar();
      if (mounted) {
        setState(() {
          _repo = repo;
          _repoInicializado = true;
          _totalExtranjeros = total;
        });
        _cargarPrimeraPagina();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _repoInicializado = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar extranjeros: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _cargarPrimeraPagina() async {
    if (!_repoInicializado || _repo == null) {
      await _inicializarRepositorio();
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final datos = await _repo!.obtenerPaginado(0, _pageSize);
      final total = await _repo!.contar();
      if (mounted) {
        setState(() {
          _extranjeros = datos;
          _hasMore = datos.length >= _pageSize;
          _totalExtranjeros = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar la lista: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _cargarMas() async {
    if (!_hasMore || _isLoadingMore || _repo == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final datos = await _repo!.obtenerPaginado(
        _extranjeros.length,
        _pageSize,
      );
      if (mounted) {
        setState(() {
          _extranjeros = [..._extranjeros, ...datos];
          _hasMore = datos.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar más: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Listado de Extranjeros"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Total de Extranjeros: $_totalExtranjeros",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchExtranjeroPage()),
              );
            },
            tooltip: 'Buscar extranjero',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BulkUploadExtranjerosPage(),
                ),
              );
              if (result == true) {
                _cargarPrimeraPagina();
              }
            },
            tooltip: 'Carga Masiva',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPrimeraPagina,
            tooltip: 'Recargar lista',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExtranjeroPage()),
          );
          _cargarPrimeraPagina();
        },
        label: const Text("Nuevo Extranjero"),
        icon: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _extranjeros.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  _extranjeros.length +
                  ((_hasMore && _isLoadingMore) ? 1 : 0) +
                  1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildTotalCard();
                }
                final extranjeroIndex = index - 1;
                if (extranjeroIndex >= _extranjeros.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final e = _extranjeros[extranjeroIndex];
                return _buildExtranjeroCard(e);
              },
            ),
    );
  }

  Widget _buildTotalCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: cs.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.public, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total de Extranjeros Registrados",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _totalExtranjeros.toString(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            "No hay registros locales",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtranjeroCard(Extranjero e) {
    final ubicacion = '${e.departamento}, ${e.municipio}'.trim();
    final nombre = e.nombreCompleto.isNotEmpty
        ? e.nombreCompleto
        : 'Sin nombre';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExtranjeroProfilePage(extranjero: e),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryUltraLight,
          child: Text(
            nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          nombre,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "C.C: ${e.cedulaColombiana} • $ubicacion",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              e.isSynced ? Icons.cloud_done : Icons.cloud_off,
              color: e.isSynced ? AppColors.success : AppColors.warning,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              e.isSynced ? "En Línea" : "Pendiente",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: e.isSynced ? AppColors.success : AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
