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

# ======================================================================
#  PROGRAMA DE PRUEBA DE LA LOGICA (LG_*)          -- NO va en el repo --
#  Reemplaza a main/ST_*/IN_*/UI_* para poder ejecutar solo el modulo de
#  Daniel. Cada caso imprime OK o FALLO en la ventana Run I/O.
# ======================================================================
.data
T_FALLOS:   .word 0                 # cantidad de pruebas fallidas
T_TOTAL:    .word 0                 # cantidad de pruebas ejecutadas

# --- tableros de prueba para LG_VERIFICAR_FIN: 9 bytes tablero + 1 byte esperado
#     (esperado: 0 en curso, 1 gana X, 2 gana O, 3 empate)
T_FIN:
    .byte 1,1,1, 0,0,0, 0,0,0,  1      # fila 1 (X)
    .byte 0,0,0, 1,1,1, 0,0,0,  1      # fila 2 (X)
    .byte 0,0,0, 0,0,0, 1,1,1,  1      # fila 3 (X)
    .byte 1,0,0, 1,0,0, 1,0,0,  1      # columna 1 (X)
    .byte 0,1,0, 0,1,0, 0,1,0,  1      # columna 2 (X)
    .byte 0,0,1, 0,0,1, 0,0,1,  1      # columna 3 (X)
    .byte 1,0,0, 0,1,0, 0,0,1,  1      # diagonal principal (X)
    .byte 0,0,1, 0,1,0, 1,0,0,  1      # diagonal secundaria (X)
    .byte 2,2,2, 0,0,0, 0,0,0,  2      # fila 1 (O)
    .byte 0,0,2, 0,2,0, 2,0,0,  2      # diagonal secundaria (O)
    .byte 0,0,0, 0,0,0, 0,0,0,  0      # tablero vacio
    .byte 1,2,0, 0,1,0, 0,0,2,  0      # partida en curso, sin linea
    .byte 1,1,0, 0,0,0, 0,0,0,  0      # dos X en fila, falta una: sigue
    .byte 1,2,1, 1,2,2, 2,1,1,  3      # tablero lleno sin ganador: empate
    .byte 1,1,1, 2,2,1, 1,2,2,  1      # 9a jugada gana: victoria, no empate
            .align 2               # las palabras deben quedar alineadas a 4
T_FIN_N:    .word 15

# --- tableros de prueba para LG_TURNO_CPU: 9 bytes tablero + 1 byte = casilla
#     (1-9) donde se espera la O nueva; 0 = tablero lleno, no debe cambiar
T_CPU:
    .byte 2,2,0, 1,1,0, 0,0,0,  3      # gana en fila 1 (y NO bloquea la casilla 6)
    .byte 1,1,0, 0,2,0, 0,0,0,  3      # bloquea la fila 1 del jugador
    .byte 1,0,0, 1,0,0, 0,2,2,  7      # bloquea columna 1 (ganar seria 7 tambien)
    .byte 2,0,0, 1,2,0, 1,0,0,  9      # gana en la diagonal principal
    .byte 1,0,0, 0,0,0, 0,0,0,  5      # sin amenazas: toma el centro
    .byte 0,0,0, 0,1,0, 0,0,0,  1      # centro ocupado: toma una esquina
    .byte 1,2,1, 1,2,2, 2,1,1,  0      # tablero lleno: no cambia nada
            .align 2
T_CPU_N:    .word 7

# --- cadenas ---
S_LIMPIAR:  .asciiz "LG_LIMPIAR_TABLERO       "
S_VALIDAR:  .asciiz "LG_VALIDAR_JUGADA        "
S_COLOCAR:  .asciiz "LG_COLOCAR_FICHA         "
S_FIN:      .asciiz "LG_VERIFICAR_FIN  caso "
S_CPU:      .asciiz "LG_TURNO_CPU      caso "
S_OK:       .asciiz "  OK\n"
S_FALLO:    .asciiz "  FALLO  <<<<<<\n"
S_TITULO:   .asciiz "=== PRUEBAS DE LA LOGICA (Daniel) ===\n"
S_RESUMEN:  .asciiz "\nPruebas ejecutadas: "
S_FALLIDAS: .asciiz "   Fallidas: "
S_SUCIO:    .byte 1,2,1,2,1,2,1,2,1          # tablero "sucio" para LIMPIAR

.text
.globl main
main:
    M_PRINT(S_TITULO)

    # ---------------- LG_LIMPIAR_TABLERO ----------------
    la   $a0, S_SUCIO
    jal  T_CARGAR                  # tablero lleno de fichas
    li   $t0, 2
    sb   $t0, TURNO                # turno de la CPU
    li   $t0, 3
    sb   $t0, RESULTADO            # resultado "empate"
    jal  LG_LIMPIAR_TABLERO
    jal  T_CONTAR                  # $v0 = casillas no vacias (debe ser 0)
    move $t5, $v0
    lb   $t6, TURNO                # debe ser 1
    lb   $t7, RESULTADO            # debe ser 0
    li   $a1, 0
    bnez $t5, lm_rep
    li   $t8, 1
    bne  $t6, $t8, lm_rep
    bnez $t7, lm_rep
    li   $a1, 1
lm_rep:
    la   $a0, S_LIMPIAR
    jal  T_REPORTE

    # ---------------- LG_VALIDAR_JUGADA ----------------
    la   $a0, T_FIN                # primer tablero: casillas 1,2,3 ocupadas
    jal  T_CARGAR
    li   $a0, 0
    jal  LG_VALIDAR_JUGADA         # 0 fuera de rango -> 1
    li   $t0, 1
    bne  $v0, $t0, lv_mal
    li   $a0, 10
    jal  LG_VALIDAR_JUGADA         # 10 fuera de rango -> 1
    li   $t0, 1
    bne  $v0, $t0, lv_mal
    li   $a0, -3
    jal  LG_VALIDAR_JUGADA         # negativo -> 1
    li   $t0, 1
    bne  $v0, $t0, lv_mal
    li   $a0, 1
    jal  LG_VALIDAR_JUGADA         # ocupada -> 1
    li   $t0, 1
    bne  $v0, $t0, lv_mal
    li   $a0, 3
    jal  LG_VALIDAR_JUGADA         # ocupada (borde) -> 1
    li   $t0, 1
    bne  $v0, $t0, lv_mal
    li   $a0, 4
    jal  LG_VALIDAR_JUGADA         # libre -> 0
    bnez $v0, lv_mal
    li   $a0, 9
    jal  LG_VALIDAR_JUGADA         # libre (borde) -> 0
    bnez $v0, lv_mal
    li   $a1, 1
    j    lv_rep
lv_mal:
    li   $a1, 0
lv_rep:
    la   $a0, S_VALIDAR
    jal  T_REPORTE

    # ---------------- LG_COLOCAR_FICHA ----------------
    jal  LG_LIMPIAR_TABLERO        # parte de un tablero limpio
    li   $a0, 5
    li   $a1, 1
    jal  LG_COLOCAR_FICHA          # X en el centro
    li   $a0, 1
    li   $a1, 2
    jal  LG_COLOCAR_FICHA          # O en la casilla 1
    li   $a0, 9
    li   $a1, 1
    jal  LG_COLOCAR_FICHA          # X en la casilla 9
    jal  T_CONTAR                  # debe haber exactamente 3 fichas
    move $t5, $v0
    la   $t0, TABLERO
    lb   $t1, 4($t0)               # casilla 5 -> 1
    lb   $t2, 0($t0)               # casilla 1 -> 2
    lb   $t3, 8($t0)               # casilla 9 -> 1
    li   $a1, 0
    li   $t4, 1
    bne  $t1, $t4, cf_rep
    li   $t4, 2
    bne  $t2, $t4, cf_rep
    li   $t4, 1
    bne  $t3, $t4, cf_rep
    li   $t4, 3
    bne  $t5, $t4, cf_rep
    li   $a1, 1
cf_rep:
    la   $a0, S_COLOCAR
    jal  T_REPORTE

    # ---------------- LG_VERIFICAR_FIN (tabla T_FIN) ----------------
    li   $s0, 0                    # $s0 = numero de caso
    la   $s1, T_FIN                # $s1 = puntero al caso actual
tf_bucle:
    lw   $t0, T_FIN_N
    bge  $s0, $t0, tf_fin
    move $a0, $s1
    jal  T_CARGAR
    jal  LG_VERIFICAR_FIN
    lb   $t1, RESULTADO
    lb   $t2, 9($s1)               # resultado esperado
    li   $a1, 0
    bne  $t1, $t2, tf_rep
    li   $a1, 1
tf_rep:
    la   $a0, S_FIN
    addi $a2, $s0, 1               # numero de caso (1..)
    jal  T_REPORTE_N
    addi $s0, $s0, 1
    addi $s1, $s1, 10
    j    tf_bucle
tf_fin:

    # ---------------- LG_TURNO_CPU (tabla T_CPU) ----------------
    li   $s0, 0
    la   $s1, T_CPU
tc_bucle:
    lw   $t0, T_CPU_N
    bge  $s0, $t0, tc_fin
    move $a0, $s1
    jal  T_CARGAR
    jal  T_CONTAR
    move $s2, $v0                  # $s2 = fichas antes
    jal  LG_TURNO_CPU
    jal  T_CONTAR                  # $v0 = fichas despues
    move $s3, $v0
    lb   $s4, 9($s1)               # casilla esperada (0 = sin cambios)
    lb   $s5, RESULTADO            # debe seguir en 0
    li   $a1, 0
    bnez $s5, tc_rep
    beqz $s4, tc_lleno
    addi $t0, $s2, 1
    bne  $s3, $t0, tc_rep          # debe haber exactamente una ficha mas
    la   $t1, TABLERO
    add  $t1, $t1, $s4
    lb   $t2, -1($t1)              # contenido de la casilla esperada
    li   $t3, 2
    bne  $t2, $t3, tc_rep          # debe ser una O
    li   $a1, 1
    j    tc_rep
tc_lleno:
    bne  $s3, $s2, tc_rep          # tablero lleno: no debe cambiar
    li   $a1, 1
tc_rep:
    la   $a0, S_CPU
    addi $a2, $s0, 1
    jal  T_REPORTE_N
    addi $s0, $s0, 1
    addi $s1, $s1, 10
    j    tc_bucle
tc_fin:

    # ---------------- resumen ----------------
    M_PRINT(S_RESUMEN)
    lw   $a0, T_TOTAL
    li   $v0, 1
    syscall
    M_PRINT(S_FALLIDAS)
    lw   $a0, T_FALLOS
    li   $v0, 1
    syscall
    M_PRINT_CHAR(10)
    li   $v0, 10
    syscall

# ---------------------------------------------------------------------
# T_CARGAR: $a0 = direccion de 9 bytes. Copia a TABLERO y pone
# RESULTADO = 0 y TURNO = 1.   (hoja; usa $t0-$t3)
# ---------------------------------------------------------------------
T_CARGAR:
    la   $t0, TABLERO
    li   $t1, 0
tcg_bucle:
    lb   $t2, 0($a0)
    sb   $t2, 0($t0)
    addi $a0, $a0, 1
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    li   $t3, 9
    blt  $t1, $t3, tcg_bucle
    sb   $zero, RESULTADO
    li   $t3, 1
    sb   $t3, TURNO
    jr   $ra

# T_CONTAR: $v0 = cantidad de casillas no vacias de TABLERO  (hoja)
T_CONTAR:
    la   $t0, TABLERO
    li   $t1, 0
    li   $v0, 0
tcn_bucle:
    lb   $t2, 0($t0)
    beqz $t2, tcn_sig
    addi $v0, $v0, 1
tcn_sig:
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    li   $t3, 9
    blt  $t1, $t3, tcn_bucle
    jr   $ra

# T_REPORTE: $a0 = nombre (cadena), $a1 = 1 si paso / 0 si fallo
T_REPORTE:
    M_PUSH($ra)
    M_PUSH($s7)
    move $s7, $a1
    li   $v0, 4
    syscall                        # imprime $a0 (el nombre)
    jal  T_RESULTADO
    M_POP($s7)
    M_POP($ra)
    jr   $ra

# T_REPORTE_N: igual, pero imprime tambien el numero de caso ($a2)
T_REPORTE_N:
    M_PUSH($ra)
    M_PUSH($s7)
    move $s7, $a1
    li   $v0, 4
    syscall                        # nombre
    move $a0, $a2
    li   $v0, 1
    syscall                        # numero de caso
    jal  T_RESULTADO
    M_POP($s7)
    M_POP($ra)
    jr   $ra

# T_RESULTADO: imprime OK/FALLO segun $s7 y actualiza contadores
T_RESULTADO:
    M_PUSH($ra)
    lw   $t0, T_TOTAL
    addi $t0, $t0, 1
    sw   $t0, T_TOTAL
    bnez $s7, tr_ok
    lw   $t0, T_FALLOS
    addi $t0, $t0, 1
    sw   $t0, T_FALLOS
    M_PRINT(S_FALLO)
    j    tr_fin
tr_ok:
    M_PRINT(S_OK)
tr_fin:
    M_POP($ra)
    jr   $ra

# ======================================================================
#  MODULO DE LOGICA DEL JUEGO                                  [DANIEL]
#  Archivo: gato_daniel.s  (SOLO el modulo de Daniel)
#  Prefijos: LG_ para rutinas y constantes, lg_ para etiquetas locales
# ----------------------------------------------------------------------
#  Datos que usa (los define Jeferson en el segmento .data):
#    TABLERO   : 9 bytes, indices 0-8 (0 vacia, 1 = X, 2 = O)
#    TURNO     : 1 jugador, 2 CPU
#    RESULTADO : 0 curso, 1 jugador, 2 CPU, 3 empate
#    LINEAS    : 24 bytes = 8 lineas ganadoras x 3 casillas
# ======================================================================

# --- constantes propias (.eqv no ocupa memoria) ---
.eqv LG_NUM_CASILLAS  9
.eqv LG_NUM_LINEAS    8
.eqv LG_VACIA         0
.eqv LG_FICHA_X       1
.eqv LG_FICHA_O       2
.macro LG_DIR_CASILLA(%dest, %casilla)
    la   %dest, TABLERO
    add  %dest, %dest, %casilla
    addi %dest, %dest, -1
.end_macro

# --- datos propios de la logica ---
.data
# Orden de preferencia de la CPU: centro, esquinas, lados (casillas 1-9)
LG_ORDEN:     .byte 5,1,3,7,9,2,4,6,8

.text

# LG_LIMPIAR_TABLERO: deja el tablero listo para una partida nueva
#   TABLERO[0..8] = 0, TURNO = 1 (empieza el jugador), RESULTADO = RES_CURSO
# Entrada: ninguna   Salida: ninguna
# Usa: $t0-$t3 (procedimiento hoja, no necesita guardar $ra)
LG_LIMPIAR_TABLERO:
    la   $t0, TABLERO           # $t0 = direccion de la casilla 0
    li   $t1, 0                 # $t1 = contador i = 0
    li   $t3, LG_NUM_CASILLAS   # $t3 = 9 (limite del ciclo)
lg_lt_bucle:
    sb   $zero, 0($t0)          # TABLERO[i] = 0
    addi $t0, $t0, 1            # avanza a la siguiente casilla (1 byte)
    addi $t1, $t1, 1            # i = i + 1
    blt  $t1, $t3, lg_lt_bucle  # si i < 9, repite
    li   $t2, 1
    sb   $t2, TURNO             # TURNO = 1 (jugador)
    li   $t2, RES_CURSO
    sb   $t2, RESULTADO         # RESULTADO = 0 (partida en curso)
    jr   $ra

# LG_VALIDAR_JUGADA: $a0 = casilla (1-9)
# Salida: $v0 = 0 jugada valida, 1 jugada invalida
# Invalida si la casilla esta fuera de 1-9 o ya esta ocupada.
# Usa: $t0-$t3 (procedimiento hoja)
LG_VALIDAR_JUGADA:
    li   $v0, 1                 # supone invalida hasta demostrar lo contrario
    li   $t0, 1
    blt  $a0, $t0, lg_vj_fin    # casilla < 1  -> invalida
    li   $t0, LG_NUM_CASILLAS
    bgt  $a0, $t0, lg_vj_fin    # casilla > 9  -> invalida
    LG_DIR_CASILLA($t1, $a0)    # $t1 = &TABLERO[casilla - 1]
    lb   $t3, 0($t1)            # $t3 = contenido de la casilla
    bnez $t3, lg_vj_fin         # distinta de vacia -> ocupada -> invalida
    li   $v0, 0                 # paso todas las pruebas: valida
lg_vj_fin:
    jr   $ra

# LG_COLOCAR_FICHA: $a0 = casilla (1-9), $a1 = jugador (1 = X, 2 = O)
# Escribe la ficha en TABLERO[casilla - 1].
# NO valida: quien llama debe usar LG_VALIDAR_JUGADA antes.
# Usa: $t0 (procedimiento hoja)
LG_COLOCAR_FICHA:
    LG_DIR_CASILLA($t0, $a0)    # $t0 = &TABLERO[casilla - 1]
    sb   $a1, 0($t0)            # TABLERO[casilla - 1] = jugador
    jr   $ra

# LG_VERIFICAR_FIN: revisa el tablero y actualiza RESULTADO
#   1 = gana el jugador (X)   2 = gana la CPU (O)
#   3 = empate (tablero lleno sin ganador)   0 = la partida sigue
# Nota: los valores 1 y 2 de RESULTADO coinciden con las fichas X (1) y
#       O (2), por eso se puede guardar la ficha ganadora directamente.
# Entrada: ninguna   Salida: ninguna
# Usa: $t0-$t6 (procedimiento hoja)
LG_VERIFICAR_FIN:
    la   $t0, LINEAS            # $t0 = puntero a la linea actual en LINEAS
    la   $t1, TABLERO           # $t1 = direccion base de TABLERO
    li   $t2, 0                 # $t2 = numero de linea (0-7)
    li   $t3, LG_NUM_LINEAS     # $t3 = 8
lg_vf_lineas:
    lb   $t4, 0($t0)            # indice de la 1a casilla de la linea
    lb   $t5, 1($t0)            # indice de la 2a casilla
    lb   $t6, 2($t0)            # indice de la 3a casilla
    add  $t4, $t4, $t1          # indice -> direccion en TABLERO
    add  $t5, $t5, $t1
    add  $t6, $t6, $t1
    lb   $t4, 0($t4)            # contenido de la 1a casilla
    lb   $t5, 0($t5)            # contenido de la 2a casilla
    lb   $t6, 0($t6)            # contenido de la 3a casilla
    beqz $t4, lg_vf_sig         # casilla vacia: esta linea no puede ganar
    bne  $t4, $t5, lg_vf_sig    # 1a distinta de 2a: no hay linea
    bne  $t4, $t6, lg_vf_sig    # 1a distinta de 3a: no hay linea
    sb   $t4, RESULTADO         # linea completa: gana quien tenga esa ficha
    jr   $ra
lg_vf_sig:
    addi $t0, $t0, 3            # siguiente linea (cada una ocupa 3 bytes)
    addi $t2, $t2, 1            # numero de linea + 1
    blt  $t2, $t3, lg_vf_lineas # mientras queden lineas por revisar

    # --- ninguna linea ganadora: es empate solo si no queda casilla vacia ---
    li   $t2, 0                 # $t2 = contador de casillas
    li   $t3, LG_NUM_CASILLAS   # $t3 = 9
lg_vf_vacias:
    lb   $t4, 0($t1)            # contenido de la casilla actual
    beqz $t4, lg_vf_curso       # hay una vacia: la partida sigue
    addi $t1, $t1, 1            # siguiente casilla
    addi $t2, $t2, 1
    blt  $t2, $t3, lg_vf_vacias
    li   $t4, RES_EMPATE        # recorrio las 9 y ninguna estaba vacia
    sb   $t4, RESULTADO
    jr   $ra
lg_vf_curso:
    li   $t4, RES_CURSO
    sb   $t4, RESULTADO
    jr   $ra

# LG_PROBAR_GANADA: $a0 = ficha (1 = X, 2 = O)
# Salida: $v0 = casilla (1-9) donde esa ficha completaria una linea,
#         o 0 si no existe ninguna.
# Prueba cada casilla libre: coloca la ficha de forma provisional, llama a
# LG_VERIFICAR_FIN, mira si RESULTADO == ficha y deshace la jugada.
# Supone que RESULTADO = RES_CURSO al entrar (lo restaura al salir).
# Usa $s0 (ficha), $s1 (casilla), $s2 (resultado): se guardan en la pila.
LG_PROBAR_GANADA:
    M_PUSH($ra)
    M_PUSH($s0)
    M_PUSH($s1)
    M_PUSH($s2)
    move $s0, $a0               # $s0 = ficha a probar
    li   $s1, 1                 # $s1 = casilla actual (1-9)
lg_pg_bucle:
    move $a0, $s1
    jal  LG_VALIDAR_JUGADA
    bnez $v0, lg_pg_sig         # ocupada: no se puede probar
    move $a0, $s1
    move $a1, $s0
    jal  LG_COLOCAR_FICHA       # jugada provisional
    jal  LG_VERIFICAR_FIN
    lb   $s2, RESULTADO         # resultado con la jugada provisional
    move $a0, $s1
    li   $a1, LG_VACIA
    jal  LG_COLOCAR_FICHA       # deshace la jugada
    li   $t0, RES_CURSO
    sb   $t0, RESULTADO         # restaura RESULTADO
    beq  $s2, $s0, lg_pg_hallada  # RESULTADO == ficha: esa jugada gana
lg_pg_sig:
    addi $s1, $s1, 1
    li   $t0, LG_NUM_CASILLAS
    ble  $s1, $t0, lg_pg_bucle  # mientras casilla <= 9
    li   $v0, 0                 # ninguna jugada gana
    j    lg_pg_fin
lg_pg_hallada:
    move $v0, $s1               # devuelve la casilla ganadora
lg_pg_fin:
    M_POP($s2)
    M_POP($s1)
    M_POP($s0)
    M_POP($ra)
    jr   $ra

# LG_PRIMERA_LIBRE: recorre LG_ORDEN y devuelve en $v0 la primera casilla
# libre segun esa preferencia, o 0 si el tablero esta lleno.
# Usa $s0 (puntero a LG_ORDEN) y $s1 (contador): se guardan en la pila.
LG_PRIMERA_LIBRE:
    M_PUSH($ra)
    M_PUSH($s0)
    M_PUSH($s1)
    la   $s0, LG_ORDEN          # puntero a la preferencia actual
    li   $s1, 0                 # cuantas se han probado
lg_pl_bucle:
    lb   $a0, 0($s0)            # casilla candidata
    jal  LG_VALIDAR_JUGADA
    beqz $v0, lg_pl_hallada     # 0 = esta libre
    addi $s0, $s0, 1
    addi $s1, $s1, 1
    li   $t0, LG_NUM_CASILLAS
    blt  $s1, $t0, lg_pl_bucle
    li   $v0, 0                 # ninguna libre
    j    lg_pl_fin
lg_pl_hallada:
    lb   $v0, 0($s0)            # devuelve la casilla elegida
lg_pl_fin:
    M_POP($s1)
    M_POP($s0)
    M_POP($ra)
    jr   $ra

# LG_TURNO_CPU: la CPU coloca su ficha (O). Prioridad:
#   1) ganar   2) bloquear al jugador   3) centro, esquinas, lados
# Entrada: ninguna   Salida: ninguna
# No usa $s, pero llama a otras rutinas con jal: guarda $ra en la pila.
LG_TURNO_CPU:
    M_PUSH($ra)
    li   $a0, LG_FICHA_O
    jal  LG_PROBAR_GANADA       # 1) puede ganar la CPU?
    bnez $v0, lg_tc_jugar
    li   $a0, LG_FICHA_X
    jal  LG_PROBAR_GANADA       # 2) ganaria el jugador? (bloquear)
    bnez $v0, lg_tc_jugar
    jal  LG_PRIMERA_LIBRE       # 3) preferencias
    beqz $v0, lg_tc_fin         # tablero lleno: no hay nada que jugar
lg_tc_jugar:
    move $a0, $v0
    li   $a1, LG_FICHA_O
    jal  LG_COLOCAR_FICHA
lg_tc_fin:
    M_POP($ra)
    jr   $ra