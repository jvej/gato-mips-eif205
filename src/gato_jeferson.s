# ======================================================================
#  EIF205 - Arquitectura de Computadoras - Proyecto 2
#  JUEGO DEL GATO (TRES EN RAYA) - MIPS32 (MARS)
#  Archivo: gato_jeferson.s  (SOLO el modulo de Jeferson)
# ----------------------------------------------------------------------
#  MODULOS Y RESPONSABLES
#    [JEFERSON] Datos, programa principal, estados, puntuacion, vidas,
#               high score y reinicio              -> prefijo ST_
#    [DANIEL]   Logica del juego                   -> prefijo LG_
#    [KIM]      Entrada, interfaz y macros         -> prefijos IN_ / UI_ / M_
#
#  Este archivo contiene unicamente la parte de JEFERSON (datos, main,
#  estados, puntuacion, vidas, high score y reinicio) mas las macros
#  comunes que su codigo necesita. NO ensambla solo: faltan las rutinas
#  de Daniel (LG_*) y Kim (IN_* / UI_*) listadas al final. Se integra con
#  gato_completo.s o con los modulos finales de cada companero.
# ----------------------------------------------------------------------
#  CONVENCION DE REGISTROS (reemplaza al CF y a AL/AH del 8086)
#    $a0, $a1 : parametros de entrada      $v0 : valor de salida
#    $t0-$t9  : temporales (el que llama NO espera que se conserven)
#    $s0-$s7  : se guardan en la pila si el procedimiento los usa
#    $ra      : se guarda en la pila si el procedimiento llama a otro
#    OJO: M_PRINT, M_PRINT_CHAR, M_DELAY y M_CLS usan $a0 y $v0
#
#  CONTRATO ENTRE MODULOS
#   IN_LEER_TECLA      : espera una tecla. Sale $v0 = 1..9 (digitos),
#                        letra MAYUSCULA, 13 (ENTER) o 27 (ESC)
#                        (en MARS: J = 13, Q = 27, ver nota abajo)
#   IN_VACIAR_BUFER    : descarta teclas pendientes del teclado
#   LG_LIMPIAR_TABLERO : TABLERO = 0, TURNO = 1, RESULTADO = RES_CURSO
#   LG_VALIDAR_JUGADA  : $a0 = casilla (1-9). $v0 = 0 valida, 1 invalida
#   LG_COLOCAR_FICHA   : $a0 = casilla, $a1 = jugador (1 = X, 2 = O)
#   LG_VERIFICAR_FIN   : actualiza RESULTADO (0 curso, 1 jugador, 2 CPU,
#                        3 empate)
#   LG_TURNO_CPU       : el CPU coloca su ficha (O) en el tablero
#   UI_*               : solo dibujan; leen variables pero no las cambian
#
#  NOTA DE TECLADO EN MARS: la consola de MARS no permite escribir ESC
#  ni distinguir ENTER de forma confiable, asi que IN_LEER_TECLA traduce
#  J -> 13 (ENTER) y Q -> 27 (ESC), y descarta los saltos de linea.
#  Se escribe la tecla y se pulsa ENTER en la ventana Run I/O.
# ======================================================================

# ----------------------------------------------------------------------
#  CONSTANTES (.eqv no ocupan memoria)
# ----------------------------------------------------------------------
.eqv EST_MENU      0
.eqv EST_JUEGO     1
.eqv EST_PAUSA     2
.eqv EST_GAMEOVER  3
.eqv EST_VICTORIA  4

.eqv RES_CURSO     0
.eqv RES_JUGADOR   1
.eqv RES_CPU       2
.eqv RES_EMPATE    3

.eqv PTS_VICTORIA  10       # puntos por ganar una partida
.eqv PTS_EMPATE    5        # puntos por empatar
.eqv PTS_META      50       # meta para la victoria del juego
.eqv VIDAS_INI     3        # vidas al iniciar un juego

.eqv K_ENTER       13
.eqv K_ESC         27
.eqv K_P           80
.eqv K_R           82
.eqv K_I           73
.eqv K_W           87
.eqv K_L           76
.eqv K_D           68

# ----------------------------------------------------------------------
#  MACROS COMUNES  (Kim las amplia en K2)
# ----------------------------------------------------------------------
.macro M_PUSH(%r)
    addi $sp, $sp, -4
    sw   %r, 0($sp)
.end_macro

.macro M_POP(%r)
    lw   %r, 0($sp)
    addi $sp, $sp, 4
.end_macro

.macro M_PRINT(%cadena)         # imprime una cadena .asciiz
    la   $a0, %cadena
    li   $v0, 4
    syscall
.end_macro

.macro M_PRINT_CHAR(%c)         # imprime un caracter (codigo ASCII)
    li   $a0, %c
    li   $v0, 11
    syscall
.end_macro

.macro M_CLS                    # "limpia" la consola con 25 saltos de linea
    la   $a0, STR_CLS
    li   $v0, 4
    syscall
.end_macro

.macro M_DELAY(%ms)             # retraso en milisegundos (syscall 32)
    li   $a0, %ms
    li   $v0, 32
    syscall
.end_macro

# ======================================================================
#  SEGMENTO DE DATOS                                        [JEFERSON]
#  Orden pensado para el mapeo de memoria: primero los bytes (16 en total)
#  y luego .align 2, asi las palabras PUNTOS y HIGHSCORE quedan alineadas
#  a 4 bytes (obligatorio en MIPS para lw/sw).
# ======================================================================
.data
# --- variables de 1 byte (desplazamientos 0 - 15 desde TABLERO) ---
TABLERO:      .byte 0,0,0,0,0,0,0,0,0   # 0 vacia, 1 = X (jugador), 2 = O (CPU)
TURNO:        .byte 1                   # 1 jugador, 2 CPU
ESTADO:       .byte 0                   # EST_MENU .. EST_VICTORIA
RESULTADO:    .byte 0                   # RES_CURSO .. RES_EMPATE
VIDAS:        .byte 3
NUEVO_REC:    .byte 0                   # 1 si en este juego se supero el record
SALIR:        .byte 0                   # 1 = terminar el programa
MODO_PRUEBA:  .byte 1                   # 1 = teclas W/L/D fuerzan resultado (poner 0 al entregar)

# --- variables de 1 palabra (alineadas a 4 bytes) ---
.align 2
PUNTOS:       .word 0
HIGHSCORE:    .word 0                   # solo se inicializa al abrir el programa

# --- tabla de las 8 lineas ganadoras (indices de casilla 0-8) ---
LINEAS:       .byte 0,1,2, 3,4,5, 6,7,8, 0,3,6, 1,4,7, 2,5,8, 0,4,8, 2,4,6

# --- mensajes (terminan en NUL con .asciiz) ---
STR_CLS:      .asciiz "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
CRLF:         .asciiz "\n"
SEP:          .asciiz " | "
LINEA_H:      .asciiz "---+---+---\n"
MSG_TITULO:   .asciiz "=== JUEGO DEL GATO (TRES EN RAYA) ===\n\n"
MSG_MENU:     .asciiz "  J = Jugar\n  I = Instrucciones\n  Q = Salir\n\n"
MSG_RECORD:   .asciiz "Marcador maximo: "
MSG_AYUDA:    .asciiz "INSTRUCCIONES\n\nTu eres X y juegas primero. El CPU es O.\nTeclas 1-9: eligen la casilla del tablero.\nP = pausa   R = reiniciar partida   Q = menu\nGanar la partida = +10 puntos. Empate = +5 puntos.\nPerder la partida = -1 vida (empiezas con 3).\nVictoria al llegar a 50 puntos. Game Over sin vidas.\n(Escribe la tecla y pulsa ENTER en la consola)\n\nEscriba una tecla para volver...\n"
MSG_AYUDA_J:  .asciiz "\n[1-9] Casilla  [P] Pausa  [R] Reiniciar partida  [Q] Menu\n"
MSG_PRUEBA:   .asciiz "[MODO PRUEBA]  W = gana  L = pierde  D = empate\n"
MSG_GANASTE:  .asciiz "\nGANASTE la partida! +10 puntos. Escriba una tecla...\n"
MSG_EMPATE:   .asciiz "\nEMPATE. +5 puntos. Escriba una tecla...\n"
MSG_PERDISTE: .asciiz "\nPERDISTE la partida. -1 vida. Escriba una tecla...\n"
MSG_PAUSA:    .asciiz "\n*** PAUSA ***   P = continuar   Q = menu\n"
MSG_GAMEOVER: .asciiz "*** GAME OVER ***\nTe quedaste sin vidas.\n\n"
MSG_VICTORIA: .asciiz "*** VICTORIA! ***\nAlcanzaste la meta de 50 puntos.\n\n"
MSG_PTS_FIN:  .asciiz "Puntos finales: "
MSG_NUEVOREC: .asciiz "\nNUEVO RECORD!\n"
MSG_REINICIO: .asciiz "\nJ o R = jugar de nuevo   Q = menu\n"
MSG_HUD1:     .asciiz "PUNTOS: "
MSG_HUD2:     .asciiz "   RECORD: "
MSG_HUD3:     .asciiz "   VIDAS: "
MSG_HUD4:     .asciiz "   TURNO: "
MSG_TJ:       .asciiz "Jugador (X)"
MSG_TC:       .asciiz "CPU (O)"
MSG_ADIOS:    .asciiz "Hasta luego!\n"

.text
.globl main

# ======================================================================
#  PROGRAMA PRINCIPAL                                       [JEFERSON]
# ======================================================================
main:
    jal  ST_INICIAR
    jal  ST_IR_MENU
mn_bucle:
    lb   $t0, SALIR
    bnez $t0, mn_fin
    jal  IN_LEER_TECLA          # $v0 = tecla traducida
    move $a0, $v0
    jal  ST_DESPACHAR           # actua segun el estado actual
    j    mn_bucle
mn_fin:
    M_CLS
    M_PRINT(MSG_ADIOS)
    li   $v0, 10                # exit
    syscall

# ======================================================================
#  MODULO DE ESTADOS Y PUNTUACION                           [JEFERSON]
# ======================================================================

# ST_INICIAR: valores iniciales (HIGHSCORE solo se pone en 0 aqui)
# Entrada: ninguna   Salida: ninguna   Usa: $t0   (procedimiento hoja)
ST_INICIAR:
    sw   $zero, HIGHSCORE
    sw   $zero, PUNTOS
    li   $t0, VIDAS_INI
    sb   $t0, VIDAS
    sb   $zero, NUEVO_REC
    sb   $zero, SALIR
    jr   $ra

# ST_IR_MENU: pasa al estado MENU y dibuja el menu
ST_IR_MENU:
    M_PUSH($ra)
    li   $t0, EST_MENU
    sb   $t0, ESTADO
    jal  UI_PANTALLA_MENU
    M_POP($ra)
    jr   $ra

# ST_NUEVO_JUEGO: reinicia puntos y vidas (conserva HIGHSCORE) y
# arranca la primera partida. Permite reiniciar sin cerrar MARS.
ST_NUEVO_JUEGO:
    M_PUSH($ra)
    sw   $zero, PUNTOS
    li   $t0, VIDAS_INI
    sb   $t0, VIDAS
    sb   $zero, NUEVO_REC
    jal  ST_NUEVA_PARTIDA
    M_POP($ra)
    jr   $ra

# ST_NUEVA_PARTIDA: tablero limpio, estado JUEGO y pantalla redibujada
ST_NUEVA_PARTIDA:
    M_PUSH($ra)
    jal  LG_LIMPIAR_TABLERO
    li   $t0, EST_JUEGO
    sb   $t0, ESTADO
    jal  ST_REDIBUJAR
    M_POP($ra)
    jr   $ra

# ST_REDIBUJAR: pantalla completa de juego (marcador + tablero + ayuda)
ST_REDIBUJAR:
    M_PUSH($ra)
    M_CLS
    jal  UI_DIBUJAR_HUD
    M_PRINT(CRLF)
    jal  UI_DIBUJAR_TABLERO
    M_PRINT(MSG_AYUDA_J)
    lb   $t0, MODO_PRUEBA
    li   $t1, 1
    bne  $t0, $t1, sr_fin
    M_PRINT(MSG_PRUEBA)
sr_fin:
    M_POP($ra)
    jr   $ra

# ST_DESPACHAR: $a0 = tecla. Llama al manejador del estado actual
ST_DESPACHAR:
    M_PUSH($ra)
    lb   $t0, ESTADO
    li   $t1, EST_MENU
    bne  $t0, $t1, sd_1
    jal  ST_PROC_MENU
    j    sd_fin
sd_1:
    li   $t1, EST_JUEGO
    bne  $t0, $t1, sd_2
    jal  ST_PROC_JUEGO
    j    sd_fin
sd_2:
    li   $t1, EST_PAUSA
    bne  $t0, $t1, sd_3
    jal  ST_PROC_PAUSA
    j    sd_fin
sd_3:
    jal  ST_PROC_FINAL          # GAME_OVER o VICTORIA
sd_fin:
    M_POP($ra)
    jr   $ra

# ST_PROC_MENU: ENTER = jugar, I = instrucciones, ESC = salir ($a0 = tecla)
ST_PROC_MENU:
    M_PUSH($ra)
    li   $t0, K_ENTER
    bne  $a0, $t0, spm_1
    jal  ST_NUEVO_JUEGO
    j    spm_fin
spm_1:
    li   $t0, K_I
    bne  $a0, $t0, spm_2
    jal  UI_PANTALLA_AYUDA
    jal  ST_IR_MENU
    j    spm_fin
spm_2:
    li   $t0, K_ESC
    bne  $a0, $t0, spm_fin
    li   $t1, 1
    sb   $t1, SALIR
spm_fin:
    M_POP($ra)
    jr   $ra

# ST_PROC_JUEGO: P = pausa, R = reiniciar partida, ESC = menu,
# 1-9 = jugada. Con MODO_PRUEBA tambien W / L / D. ($a0 = tecla)
ST_PROC_JUEGO:
    M_PUSH($ra)
    li   $t0, K_P
    bne  $a0, $t0, spj_1
    jal  ST_PAUSAR
    j    spj_fin
spj_1:
    li   $t0, K_R
    bne  $a0, $t0, spj_2
    jal  ST_NUEVA_PARTIDA       # sin penalizacion: solo limpia el tablero
    j    spj_fin
spj_2:
    li   $t0, K_ESC
    bne  $a0, $t0, spj_3
    jal  ST_IR_MENU
    j    spj_fin
spj_3:
    lb   $t0, MODO_PRUEBA
    li   $t1, 1
    bne  $t0, $t1, spj_4
    jal  ST_TECLA_PRUEBA        # $v0 = 1 si la tecla fue W / L / D
    bnez $v0, spj_fin
spj_4:
    jal  ST_JUGADA_JUGADOR      # ignora lo que no sea 1-9
spj_fin:
    M_POP($ra)
    jr   $ra

# ST_PAUSAR: estado PAUSA
ST_PAUSAR:
    M_PUSH($ra)
    li   $t0, EST_PAUSA
    sb   $t0, ESTADO
    jal  UI_PANTALLA_PAUSA
    M_POP($ra)
    jr   $ra

# ST_PROC_PAUSA: P = continuar, ESC = menu (otras teclas se ignoran)
ST_PROC_PAUSA:
    M_PUSH($ra)
    li   $t0, K_P
    bne  $a0, $t0, spp_1
    li   $t1, EST_JUEGO
    sb   $t1, ESTADO
    jal  ST_REDIBUJAR
    j    spp_fin
spp_1:
    li   $t0, K_ESC
    bne  $a0, $t0, spp_fin
    jal  ST_IR_MENU
spp_fin:
    M_POP($ra)
    jr   $ra

# ST_PROC_FINAL: GAME OVER / VICTORIA. ENTER o R = nuevo juego, ESC = menu
ST_PROC_FINAL:
    M_PUSH($ra)
    li   $t0, K_ENTER
    beq  $a0, $t0, spf_nuevo
    li   $t0, K_R
    beq  $a0, $t0, spf_nuevo
    li   $t0, K_ESC
    bne  $a0, $t0, spf_fin
    jal  ST_IR_MENU
    j    spf_fin
spf_nuevo:
    jal  ST_NUEVO_JUEGO
spf_fin:
    M_POP($ra)
    jr   $ra

# ST_JUGADA_JUGADOR: $a0 = tecla. Si es 1-9 y la casilla esta libre,
# juega el jugador y despues el CPU; si la partida termina, la cierra.
# Usa $s0 (tecla); lo guarda en la pila.
ST_JUGADA_JUGADOR:
    M_PUSH($ra)
    M_PUSH($s0)
    move $s0, $a0
    li   $t0, 1
    blt  $s0, $t0, sjj_ret
    li   $t0, 9
    bgt  $s0, $t0, sjj_ret
    move $a0, $s0
    jal  LG_VALIDAR_JUGADA
    bnez $v0, sjj_ret           # casilla ocupada: se ignora
    move $a0, $s0
    li   $a1, 1
    jal  LG_COLOCAR_FICHA
    jal  LG_VERIFICAR_FIN
    lb   $t0, RESULTADO
    bnez $t0, sjj_fin
    li   $t0, 2                 # turno del CPU
    sb   $t0, TURNO
    jal  ST_REDIBUJAR
    M_DELAY(300)
    jal  LG_TURNO_CPU
    jal  LG_VERIFICAR_FIN
    li   $t0, 1
    sb   $t0, TURNO
    lb   $t0, RESULTADO
    bnez $t0, sjj_fin
    jal  ST_REDIBUJAR
    j    sjj_ret
sjj_fin:
    jal  ST_FIN_PARTIDA
sjj_ret:
    M_POP($s0)
    M_POP($ra)
    jr   $ra

# ST_TECLA_PRUEBA: solo MODO_PRUEBA. W = gana, L = pierde, D = empata.
# Entrada $a0 = tecla. Sale $v0 = 1 si la tecla fue una de esas (y ya
# cerro la partida), 0 si no. No modifica $a0 cuando devuelve 0.
ST_TECLA_PRUEBA:
    M_PUSH($ra)
    li   $t0, K_W
    bne  $a0, $t0, stp_1
    li   $t1, RES_JUGADOR
    j    stp_hecho
stp_1:
    li   $t0, K_L
    bne  $a0, $t0, stp_2
    li   $t1, RES_CPU
    j    stp_hecho
stp_2:
    li   $t0, K_D
    bne  $a0, $t0, stp_no
    li   $t1, RES_EMPATE
stp_hecho:
    sb   $t1, RESULTADO
    jal  ST_FIN_PARTIDA
    li   $v0, 1
    j    stp_fin
stp_no:
    li   $v0, 0
stp_fin:
    M_POP($ra)
    jr   $ra

# ST_FIN_PARTIDA: aplica RESULTADO a puntos / vidas / high score y decide
# el siguiente estado (otra partida, VICTORIA o GAME OVER).
ST_FIN_PARTIDA:
    M_PUSH($ra)
    jal  ST_ACTUALIZAR_PUNTOS
    jal  ST_REDIBUJAR           # deja ver la jugada final
    lb   $t0, ESTADO
    li   $t1, EST_JUEGO
    bne  $t0, $t1, sf_final
    jal  UI_MENSAJE_RESULTADO
    jal  IN_VACIAR_BUFER
    jal  IN_LEER_TECLA          # cualquier tecla continua
    jal  ST_NUEVA_PARTIDA
    j    sf_fin
sf_final:
    M_DELAY(600)
    lb   $t0, ESTADO
    li   $t1, EST_VICTORIA
    bne  $t0, $t1, sf_go
    jal  UI_PANTALLA_VICTORIA
    j    sf_fin
sf_go:
    jal  UI_PANTALLA_GAMEOVER
sf_fin:
    M_POP($ra)
    jr   $ra

# ST_ACTUALIZAR_PUNTOS: segun RESULTADO
#   gana jugador -> +PTS_VICTORIA      empate -> +PTS_EMPATE
#   gana CPU     -> -1 vida
# Luego actualiza el record y decide: PUNTOS >= PTS_META -> VICTORIA,
# VIDAS = 0 -> GAME OVER; si no, el estado sigue en JUEGO.
ST_ACTUALIZAR_PUNTOS:
    M_PUSH($ra)
    lb   $t0, RESULTADO
    li   $t1, RES_JUGADOR
    bne  $t0, $t1, sa_1
    lw   $t2, PUNTOS
    addi $t2, $t2, PTS_VICTORIA
    sw   $t2, PUNTOS
    j    sa_rec
sa_1:
    li   $t1, RES_EMPATE
    bne  $t0, $t1, sa_2
    lw   $t2, PUNTOS
    addi $t2, $t2, PTS_EMPATE
    sw   $t2, PUNTOS
    j    sa_rec
sa_2:
    li   $t1, RES_CPU
    bne  $t0, $t1, sa_rec
    lb   $t2, VIDAS
    addi $t2, $t2, -1
    sb   $t2, VIDAS
sa_rec:
    jal  ST_ACTUALIZAR_HIGHSCORE
    lw   $t2, PUNTOS
    li   $t3, PTS_META
    blt  $t2, $t3, sa_vidas
    li   $t4, EST_VICTORIA
    sb   $t4, ESTADO
    j    sa_fin
sa_vidas:
    lb   $t2, VIDAS
    bnez $t2, sa_fin
    li   $t4, EST_GAMEOVER
    sb   $t4, ESTADO
sa_fin:
    M_POP($ra)
    jr   $ra

# ST_ACTUALIZAR_HIGHSCORE: si PUNTOS supera el record lo reemplaza
# Usa $t0-$t2 (procedimiento hoja)
ST_ACTUALIZAR_HIGHSCORE:
    lw   $t0, PUNTOS
    lw   $t1, HIGHSCORE
    ble  $t0, $t1, sh_fin
    sw   $t0, HIGHSCORE
    li   $t2, 1
    sb   $t2, NUEVO_REC
sh_fin:
    jr   $ra

# ======================================================================
#  RUTINAS EXTERNAS QUE ESTE MODULO LLAMA (no son de Jeferson)
#    Daniel : LG_LIMPIAR_TABLERO, LG_VALIDAR_JUGADA, LG_COLOCAR_FICHA,
#             LG_VERIFICAR_FIN, LG_TURNO_CPU
#    Kim    : IN_LEER_TECLA, IN_VACIAR_BUFER, UI_DIBUJAR_TABLERO,
#             UI_DIBUJAR_HUD, UI_PANTALLA_MENU, UI_PANTALLA_AYUDA,
#             UI_PANTALLA_PAUSA, UI_MENSAJE_RESULTADO,
#             UI_PANTALLA_GAMEOVER, UI_PANTALLA_VICTORIA
#  (la firma de cada una esta en el CONTRATO ENTRE MODULOS del inicio)
# ======================================================================
