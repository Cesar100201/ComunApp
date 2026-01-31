import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/app_config.dart';
import '../../../../core/contracts/habitante_repository.dart';
import 'habitante_profile_page.dart';

class SearchHabitantePage extends StatefulWidget {
  const SearchHabitantePage({super.key});

  @override
  State<SearchHabitantePage> createState() => _SearchHabitantePageState();
}

class _SearchHabitantePageState extends State<SearchHabitantePage> {
  final _searchController = TextEditingController();
  HabitanteRepository? _repo;
  List<Habitante> _resultados = [];
  bool _repoInicializado = false;
  bool _buscando = false;
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInicializado) {
      _repo = AppConfigScope.of(context).habitanteRepository;
      _repoInicializado = true;
    }
  }

  Future<void> _inicializarRepositorio() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    setState(() {
      _repo = AppConfigScope.of(context).habitanteRepository;
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
        title: const Text("Buscador Inteligente"),
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
                hintText: "Cédula, Nombre o Dirección...",
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
            Icons.person_search_rounded,
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
        final h = _resultados[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: h.isSynced
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              child: Icon(
                Icons.person,
                color: h.isSynced ? AppColors.success : AppColors.warning,
              ),
            ),
            title: Text(
              h.nombreCompleto,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "C.I: ${h.cedula}${h.direccion.isNotEmpty ? ' • ${h.direccion}' : ''}",
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
                  builder: (context) => HabitanteProfilePage(habitante: h),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
