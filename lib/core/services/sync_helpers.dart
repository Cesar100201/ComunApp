import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:isar/isar.dart';
import '../../database/db_helper.dart';
import '../utils/logger.dart';
import '../utils/constants.dart';
import '../utils/syncable.dart';

export '../utils/syncable.dart';

/// Configuración para sincronizar una colección.
/// 
/// Define cómo mapear entre una colección local (Isar) y remota (Firebase).
class SyncConfig<T extends Syncable> {
  /// Nombre de la colección en Firebase.
  final String firebaseCollection;
  
  /// Función para obtener el ID del documento en Firebase.
  final String Function(T item) getDocumentId;
  
  /// Función para convertir un item local a un Map para Firebase.
  final Map<String, dynamic> Function(T item) toFirebaseMap;
  
  /// Función para crear/actualizar un item local desde datos de Firebase.
  final Future<T?> Function(Isar isar, firestore.DocumentSnapshot doc) fromFirebaseDoc;
  
  /// Función para obtener items pendientes de sincronizar.
  final Future<List<T>> Function(Isar isar) getPendingItems;
  
  /// Función para guardar un item en Isar.
  final Future<void> Function(Isar isar, T item) saveItem;
  
  /// Función opcional para cargar relaciones antes de subir.
  final Future<void> Function(T item)? loadRelations;
  
  /// Función opcional para guardar relaciones después de descargar.
  final Future<void> Function(Isar isar, T item)? saveRelations;

  const SyncConfig({
    required this.firebaseCollection,
    required this.getDocumentId,
    required this.toFirebaseMap,
    required this.fromFirebaseDoc,
    required this.getPendingItems,
    required this.saveItem,
    this.loadRelations,
    this.saveRelations,
  });
}

/// Helper genérico para sincronización bidireccional.
/// 
/// Elimina la duplicación de código al proveer métodos genéricos
/// para subir y descargar datos entre Isar y Firebase.
class SyncHelper {
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;
  static const int _batchSize = AppConstants.batchSize;

  /// Sube items pendientes a Firebase.
  /// 
  /// Retorna el número de items sincronizados exitosamente.
  Future<int> uploadPending<T extends Syncable>(SyncConfig<T> config) async {
    final isar = await DbHelper().db;
    final pendientes = await config.getPendingItems(isar);
    
    if (pendientes.isEmpty) return 0;

    int count = 0;
    
    for (int i = 0; i < pendientes.length; i += _batchSize) {
      final lote = pendientes.skip(i).take(_batchSize).toList();
      final batch = _firestore.batch();
      final paraMarcar = <T>[];

      // Cargar relaciones si es necesario
      if (config.loadRelations != null) {
        await Future.wait(lote.map((item) => config.loadRelations!(item)));
      }

      // Preparar documentos y obtener snapshots
      final docRefs = lote.map((item) => 
        _firestore.collection(config.firebaseCollection).doc(config.getDocumentId(item))
      ).toList();
      final snapshots = await Future.wait(docRefs.map((ref) => ref.get()));

      for (int j = 0; j < lote.length; j++) {
        final item = lote[j];
        final docRef = docRefs[j];
        final docSnapshot = snapshots[j];

        try {
          if (item.isDeleted) {
            if (docSnapshot.exists) batch.delete(docRef);
            paraMarcar.add(item);
            count++;
            continue;
          }

          final data = config.toFirebaseMap(item);
          data['ultimaActualizacion'] = firestore.FieldValue.serverTimestamp();

          if (docSnapshot.exists) {
            batch.update(docRef, data);
          } else {
            batch.set(docRef, data);
          }
          paraMarcar.add(item);
          count++;
        } catch (e) {
          AppLogger.warning('Error preparando ${config.firebaseCollection} ${config.getDocumentId(item)}: $e');
        }
      }

      // Commit y marcar como sincronizados
      await _commitAndMark(isar, batch, paraMarcar, config.saveItem);
    }

    AppLogger.debug('Upload ${config.firebaseCollection}: $count items');
    return count;
  }

  /// Descarga items de Firebase con paginación.
  /// 
  /// Usa paginación para evitar problemas de memoria con colecciones grandes.
  /// Retorna el número de items descargados.
  Future<int> downloadWithPagination<T extends Syncable>(
    SyncConfig<T> config, {
    int pageSize = AppConstants.defaultPageSize,
    Duration timeout = AppConstants.networkTimeout,
  }) async {
    final isar = await DbHelper().db;
    int count = 0;
    firestore.DocumentSnapshot? lastDoc;

    try {
      while (true) {
        // Construir query con paginación
        firestore.Query<Map<String, dynamic>> query = _firestore
            .collection(config.firebaseCollection)
            .limit(pageSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snapshot = await query.get().timeout(timeout);

        if (snapshot.docs.isEmpty) break;

        for (var doc in snapshot.docs) {
          try {
            final item = await config.fromFirebaseDoc(isar, doc);
            if (item == null) continue;

            item.isSynced = true;
            item.isDeleted = false;

            await isar.writeTxn(() async {
              await config.saveItem(isar, item);
              if (config.saveRelations != null) {
                await config.saveRelations!(isar, item);
              }
            });
            count++;
          } catch (e) {
            AppLogger.warning('Error descargando ${config.firebaseCollection} ${doc.id}: $e');
          }
        }

        lastDoc = snapshot.docs.last;

        // Si obtuvimos menos documentos que el límite, no hay más páginas
        if (snapshot.docs.length < pageSize) break;
      }
    } catch (e) {
      AppLogger.error('Error en download ${config.firebaseCollection}', e);
    }

    AppLogger.debug('Download ${config.firebaseCollection}: $count items');
    return count;
  }

  /// Ejecuta un batch de Firebase y marca los items como sincronizados.
  Future<void> _commitAndMark<T extends Syncable>(
    Isar isar,
    firestore.WriteBatch batch,
    List<T> items,
    Future<void> Function(Isar isar, T item) saveItem,
  ) async {
    if (items.isEmpty) return;
    
    try {
      await batch.commit();
      await isar.writeTxn(() async {
        for (var item in items) {
          item.isSynced = true;
          await saveItem(isar, item);
        }
      });
    } catch (e) {
      AppLogger.error('Error ejecutando batch', e);
      // Fallback: intentar uno por uno
      for (var item in items) {
        try {
          await isar.writeTxn(() async {
            item.isSynced = true;
            await saveItem(isar, item);
          });
        } catch (e2) {
          AppLogger.warning('Error en fallback para item: $e2');
        }
      }
    }
  }
}

/// Resultado de una operación de sincronización.
class SyncResult {
  final int uploaded;
  final int downloaded;
  final List<String> errors;

  const SyncResult({
    required this.uploaded,
    required this.downloaded,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  int get total => uploaded + downloaded;

  @override
  String toString() => 'SyncResult(uploaded: $uploaded, downloaded: $downloaded, errors: ${errors.length})';
}
