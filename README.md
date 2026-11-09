# Juego del Gato - MIPS32 (MARS)

## Descripción

Proyecto desarrollado en lenguaje ensamblador MIPS32 utilizando MARS para el curso EIF205.

El juego consiste en una versión de tres en raya donde el jugador utiliza X y compite contra la computadora, que utiliza O.

## Integrantes

- Jeferson Sánchez Sánchez
- Daniel Centeno Gutiérrez
- Kimberly Ángulo Mendoza

## Requisitos

- MARS 4.5 o superior.
- Java instalado.


## Cómo ejecutar el proyecto

1. Abrir MARS.
2. Seleccionar File → Open.
3. Abrir el archivo `src/gato.s`.
4. Presionar Assemble (F3).
5. Presionar Run (F5).
6. Utilizar la consola Run I/O para ingresar las teclas.

## Cómo jugar

El jugador utiliza X y comienza la partida.

La computadora utiliza O y responde automáticamente después de cada jugada.

El tablero utiliza las posiciones del 1 al 9:

```text
 1 | 2 | 3
---+---+---
 4 | 5 | 6
---+---+---
 7 | 8 | 9
```

El jugador debe ingresar el número correspondiente a la casilla donde desea colocar su ficha.

## Teclas

| Tecla | Función |
|---|---|
| J | Iniciar juego |
| I | Mostrar instrucciones |
| Q | Salir o volver al menú |
| 1-9 | Seleccionar casilla |
| P | Pausar partida |
| R | Reiniciar partida |
| W | Forzar victoria en modo prueba |
| L | Forzar derrota en modo prueba |
| D | Forzar empate en modo prueba |

Las teclas W, L y D solo están disponibles cuando `MODO_PRUEBA = 1`.

## Sistema de puntos y vidas

- Victoria: +10 puntos.
- Empate: +5 puntos.
- Derrota: se pierde una vida.
- El jugador inicia con 3 vidas.
- La meta de victoria es alcanzar 50 puntos.
- El juego termina cuando se pierden todas las vidas.

## Archivos principales

- `src/gato.s`: programa integrado que se ejecuta en MARS.
- `src/gato_kim.asm`: módulo de entrada e interfaz de Kim.
- `pruebas/prueba_logica.asm`: pruebas de la lógica.
- `INFORME_TECNICO.md`: documentación técnica del proyecto.
