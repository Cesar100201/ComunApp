# Reglas de Firestore recomendadas (niveles de usuario)

Este documento describe las reglas sugeridas para las colecciones usadas por el sistema de niveles de usuario (**1=Invitado, 2=Generador, 3=Administrador**). Aplíquelas en la consola de Firebase (Firestore > Reglas) o en el archivo `firestore.rules` si su proyecto lo versiona.

## Colección `users`

Almacena el nivel de usuario por UID. Campos: `nivel` (int 1, 2 o 3), opcionalmente `email`, `updatedAt`.

- **Lectura**: solo el usuario autenticado puede leer su propio documento `users/{uid}`.
- **Escritura**: en producción, solo usuarios con nivel **3** (administrador) deberían poder crear o actualizar documentos en `users`. Para el primer despliegue, un administrador puede crear manualmente el documento desde la consola o mediante una Cloud Function.

Ejemplo de regla:

```
match /users/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.nivel == 3;
}
```

Nota: la condición de escritura exige que quien escribe tenga `users/{uid}.nivel == 3`. Para el primer admin puede ser necesario crear el documento desde la consola o usar una regla temporal.

## Colección `deepSyncRequests`

Solicitudes de sincronización profunda (iniciadas por invitados). Campos: `userId`, `email`, `status` (pending | approved | rejected), `createdAt`, `resolvedAt`, `resolvedBy`.

- **Crear**: cualquier usuario autenticado puede crear un documento (su solicitud).
- **Leer**: solo usuarios con nivel **3** (administrador) pueden leer todos los documentos. Opcionalmente, cada usuario puede leer sus propias solicitudes.
- **Actualizar**: solo nivel **3** puede actualizar (autorizar/rechazar: cambiar `status`, `resolvedAt`, `resolvedBy`).

Ejemplo:

```
match /deepSyncRequests/{requestId} {
  allow create: if request.auth != null;
  allow read: if request.auth != null && (
    resource.data.userId == request.auth.uid ||
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.nivel == 3
  );
  allow update: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.nivel == 3;
  allow delete: if false;
}
```

## Índice compuesto para `deepSyncRequests`

Para la consulta `where('status', isEqualTo: 'pending').orderBy('createdAt', descending: true)` debe existir un índice compuesto:

- Colección: `deepSyncRequests`
- Campos: `status` (Ascending), `createdAt` (Descending)

El archivo `firestore.indexes.json` del proyecto ya incluye este índice; despliegue con `firebase deploy --only firestore:indexes` si usa Firebase CLI.

## Resumen de seguridad

- **Nivel por defecto**: si no existe documento en `users/{uid}`, la app trata al usuario como invitado (nivel 1). Las reglas deben denegar escritura en colecciones sensibles para quien no tenga documento o tenga nivel 1 (invitado).
- **Auditoría**: opcionalmente registrar en `auditoria_logs` o en un campo cuando un admin autoriza/rechaza una solicitud de sync profunda.
- Otras colecciones (habitantes, solicitudes, etc.): según política, restringir escritura/borrado a nivel 3 (admin) o niveles 2 y 3; la app ya oculta acciones según nivel, pero las reglas refuerzan la seguridad en el servidor.
