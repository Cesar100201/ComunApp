import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/models.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/extranjero_repository.dart';
import '../../../../core/theme/app_theme.dart';

/// Departamentos y municipios de Colombia embebidos en código (sin base de datos).
/// Si se selecciona un departamento, el desplegable de municipios solo muestra los de ese departamento.
class _DepartamentosColombia {
  static const Map<String, List<String>> datos = {
    'Norte de Santander': [
      'Ábrego',
      'Arboledas',
      'Bochalema',
      'Bucarasica',
      'Cáchira',
      'Cácota',
      'Chinácota',
      'Chitagá',
      'Convención',
      'Cúcuta',
      'Cucutilla',
      'Duranía',
      'El Carmen',
      'El Tarra',
      'El Zulia',
      'Gramalote',
      'Hacarí',
      'Herrán',
      'La Esperanza',
      'La Playa de Belén',
      'Labateca',
      'Los Patios',
      'Lourdes',
      'Mutiscua',
      'Ocaña',
      'Pamplona',
      'Pamplonita',
      'Puerto Santander',
      'Ragonvalia',
      'Salazar de las Palmas',
      'San Calixto',
      'San Cayetano',
      'Santa Isabel',
      'Santiago',
      'Sardinata',
      'Silos',
      'Teorama',
      'Tibú',
      'Toledo',
      'Villa Caro',
      'Villa del Rosario',
    ],
    'Cundinamarca': [
      'Agua de Dios',
      'Albán',
      'Anapoima',
      'Anolaima',
      'Apulo',
      'Arbeláez',
      'Bogotá D.C.',
      'Bojacá',
      'Cabrera',
      'Cachipay',
      'Cajicá',
      'Caparrapí',
      'Cáqueza',
      'Carmen de Carupa',
      'Chaguaní',
      'Chía',
      'Chipaque',
      'Choachí',
      'Chocontá',
      'Cogua',
      'Cota',
      'Cucunubá',
      'El Colegio',
      'El Peñón',
      'El Rosal',
      'Facatativá',
      'Fómeque',
      'Fosca',
      'Funza',
      'Fúquene',
      'Fusagasugá',
      'Gachalá',
      'Gachancipá',
      'Gachetá',
      'Gama',
      'Girardot',
      'Granada',
      'Guachetá',
      'Guaduas',
      'Guasca',
      'Guataquí',
      'Guatavita',
      'Guayabal de Siquima',
      'Gutiérrez',
      'Jerusalén',
      'Junín',
      'La Calera',
      'La Mesa',
      'La Palma',
      'La Peña',
      'La Vega',
      'Lenguazaque',
      'Machetá',
      'Madrid',
      'Manta',
      'Medina',
      'Mosquera',
      'Nariño',
      'Nemocón',
      'Nilo',
      'Nimaima',
      'Nocaima',
      'Pacho',
      'Paime',
      'Pandi',
      'Paratebueno',
      'Pasca',
      'Puerto Salgar',
      'Pulí',
      'Quebradanegra',
      'Quetame',
      'Quipile',
      'Ricaurte',
      'San Antonio del Tequendama',
      'San Bernardo',
      'San Cayetano',
      'San Francisco',
      'Sesquilé',
      'Sibaté',
      'Silvania',
      'Simijaca',
      'Soacha',
      'Sopó',
      'Subachoque',
      'Suesca',
      'Supatá',
      'Susa',
      'Sutatausa',
      'Tabio',
      'Tausa',
      'Tena',
      'Tenjo',
      'Tibacuy',
      'Tibirita',
      'Tocaima',
      'Tocancipá',
      'Topaipí',
      'Ubalá',
      'Ubaque',
      'Une',
      'Útica',
      'Venecia',
      'Vergara',
      'Vianí',
      'Villagómez',
      'Villapinzón',
      'Villeta',
      'Viotá',
      'Yacopí',
      'Zipacón',
      'Zipaquirá',
    ],
    'Antioquia': [
      'Abejorral',
      'Abriaquí',
      'Alejandría',
      'Amagá',
      'Amalfi',
      'Andes',
      'Angelópolis',
      'Angostura',
      'Anorí',
      'Anzá',
      'Apartadó',
      'Arboletes',
      'Argelia',
      'Armenia',
      'Barbosa',
      'Bello',
      'Belmira',
      'Betania',
      'Betulia',
      'Briceño',
      'Buriticá',
      'Cáceres',
      'Caicedo',
      'Caldas',
      'Campamento',
      'Cañasgordas',
      'Caracolí',
      'Caramanta',
      'Carepa',
      'Carolina del Príncipe',
      'Caucasia',
      'Chigorodó',
      'Cisneros',
      'Ciudad Bolívar',
      'Cocorná',
      'Concepción',
      'Concordia',
      'Copacabana',
      'Dabeiba',
      'Don Matías',
      'Ebéjico',
      'El Bagre',
      'El Carmen de Viboral',
      'El Santuario',
      'Entrerríos',
      'Envigado',
      'Fredonia',
      'Giraldo',
      'Girardota',
      'Gómez Plata',
      'Granada',
      'Guadalupe',
      'Guarne',
      'Guatapé',
      'Heliconia',
      'Hispania',
      'Itagüí',
      'Ituango',
      'Jardín',
      'Jericó',
      'La Ceja',
      'La Estrella',
      'La Pintada',
      'La Unión',
      'Liborina',
      'Maceo',
      'Marinilla',
      'Medellín',
      'Montebello',
      'Murindó',
      'Mutatá',
      'Nariño',
      'Nechí',
      'Necoclí',
      'Olaya',
      'Peñol',
      'Peque',
      'Puerto Berrío',
      'Puerto Nare',
      'Puerto Triunfo',
      'Remedios',
      'Retiro',
      'Rionegro',
      'Sabanalarga',
      'Sabaneta',
      'Salgar',
      'San Andrés de Cuerquía',
      'San Carlos',
      'San Francisco',
      'San Jerónimo',
      'San José de La Montaña',
      'San Juan de Urabá',
      'San Luis',
      'San Pedro',
      'San Pedro de Urabá',
      'San Rafael',
      'San Roque',
      'San Vicente',
      'Santa Bárbara',
      'Santa Rosa de Osos',
      'Santo Domingo',
      'Santuario',
      'Segovia',
      'Sonsón',
      'Sopetrán',
      'Támesis',
      'Tarazá',
      'Tarso',
      'Titiribí',
      'Toledo',
      'Turbo',
      'Uramita',
      'Urrao',
      'Valdivia',
      'Valparaíso',
      'Vegachí',
      'Venecia',
      'Vigía del Fuerte',
      'Yalí',
      'Yarumal',
      'Yolombó',
      'Yondó',
      'Zaragoza',
    ],
  };

  static List<String> get departamentos => datos.keys.toList()..sort();
  static List<String> municipiosDe(String departamento) {
    final list = datos[departamento];
    if (list == null) return [];
    return List<String>.from(list)..sort();
  }
}

class AddExtranjeroPage extends StatefulWidget {
  const AddExtranjeroPage({super.key});

  @override
  State<AddExtranjeroPage> createState() => _AddExtranjeroPageState();
}

class _AddExtranjeroPageState extends State<AddExtranjeroPage> {
  final _formKey = GlobalKey<FormState>();
  ExtranjeroRepository? _repo;
  bool _repoInicializado = false;

  final _nombreController = TextEditingController();
  final _cedulaColombianaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _emailController = TextEditingController();
  final _cedulaVenezolanaController = TextEditingController();
  final _nivelSisbenController = TextEditingController();

  String? _selectedDepartamento;
  String? _selectedMunicipio;
  bool _esNacionalizado = false;
  bool _poseeSisben = false;
  bool _isSaving = false;

  List<String> get _municipiosFiltrados {
    if (_selectedDepartamento == null) return [];
    return _DepartamentosColombia.municipiosDe(_selectedDepartamento!);
  }

  @override
  void initState() {
    super.initState();
    _cargarRepositorio();
  }

  Future<void> _cargarRepositorio() async {
    final isar = await DbHelper().db;
    if (!mounted) return;
    setState(() {
      _repo = ExtranjeroRepository(isar);
      _repoInicializado = true;
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaColombianaController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _emailController.dispose();
    _cedulaVenezolanaController.dispose();
    _nivelSisbenController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDepartamento == null || _selectedDepartamento!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un departamento'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (_selectedMunicipio == null || _selectedMunicipio!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un municipio'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_esNacionalizado && (_cedulaVenezolanaController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si es nacionalizado debe indicar la cédula venezolana',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final cedulaColombiana = int.tryParse(
      _cedulaColombianaController.text.trim(),
    );
    if (cedulaColombiana == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cédula colombiana debe ser un número válido'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_repoInicializado || _repo == null) await _cargarRepositorio();
    final existente = await _repo!.getByCedulaColombiana(cedulaColombiana);
    if (existente != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ya existe un extranjero registrado con esta cédula colombiana',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final e = Extranjero()
        ..nombreCompleto = _nombreController.text.trim().toUpperCase()
        ..cedulaColombiana = cedulaColombiana
        ..telefono = _telefonoController.text.trim()
        ..direccion = _direccionController.text.trim().isEmpty
            ? null
            : _direccionController.text.trim()
        ..email = _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim()
        ..esNacionalizado = _esNacionalizado
        ..cedulaVenezolana = _esNacionalizado
            ? int.tryParse(_cedulaVenezolanaController.text.trim())
            : null
        ..departamento = _selectedDepartamento!
        ..municipio = _selectedMunicipio!
        ..nivelSisben = _poseeSisben
            ? _nivelSisbenController.text.trim().toUpperCase()
            : null
        ..isSynced = false
        ..isDeleted = false;

      await _repo!.guardarExtranjero(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extranjero registrado con éxito'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $err'),
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
      appBar: AppBar(title: const Text('Registro de Extranjeros')),
      body: Form(
        key: _formKey,
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildInput(
                'Nombre completo',
                Icons.person,
                _nombreController,
                required: true,
              ),
              const SizedBox(height: 16),
              _buildInput(
                'Cédula colombiana',
                Icons.badge,
                _cedulaColombianaController,
                required: true,
                isNumber: true,
              ),
              const SizedBox(height: 16),
              _buildInput(
                'Teléfono',
                Icons.phone,
                _telefonoController,
                required: true,
                isNumber: true,
              ),
              const SizedBox(height: 16),
              _buildInput(
                'Dirección (opcional)',
                Icons.location_on,
                _direccionController,
                required: false,
              ),
              const SizedBox(height: 16),
              _buildInput(
                'Correo electrónico (opcional)',
                Icons.email,
                _emailController,
                required: false,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              _buildDepartamentoDropdown(),
              const SizedBox(height: 16),
              _buildMunicipioDropdown(),
              const SizedBox(height: 24),
              _buildNacionalizadoSection(),
              const SizedBox(height: 24),
              _buildSisbenSection(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _guardar,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar registro',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppColors.primaryUltraLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              (isDark
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.primaryLight)
                  .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_add,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Datos del extranjero',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Departamento y municipio según ubicación en Colombia',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    String label,
    IconData icon,
    TextEditingController controller, {
    required bool required,
    bool isNumber = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
          keyboardType ??
          (isNumber ? TextInputType.number : TextInputType.text),
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      textCapitalization: TextCapitalization.words,
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Campo requerido';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDepartamentoDropdown() {
    final departamentos = _DepartamentosColombia.departamentos;
    return DropdownButtonFormField<String>(
      initialValue: _selectedDepartamento,
      decoration: InputDecoration(
        labelText: 'Departamento',
        prefixIcon: const Icon(Icons.map, color: AppColors.primary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Seleccione departamento...'),
        ),
        ...departamentos.map(
          (d) => DropdownMenuItem<String>(value: d, child: Text(d)),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedDepartamento = value;
          _selectedMunicipio = null;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) return 'Seleccione un departamento';
        return null;
      },
    );
  }

  Widget _buildMunicipioDropdown() {
    final municipios = _municipiosFiltrados;
    return DropdownButtonFormField<String>(
      initialValue: _selectedMunicipio,
      decoration: InputDecoration(
        labelText: 'Municipio',
        prefixIcon: const Icon(Icons.location_city, color: AppColors.primary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Seleccione municipio...'),
        ),
        ...municipios.map(
          (m) => DropdownMenuItem<String>(value: m, child: Text(m)),
        ),
      ],
      onChanged: _selectedDepartamento != null
          ? (value) {
              setState(() {
                _selectedMunicipio = value;
              });
            }
          : null,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Seleccione un municipio';
        return null;
      },
    );
  }

  Widget _buildNacionalizadoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '¿Es nacionalizado?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RadioGroup<bool>(
            groupValue: _esNacionalizado,
            onChanged: (v) {
              if (v != null) {
                setState(() => _esNacionalizado = v);
              }
            },
            child: Column(
              children: [
                const RadioListTile<bool>(title: Text('Sí'), value: true),
                const RadioListTile<bool>(title: Text('No'), value: false),
              ],
            ),
          ),
          if (_esNacionalizado) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _cedulaVenezolanaController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _esNacionalizado
                  ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Indique la cédula venezolana';
                      }
                      return null;
                    }
                  : null,
              decoration: InputDecoration(
                labelText: 'Cédula venezolana',
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.primary,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSisbenSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.health_and_safety,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Programa Sisbén',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RadioGroup<bool>(
            groupValue: _poseeSisben,
            onChanged: (v) {
              if (v != null) {
                setState(() => _poseeSisben = v);
              }
            },
            child: Column(
              children: [
                const RadioListTile<bool>(title: Text('Sí'), value: true),
                const RadioListTile<bool>(
                  title: Text('No posee'),
                  value: false,
                ),
              ],
            ),
          ),
          if (_poseeSisben) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _nivelSisbenController,
              keyboardType: TextInputType.text,
              validator: _poseeSisben
                  ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Indique la clasificación del Sisbén';
                      }
                      return null;
                    }
                  : null,
              decoration: InputDecoration(
                labelText: 'Clasificación Sisbén',
                hintText: 'Ej. B4, A1, C10',
                prefixIcon: const Icon(
                  Icons.assignment_ind,
                  color: AppColors.primary,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
