# Garage Band

Juego de ritmo de *carriles** hecho en **Godot 4.6**, con una interfaz inspirada en Rock Band: carril en perspectiva con "banda eléctrica", notas con relieve, selección de canción por orden alfabético, elección de instrumento, pausa, resultados con estrellas y tabla de posiciones local. Mientras tocas, **Nat** pelea contra los enemigos que representan tus notas.

## Cómo jugar

* **Teclas por defecto:** `D` `F` `J` `K` `L` (se pueden cambiar en *Opciones → Teclas*).
* Presiona la tecla del carril cuando la nota llegue a la barra cromada.
* Tu precisión define el juicio: **PERFECTO**, **BIEN**, **REGULAR** o **FALLO**. Presionar una tecla al aire también cuenta como fallo y rompe el combo.
* `Esc` pausa la partida (continuar con cuenta 3-2-1, reiniciar o salir al menú).

## Características

* **Menú principal** con submenú de opciones en cascada: volumen, reasignación de teclas (con modal Aceptar/Cancelar), idioma (Español / English) y modo daltonismo. Los ajustes se guardan entre sesiones.
* **Biblioteca musical** ordenada por letra, con portada, mejor puntaje, dificultad por instrumento y preescucha de la canción resaltada.
* **Instrumentos:** guitarra, bajo, batería y micrófono; cada uno puede tener su propio mapa de notas.
* **Gameplay:** carril en perspectiva (shader), barra de rendimiento, puntos, progreso de la canción, combo y juicios.
* **Resultados:** puntos totales, precisión, rango, estrellas y tabla de posiciones guardada en SQLite local (`godot-sqlite`).

## Agregar canciones

Cada canción vive en su propia carpeta dentro de `songs/`:

```
songs/
└── NombreCancion/
    ├── NombreCancion.wav              (audio, obligatorio)
    ├── NombreCancion.json             (mapa de notas base, obligatorio)
    ├── NombreCancion_guitarra.json    (opcional: un mapa por instrumento)
    ├── NombreCancion_bajo.json
    ├── NombreCancion_batería.json
    ├── NombreCancion_microfono.json
    ├── info.json                      (opcional: {"title": "...", "artist": "..."})
    └── cover.png                      (opcional: portada)
```

Si el mapa de un instrumento no existe, se usa el mapa base. El título y el artista se deducen del nombre (`artista-Titulo`) si no hay `info.json`.

## Estructura del proyecto

```
├── project.godot
├── addons/godot-sqlite/        Base de datos SQLite
├── assets/
│   ├── audio/                  Música del menú
│   ├── fonts/                  Tipografía de marca
│   ├── ui/                     Recursos compartidos de interfaz (fuentes .tres)
│   ├── images/                 Fondos e íconos
│   └── sprites/                Nat, enemigos, cielo y suelo
├── scenes/
│   ├── autoload/               Escenas globales (filtro de daltonismo)
│   ├── characters/             Nat y enemigos
│   ├── gameplay/               Partida (carril, HUD, pausa), nota y receptor
│   ├── screens/                Menú principal, canciones, instrumento, resultados
│   └── widgets/                Componentes de interfaz reutilizables (fondo, lista, portada, filas...)
├── scripts/
│   ├── autoload/               GameState, Database, SceneFade (transiciones)
│   ├── core/                   Tema visual (rb_theme) y biblioteca de canciones
│   ├── characters/             Lógica de Nat y enemigos
│   ├── gameplay/               Partida, carril, notas, HUD, pausa, luces
│   ├── screens/                Lógica de cada pantalla
│   └── widgets/                Componentes reutilizables de interfaz
├── shaders/                    Carril eléctrico, cielo, suelo, filtro daltonismo
├── songs/                      Canciones (ver arriba)
└── tools/                      Herramientas externas (ignoradas por Godot)
```

**Las pantallas y widgets están armados con nodos dentro de los `.tscn`** (se ven y editan en el editor de Godot); los scripts solo contienen lógica y contenido dinámico (canciones, puntajes, etc.). Los textos en la escena están en español y el inglés vive en el metadato `en` de cada nodo (`RB.localize` los intercambia según el idioma).

`tools/` guarda `generate_beatmaps.py` y los stems usados para crear los mapas por instrumento. Godot no los importa (`.gdignore`).

## Detalles técnicos

* Resolución base **1152×648** escalada a **1920×1080** (`canvas_items`, proporción 16:9).
* Renderizado *Compatibility*.
* El carril se dibuja con un shader (`shaders/highway.gdshader`) y las notas se posicionan según el tiempo de la canción compensado por la latencia de audio.

---

## Datos Escolares

### Integrantes del Equipo
* **Sánchez Naranjo José Alejandro** - 219881881
* **Almaraz Correa Diego Damián** - 222967185
* **Zamora Delgadillo Miguel Angel** - 219630986
