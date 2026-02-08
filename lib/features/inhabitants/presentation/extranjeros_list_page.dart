import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../data/repositories/extranjero_repository.dart';
import 'add_extranjero_page.dart';
import 'extranjero_profile_page.dart';
import 'search_extranjero_page.dart';
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
    final isar = await DbHelper().db;
    final repo = ExtranjeroRepository(isar);
    final total = await repo.contar();
    setState(() {
      _repo = repo;
      _repoInicializado = true;
      _totalExtranjeros = total;
    });
    _cargarPrimeraPagina();
  }

  Future<void> _cargarPrimeraPagina() async {
    if (!_repoInicializado || _repo == null) {
      await _inicializarRepositorio();
      return;
    }
    setState(() => _isLoading = true);
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
  }

  Future<void> _cargarMas() async {
    if (!_hasMore || _isLoadingMore || _repo == null) return;
    setState(() => _isLoadingMore = true);
    final datos = await _repo!.obtenerPaginado(_extranjeros.length, _pageSize);
    if (mounted) {
      setState(() {
        _extranjeros = [..._extranjeros, ...datos];
        _hasMore = datos.length >= _pageSize;
        _isLoadingMore = false;
      });
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
                    color: Colors.white.withOpacity(0.9),
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
                  itemCount: _extranjeros.length + ((_hasMore && _isLoadingMore) ? 1 : 0) + 1,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.primary.withOpacity(0.1),
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
                          color: AppColors.textSecondary,
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

  Widget _buildExtranjeroCard(Extranjero e) {
    final ubicacion = '${e.departamento}, ${e.municipio}';
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryUltraLight,
          child: Text(
            e.nombreCompleto.isNotEmpty ? e.nombreCompleto.substring(0, 1) : '?',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          e.nombreCompleto,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "C.C: ${e.cedulaColombiana} • $ubicacion",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
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
