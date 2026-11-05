# Informe técnico

**Proyecto 2 – Juego del Gato (MIPS32 / MARS) – EIF205 Arquitectura de Computadoras**
**Integrantes:** Kimberly Angulo Mendoza, Daniel Centeno Gutiérrez, Jeferson Sánchez Sánchez
**Última actualización:** 05/11/2026

> En este documento se registra cómo se construyó la lógica, qué se probó y qué errores aparecieron.
> Se organiza en cuatro secciones: *1. Descripción general*, *2. Descripción de módulos*,
> *3. Mapeo de memoria* y *4. Bitácora de pruebas*.

---

## 1. Descripción general

### 1.1 Descripción del enunciado basado en el juego

El Proyecto 2 del curso Arquitectura de Computadoras (EIF205, Escuela de Informática, Facultad de
Ciencias Exactas y Naturales, Universidad Nacional) consiste en implementar un
juego 2D simple en lenguaje ensamblador. El enunciado deja libre el género (por ejemplo *snake*, *maze* o
*centipede*).

El grupo eligió el **Juego del Gato** (tres en raya), implementado en **MIPS32** y ejecutado en el emulador
**MARS 4.5**. La siguiente tabla relaciona los requerimientos del enunciado con la forma en que el proyecto
los aborda:

| Requerimiento del enunciado | Cómo se aborda en el proyecto |
|---|---|
| Juego 2D simple | Juego del Gato: tablero de 3 × 3, jugador (X) contra la computadora (O) |
| Lógica del juego (movimientos, colisiones) | Módulo de lógica `LG_*`: validación de casilla (rango y ocupación), detección de línea ganadora y de empate, turno de la CPU |
| Gráficos en modo texto o gráfico | Modo texto en la consola de MARS (*Run I/O*), a cargo del módulo de vista (`UI_*`, sección 2.5) |
| Interfaz de usuario sencilla | Módulo de vista `UI_*`: menú, tablero, marcador y pantallas de pausa, resultado, Game Over y victoria |
| Entrada por teclado | Rutina `IN_LEER_TECLA`; en MARS se escribe la tecla y se pulsa ENTER en *Run I/O* |
| Puntuación acumulativa y marcador máximo (*High Score*) | Módulo de estados: `PUNTOS` y `HIGHSCORE` (`ST_ACTUALIZAR_PUNTOS`, `ST_ACTUALIZAR_HIGHSCORE`) |
| Condiciones explícitas de victoria y derrota, con reinicio sin reiniciar el emulador | Estados `EST_VICTORIA` y `EST_GAMEOVER`; `ST_NUEVO_JUEGO` reinicia puntos y vidas conservando el récord |
| Efectos de sonido (opcional) | No contemplados en los módulos actuales |
| Documentación: README e informe técnico | `README.md` (instrucciones de ejecución) y este informe |
| Código bien comentado | Las rutinas documentan su propósito y sus parámetros en comentarios |
| Alineación de memoria (`.align`), uso del *stack frame* (`$sp`) y gestión de retrasos | `.align 2` antes de las palabras; `M_PUSH` / `M_POP` en cada procedimiento; `M_DELAY` (syscall 32) en el turno de la CPU y al terminar la partida |
| Control de versiones con Git y commits distribuidos entre los integrantes | Repositorio `jvej/gato-mips-eif205`, ramas por módulo (`estado`, `logica`, `interfaz`) y commits por módulo |

### 1.2 Reglas del juego

- El jugador es **X** y juega primero; la computadora es **O**.
- El tablero tiene 9 casillas numeradas del 1 al 9 (numeración que asume la lógica):

  ```
   1 | 2 | 3
  ---+---+---
   4 | 5 | 6
  ---+---+---
   7 | 8 | 9
  ```

- Se elige la casilla con las teclas **1-9**. Una casilla ocupada se ignora.
- Gana la partida quien complete una de las 8 líneas (3 filas, 3 columnas, 2 diagonales). Si el tablero se llena
  sin línea, es **empate**. Si la última jugada llena el tablero y completa una línea, cuenta como victoria.
- Puntuación y vidas: **ganar** la partida suma 10 puntos, **empatar** suma 5 y **perder** quita 1 vida. Se empieza
  con 3 vidas.
- **Victoria del juego** al llegar a 50 puntos; **Game Over** al quedarse sin vidas. Tras cualquiera de los dos
  se puede jugar de nuevo sin cerrar MARS.
- Otras teclas: **P** pausa, **R** reinicia la partida (sin penalización), **Q** vuelve al menú.
- El marcador máximo se conserva entre juegos mientras el programa siga abierto; solo se pone en 0 al iniciar.
- En MARS la consola no permite escribir ESC ni distinguir ENTER de forma confiable, así que la entrada traduce
  J → ENTER (13) y Q → ESC (27). Se escribe la tecla y se pulsa ENTER en la ventana *Run I/O*.

### 1.3 Objetivo del proyecto

Según el enunciado, el objetivo es desarrollar en el estudiante habilidades de resolución de problemas mediante
la implementación de un juego 2D en lenguaje ensamblador, estructurando el código con un buen diseño modular
apoyado en procedimientos y macros. En términos concretos, el proyecto busca:

- Dividir el sistema en procedimientos independientes (inicialización, renderizado, entrada por teclado,
  física/colisiones y gestión del estado del juego).
- Preservar `$ra` y los registros `$s0`-`$s7` en la pila (`$sp`) antes de realizar llamadas anidadas.
- Usar macros para las secuencias repetitivas (por ejemplo, impresión de mensajes o cálculo de direcciones).
- Respetar la alineación de memoria y manejar los retrasos de tiempo.
- Documentar la arquitectura, los módulos y las pruebas, y trabajar con un historial de commits constante y
  distribuido entre los integrantes.

**Decisión de alcance:** se consideró incluir dos modos de juego; jugador contra la computadora y jugador contra jugador. Este último se terminó descartando. El juego es siempre jugador (X) contra la computadora (O).

---

## 2. Descripción de módulos

### 2.1 ¿Por qué desarrollar el proyecto en módulos?

- **El enunciado lo pide.** Las buenas prácticas del proyecto exigen un diseño modular activo, con
  procedimientos independientes para cada responsabilidad del juego.
- **Permite el trabajo en paralelo.** Tres integrantes pueden avanzar a la vez si los módulos acuerdan de antemano
  un **contrato**: qué rutinas existen, qué registros reciben y cuáles devuelven (ver sección 3.3).
- **Evita choques de nombres.** Cada módulo usa un prefijo propio en sus etiquetas y constantes (`ST_`, `LG_`,
  `IN_`, `UI_`, `M_`). En ensamblador todas las etiquetas comparten un único espacio de nombres, por lo que dos
  etiquetas iguales impiden ensamblar.
- **Facilita las pruebas.** Un módulo con interfaz clara puede probarse aislado (ver sección 4), sin esperar al resto.
- **Reduce la repetición.** Las secuencias comunes se encapsulan en macros (`M_PUSH`, `M_POP`, `M_PRINT`, etc.).

**Flujo de trabajo seguido**

1. Jeferson definió en la cabecera de su archivo el **contrato entre módulos** (rutinas `LG_*`, `IN_*` y `UI_*`
   con sus parámetros y valores de retorno).
2. Cada integrante trabaja su parte en un archivo propio. Jeferson usó la rama `estado` para el módulo de
   estados, Daniel la rama `logica` para la lógica y Kim la rama `interfaz` para la vista.
3. La rama `logica` incorporó lo hecho en `estado` y, sobre eso, se construyó la lógica por módulos (ver 2.4.1),
   con un commit por módulo.
4. Las partes integradas se reunieron en un **único archivo**, `src/gato.s`. Es un solo archivo a propósito:
   en MARS los `.eqv`, los macros y las etiquetas sin `.globl` no se comparten entre archivos distintos, así que
   el código de un módulo no vería los datos ni los macros de otro.


### 2.2 División de los módulos

| Integrante | Sección | Módulos |
|---|---|---|
| Jeferson Sánchez | Estado (2.3) | Datos, programa principal (`main`), máquina de estados, puntuación, vidas, high score y reinicio. Prefijo `ST_`. **Integrado** en `src/gato.s`. |
| Daniel Centeno| Lógica (2.4) | Tablero, validación de jugadas, colocación de fichas, detección de ganador y empate, turno de la CPU. Prefijo `LG_`. **Integrado** en `src/gato.s`. |
| Kimberly Angulo | Vista (2.5) | Entrada por teclado, interfaz (tablero, marcador, pantallas) y macros de pantalla. Prefijos `IN_`, `UI_` y `M_`. **Integrado** en `src/gato.s` (también en `src/gato_kim.asm`). |

### 2.3 Estado

**Propósito.** Controla el flujo del juego: decide en qué pantalla o fase se encuentra el programa (menú, partida,
pausa, fin del juego), qué hace cada tecla según esa fase, y lleva la puntuación, las vidas y el marcador máximo.
También permite reiniciar el juego sin cerrar el emulador. Responsable: Jeferson Sánchez. Prefijo `ST_`.

Estados (`ESTADO`) y transiciones, según el código:

| Estado | Valor | Tecla | Efecto |
|---|---|---|---|
| `EST_MENU` | 0 | ENTER | Nuevo juego (`EST_JUEGO`) |
| | | I | Muestra instrucciones y vuelve al menú |
| | | ESC | Termina el programa |
| `EST_JUEGO` | 1 | 1-9 | Jugada del jugador y respuesta de la CPU |
| | | P | Pasa a `EST_PAUSA` |
| | | R | Reinicia la partida (sin penalización) |
| | | ESC | Vuelve al menú |
| `EST_PAUSA` | 2 | P | Continúa la partida |
| | | ESC | Vuelve al menú |
| `EST_GAMEOVER` / `EST_VICTORIA` | 3 / 4 | ENTER o R | Nuevo juego |
| | | ESC | Vuelve al menú |

Al terminar una partida, el estado queda en `EST_JUEGO` (nueva partida), `EST_VICTORIA` o `EST_GAMEOVER`
según los puntos y las vidas.

#### 2.3.1 Constantes, datos y macros comunes

Define las constantes `.eqv` (`EST_*` para los estados, `RES_*` para el resultado de una partida, `PTS_VICTORIA` = 10,
`PTS_EMPATE` = 5, `PTS_META` = 50, `VIDAS_INI` = 3 y los códigos de tecla `K_*`), las variables del segmento de
datos (ver sección 3), los mensajes `.asciiz` y los macros comunes: `M_PUSH` y `M_POP` (guardar y recuperar un
registro en la pila), `M_PRINT` (imprime una cadena), `M_PRINT_CHAR` (imprime un carácter), `M_CLS` (limpia la
consola con saltos de línea) y `M_DELAY` (retraso en milisegundos con la syscall 32).

#### 2.3.2 Programa principal (`main`)

Llama a `ST_INICIAR` y `ST_IR_MENU`, y luego repite un ciclo: si `SALIR` vale 1 termina; si no, lee una tecla con
`IN_LEER_TECLA` y se la pasa a `ST_DESPACHAR`. Al salir muestra el mensaje de despedida y finaliza con la syscall 10.

#### 2.3.3 Inicialización y cambios de estado

- `ST_INICIAR`: valores iniciales. `HIGHSCORE` solo se pone en 0 aquí (al abrir el programa).
- `ST_IR_MENU`: pasa al estado `EST_MENU` y dibuja el menú.
- `ST_NUEVO_JUEGO`: reinicia puntos y vidas (conserva `HIGHSCORE`) y arranca la primera partida. Es lo que permite
  reiniciar sin cerrar MARS.
- `ST_NUEVA_PARTIDA`: limpia el tablero con `LG_LIMPIAR_TABLERO`, pasa a `EST_JUEGO` y redibuja.
- `ST_REDIBUJAR`: pantalla completa de juego (marcador, tablero y ayuda); en modo de prueba agrega el mensaje de teclas W/L/D.
- `ST_PAUSAR`: pasa al estado `EST_PAUSA` y muestra la pantalla de pausa.

#### 2.3.4 Despacho de teclas por estado

`ST_DESPACHAR` llama al manejador correspondiente al estado actual: `ST_PROC_MENU`, `ST_PROC_JUEGO`,
`ST_PROC_PAUSA` o `ST_PROC_FINAL` (este último atiende Game Over y Victoria). Cada manejador traduce la tecla
recibida en `$a0` a la acción de la tabla de transiciones anterior.

#### 2.3.5 Jugada del jugador y turno de la CPU

`ST_JUGADA_JUGADOR` recibe la tecla; si no es 1-9 la ignora. Valida la casilla con `LG_VALIDAR_JUGADA` (una casilla
ocupada se ignora), coloca la X con `LG_COLOCAR_FICHA` y llama a `LG_VERIFICAR_FIN`. Si la partida sigue, pone
`TURNO` = 2, redibuja, espera 300 ms con `M_DELAY`, llama a `LG_TURNO_CPU`, vuelve a verificar el fin y devuelve el
turno al jugador. Si la partida terminó en cualquiera de los dos momentos, llama a `ST_FIN_PARTIDA`.
Guarda `$ra` y `$s0` (la tecla) en la pila.

#### 2.3.6 Fin de partida, puntuación, vidas y récord

- `ST_FIN_PARTIDA`: aplica el resultado y redibuja para mostrar la jugada final. Si el juego continúa, muestra el
  mensaje del resultado, espera una tecla y empieza otra partida; si no, espera 600 ms y muestra la pantalla de
  victoria o de Game Over.
- `ST_ACTUALIZAR_PUNTOS`: gana el jugador, +`PTS_VICTORIA`; empate, +`PTS_EMPATE`; gana la CPU, −1 vida. Luego
  actualiza el récord y decide el siguiente estado: primero compara los puntos con `PTS_META` (victoria) y después
  las vidas (Game Over).
- `ST_ACTUALIZAR_HIGHSCORE`: si `PUNTOS` supera a `HIGHSCORE`, lo reemplaza y activa `NUEVO_REC`.

#### 2.3.7 Modo de prueba

`ST_TECLA_PRUEBA` solo actúa si `MODO_PRUEBA` vale 1: las teclas W, L y D fuerzan que el resultado de la partida sea
victoria, derrota o empate, para poder probar la puntuación y los estados sin jugar cada partida completa. Debe ponerse
`MODO_PRUEBA` en 0 antes de entregar.

### 2.4 Lógica

**Propósito.** Implementa las reglas del tablero, sin dibujar nada ni leer el teclado: guarda el estado del tablero,
decide si una jugada es válida, coloca fichas, determina si hay un ganador o un empate y calcula la jugada de la
computadora. Responsable: Daniel Centeno. Prefijo `LG_` (etiquetas locales `lg_`). Sus datos y su contrato con el módulo de
estados se detallan en la sección 3.

#### 2.4.1 Flujo de construcción

La lógica se construyó por módulos que se fueron integrando, cada uno con su propio commit y su revisión.

| Módulo | Contenido | Decisiones relevantes |
|---|---|---|
| 0 | Esqueleto de la sección `LG_*`, constantes con prefijo `LG_` | Las cinco rutinas del contrato nacen como esqueletos (`jr $ra`; `LG_VALIDAR_JUGADA` devuelve 1) para que el resto del programa pudiera ensamblar. Prefijo `LG_` / `lg_` para evitar etiquetas duplicadas. |
| 1 | `LG_LIMPIAR_TABLERO` | Ciclo de 9 vueltas con `sb`; condición `blt` (con `ble` escribiría un décimo byte sobre `TURNO`). `TURNO` = 1 porque el jugador (X) empieza. |
| 2 | `LG_VALIDAR_JUGADA`, `LG_COLOCAR_FICHA`, macro `LG_DIR_CASILLA` | Patrón "supongo inválida": `$v0` = 1 desde el inicio y cada prueba fallida sale directo. `LG_COLOCAR_FICHA` no valida; quien llama debe validar antes. Conversión casilla 1-9 → índice 0-8. |
| 3 | `LG_VERIFICAR_FIN` | Recorre `LINEAS`; una línea cuenta solo si la primera casilla no está vacía (si no, tres vacías `0,0,0` serían una "victoria"). El empate se evalúa **después** de las líneas para que una 9.ª jugada ganadora cuente como victoria. |
| 4 | `LG_TURNO_CPU`, `LG_PROBAR_GANADA`, `LG_PRIMERA_LIBRE` | Prioridad: 1) ganar, 2) bloquear, 3) `LG_ORDEN`. Para detectar jugadas ganadoras se coloca una ficha provisional, se llama a `LG_VERIFICAR_FIN`, se compara `RESULTADO` con la ficha y se deshace. Primer uso de marco de pila (`$ra`, `$s0`-`$s2`). |
| 5 | Pruebas e integración | Programa de prueba aislado, integración de `LG_*` con `ST_*` en `src/gato.s`, esta bitácora. |

#### 2.4.2 Constantes y macro de apoyo

Constantes propias (`.eqv`, no ocupan memoria): `LG_NUM_CASILLAS` = 9, `LG_NUM_LINEAS` = 8, `LG_VACIA` = 0,
`LG_FICHA_X` = 1 y `LG_FICHA_O` = 2. El macro `LG_DIR_CASILLA(%dest, %casilla)` calcula en `%dest` la dirección de
`TABLERO[%casilla - 1]`: carga la dirección base, suma la casilla y resta 1 (conversión de la numeración 1-9 del
jugador al índice 0-8 del arreglo). Los dos parámetros deben ser registros distintos, porque `%dest` se escribe
antes de leer `%casilla`. Un macro se copia en cada lugar donde se usa; no es una llamada y no toca `$ra`.

#### 2.4.3 `LG_LIMPIAR_TABLERO`

Deja el tablero listo para una partida nueva: `TABLERO[0..8]` = 0, `TURNO` = 1 (empieza el jugador) y
`RESULTADO` = `RES_CURSO`. Sin entrada ni salida. La llama `ST_NUEVA_PARTIDA`. Recorre las 9 casillas con un
puntero que avanza un byte por vuelta y escribe con `sb`. Procedimiento hoja: usa `$t0`-`$t3` y no guarda nada en la pila.

#### 2.4.4 `LG_VALIDAR_JUGADA`

Entrada: `$a0` = casilla (1-9). Salida: `$v0` = **0** si la jugada es válida y **1** si es inválida (es el sentido que
espera el `bnez` de `ST_JUGADA_JUGADOR`). Es inválida si la casilla está fuera de 1-9 o ya está ocupada. Empieza
suponiendo "inválida" y solo cambia `$v0` a 0 si pasa las tres pruebas (mínimo, máximo y casilla vacía). No modifica
el tablero. Procedimiento hoja que usa `$t0`-`$t3`.

#### 2.4.5 `LG_COLOCAR_FICHA`

Entrada: `$a0` = casilla (1-9), `$a1` = ficha (1 = X, 2 = O). Escribe la ficha en `TABLERO[casilla - 1]` con ayuda de
`LG_DIR_CASILLA`. **No valida**: quien la llama debe usar `LG_VALIDAR_JUGADA` antes. Procedimiento hoja que usa `$t0`.

#### 2.4.6 `LG_VERIFICAR_FIN`

Revisa el tablero y actualiza `RESULTADO`: 1 si gana el jugador (X), 2 si gana la CPU (O), 3 si hay empate, 0 si la
partida sigue. Primero recorre las 8 líneas de `LINEAS`: para cada una lee los tres índices, convierte cada índice en
dirección de `TABLERO` y lee la ficha; la línea gana si la primera casilla no está vacía y las tres fichas son iguales,
y en ese caso guarda la ficha ganadora directamente en `RESULTADO` (los códigos 1 y 2 coinciden con las fichas).
Si ninguna línea gana, recorre las 9 casillas: si encuentra una vacía, `RESULTADO` = 0; si no, `RESULTADO` = 3.
El empate se evalúa después de las líneas para que una novena jugada ganadora cuente como victoria. Procedimiento
hoja que usa `$t0`-`$t6` y tiene varias salidas con `jr $ra`.

#### 2.4.7 `LG_TURNO_CPU`

La CPU coloca su ficha (O). Sin entrada ni salida. Aplica esta prioridad: 1) si puede ganar en esta jugada, gana;
2) si el jugador está a una jugada de ganar, bloquea; 3) toma la primera casilla libre según el orden de preferencia
`LG_ORDEN`. Si el tablero está lleno no hace nada. No usa registros `$s`, pero llama a otras rutinas con `jal`, por lo
que guarda `$ra` en la pila.

#### 2.4.8 `LG_PROBAR_GANADA`

Entrada: `$a0` = ficha. Salida: `$v0` = casilla (1-9) donde esa ficha completaría una línea, o 0 si no existe. Para cada
casilla libre coloca la ficha de forma provisional, llama a `LG_VERIFICAR_FIN`, guarda `RESULTADO`, deshace la jugada
(escribe `LG_VACIA`) y restaura `RESULTADO` a `RES_CURSO`; si `RESULTADO` coincidía con la ficha, esa casilla gana.
Supone `RESULTADO` = 0 al entrar. Guarda `$ra`, `$s0` (ficha), `$s1` (casilla) y `$s2` (resultado) en la pila.

#### 2.4.9 `LG_PRIMERA_LIBRE`

Salida: `$v0` = primera casilla libre según `LG_ORDEN` (centro, esquinas, lados), o 0 si el tablero está lleno.
Recorre `LG_ORDEN` y usa `LG_VALIDAR_JUGADA` para comprobar cada candidata. Guarda `$ra`, `$s0` (puntero a `LG_ORDEN`)
y `$s1` (contador) en la pila.

### 2.5 Vista

**Propósito.** Es la capa que habla con el usuario: lee el teclado y dibuja el tablero, el marcador y las pantallas del
juego en la consola de MARS. Las rutinas `UI_*` solo dibujan: leen variables pero no las cambian. Responsable: Kimberly Angulo.
Prefijos `IN_`, `UI_` y `M_` (etiquetas locales `il_`, `uc_`, `udt_`, `hud_`, `umr_`, `upf_`).

**Estado: integrado** al final de `src/gato.s`, después del módulo de la lógica. El mismo código está también en
`src/gato_kim.asm`, que sirve como archivo de trabajo del módulo; no ensambla solo porque necesita las macros, las
variables y los mensajes que define Jeferson.

#### 2.5.1 Resumen de rutinas

| Rutina | Entrada | Salida | Registros | Pila |
|---|---|---|---|---|
| `IN_LEER_TECLA` | — | `$v0` = tecla traducida | `$t0` | Hoja |
| `IN_VACIAR_BUFER` | — | — | — | Hoja |
| `UI_CELDA` (auxiliar) | `$a0` = índice 0-8 | imprime una casilla | `$t0`-`$t2` | Hoja |
| `UI_DIBUJAR_TABLERO` | — | imprime el tablero 3 × 3 | `$s0`, `$s1`, `$t0` | `$ra`, `$s0`, `$s1` (12 bytes) |
| `UI_DIBUJAR_HUD` | — | imprime puntos, récord, vidas y turno | `$t0`, `$t1` | `$ra` (4 bytes) |
| `UI_PANTALLA_MENU` | — | imprime el menú principal | `$t0` | `$ra` (4 bytes) |
| `UI_PANTALLA_AYUDA` | — | imprime las instrucciones y espera una tecla | — | `$ra` (4 bytes) |
| `UI_PANTALLA_PAUSA` | — | imprime el mensaje de pausa | — | `$ra` (4 bytes) |
| `UI_MENSAJE_RESULTADO` | — | imprime ganaste, empate o perdiste según `RESULTADO` | `$t0`, `$t1` | `$ra` (4 bytes) |
| `UI_PANTALLA_GAMEOVER` | — | imprime la pantalla de Game Over | — | `$ra` (4 bytes) |
| `UI_PANTALLA_VICTORIA` | — | imprime la pantalla de victoria | — | `$ra` (4 bytes) |
| `UI_PIE_FINAL` (auxiliar) | — | imprime puntos finales, aviso de nuevo récord y opciones de reinicio | `$t0` | `$ra` (4 bytes) |

#### 2.5.2 Macro de apoyo

`M_PRINT_INT(%reg)` copia el registro recibido en `$a0` y llama a la syscall 1 para imprimir un entero. Se usa en el
marcador, en el menú y en la pantalla final. Se define junto a los macros comunes de Jeferson (`M_PUSH`, `M_POP`,
`M_PRINT`, `M_PRINT_CHAR`, `M_CLS`, `M_DELAY`), antes de su primer uso. Como todos esos macros, usa `$a0` y `$v0`.

#### 2.5.3 `IN_LEER_TECLA` e `IN_VACIAR_BUFER`

`IN_LEER_TECLA` espera un carácter con la syscall 12 y lo traduce al código que espera el módulo de estados:

- Los saltos de línea (códigos 10 y 13) se descartan y se vuelve a leer. En MARS el usuario escribe la tecla y pulsa
  ENTER, y ese ENTER llega como un carácter extra.
- Las minúsculas se pasan a mayúscula (se resta 32 a los códigos 97-122).
- Los dígitos `'1'`-`'9'` se convierten en los números 1-9 (se resta 48).
- `J` se devuelve como 13 (ENTER) y `Q` como 27 (ESC), porque la consola de MARS no permite escribir esas teclas.
- Cualquier otra letra se devuelve con su código ASCII (por ejemplo `P` = 80 y `R` = 82).

Es un procedimiento hoja y solo usa `$t0`. `IN_VACIAR_BUFER` solo ejecuta `jr $ra`: la consola de MARS no permite vaciar el
buffer y, como `IN_LEER_TECLA` ya descarta los saltos de línea, no hace falta. Se mantiene para cumplir el contrato
entre módulos.

#### 2.5.4 Tablero y marcador

`UI_CELDA` recibe un índice 0-8 en `$a0`, lee `TABLERO[índice]` e imprime una casilla: `X` si vale 1, `O` si vale 2 y, si está
vacía, su número de casilla (índice + 1). Así el jugador ve qué tecla corresponde a cada casilla.

`UI_DIBUJAR_TABLERO` recorre las 3 filas con `$s0` (fila) y `$s1` (primer índice de la fila, fila × 3). Para cada fila
imprime un margen, las tres casillas separadas por `SEP` (` | `) y un salto de línea; entre filas imprime `LINEA_H`
(`---+---+---`), y no después de la última. Guarda `$ra`, `$s0` y `$s1` en la pila porque llama a `UI_CELDA`.

`UI_DIBUJAR_HUD` imprime en una línea `PUNTOS`, `HIGHSCORE` (récord), `VIDAS` y el turno actual (`Jugador (X)` o `CPU (O)`
según `TURNO`), usando `M_PRINT_INT` para los números.

#### 2.5.5 Pantallas

- `UI_PANTALLA_MENU`: limpia la consola, imprime el título, el marcador máximo (`HIGHSCORE`) y las opciones J, I y Q.
- `UI_PANTALLA_AYUDA`: limpia la consola, imprime las instrucciones y espera una tecla antes de volver; después
  `ST_PROC_MENU` redibuja el menú.
- `UI_PANTALLA_PAUSA`: imprime el mensaje de pausa debajo del tablero actual, sin limpiar la pantalla.
- `UI_MENSAJE_RESULTADO`: según `RESULTADO` imprime el mensaje de partida ganada, empatada o perdida.
- `UI_PANTALLA_GAMEOVER` y `UI_PANTALLA_VICTORIA`: limpian la consola, imprimen su título y llaman a `UI_PIE_FINAL`, que
  muestra los puntos finales, el aviso de nuevo récord (solo si `NUEVO_REC` vale 1) y las opciones para jugar de nuevo
  o volver al menú.

#### 2.5.6 Decisiones de diseño

- **La vista no cambia el estado.** Todas las rutinas `UI_*` leen variables de Jeferson (`TABLERO`, `PUNTOS`, `HIGHSCORE`,
  `VIDAS`, `TURNO`, `RESULTADO`, `NUEVO_REC`) pero nunca las escriben; así el estado solo lo modifican `ST_*` y `LG_*`.
- **Los textos están en el `.data` de Jeferson.** La vista solo los imprime con `M_PRINT`, de modo que cambiar un mensaje
  no obliga a tocar código de la vista.
- **Las casillas vacías muestran su número**, para que no haga falta una leyenda aparte del tablero.
- **Un solo archivo en la entrega.** La vista usa las macros, las constantes y las variables de los otros módulos, y en
  MARS esos elementos no se comparten entre archivos; por eso va dentro de `src/gato.s`.

---

## 3. Mapeo de memoria

### 3.1 Datos que usa la lógica

Definidos por Jeferson en el segmento `.data` (direcciones con la configuración por defecto de MARS,
base `0x10010000`):

| Etiqueta | Tamaño | Offset | Dirección | Contenido |
|---|---|---|---|---|
| `TABLERO` | 9 bytes | +0 … +8 | `0x10010000` | Casillas 0-8: 0 vacía, 1 = X (jugador), 2 = O (CPU) |
| `TURNO` | 1 byte | +9 | `0x10010009` | 1 jugador, 2 CPU |
| `ESTADO` | 1 byte | +10 | `0x1001000A` | Estado de la máquina de estados |
| `RESULTADO` | 1 byte | +11 | `0x1001000B` | 0 en curso, 1 gana jugador, 2 gana CPU, 3 empate |
| `VIDAS`, `NUEVO_REC`, `SALIR`, `MODO_PRUEBA` | 1 byte c/u | +12 … +15 | | Variables de Jeferson |
| `PUNTOS`, `HIGHSCORE` | 1 word c/u | +16, +20 | `0x10010010`, `0x10010014` | Alineadas a 4 bytes con `.align 2` |
| `LINEAS` | 24 bytes | +24 | `0x10010018` | 8 líneas ganadoras × 3 índices de casilla (0-8) |

Dato propio de la lógica (`.data` de Daniel, a continuación de los de Jeferson):

| Etiqueta | Tamaño | Contenido |
|---|---|---|
| `LG_ORDEN` | 9 bytes | Preferencia de la CPU cuando no puede ganar ni debe bloquear: `5,1,3,7,9,2,4,6,8` (centro, esquinas, lados) |

Constantes propias (`.eqv`, no ocupan memoria): `LG_NUM_CASILLAS` = 9, `LG_NUM_LINEAS` = 8,
`LG_VACIA` = 0, `LG_FICHA_X` = 1, `LG_FICHA_O` = 2.

Datos que **lee** la vista (definidos por Jeferson; la vista no los modifica): `TABLERO`, `TURNO`, `RESULTADO`, `VIDAS`,
`NUEVO_REC`, `PUNTOS`, `HIGHSCORE` y los mensajes `.asciiz` (`MSG_*`, `SEP`, `LINEA_H`, `CRLF`, `STR_CLS`). La vista no
declara datos propios.

**Coincidencia de códigos (decisión de diseño):** las fichas (1 = X, 2 = O) coinciden con
`RES_JUGADOR` = 1 y `RES_CPU` = 2. Por eso `LG_VERIFICAR_FIN` guarda directamente la ficha
ganadora en `RESULTADO`, y `LG_PROBAR_GANADA` compara `RESULTADO` con la ficha.

### 3.2 Convención de registros

- `$a0`, `$a1`: parámetros. `$v0`: valor de retorno.
- `$t0`-`$t9`: temporales; nadie espera que sobrevivan a una llamada.
- `$s0`-`$s7` y `$ra`: cualquier procedimiento que los use o llame a otro con `jal` los guarda en la pila
  con `M_PUSH` y los restaura con `M_POP` en orden inverso.
- `LG_DIR_CASILLA(%dest, %casilla)` (macro): `%dest = &TABLERO[%casilla - 1]`. Los dos
  parámetros deben ser registros distintos.

### 3.3 Interfaz con el módulo de estados

| Rutina | Entrada | Salida | Quién la llama |
|---|---|---|---|
| `LG_LIMPIAR_TABLERO` | — | `TABLERO` = 0, `TURNO` = 1, `RESULTADO` = 0 | `ST_NUEVA_PARTIDA` |
| `LG_VALIDAR_JUGADA` | `$a0` = casilla 1-9 | `$v0` = **0 válida**, 1 inválida | `ST_JUGADA_JUGADOR` |
| `LG_COLOCAR_FICHA` | `$a0` = casilla, `$a1` = ficha | escribe en `TABLERO` (no valida) | `ST_JUGADA_JUGADOR` |
| `LG_VERIFICAR_FIN` | — | actualiza `RESULTADO` | `ST_JUGADA_JUGADOR` |
| `LG_TURNO_CPU` | — | la CPU coloca una O | `ST_JUGADA_JUGADOR` |

### 3.4 Segmentos y uso de la pila

Con la configuración por defecto de MARS, el código (`.text`) empieza en `0x00400000`, los datos (`.data`) en
`0x10010000` y la pila (`$sp`) empieza cerca de `0x7FFFEFFC` y **crece hacia direcciones menores**. En el segmento de
datos se declaran primero los bytes (16 en total, desde `TABLERO`), luego `.align 2` y las palabras, para que
`PUNTOS` y `HIGHSCORE` queden alineadas a 4 bytes (obligatorio para `lw` / `sw`); después van la tabla `LINEAS` y los
mensajes `.asciiz`.

`M_PUSH` reserva 4 bytes por registro (`addi $sp, $sp, -4` y `sw`) y `M_POP` los recupera y libera en orden inverso.
Marcos de pila de la lógica:

| Rutina | Registros guardados | Bytes |
|---|---|---|
| `LG_PROBAR_GANADA` | `$ra`, `$s0`, `$s1`, `$s2` | 16 |
| `LG_PRIMERA_LIBRE` | `$ra`, `$s0`, `$s1` | 12 |
| `LG_TURNO_CPU` | `$ra` | 4 |
| `UI_DIBUJAR_TABLERO` | `$ra`, `$s0`, `$s1` | 12 |
| `UI_DIBUJAR_HUD`, `UI_PANTALLA_MENU`, `UI_PANTALLA_AYUDA`, `UI_PANTALLA_PAUSA`, `UI_MENSAJE_RESULTADO`, `UI_PANTALLA_GAMEOVER`, `UI_PANTALLA_VICTORIA`, `UI_PIE_FINAL` | `$ra` | 4 |

Las demás rutinas `LG_*`, además de `IN_LEER_TECLA`, `IN_VACIAR_BUFER` y `UI_CELDA`, son procedimientos hoja (no llaman a otras) y no usan la pila.

---

## 4. Bitácora de pruebas

Se le solicitó a una Inteligencia Artificial que generara y probara un archivo de pruebas correspondientes al funcionamiento de los módulos que integran la lógica del juego. En total se generaron 25 casos de prueba que evalúan casos límite y en general el correcto funcionamiento de cada uno de ellos.

### 4.1 Cómo se efectúan las pruebas

`pruebas/prueba_logica.asm` reemplaza `main`, `ST_*`, `IN_*` y `UI_*` por un probador, de modo que
`LG_*` se ejecuta aislada. Contiene una copia del código de la lógica (si ese código cambia, hay que regenerarlo).
**No se debe ensamblar junto a `gato.s`** (ambos tienen `main`).

Para ejecutarlo: abrir el archivo en MARS → Assemble (F3) → Run (F5). La ventana *Run I/O* imprime
`OK` o `FALLO` por caso y un resumen final.

### 4.2 Casos y resultados esperados

**`LG_LIMPIAR_TABLERO`**

| # | Caso | Esperado |
|---|---|---|
| 1 | Tablero lleno (`1,2,1,2,1,2,1,2,1`), `TURNO` = 2, `RESULTADO` = 3 | Tablero en 0, `TURNO` = 1, `RESULTADO` = 0 |

**`LG_VALIDAR_JUGADA`** (tablero con las casillas 1, 2 y 3 ocupadas) — pruebas de **límites y colisión**

| # | Casilla | Esperado (`$v0`) |
|---|---|---|
| 2 | 0, 10, -3 (fuera de rango) | 1 (inválida) |
| 2 | 1 y 3 (ocupadas, incluido el borde) | 1 (inválida) |
| 2 | 4 y 9 (libres, incluido el borde) | 0 (válida) |

**`LG_COLOCAR_FICHA`**

| # | Caso | Esperado |
|---|---|---|
| 3 | X en 5, O en 1, X en 9 sobre tablero limpio | `TABLERO[4]`=1, `[0]`=2, `[8]`=1; exactamente 3 fichas |

**`LG_VERIFICAR_FIN`** (15 casos; tablero → `RESULTADO` esperado)

| Casos | Tablero | Esperado |
|---|---|---|
| 1-3 | Cada fila completa de X | 1 |
| 4-6 | Cada columna completa de X | 1 |
| 7-8 | Las dos diagonales de X | 1 |
| 9-10 | Fila 1 de O; diagonal secundaria de O | 2 |
| 11 | Tablero vacío | 0 |
| 12 | `1,2,0 / 0,1,0 / 0,0,2` (en curso, sin línea) | 0 |
| 13 | `1,1,0 / 0,0,0 / 0,0,0` (dos X en fila, falta una) | 0 |
| 14 | `1,2,1 / 1,2,2 / 2,1,1` (lleno, sin línea) | 3 (empate) |
| 15 | `1,1,1 / 2,2,1 / 1,2,2` (lleno **y** con línea de X) | 1 (victoria, no empate) |

**`LG_TURNO_CPU`** (7 casos; tablero → casilla donde debe aparecer la O)

| Caso | Tablero | Esperado |
|---|---|---|
| 1 | `2,2,0 / 1,1,0 / 0,0,0` (puede ganar y también bloquear) | Casilla 3: **gana** antes de bloquear |
| 2 | `1,1,0 / 0,2,0 / 0,0,0` | Casilla 3: bloquea la fila 1 |
| 3 | `1,0,0 / 1,0,0 / 0,2,2` | Casilla 7 |
| 4 | `2,0,0 / 1,2,0 / 1,0,0` | Casilla 9: gana por la diagonal |
| 5 | `1,0,0 / 0,0,0 / 0,0,0` | Casilla 5: toma el centro |
| 6 | `0,0,0 / 0,1,0 / 0,0,0` | Casilla 1: centro ocupado, toma esquina |
| 7 | Tablero lleno | Sin cambios y sin errores |

En todos los casos de CPU se comprueba además que aparezca **exactamente una** ficha nueva y que
`RESULTADO` quede en 0 (la prueba provisional no debe dejar rastro).

### 4.3 Resultados obtenidos

| Fecha | Entorno | Resultado |
|---|---|---|
| 31/10/2026 | Intérprete MIPS auxiliar (subconjunto de instrucciones del proyecto; **no es MARS**) | 25 pruebas, 0 fallidas. `$sp` final igual al inicial (pila balanceada). |
| 31/10/2026 | MARS (ejecución de `pruebas/prueba_logica.asm` realizada por Daniel) | 25 pruebas, 0 fallidas. Coincide con el resultado del intérprete auxiliar. Salida completa a continuación. |

Salida de la ventana *Run I/O* de MARS:

```
=== PRUEBAS DE LA LOGICA (Daniel) ===
LG_LIMPIAR_TABLERO         OK
LG_VALIDAR_JUGADA          OK
LG_COLOCAR_FICHA           OK
LG_VERIFICAR_FIN  caso 1  OK
LG_VERIFICAR_FIN  caso 2  OK
LG_VERIFICAR_FIN  caso 3  OK
LG_VERIFICAR_FIN  caso 4  OK
LG_VERIFICAR_FIN  caso 5  OK
LG_VERIFICAR_FIN  caso 6  OK
LG_VERIFICAR_FIN  caso 7  OK
LG_VERIFICAR_FIN  caso 8  OK
LG_VERIFICAR_FIN  caso 9  OK
LG_VERIFICAR_FIN  caso 10  OK
LG_VERIFICAR_FIN  caso 11  OK
LG_VERIFICAR_FIN  caso 12  OK
LG_VERIFICAR_FIN  caso 13  OK
LG_VERIFICAR_FIN  caso 14  OK
LG_VERIFICAR_FIN  caso 15  OK
LG_TURNO_CPU      caso 1  OK
LG_TURNO_CPU      caso 2  OK
LG_TURNO_CPU      caso 3  OK
LG_TURNO_CPU      caso 4  OK
LG_TURNO_CPU      caso 5  OK
LG_TURNO_CPU      caso 6  OK
LG_TURNO_CPU      caso 7  OK

Pruebas ejecutadas: 25   Fallidas: 0

-- program is finished running --
```

### 4.4 Pruebas de sensibilidad (�las pruebas detectan errores?)

Se introdujeron fallos a propósito en una copia del código para comprobar que las pruebas los notan:

| Fallo introducido | Resultado de las pruebas |
|---|---|
| Quitar el chequeo de casilla vacía en `LG_VERIFICAR_FIN` | Fallan varios casos de `LG_VERIFICAR_FIN` (se declaran victorias falsas) |
| Quitar la restauración de `RESULTADO` en `LG_PROBAR_GANADA` | Fallan los casos de `LG_TURNO_CPU` |
| Quitar un `M_POP` en `LG_PROBAR_GANADA` | El programa salta fuera del código (`$ra` equivocado) |
| `ble` en lugar de `blt` en `LG_LIMPIAR_TABLERO` | **No detectado**: la décima escritura cae en `TURNO`, que se reescribe después |

El último caso es una limitación conocida de las pruebas: por eso `LG_LIMPIAR_TABLERO` debe mantener `blt`.

### 4.5 Registro de errores encontrados y soluciones

| # | Error detectado | Impacto | Soluci�n aplicada |
|---|---|---|---|
| 1 | Una tabla de conteo `.word` quedó declarada justo después de datos `.byte` sin `.align 2` (en el programa de prueba) | Desalineaci�n de memoria: `lw` sobre una direcci�n no m�ltiplo de 4 detuvo la ejecuci�n con excepci�n | Agregar `.align 2` antes de cada `.word` que siga a datos de 1 byte. En `gato.s` ya se respeta ese orden (bytes primero, `.align 2`, luego palabras). |
| 2 | Al ensamblar `gato.s` en MARS: `Symbol "IN_LEER_TECLA" not found in symbol table` (l�nea 175) | El programa no ensamblaba | MARS seguía usando la versión de `gato.s` sin el módulo de la vista (743 líneas): el archivo no se había reemplazado en el repo y MARS no recarga archivos cambiados desde fuera. Se reemplazó el archivo por la versión integrada (965 líneas), se comprobó con `findstr /n "IN_LEER_TECLA:"` y se cerró y volvió a abrir en MARS. |
| 3 | Un commit de `gato_kim.asm` se hizo con el archivo vacío (`0 insertions`) | El m�dulo de la vista no quedaba en el historial | El archivo se había creado sin contenido. Se copió el código completo, se verificó el tamaño (245 líneas) antes de hacer un nuevo commit y recién entonces se subió. |

No se registraron otros errores en la lógica durante las pruebas descritas.

#### Riesgos conocidos (sin error observado)

- `LG_COLOCAR_FICHA` no valida: con `$a0` = 10 escribiría un byte despu�s de `TABLERO` (sobre `TURNO`).
  Es seguro mientras se llame despu�s de `LG_VALIDAR_JUGADA`, como hace `ST_JUGADA_JUGADOR`.
- `LG_PROBAR_GANADA` supone `RESULTADO` = 0 al entrar y lo deja en 0; `ST_JUGADA_JUGADOR` solo llama a
  `LG_TURNO_CPU` cuando la partida sigue en curso, as� que se cumple.
- `MODO_PRUEBA` est� en 1 para poder probar los estados; debe ponerse en 0 en el `.data` antes de entregar.
- La vista depende de que `ST_*` y `LG_*` mantengan los valores de `TABLERO` (0, 1, 2), `TURNO` (1, 2) y `RESULTADO` (0-3):
  si cambia esa codificaci�n, `UI_CELDA`, `UI_DIBUJAR_HUD` y `UI_MENSAJE_RESULTADO` deben revisarse.
- La estrategia de la CPU no es perfecta: una "horquilla" (dos amenazas a la vez) puede ganarle. Para modificar la dificultad se puede cambiar el orden de preferencia en `LG_ORDEN`, que solo afecta la jugada de relleno; para una CPU más fácil de vencer también puede quitarse el paso de bloqueo en `LG_TURNO_CPU`.

### 4.6 Pruebas de la vista (manuales)

La vista solo imprime texto en la consola de MARS, por lo que se prueba jugando y comparando lo que aparece en la
ventana *Run I/O* con lo esperado. Cada prueba se hace escribiendo la tecla y pulsando ENTER. Con `MODO_PRUEBA` = 1 las
teclas W, L y D fuerzan victoria, derrota y empate sin jugar una partida completa.

| # | Acci�n | Resultado esperado | Resultado obtenido |
|---|---|---|---|
| 1 | Ensamblar `src/gato.s` (F3) | `Assemble: operation completed successfully` | Correcto (ensambl� sin errores tras reemplazar el archivo; ver error 2) |
| 2 | Ejecutar (F5) | Se muestra el men� con el t�tulo, el marcador m�ximo en 0 y las opciones J, I y Q | Por registrar |
| 3 | `j` | Se muestra el marcador (puntos 0, vidas 3, turno del jugador) y el tablero con los números 1 a 9 | Por registrar |
| 4 | `5` | Aparece X en el centro y luego la O de la CPU | Por registrar |
| 5 | Elegir una casilla ocupada | Se ignora: el tablero no cambia | Por registrar |
| 6 | `p` y luego `p` | Aparece el mensaje de pausa; al repetir vuelve el tablero | Por registrar |
| 7 | `i` desde el men� | Se muestran las instrucciones y al pulsar una tecla vuelve el men� | Por registrar |
| 8 | `w` | Mensaje de partida ganada, +10 puntos en el marcador | Por registrar |
| 9 | `d` | Mensaje de empate, +5 puntos | Por registrar |
| 10 | `l` tres veces | Mensaje de partida perdida, una vida menos cada vez y, al llegar a 0, pantalla de Game Over | Por registrar |
| 11 | Llegar a 50 puntos con `w` | Pantalla de victoria y, si se superó el r�cord, el aviso de nuevo r�cord | Por registrar |
| 12 | `j` o `r` en la pantalla final | Empieza un juego nuevo con puntos y vidas reiniciados y el r�cord conservado | Por registrar |
| 13 | `q` | Vuelve al men�; `q` desde el men� termina el programa | Por registrar |
