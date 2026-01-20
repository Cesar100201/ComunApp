import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

/// Generador de archivo CSV de ejemplo para carga masiva de habitantes
class CsvTemplateGenerator {
  
  /// Genera un archivo CSV de ejemplo con el formato correcto
  static Future<File> generarArchivoEjemplo() async {
    // Encabezados
    final headers = [
      'cedula',
      'nombre completo',
      'nacionalidad',
      'telefono',
      'genero',
      'fecha nacimiento',
      'estado',
      'municipio',
      'PARROQUIA',
      'comuna',
      'consejo comunal',
      'comunidad',
      'calle',
      'numero casa',
      'estatus politico',
      'nivel voto',
      'clap',
      'cedula jefe',
    ];
    
    // Datos de ejemplo
    final datosEjemplo = [
      [
        '12345678',
        'JUAN CARLOS PÉREZ GONZÁLEZ',
        'V',
        '04121234567',
        'M',
        '15/03/1985',
        'Táchira',
        'García de Hevia',
        'LaFria',
        'Comuna Central',
        'Consejo Central',
        'Comunidad El Centro',
        'Av. Bolívar',
        '15',
        'Chavista',
        'Duro',
        'CLAP Centro',
        '',
      ],
      [
        '87654321',
        'MARÍA JOSÉ GONZÁLEZ LÓPEZ',
        'V',
        '04241234567',
        'F',
        '20/07/1990',
        'Táchira',
        'García de Hevia',
        'LaFria',
        'Comuna Norte',
        'Consejo Norte',
        'Comunidad Los Mangos',
        'Calle 5',
        '23',
        'Neutral',
        'Blando',
        'CLAP Norte',
        '',
      ],
      [
        '11223344',
        'PEDRO ANTONIO RODRÍGUEZ MARTÍNEZ',
        'V',
        '04161234567',
        'M',
        '10/12/1978',
        'Táchira',
        'García de Hevia',
        'BocaDeGrita',
        'Comuna Sur',
        'Consejo Sur',
        '',
        'Av. Sucre',
        '8',
        'Opositor',
        'Opositor',
        '',
        '12345678',
      ],
      [
        '99887766',
        'ANA SOFÍA MORALES SÁNCHEZ',
        'V',
        '04261234567',
        'F',
        '05/09/1995',
        'Táchira',
        'García de Hevia',
        'JoseAntonioPaez',
        'Comuna Este',
        'Consejo Este',
        'Comunidad La Esperanza',
        'Calle Principal',
        '42',
        'OpositorSimpatizante',
        'Blando',
        'CLAP Este',
        '',
      ],
      [
        '55443322',
        'CARLOS ALBERTO RIVAS TORRES',
        'E',
        '04141234567',
        'M',
        '25/11/1988',
        'Táchira',
        'García de Hevia',
        'LaFria',
        'Comuna Central',
        'Consejo Central',
        '',
        'Calle Libertad',
        '12',
        'Neutral',
        'Blando',
        '',
        '12345678',
      ],
    ];
    
    // Construir CSV usando el paquete csv para manejar correctamente comas, espacios, etc.
    final csvData = <List<dynamic>>[];
    csvData.add(headers);
    csvData.addAll(datosEjemplo);
    
    final csvString = const ListToCsvConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      textEndDelimiter: '"',
      eol: '\n',
    ).convert(csvData);
    
    // Agregar BOM UTF-8 para que Excel lo lea correctamente
    final bom = utf8.encode('\uFEFF');
    final csvBytes = [...bom, ...utf8.encode(csvString)];
    
    // Guardar archivo
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/plantilla_carga_masiva_habitantes.csv';
    final file = File(path);
    
    await file.writeAsBytes(csvBytes);
    return file;
  }
  
  /// Genera un archivo CSV vacío solo con encabezados
  static Future<File> generarArchivoVacio() async {
    final headers = [
      'cedula',
      'nombre completo',
      'nacionalidad',
      'telefono',
      'genero',
      'fecha nacimiento',
      'estado',
      'municipio',
      'PARROQUIA',
      'comuna',
      'consejo comunal',
      'comunidad',
      'calle',
      'numero casa',
      'estatus politico',
      'nivel voto',
      'clap',
      'cedula jefe',
    ];
    
    final csvData = <List<dynamic>>[headers];
    final csvString = const ListToCsvConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      textEndDelimiter: '"',
      eol: '\n',
    ).convert(csvData);
    
    // Agregar BOM UTF-8 para que Excel lo lea correctamente
    final bom = utf8.encode('\uFEFF');
    final csvBytes = [...bom, ...utf8.encode(csvString)];
    
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/plantilla_carga_masiva_habitantes_vacia.csv';
    final file = File(path);
    
    await file.writeAsBytes(csvBytes);
    return file;
  }
}
