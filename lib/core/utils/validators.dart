/// Utilidades de validación para la aplicación.
/// 
/// Provee validadores reutilizables para campos comunes como
/// cédulas, teléfonos, fechas, emails, etc.
class Validators {
  // ============================================================================
  // CÉDULA
  // ============================================================================

  /// Valida que la cédula sea un número válido venezolano.
  /// 
  /// Reglas:
  /// - Solo números
  /// - Entre 6 y 9 dígitos
  /// - No puede empezar con 0
  /// 
  /// Retorna mensaje de error o null si es válida.
  static String? validarCedula(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La cédula es requerida';
    }

    final cedula = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cedula.isEmpty) {
      return 'La cédula debe contener solo números';
    }

    if (cedula.length < 6 || cedula.length > 9) {
      return 'La cédula debe tener entre 6 y 9 dígitos';
    }

    if (cedula.startsWith('0')) {
      return 'La cédula no puede empezar con 0';
    }

    final numero = int.tryParse(cedula);
    if (numero == null || numero <= 0) {
      return 'Cédula inválida';
    }

    return null;
  }

  /// Extrae el número de cédula limpio de un string.
  static int? parseCedula(String? value) {
    if (value == null) return null;
    final cedula = value.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cedula);
  }

  // ============================================================================
  // TELÉFONO
  // ============================================================================

  /// Valida un número de teléfono venezolano.
  /// 
  /// Formatos aceptados:
  /// - 04XX-XXXXXXX
  /// - 04XXXXXXXXX
  /// - +58 4XX XXXXXXX
  /// 
  /// Retorna mensaje de error o null si es válido.
  static String? validarTelefono(String? value, {bool requerido = false}) {
    if (value == null || value.trim().isEmpty) {
      return requerido ? 'El teléfono es requerido' : null;
    }

    final telefono = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (telefono.isEmpty) {
      return requerido ? 'El teléfono es requerido' : null;
    }

    // Teléfono venezolano: 11 dígitos con código de país o 10-11 sin código
    if (telefono.length < 10 || telefono.length > 12) {
      return 'El teléfono debe tener entre 10 y 12 dígitos';
    }

    // Validar prefijo de operadora venezolana si empieza con 04
    if (telefono.startsWith('04')) {
      final prefijos = ['0412', '0414', '0416', '0424', '0426'];
      final prefijo = telefono.substring(0, 4);
      if (!prefijos.contains(prefijo)) {
        return 'Prefijo de operadora inválido ($prefijo)';
      }
    }

    return null;
  }

  /// Formatea un número de teléfono al formato estándar (04XX-XXXXXXX).
  static String formatearTelefono(String? value) {
    if (value == null || value.isEmpty) return '';
    
    final telefono = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (telefono.length == 11 && telefono.startsWith('04')) {
      return '${telefono.substring(0, 4)}-${telefono.substring(4)}';
    }
    
    if (telefono.length == 12 && telefono.startsWith('58')) {
      return '0${telefono.substring(2, 5)}-${telefono.substring(5)}';
    }
    
    return telefono;
  }

  // ============================================================================
  // FECHA DE NACIMIENTO
  // ============================================================================

  /// Valida una fecha de nacimiento.
  /// 
  /// Reglas:
  /// - No puede ser futura
  /// - No puede ser anterior a 1900
  /// - La persona debe tener entre 0 y 120 años
  /// 
  /// Retorna mensaje de error o null si es válida.
  static String? validarFechaNacimiento(DateTime? fecha, {bool requerido = false}) {
    if (fecha == null) {
      return requerido ? 'La fecha de nacimiento es requerida' : null;
    }

    final ahora = DateTime.now();
    
    if (fecha.isAfter(ahora)) {
      return 'La fecha de nacimiento no puede ser futura';
    }

    final fechaMinima = DateTime(1900, 1, 1);
    if (fecha.isBefore(fechaMinima)) {
      return 'La fecha de nacimiento no puede ser anterior a 1900';
    }

    final edad = _calcularEdad(fecha);
    if (edad < 0) {
      return 'Fecha de nacimiento inválida';
    }
    
    if (edad > 120) {
      return 'La edad no puede superar los 120 años';
    }

    return null;
  }

  /// Calcula la edad a partir de una fecha de nacimiento.
  static int _calcularEdad(DateTime fechaNacimiento) {
    final ahora = DateTime.now();
    int edad = ahora.year - fechaNacimiento.year;
    
    if (ahora.month < fechaNacimiento.month ||
        (ahora.month == fechaNacimiento.month && ahora.day < fechaNacimiento.day)) {
      edad--;
    }
    
    return edad;
  }

  /// Obtiene la edad actual de una persona.
  static int? obtenerEdad(DateTime? fechaNacimiento) {
    if (fechaNacimiento == null) return null;
    return _calcularEdad(fechaNacimiento);
  }

  /// Valida que una fecha esté en un rango razonable (no muy antigua, no futura).
  static bool esFechaValida(DateTime? fecha) {
    if (fecha == null) return false;
    
    final ahora = DateTime.now();
    final fechaMinima = DateTime(1900, 1, 1);
    
    return fecha.isAfter(fechaMinima) && fecha.isBefore(ahora.add(const Duration(days: 1)));
  }

  // ============================================================================
  // EMAIL
  // ============================================================================

  /// Valida un correo electrónico.
  static String? validarEmail(String? value, {bool requerido = false}) {
    if (value == null || value.trim().isEmpty) {
      return requerido ? 'El correo electrónico es requerido' : null;
    }

    final email = value.trim().toLowerCase();
    
    // Regex básico para email
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'El correo electrónico no es válido';
    }

    return null;
  }

  // ============================================================================
  // TEXTO GENERAL
  // ============================================================================

  /// Valida que un campo de texto no esté vacío.
  static String? validarRequerido(String? value, String nombreCampo) {
    if (value == null || value.trim().isEmpty) {
      return '$nombreCampo es requerido';
    }
    return null;
  }

  /// Valida la longitud de un texto.
  static String? validarLongitud(String? value, String nombreCampo, {int? min, int? max}) {
    if (value == null || value.isEmpty) return null;
    
    if (min != null && value.length < min) {
      return '$nombreCampo debe tener al menos $min caracteres';
    }
    
    if (max != null && value.length > max) {
      return '$nombreCampo no puede tener más de $max caracteres';
    }
    
    return null;
  }

  /// Valida que un texto contenga solo letras y espacios.
  static String? validarSoloLetras(String? value, String nombreCampo) {
    if (value == null || value.isEmpty) return null;
    
    final regex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$');
    if (!regex.hasMatch(value)) {
      return '$nombreCampo solo puede contener letras';
    }
    
    return null;
  }

  // ============================================================================
  // NÚMEROS
  // ============================================================================

  /// Valida que un valor sea un número positivo.
  static String? validarNumeroPositivo(String? value, String nombreCampo, {bool requerido = false}) {
    if (value == null || value.trim().isEmpty) {
      return requerido ? '$nombreCampo es requerido' : null;
    }

    final numero = double.tryParse(value);
    if (numero == null) {
      return '$nombreCampo debe ser un número válido';
    }

    if (numero < 0) {
      return '$nombreCampo no puede ser negativo';
    }

    return null;
  }

  /// Valida un número entero en un rango.
  static String? validarRango(String? value, String nombreCampo, {int? min, int? max}) {
    if (value == null || value.isEmpty) return null;
    
    final numero = int.tryParse(value);
    if (numero == null) {
      return '$nombreCampo debe ser un número entero';
    }
    
    if (min != null && numero < min) {
      return '$nombreCampo debe ser al menos $min';
    }
    
    if (max != null && numero > max) {
      return '$nombreCampo no puede ser mayor a $max';
    }
    
    return null;
  }

  // ============================================================================
  // CÓDIGOS ESPECÍFICOS
  // ============================================================================

  /// Valida un código SITUR (formato específico para consejos comunales).
  static String? validarCodigoSitur(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El código SITUR es requerido';
    }

    // El código SITUR típicamente tiene formato específico
    // Por ahora solo validamos longitud mínima
    if (value.trim().length < 5) {
      return 'El código SITUR parece ser muy corto';
    }

    return null;
  }

  /// Valida un RIF venezolano.
  static String? validarRif(String? value, {bool requerido = false}) {
    if (value == null || value.trim().isEmpty) {
      return requerido ? 'El RIF es requerido' : null;
    }

    final rif = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    // Formato: J-12345678-9 o similar
    final rifRegex = RegExp(r'^[JGVEP]\d{8,9}$');
    
    if (!rifRegex.hasMatch(rif)) {
      return 'El RIF no tiene un formato válido (Ej: J-12345678-9)';
    }

    return null;
  }

  // ============================================================================
  // COORDENADAS
  // ============================================================================

  /// Valida una coordenada de latitud geográfica.
  static String? validarCoordenadaLatitud(double? value) {
    if (value == null) return null;
    
    if (value < -90 || value > 90) {
      return 'La latitud debe estar entre -90 y 90';
    }
    
    return null;
  }

  /// Valida una coordenada de longitud geográfica.
  static String? validarCoordenadaLongitud(double? value) {
    if (value == null) return null;
    
    if (value < -180 || value > 180) {
      return 'La longitud debe estar entre -180 y 180';
    }
    
    return null;
  }

  /// Valida coordenadas para Venezuela (aproximadas).
  static String? validarCoordenadasVenezuela(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    
    // Límites aproximados de Venezuela
    const latMin = 0.5;
    const latMax = 12.5;
    const lngMin = -73.5;
    const lngMax = -59.5;
    
    if (lat < latMin || lat > latMax || lng < lngMin || lng > lngMax) {
      return 'Las coordenadas parecen estar fuera de Venezuela';
    }
    
    return null;
  }
}

/// Extension para facilitar validaciones en formularios Flutter.
extension ValidatorExtension on String? {
  /// Valida como cédula.
  String? get asCedula => Validators.validarCedula(this);
  
  /// Valida como teléfono.
  String? asTelefono({bool requerido = false}) => 
      Validators.validarTelefono(this, requerido: requerido);
  
  /// Valida como email.
  String? asEmail({bool requerido = false}) => 
      Validators.validarEmail(this, requerido: requerido);
  
  /// Valida como campo requerido.
  String? asRequerido(String nombreCampo) => 
      Validators.validarRequerido(this, nombreCampo);
}
