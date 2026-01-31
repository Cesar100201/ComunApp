/// Stub para conditional import cuando no hay dart.library.io ni dart.library.html.
/// En Flutter siempre se usa main_mobile (io) o main_web (html).
Future<void> main() async {
  throw UnsupportedError(
    'No se pudo determinar la plataforma. Use Flutter para móvil o web.',
  );
}
