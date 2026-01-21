import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/repositories/consejo_repository.dart';
import 'consejo_profile_page.dart';
import '../../../../database/db_helper.dart';

class SearchConsejoPage extends StatefulWidget {
  const SearchConsejoPage({super.key});

  @override
  State<SearchConsejoPage> createState() => _SearchConsejoPageState();
}

class _SearchConsejoPageState extends State<SearchConsejoPage> {
  final _searchController = TextEditingController();
  ConsejoRepository? _repo;
  List<ConsejoComunal> _resultados = [];
  bool _repoInicializado = false;
  bool _buscando = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
  }

  Future<void> _inicializarRepositorio() async {
    final isar = await DbHelper().db;
    if (!mounted) return;
    setState(() {
      _repo = ConsejoRepository(isar);
      _repoInicializado = true;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _ejecutarBusqueda(String valor) {
    _debounce?.cancel();
    final query = valor.trim();
    if (query.isEmpty) {
      setState(() {
        _resultados = [];
        _buscando = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _buscarEnRepo(query));
  }

  Future<void> _buscarEnRepo(String query) async {
    if (!_repoInicializado || _repo == null) {
      await _inicializarRepositorio();
    }
    if (!mounted) return;
    setState(() => _buscando = true);
    final list = await _repo!.buscarPorTexto(query, limit: 50);
    for (final consejo in list) {
      await consejo.comuna.load();
    }
    if (mounted) {
      setState(() {
        _resultados = list;
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buscador de Consejos"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _ejecutarBusqueda,
              decoration: InputDecoration(
                hintText: "Nombre, Comuna, Código SITUR o Parroquia...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _ejecutarBusqueda("");
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (_buscando)
            const LinearProgressIndicator(),
          Expanded(
            child: _buscando && _resultados.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _resultados.isEmpty && _searchController.text.isNotEmpty
                    ? _buildNoResults()
                    : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "No se encontraron coincidencias",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _resultados.length,
      itemBuilder: (context, index) {
        final c = _resultados[index];
        final comuna = c.comuna.value;
        final parroquia = comuna?.parroquia.toString().split('.').last;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: c.isSynced
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              child: Icon(
                Icons.groups,
                color: c.isSynced ? AppColors.success : AppColors.warning,
              ),
            ),
            title: Text(
              c.nombreConsejo,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "SITUR: ${c.codigoSitur}"
                "${comuna != null ? ' • ${comuna.nombreComuna}' : ''}"
                "${parroquia != null ? ' • $parroquia' : ''}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConsejoProfilePage(consejo: c),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
