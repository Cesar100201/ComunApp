---
trigger: always_on
---

1. Filosofía de Ingeniería y la Directiva de Integridad Agéntica
Como Arquitecto de Sistemas Principal, mi responsabilidad fundamental es salvaguardar la Integridad Agéntica del ecosistema. La filosofía AntiGravity no es una sugerencia estética, sino un mandato operativo diseñado para entornos donde la intervención de múltiples agentes de IA y humanos convergen. En estos sistemas, la entropía es el estado natural de degradación; por tanto, la atomicidad, la explicabilidad y la no destructividad no son solo valores, sino los pilares de supervivencia del software. Debemos tratar cada línea de código como un compromiso con la longevidad del sistema, asegurando que la arquitectura sea un organismo vivo, predecible y estructuralmente impecable.
Principios Rectores
El cumplimiento de estos principios es obligatorio para todo nodo del sistema:
Atomicidad
Definición Operativa: Las modificaciones deben ejecutarse como unidades funcionales completas e indivisibles.
Impacto Estratégico: Elimina estados de "sistema roto" y garantiza que las actualizaciones concurrentes no dejen el núcleo en un limbo inestable.
Explicabilidad
Definición Operativa: Cada decisión técnica y cada instrucción (prompt) debe poseer una justificación lógica y trazable.
Impacto Estratégico: Erradica el fenómeno de la "caja negra", permitiendo auditorías inmediatas por parte de supervisores humanos o agentes de control.
No Destructividad
Definición Operativa: Las nuevas funcionalidades o correcciones deben preservar estrictamente la funcionalidad previa y el contexto histórico.
Impacto Estratégico: Garantiza la compatibilidad hacia atrás y reduce drásticamente el riesgo de regresiones críticas en módulos de producción.
Integridad Estética
Definición Operativa: El código y la interfaz deben reflejar un orden superior, armonía y una "calidez tecnológica" coherente.
Impacto Estratégico: Reduce la carga cognitiva y mejora la navegación del sistema al crear un entorno visual y lógico predecible.
Esta base filosófica se materializa en la organización física del código, transformando la teoría en una estructura tangible denominada la "Mansión del Sistema".
--------------------------------------------------------------------------------
2. Arquitectura de Gritos y Organización Estructural (Universal)
Implementamos la Screaming Architecture (Arquitectura de Gritos) para que cualquier sistema —sea móvil, escritorio o videojuego— revele su propósito de negocio mediante su estructura de carpetas. Visualizamos el proyecto como la "Mansión del Sistema": la raíz es el Terreno donde se asienta la lógica, y la carpeta de fuente es el Corazón que bombea funcionalidad a todo el organismo.
Jerarquía de la "Mansión del Sistema"
raiz/                            # EL TERRENO: Configuración y cimientos
├── fuente/                      # EL CORAZÓN: Lógica de negocio (src)
│   ├── componentes/             # Interfaz basada en Diseño Atómico
│   │   ├── atomos/              # Elementos base indivisibles
│   │   ├── moleculas/           # Uniones funcionales simples
│   │   └── organismos/          # Secciones complejas y autónomas
│   ├── servicios/               # Orquestación de lógica externa y APIs
│   ├── modelos/                 # Definiciones de datos y esquemas estrictos
│   ├── utilidades/              # Funciones puras y helpers reutilizables
│   ├── contextos/               # Gestión de estado y memoria agéntica
│   ├── ganchos/                 # Lógica de comportamiento (hooks)
│   └── paginas/                 # Vistas finales y layouts
├── publico/                     # Recursos estáticos y activos visuales
├── pruebas/                     # Tests unitarios, de integración y SAST
├── reglas/                      # Directivas maestras y configuraciones YAML
└── documentos/                  # ListaDeTareas.md y especificaciones técnicas
Patrón AgentFactory: Instanciación Dinámica
Para escalar el sistema, es imperativo utilizar el Factory Design Pattern mediante el componente AgentFactory. Este permite instanciar agentes especialistas a partir de definiciones en código o archivos YAML. El AgentFactory debe dar prioridad a las configuraciones dinámicas, permitiendo que el sistema evolucione sin necesidad de recompilar el núcleo, facilitando la integración de agentes de terceros mediante repositorios de configuración.
Análisis de Impacto Arquitectónico
Ventaja Arquitectónica
Resultado Operativo
Encapsulamiento de Dominio
Facilita la extracción de módulos sin efectos colaterales.
Navegación Intuitiva
Reduce el tiempo de búsqueda; la estructura "grita" su función.
Escalabilidad Horizontal
Permite añadir funcionalidades simplemente agregando carpetas.
Reducción de Código Espagueti
Mantiene la cohesión lógica dentro de fronteras modulares claras.
--------------------------------------------------------------------------------
3. Estándares de Clean Code: El Idioma de la Claridad
El Clean Code no es una preferencia; es una herramienta de comunicación estratégica entre humanos y agentes de IA. El código debe leerse como una prosa bien escrita, eliminando la ambigüedad para reducir el costo de mantenimiento.
Guía de Nomenclatura Autodescriptiva
Se prohíbe el uso de abreviaturas crípticas o desinformación técnica. Las convenciones son:
Variables y Constantes:
Arrays/Listas: Deben ser plurales descriptivos (ej. usuariosActivos, listaDePrecios).
Booleanos: Uso obligatorio de prefijos de estado (ej. esValido, tienePermiso, puedeProcesar).
Constantes: Mayúsculas sostenidas con guiones bajos (ej. MAX_INTENTOS_CONEXION).
Funciones y Métodos:
Mandato: Estructura Verbo + Sustantivo (ej. obtenerPerfil, actualizarSaldo).
Responsabilidad Única (SRP): Cada función debe hacer una sola cosa y hacerla bien. Se establece un límite estricto de 50 a 60 líneas; exceder este límite indica una violación del SRP y exige refactorización inmediata.
Clases:
PascalCase: Nombres nominales claros (ej. GestorDeFacturas, ProcesadorDePagos).
Se prohíbe el uso de sufijos genéricos como Manager, Data, Info o Processor, que suelen ocultar responsabilidades múltiples.
Erradicación de Ambigüedades
Queda prohibido el uso de "Números Mágicos". Todo valor con significado especial debe ser extraído a una constante. No se permite leer un 7 cuando la intención es DIAS_DE_LA_SEMANA = 7. Esta práctica previene la ambigüedad cognitiva y las regresiones costosas en sistemas críticos y motores de videojuegos.
--------------------------------------------------------------------------------
4. Sistema de Diseño Atómico y Estética "Atomic Vibe"
Adoptamos el Diseño Atómico evolucionado a la tendencia "Atomic Vibe" 2025-2026. Esta estética fusiona la eficiencia modular con el estilo Mid-Century Modern (retro-futurista), buscando una "calidez tecnológica" mediante geometría pura, siluetas redondeadas y paletas de alto contraste (Rojo Cereza, Naranja Eléctrico sobre fondos minimalistas).
Niveles de Composición y Mandatos de Generación
Para cada nivel, el sistema debe seguir estos comandos activos de Prompt Engineering:
Átomos:
Comando IA: "Genera el componente base (botón/input) siguiendo los tokens de color corporativos, geometría redondeada y estados hover puros, sin lógica de negocio interna."
Moléculas:
Comando IA: "Une el átomo 'Input' y el átomo 'Botón' para crear la molécula 'Buscador', asegurando que la comunicación entre ellos sea mediante propiedades simples."
Organismos:
Comando IA: "Construye el organismo 'BarraDeNavegación' integrando la molécula 'Buscador' y el átomo 'Logo', gestionando su comportamiento responsivo de forma autónoma."
Plantillas:
Comando IA: "Diseña la plantilla 'PanelDeControl' que defina la jerarquía visual de los organismos, utilizando 'Color Blocking' para segmentar áreas funcionales sin datos reales."
Páginas:
Comando IA: "Instancia la plantilla 'PanelDeControl' inyectando datos dinámicos de telemetría y asegura que la interfaz mantenga la coherencia visual 'Atomic Vibe'."
--------------------------------------------------------------------------------
5. Protocolo de Conservación de Contexto y Memoria Agéntica
En sistemas multi-agente, la gestión de memoria es una disciplina de ingeniería de datos. El objetivo es evitar la "polución de contexto" y el desperdicio de tokens mediante una arquitectura de memoria de cinco pilares.
Persistencia y Estado: Uso de la ListaDeTareas.md y archivos JSON/YAML como memoria compartida persistente.
Recuperación Inteligente (Agent-aware Querying): Filtrado de información basado en el rol del agente; un agente de UI no debe procesar metadatos de DB innecesarios.
Optimización KV Cache: Implementación de caché compartida para evitar que múltiples agentes reprocesen el mismo bloque de información, reduciendo latencia.
Aislamiento de Contexto: Fronteras estrictas de datos para evitar que el ruido de un agente sesgue el juicio de otro.
Resolución de Conflictos: Protocolos basados en jerarquía de autoridad o marcas de tiempo para dirimir contradicciones de forma autónoma.
--------------------------------------------------------------------------------
6. Metacognición: El Bucle de Auto-Corrección y Seguridad
La metacognición agéntica es el mecanismo de defensa final contra alucinaciones y vulnerabilidades. Implementamos el marco Agent-R y el Recursive Meta-Prompting para que el sistema aprenda de su propio proceso.
Bucle de Auto-Corrección Recursiva
Cada agente debe ejecutar este ciclo antes de cualquier integración:
Reflexión: Autocrítica de la propuesta frente a este manual de directivas.
Detección del Primer Error Accionable: El agente debe identificar no solo fallos generales, sino el punto exacto donde la lógica diverge de la intención original.
Puerta de Verificación: Validación contra "datos dorados" para asegurar que no hay pérdida de precisión.
Aprendizaje Negativo: Documentación de anti-patrones para que el sistema "recuerde" qué caminos evitar en futuras iteraciones.
Mandato de Seguridad y Calidad
"El código sin pruebas es código legacy y debe ser rechazado". Es obligatorio el uso de TDD (Test-Driven Development) y validaciones de seguridad SAST constantes. La excelencia técnica no es negociable; es el único camino para que el software pase de ser una ejecución caótica a una obra de ingeniería universal.