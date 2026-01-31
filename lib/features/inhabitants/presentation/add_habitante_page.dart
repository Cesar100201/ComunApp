import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/app_config.dart';
import '../../../../core/contracts/habitante_repository.dart';
import '../../../../core/contracts/comuna_repository.dart';
import '../../../../core/contracts/consejo_repository.dart';
import '../../../../core/contracts/clap_repository.dart';
import 'package:isar/isar.dart';

class AddHabitantePage extends StatefulWidget {
  final Habitante? habitanteParaEditar;
  
  const AddHabitantePage({
    super.key,
    this.habitanteParaEditar,
  });

  @override
  State<AddHabitantePage> createState() => _AddHabitantePageState();
}

class _AddHabitantePageState extends State<AddHabitantePage> {
  final _formKey = GlobalKey<FormState>();
  HabitanteRepository? _habitanteRepo;
  ComunaRepository? _comunaRepo;
  ConsejoRepository? _consejoRepo;
  ClapRepository? _clapRepo;
  bool _repoInicializado = false;

  @override
  void initState() {
    super.initState();
    _cedulaNumeroController.addListener(_onCedulaChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInicializado) {
      final config = AppConfigScope.of(context);
      _habitanteRepo = config.habitanteRepository;
      _comunaRepo = config.comunaRepository;
      _consejoRepo = config.consejoRepository;
      _clapRepo = config.clapRepository;
      _repoInicializado = true;
      _cargarListas();
      if (widget.habitanteParaEditar != null) {
        _cargarDatosParaEditar();
      }
    }
  }

  Future<void> _cargarRepositorio() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final config = AppConfigScope.of(context);
    setState(() {
      _habitanteRepo = config.habitanteRepository;
      _comunaRepo = config.comunaRepository;
      _consejoRepo = config.consejoRepository;
      _clapRepo = config.clapRepository;
      _repoInicializado = true;
    });
  }

  Future<void> _cargarDatosParaEditar() async {
    final h = widget.habitanteParaEditar!;
    final habitanteCompleto = await _habitanteRepo?.getHabitanteByCedula(h.cedula);
    
    if (habitanteCompleto != null) {
      // Cargar relaciones
      await habitanteCompleto.consejoComunal.load();
      await habitanteCompleto.clap.load();
      await habitanteCompleto.jefeDeFamilia.load();
      
      // Cargar datos en controladores
      _cedulaNumeroController.text = habitanteCompleto.cedula.toString();
      _nombreController.text = habitanteCompleto.nombreCompleto;
      _telefonoController.text = habitanteCompleto.telefono;
      _selectedNacionalidad = habitanteCompleto.nacionalidad;
      _selectedGenero = habitanteCompleto.genero;
      _selectedFechaNacimiento = habitanteCompleto.fechaNacimiento;
      _selectedEstatusPolitico = habitanteCompleto.estatusPolitico;
      _selectedNivelVoto = habitanteCompleto.nivelVoto;
      _selectedNivelUsuario = habitanteCompleto.nivelUsuario;
      // Cargar comuna del consejo comunal
      if (habitanteCompleto.consejoComunal.value != null) {
        await habitanteCompleto.consejoComunal.value!.comuna.load();
        _selectedComuna = habitanteCompleto.consejoComunal.value!.comuna.value;
        if (_selectedComuna != null) {
          _selectedParroquia = _selectedComuna!.parroquia;
        }
      }
      _selectedConsejoComunal = habitanteCompleto.consejoComunal.value;
      _selectedClap = habitanteCompleto.clap.value;
      
      // Asegurar que las listas estén cargadas antes de filtrar
      if (_comunas.isEmpty || _consejosComunales.isEmpty) {
        await _cargarListas();
      } else {
        _filtrarLocalizaciones();
      }
      
      // Procesar dirección - parsear componentes
      final direccion = habitanteCompleto.direccion;
      if (direccion.isNotEmpty) {
        _parsearDireccion(direccion);
        
        // Intentar identificar la comunidad si hay consejo comunal seleccionado
        if (_selectedConsejoComunal != null && _selectedConsejoComunal!.comunidades.isNotEmpty) {
          for (var comunidad in _selectedConsejoComunal!.comunidades) {
            if (direccion.contains(comunidad)) {
              _selectedComunidad = comunidad;
              break;
            }
          }
        }
      }
      
      // Jefe de familia
      if (habitanteCompleto.jefeDeFamilia.value != null) {
        _esJefeDeFamilia = false;
        _jefeEncontrado = habitanteCompleto.jefeDeFamilia.value;
        _cedulaJefeController.text = _jefeEncontrado!.cedula.toString();
      } else {
        _esJefeDeFamilia = true;
      }
      
      if (mounted) setState(() {});
    }
  }

  // Control de pasos del wizard
  int _currentStep = 0;
  final int _totalSteps = 3;

  // ========== CONTROLADORES PASO 1: DATOS PERSONALES ==========
  final _cedulaNumeroController = TextEditingController();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _estadoController = TextEditingController();
  final _municipioController = TextEditingController();
  final _calleController = TextEditingController();
  final _numeroCasaController = TextEditingController();

  Nacionalidad _selectedNacionalidad = Nacionalidad.V;
  Genero _selectedGenero = Genero.Masculino;
  Parroquia _selectedParroquia = Parroquia.LaFria;
  Comuna? _selectedComuna;
  ConsejoComunal? _selectedConsejoComunal;
  String _selectedComunidad = '';
  DateTime _selectedFechaNacimiento = DateTime(1990, 1, 1);

  // ========== CONTROLADORES PASO 2: DATOS SOCIOECONÓMICOS ==========
  bool _esJefeDeFamilia = true;
  final _cedulaJefeController = TextEditingController();
  Habitante? _jefeEncontrado;
  bool _isBuscandoJefe = false;
  String? _errorBusquedaJefe;
  Clap? _selectedClap;

  // ========== CONTROLADORES PASO 3: CARACTERIZACIÓN POLÍTICA ==========
  EstatusPolitico _selectedEstatusPolitico = EstatusPolitico.Neutral;
  NivelVoto _selectedNivelVoto = NivelVoto.Blando;
  int _selectedNivelUsuario = 1; // Siempre se establece en 1 (usuario) automáticamente

  // Estados de guardado
  bool _isSaving = false;
  bool _isCheckingRemote = false;

  // Listas para selectores (se cargarán desde la BD)
  List<Comuna> _comunas = [];
  List<Comuna> _comunasFiltradas = [];
  List<ConsejoComunal> _consejosComunales = [];
  List<ConsejoComunal> _consejosComunalesFiltrados = [];
  List<Clap> _claps = [];


  Future<void> _cargarListas() async {
    if (_comunaRepo == null || _consejoRepo == null || _clapRepo == null) return;
    _comunas = await _comunaRepo!.getAllComunas();
    _consejosComunales = await _consejoRepo!.getAllConsejos();
    _claps = await _clapRepo!.obtenerTodos();
    await _filtrarLocalizaciones();
    if (mounted) setState(() {});
  }

  Future<void> _filtrarLocalizaciones() async {
    // Filtrar comunas por parroquia seleccionada
    _comunasFiltradas = _comunas.where((c) => c.parroquia == _selectedParroquia).toList();
    _comunasFiltradas.sort((a, b) => a.nombreComuna.compareTo(b.nombreComuna));
    
    // Si se cambió la parroquia, verificar si la comuna seleccionada aún es válida
    if (_selectedComuna != null && !_comunasFiltradas.contains(_selectedComuna)) {
      _selectedComuna = null;
      _selectedConsejoComunal = null;
      _selectedComunidad = '';
    }
    
    // Si se seleccionó una comuna, filtrar consejos comunales
    if (_selectedComuna != null) {
      _consejosComunalesFiltrados = [];
      // Cargar relaciones para verificar correctamente
      for (var cc in _consejosComunales) {
        await cc.comuna.load();
        if (cc.comuna.value?.id == _selectedComuna!.id) {
          _consejosComunalesFiltrados.add(cc);
        }
      }
      _consejosComunalesFiltrados.sort((a, b) => a.nombreConsejo.compareTo(b.nombreConsejo));
      
      // Si se cambió la comuna, verificar si el consejo comunal seleccionado aún es válido
      if (_selectedConsejoComunal != null) {
        await _selectedConsejoComunal!.comuna.load();
        if (_selectedConsejoComunal!.comuna.value?.id != _selectedComuna!.id) {
          _selectedConsejoComunal = null;
          _selectedComunidad = '';
        }
      }
    } else {
      _consejosComunalesFiltrados = [];
      _selectedConsejoComunal = null;
      _selectedComunidad = '';
    }
    
    if (mounted) setState(() {});
  }

  void _onCedulaChanged() {
    final texto = _cedulaNumeroController.text;
    if (texto.length >= 9) {
      if (_selectedNacionalidad != Nacionalidad.E) {
        setState(() {
          _selectedNacionalidad = Nacionalidad.E;
        });
      }
    } else if (texto.isNotEmpty && texto.length < 9) {
      if (_selectedNacionalidad != Nacionalidad.V) {
        setState(() {
          _selectedNacionalidad = Nacionalidad.V;
        });
      }
    }
  }

  @override
  void dispose() {
    _cedulaNumeroController.removeListener(_onCedulaChanged);
    _cedulaNumeroController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    _estadoController.dispose();
    _municipioController.dispose();
    _calleController.dispose();
    _numeroCasaController.dispose();
    _cedulaJefeController.dispose();
    super.dispose();
  }

  // ========== CÁLCULO DE EDAD (SOLO VISUAL) ==========
  int _calcularEdad() {
    final ahora = DateTime.now();
    int edad = ahora.year - _selectedFechaNacimiento.year;
    if (ahora.month < _selectedFechaNacimiento.month ||
        (ahora.month == _selectedFechaNacimiento.month && ahora.day < _selectedFechaNacimiento.day)) {
      edad--;
    }
    return edad;
  }

  // ========== BÚSQUEDA DE JEFE DE FAMILIA ==========
  Future<void> _buscarJefeDeFamilia() async {
    final cedulaTexto = _cedulaJefeController.text.trim();
    if (cedulaTexto.isEmpty) {
      setState(() {
        _jefeEncontrado = null;
        _errorBusquedaJefe = null;
      });
      return;
    }

    final cedulaInt = int.tryParse(cedulaTexto);
    if (cedulaInt == null) {
      setState(() {
        _jefeEncontrado = null;
        _errorBusquedaJefe = "Cédula inválida";
      });
      return;
    }

    setState(() {
      _isBuscandoJefe = true;
      _errorBusquedaJefe = null;
      _jefeEncontrado = null;
    });

    try {
      // Asegurar que el repositorio esté inicializado
      if (!_repoInicializado || _habitanteRepo == null) {
        await _cargarRepositorio();
      }
      
      // 1. Búsqueda Local
      final local = await _habitanteRepo!.getHabitanteByCedula(cedulaInt);
      if (local != null) {
        // Verificar que no sea carga familiar
        await local.jefeDeFamilia.load();
        if (local.jefeDeFamilia.value != null) {
          setState(() {
            _jefeEncontrado = null;
            _errorBusquedaJefe = "Error: Esta persona figura como carga familiar, no puede ser Jefe";
            _isBuscandoJefe = false;
          });
          return;
        }
        setState(() {
          _jefeEncontrado = local;
          _errorBusquedaJefe = null;
          _isBuscandoJefe = false;
        });
        return;
      }

      // 2. Búsqueda Remota
      try {
        if (!_repoInicializado || _habitanteRepo == null) {
          await _cargarRepositorio();
        }
        final remoto = await _habitanteRepo!.buscarEnNube(cedulaInt);
        if (remoto != null) {
          // Verificar que no sea carga familiar en la nube
          if (remoto['jefeDeFamiliaId'] != null) {
            setState(() {
              _jefeEncontrado = null;
              _errorBusquedaJefe = "Error: Esta persona figura como carga familiar, no puede ser Jefe";
              _isBuscandoJefe = false;
            });
            return;
          }
          // Verificar si el jefe está en local también
          final jefeLocal = await _habitanteRepo?.getHabitanteByCedula(cedulaInt);
          if (jefeLocal == null) {
            // Jefe está en la nube pero no en local
            setState(() {
              _jefeEncontrado = null;
              _errorBusquedaJefe = "Jefe encontrado en la nube pero no en local. Por favor, sincronice los datos primero.";
              _isBuscandoJefe = false;
            });
            return;
          }
          // Jefe está en local, usar ese
          setState(() {
            _jefeEncontrado = jefeLocal;
            _errorBusquedaJefe = null;
            _isBuscandoJefe = false;
          });
          return;
        }
      } catch (e) {
        // Sin conexión
        setState(() {
          _jefeEncontrado = null;
          _errorBusquedaJefe = "Sin conexión: No se puede verificar el jefe en la nube";
          _isBuscandoJefe = false;
        });
        return;
      }

      // No encontrado
      setState(() {
        _jefeEncontrado = null;
        _errorBusquedaJefe = "Jefe no encontrado";
        _isBuscandoJefe = false;
      });
    } catch (e) {
      setState(() {
        _jefeEncontrado = null;
        _errorBusquedaJefe = "Error al buscar: $e";
        _isBuscandoJefe = false;
      });
    }
  }

  // ========== VALIDACIÓN POR PASO ==========
  bool _validarPasoActual() {
    if (!_formKey.currentState!.validate()) return false;

    switch (_currentStep) {
      case 0: // Paso 1: Datos Personales
        if (_cedulaNumeroController.text.trim().isEmpty) return false;
        if (_nombreController.text.trim().isEmpty) return false;
        if (_telefonoController.text.trim().isEmpty) return false;
        if (_estadoController.text.trim().isEmpty) return false;
        if (_municipioController.text.trim().isEmpty) return false;
        if (_calleController.text.trim().isEmpty) return false;
        if (_numeroCasaController.text.trim().isEmpty) return false;
        return true;

      case 1: // Paso 2: Datos Socioeconómicos
        if (!_esJefeDeFamilia) {
          if (_cedulaJefeController.text.trim().isEmpty) return false;
          if (_jefeEncontrado == null) return false;
        }
        return true;

      case 2: // Paso 3: Caracterización Política
        return true; // Todos los campos son opcionales o tienen defaults

      default:
        return false;
    }
  }

  // ========== NAVEGACIÓN DEL WIZARD ==========
  void _siguientePaso() {
    if (_validarPasoActual()) {
      setState(() {
        if (_currentStep < _totalSteps - 1) {
          _currentStep++;
        }
      });
    }
  }

  void _pasoAnterior() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  // ========== PARSING DE DIRECCIÓN ==========
  void _parsearDireccion(String direccion) {
    // La dirección tiene formato: Estado, Municipio, Parroquia, Comuna, Consejo, Comunidad, Calle X, Casa Y
    final partes = direccion.split(',').map((e) => e.trim()).toList();
    
    for (var i = 0; i < partes.length; i++) {
      final parte = partes[i];
      
      // Buscar "Calle"
      if (parte.toLowerCase().startsWith('calle ')) {
        _calleController.text = parte.substring(6).trim();
      }
      // Buscar "Casa"
      else if (parte.toLowerCase().startsWith('casa ')) {
        _numeroCasaController.text = parte.substring(5).trim();
      }
      // Primer elemento puede ser estado
      else if (i == 0 && !parte.toLowerCase().contains('calle') && !parte.toLowerCase().contains('casa')) {
        _estadoController.text = parte;
      }
      // Segundo elemento puede ser municipio
      else if (i == 1 && !parte.toLowerCase().contains('calle') && !parte.toLowerCase().contains('casa')) {
        _municipioController.text = parte;
      }
      // Los elementos intermedios podrían ser parroquia, comuna, consejo, comunidad
      // pero esos ya se cargan de las relaciones, así que los omitimos
    }
  }

  // ========== CONCATENACIÓN DE DIRECCIÓN ==========
  String _construirDireccion() {
    final partes = <String>[];
    if (_estadoController.text.trim().isNotEmpty) partes.add(_estadoController.text.trim());
    if (_municipioController.text.trim().isNotEmpty) partes.add(_municipioController.text.trim());
    partes.add(_selectedParroquia.toString().split('.').last);
    if (_selectedComuna != null) partes.add(_selectedComuna!.nombreComuna);
    if (_selectedConsejoComunal != null) partes.add(_selectedConsejoComunal!.nombreConsejo);
    if (_selectedComunidad.isNotEmpty) partes.add(_selectedComunidad);
    if (_calleController.text.trim().isNotEmpty) partes.add("Calle ${_calleController.text.trim()}");
    if (_numeroCasaController.text.trim().isNotEmpty) partes.add("Casa ${_numeroCasaController.text.trim()}");

    return partes.join(", ");
  }

  // ========== GUARDADO ==========
  Future<void> _guardar() async {
    if (!_validarPasoActual()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Por favor complete todos los campos requeridos"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final cedulaTexto = _cedulaNumeroController.text.trim();
    final cedulaInt = int.tryParse(cedulaTexto);

    if (cedulaInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("La cédula debe ser un número válido"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Si estamos editando, procesar directamente sin verificar duplicados
    if (widget.habitanteParaEditar != null) {
      _procesarGuardado(habitanteParaActualizar: widget.habitanteParaEditar);
      return;
    }

    // Asegurar que el repositorio esté inicializado
    if (!_repoInicializado || _habitanteRepo == null) {
      await _cargarRepositorio();
    }

    // 1. Verificación Local
    final local = await _habitanteRepo!.getHabitanteByCedula(cedulaInt);
    if (local != null) {
      _mostrarDialogoConflicto(
        nombre: local.nombreCompleto,
        origen: "este teléfono",
        onConfirm: () => _procesarGuardado(habitanteParaActualizar: local),
      );
      return;
    }

    // 2. Verificación Remota
    setState(() => _isCheckingRemote = true);
    final remoto = await _habitanteRepo!.buscarEnNube(cedulaInt);
    setState(() => _isCheckingRemote = false);

    if (remoto != null) {
      _mostrarDialogoConflicto(
        nombre: remoto['nombreCompleto'] ?? "Sin Nombre",
        origen: "la base de datos central (Nube)",
        esRemoto: true,
        onConfirm: () => _procesarGuardado(),
      );
      return;
    }

    // 3. Si no existe, guardamos normal
    _procesarGuardado();
  }

  Future<void> _procesarGuardado({Habitante? habitanteParaActualizar}) async {
    setState(() => _isSaving = true);
    try {
      final h = habitanteParaActualizar ?? Habitante();

      final cedulaTexto = _cedulaNumeroController.text.trim();
      final cedulaInt = int.tryParse(cedulaTexto);
      if (cedulaInt == null) {
        throw Exception("Cédula inválida");
      }

      h.nombreCompleto = _nombreController.text.trim().toUpperCase();
      h.cedula = cedulaInt;
      h.nacionalidad = _selectedNacionalidad;
      h.telefono = _telefonoController.text.trim();
      h.genero = _selectedGenero;
      h.fechaNacimiento = _selectedFechaNacimiento;
      h.direccion = _construirDireccion();
      h.estatusPolitico = _selectedEstatusPolitico;
      h.nivelVoto = _selectedNivelVoto;
      h.nivelUsuario = _selectedNivelUsuario;
      h.fotoUrl = null;
      h.isSynced = false;

      // Relaciones
      if (_selectedConsejoComunal != null) {
        h.consejoComunal.value = _selectedConsejoComunal;
      }
      if (_selectedClap != null) {
        h.clap.value = _selectedClap;
      }

      // Lógica de Jefe de Familia
      if (_esJefeDeFamilia) {
        // Se asigna a sí mismo (o se deja vacío, según la lógica del modelo)
        h.jefeDeFamilia.value = null; // El modelo asume que si está vacío, es su propio jefe
      } else {
        // Asignar el jefe encontrado
        if (_jefeEncontrado != null) {
          final jefeCompleto = await _habitanteRepo?.getHabitanteByCedula(_jefeEncontrado!.cedula);
          if (jefeCompleto != null) {
            h.jefeDeFamilia.value = jefeCompleto;
          } else {
            // Si el jefe está en la nube pero no en local, no podemos crear el link
            // El usuario debe sincronizar primero o registrar el jefe localmente
            throw Exception("El jefe de familia debe estar registrado localmente. Por favor, sincronice los datos primero.");
          }
        }
      }

      // Si estamos editando, usar actualizarHabitante y marcar como pendiente
      if (habitanteParaActualizar != null) {
        h.isSynced = false; // Marcar como pendiente para sincronizar cambios
        await _habitanteRepo!.actualizarHabitante(h);
      } else {
        await _habitanteRepo!.guardarHabitante(h);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            habitanteParaActualizar == null
                ? "✅ Registrado con éxito"
                : "✅ Datos actualizados correctamente",
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
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

  void _mostrarDialogoConflicto({
    required String nombre,
    required String origen,
    required VoidCallback onConfirm,
    bool esRemoto = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: esRemoto ? AppColors.error : AppColors.warning,
            ),
            const SizedBox(width: 10),
            const Text("Registro Duplicado"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Esta cédula ya existe en $origen."),
            const SizedBox(height: 15),
            Text("Nombre: $nombre", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text("¿Desea sobrescribir los datos anteriores con la información nueva?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: esRemoto ? AppColors.error : AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(esRemoto ? "SOBRESCRIBIR EN NUBE" : "ACTUALIZAR LOCAL"),
          ),
        ],
      ),
    );
  }

  // ========== WIDGETS DE CONSTRUCCIÓN ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.habitanteParaEditar != null
              ? "Editar Habitante - Paso ${_currentStep + 1}/$_totalSteps"
              : "Nuevo Habitante - Paso ${_currentStep + 1}/$_totalSteps",
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Indicador de progreso
            _buildProgressIndicator(),
            
            // Contenido del paso actual
            Expanded(
              child: Container(
                color: AppColors.background,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildStepContent(),
                ),
              ),
            ),

            // Botones de navegación
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppColors.shadowSmall,
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index <= _currentStep;
              final isCurrent = index == _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : AppColors.border,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: isCurrent ? AppColors.shadowSmall : null,
                        ),
                      ),
                    ),
                    if (index < _totalSteps - 1) const SizedBox(width: 8),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_totalSteps, (index) {
              final isActive = index <= _currentStep;
              final labels = ["Datos Personales", "Socioeconómicos", "Políticos"];
              return Expanded(
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isActive ? AppColors.primary : AppColors.textTertiary,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPaso1DatosPersonales();
      case 1:
        return _buildPaso2DatosSocioeconomicos();
      case 2:
        return _buildPaso3CaracterizacionPolitica();
      default:
        return const SizedBox();
    }
  }

  // ========== PASO 1: DATOS PERSONALES ==========
  Widget _buildPaso1DatosPersonales() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Datos Personales",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Información básica del habitante",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Cédula (Composite Field)
        _buildCedulaCompositeField(),
        const SizedBox(height: 15),

        // Nombre Completo
        _buildInput("Nombre Completo", Icons.person, _nombreController),
        const SizedBox(height: 15),

        // Fila: Teléfono y Género
        Row(
          children: [
            Expanded(
              child: _buildInput("Teléfono", Icons.phone, _telefonoController, isNumber: true),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGeneroSelector(),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // Fila: Fecha de Nacimiento y Edad
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildDatePicker(),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.surfaceVariant,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Edad",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_calcularEdad()} años",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Dirección Jerárquica
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryUltraLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    "Ubicación",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                "Complete la información de ubicación en orden",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),
              
              _buildInput("Estado", Icons.public, _estadoController),
              const SizedBox(height: 16),

              _buildInput("Municipio", Icons.location_city, _municipioController),
              const SizedBox(height: 16),

              _buildDropdown<Parroquia>(
                "Parroquia",
                Icons.place,
                Parroquia.values,
                _selectedParroquia,
                (Parroquia? newValue) async {
                  setState(() {
                    _selectedParroquia = newValue!;
                    _selectedComuna = null;
                    _selectedConsejoComunal = null;
                    _selectedComunidad = '';
                  });
                  await _filtrarLocalizaciones();
                },
              ),
              const SizedBox(height: 16),

              if (_comunasFiltradas.isNotEmpty)
                _buildDropdown<Comuna?>(
                  "Comuna",
                  Icons.domain,
                  [null, ..._comunasFiltradas],
                  _selectedComuna,
                  (Comuna? newValue) async {
                    setState(() {
                      _selectedComuna = newValue;
                      _selectedConsejoComunal = null;
                      _selectedComunidad = '';
                    });
                    await _filtrarLocalizaciones();
                  },
                  itemToString: (Comuna? value) => value?.nombreComuna ?? "Seleccione una comuna...",
                ),
              if (_comunasFiltradas.isNotEmpty) const SizedBox(height: 16),

              if (_comunasFiltradas.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "No hay comunas disponibles para esta parroquia",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.warning,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_selectedComuna != null) ...[
                if (_consejosComunalesFiltrados.isNotEmpty)
                  _buildDropdown<ConsejoComunal?>(
                    "Consejo Comunal",
                    Icons.group,
                    [null, ..._consejosComunalesFiltrados],
                    _selectedConsejoComunal,
                    (ConsejoComunal? newValue) {
                      setState(() {
                        _selectedConsejoComunal = newValue;
                        _selectedComunidad = '';
                      });
                    },
                    itemToString: (ConsejoComunal? value) => value?.nombreConsejo ?? "Seleccione un consejo comunal...",
                  ),
                if (_consejosComunalesFiltrados.isNotEmpty) const SizedBox(height: 16),

                if (_consejosComunalesFiltrados.isEmpty && _selectedComuna != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "No hay consejos comunales disponibles para esta comuna",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.warning,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              if (_selectedConsejoComunal != null && _selectedConsejoComunal!.comunidades.isNotEmpty) ...[
                _buildDropdown<String>(
                  "Comunidad",
                  Icons.home_work,
                  ['', ..._selectedConsejoComunal!.comunidades],
                  _selectedComunidad,
                  (String? newValue) {
                    setState(() {
                      _selectedComunidad = newValue ?? '';
                    });
                  },
                  itemToString: (String value) => value.isEmpty ? "Seleccione una comunidad..." : value,
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Calle y Número de Casa
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.home, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Dirección Específica",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildInput("Calle", Icons.streetview, _calleController),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildInput("N° Casa", Icons.home, _numeroCasaController, isNumber: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCedulaCompositeField() {
    return Row(
      children: [
        // Selector de Prefijo
        Container(
          width: 80,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            color: AppColors.surfaceVariant,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Nacionalidad>(
              value: _selectedNacionalidad,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: [
                const DropdownMenuItem(value: Nacionalidad.V, child: Text("V")),
                const DropdownMenuItem(value: Nacionalidad.E, child: Text("E")),
              ],
              onChanged: (Nacionalidad? value) {
                setState(() {
                  _selectedNacionalidad = value!;
                });
              },
            ),
          ),
        ),
        // Input Numérico
        Expanded(
          child: TextFormField(
            controller: _cedulaNumeroController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Campo requerido";
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: "Cédula de Identidad",
              prefixIcon: const Icon(Icons.badge),
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneroSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surfaceVariant,
      ),
      child: Row(
        children: [
          Expanded(
            child: RadioListTile<Genero>(
              title: const Text("M"),
              value: Genero.Masculino,
              groupValue: _selectedGenero,
              onChanged: (Genero? value) {
                setState(() {
                  _selectedGenero = value!;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          Expanded(
            child: RadioListTile<Genero>(
              title: const Text("F"),
              value: Genero.Femenino,
              groupValue: _selectedGenero,
              onChanged: (Genero? value) {
                setState(() {
                  _selectedGenero = value!;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: "${_selectedFechaNacimiento.day.toString().padLeft(2, '0')}/${_selectedFechaNacimiento.month.toString().padLeft(2, '0')}/${_selectedFechaNacimiento.year}",
      ),
      validator: (value) => null, // La fecha siempre tiene un valor por defecto
      decoration: const InputDecoration(
        labelText: "Fecha de Nacimiento",
        prefixIcon: Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedFechaNacimiento,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null && picked != _selectedFechaNacimiento) {
          setState(() {
            _selectedFechaNacimiento = picked;
          });
        }
      },
    );
  }

  // ========== PASO 2: DATOS SOCIOECONÓMICOS ==========
  Widget _buildPaso2DatosSocioeconomicos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.family_restroom, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Datos Socioeconómicos",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Información familiar y organizacional",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Rol Familiar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Rol Familiar",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _esJefeDeFamilia = true;
                          _cedulaJefeController.clear();
                          _jefeEncontrado = null;
                          _errorBusquedaJefe = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _esJefeDeFamilia ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _esJefeDeFamilia ? AppColors.primary : AppColors.border,
                            width: _esJefeDeFamilia ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<bool>(
                              value: true,
                              groupValue: _esJefeDeFamilia,
                              onChanged: (bool? value) {
                                setState(() {
                                  _esJefeDeFamilia = value!;
                                  _cedulaJefeController.clear();
                                  _jefeEncontrado = null;
                                  _errorBusquedaJefe = null;
                                });
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Jefe de Familia",
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Persona autónoma",
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _esJefeDeFamilia = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: !_esJefeDeFamilia ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: !_esJefeDeFamilia ? AppColors.primary : AppColors.border,
                            width: !_esJefeDeFamilia ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<bool>(
                              value: false,
                              groupValue: _esJefeDeFamilia,
                              onChanged: (bool? value) {
                                setState(() {
                                  _esJefeDeFamilia = value!;
                                });
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Carga Familiar",
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Dependiente",
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Campo de Cédula del Jefe (solo si es Carga Familiar)
        if (!_esJefeDeFamilia) ...[
          TextFormField(
            controller: _cedulaJefeController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "Cédula del Jefe de Familia",
              prefixIcon: const Icon(Icons.person_search),
              suffixIcon: _isBuscandoJefe
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _buscarJefeDeFamilia,
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (!_esJefeDeFamilia && (value == null || value.isEmpty)) {
                return "Campo requerido";
              }
              return null;
            },
            onChanged: (value) {
              // Búsqueda automática después de un delay
              Future.delayed(const Duration(milliseconds: 800), () {
                if (_cedulaJefeController.text == value && value.isNotEmpty) {
                  _buscarJefeDeFamilia();
                }
              });
            },
          ),
          const SizedBox(height: 10),

          // Resultado de búsqueda
          if (_jefeEncontrado != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _jefeEncontrado!.nombreCompleto,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Cédula: ${_jefeEncontrado!.cedula}",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_errorBusquedaJefe != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorBusquedaJefe!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],

        // CLAP
        _buildDropdown<Clap?>(
          "CLAP",
          Icons.store,
          [null, ..._claps],
          _selectedClap,
          (Clap? newValue) {
            setState(() {
              _selectedClap = newValue;
            });
          },
          itemToString: (Clap? value) => value?.nombreClap ?? "Seleccione...",
        ),
      ],
    );
  }

  // ========== PASO 3: CARACTERIZACIÓN POLÍTICA ==========
  Widget _buildPaso3CaracterizacionPolitica() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.how_to_vote, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Caracterización Política",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Clasificación y nivel de participación",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildDropdown<EstatusPolitico>(
          "Estatus Político",
          Icons.how_to_vote,
          EstatusPolitico.values,
          _selectedEstatusPolitico,
          (EstatusPolitico? newValue) {
            setState(() {
              _selectedEstatusPolitico = newValue!;
            });
          },
        ),
        const SizedBox(height: 15),

        _buildDropdown<NivelVoto>(
          "Nivel de Voto",
          Icons.bar_chart,
          NivelVoto.values,
          _selectedNivelVoto,
          (NivelVoto? newValue) {
            setState(() {
              _selectedNivelVoto = newValue!;
            });
          },
        ),
      ],
    );
  }

  // ========== BOTONES DE NAVEGACIÓN ==========
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppColors.shadowMedium,
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pasoAnterior,
                icon: const Icon(Icons.arrow_back),
                label: const Text("ANTERIOR"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 15),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: ElevatedButton.icon(
              onPressed: (_isSaving || _isCheckingRemote) ? null : (_currentStep < _totalSteps - 1 ? _siguientePaso : _guardar),
              icon: (_isSaving || _isCheckingRemote)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(_currentStep < _totalSteps - 1 ? Icons.arrow_forward : Icons.save),
              label: Text(
                (_isSaving || _isCheckingRemote)
                    ? "GUARDANDO..."
                    : (_currentStep < _totalSteps - 1 ? "SIGUIENTE" : "GUARDAR DATOS"),
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== WIDGETS AUXILIARES ==========
  Widget _buildInput(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      validator: (value) => value == null || value.isEmpty ? "Campo requerido" : null,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    IconData icon,
    List<T> items,
    T selectedValue,
    void Function(T?) onChanged, {
    String Function(T)? itemToString,
  }) {
    return DropdownButtonFormField<T>(
      value: selectedValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      style: Theme.of(context).textTheme.bodyLarge,
      dropdownColor: AppColors.surface,
      items: items.map((T value) {
        return DropdownMenuItem<T>(
          value: value,
          child: Text(
            itemToString != null ? itemToString(value) : value.toString().split('.').last,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
