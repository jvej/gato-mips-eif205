# ======================================================================
#  EIF205 - Proyecto 2 - JUEGO DEL GATO (MIPS32 / MARS)
#  Archivo: gato_kim.asm  (SOLO el modulo de KIM: entrada, interfaz, macros)
# ----------------------------------------------------------------------
#  Este archivo NO tiene .data propio: usa las variables y mensajes que
#  define Jeferson (TABLERO, PUNTOS, HIGHSCORE, VIDAS, TURNO, RESULTADO,
#  NUEVO_REC, MSG_*, SEP, LINEA_H, CRLF, STR_CLS). No ensambla solo: la
#  version que se corre y se entrega es src/gato.s, que ya lo incluye.
#
#  RUTINAS QUE ENTREGA KIM (las que Jeferson llama):
#    IN_LEER_TECLA, IN_VACIAR_BUFER,
#    UI_DIBUJAR_TABLERO, UI_DIBUJAR_HUD,
#    UI_PANTALLA_MENU, UI_PANTALLA_AYUDA, UI_PANTALLA_PAUSA,
#    UI_MENSAJE_RESULTADO, UI_PANTALLA_GAMEOVER, UI_PANTALLA_VICTORIA
#
#  CONVENCION: $a0 entrada, $v0 salida, $t* temporales, $s* se guardan
#  en la pila, $ra se guarda si la rutina llama a otra.
#  Las rutinas UI_* SOLO dibujan: leen variables pero no las cambian.
# ======================================================================

.macro M_PRINT_INT(%reg)        # imprime un entero que esta en un registro
    move $a0, %reg
    li   $v0, 1
    syscall
.end_macro

# ======================================================================
#  ENTRADA                                                      [KIM]
# ======================================================================

# IN_LEER_TECLA
# Espera una tecla y la traduce:
#   '1'..'9'  -> 1..9          'J' -> 13 (ENTER)     'Q' -> 27 (ESC)
#   minuscula -> MAYUSCULA     otra letra -> su codigo ASCII (P=80, R=82..)
# Los saltos de linea (10 y 13) se descartan: en MARS el usuario escribe
# la tecla y pulsa ENTER, y ese ENTER llega como un caracter extra.
# Entrada: ninguna     Salida: $v0 = tecla traducida     Usa: $t0 (hoja)
IN_LEER_TECLA:
il_leer:
    li   $v0, 12                # syscall 12 = leer un caracter
    syscall
    li   $t0, 10
    beq  $v0, $t0, il_leer      # ignora '\n'
    li   $t0, 13
    beq  $v0, $t0, il_leer      # ignora '\r'
    li   $t0, 97                # 'a'
    blt  $v0, $t0, il_mayus
    li   $t0, 122               # 'z'
    bgt  $v0, $t0, il_mayus
    addi $v0, $v0, -32          # minuscula -> MAYUSCULA
il_mayus:
    li   $t0, 49                # '1'
    blt  $v0, $t0, il_letras
    li   $t0, 57                # '9'
    bgt  $v0, $t0, il_letras
    addi $v0, $v0, -48          # '1'..'9' -> 1..9
    jr   $ra
il_letras:
    li   $t0, 74                # 'J' -> ENTER
    bne  $v0, $t0, il_q
    li   $v0, 13
    jr   $ra
il_q:
    li   $t0, 81                # 'Q' -> ESC
    bne  $v0, $t0, il_fin
    li   $v0, 27
il_fin:
    jr   $ra

# IN_VACIAR_BUFER
# En MARS no se puede vaciar el buffer de la consola; como
# IN_LEER_TECLA ya descarta los saltos de linea, no hace falta nada.
# Se deja para cumplir el contrato entre modulos.
IN_VACIAR_BUFER:
    jr   $ra

# ======================================================================
#  INTERFAZ: TABLERO Y HUD                                      [KIM]
# ======================================================================

# UI_CELDA: imprime UNA casilla. Entrada: $a0 = indice 0-8
#   vacia -> el numero de casilla (1-9), asi el jugador sabe que teclear
#   1 -> 'X'     2 -> 'O'            Usa: $t0-$t2 (hoja)
UI_CELDA:
    la   $t0, TABLERO
    add  $t0, $t0, $a0
    lb   $t1, 0($t0)
    beqz $t1, uc_vacia
    li   $t2, 1
    beq  $t1, $t2, uc_x
    li   $a0, 79                # 'O'
    j    uc_print
uc_x:
    li   $a0, 88                # 'X'
    j    uc_print
uc_vacia:
    addi $a0, $a0, 49           # indice 0 -> '1', etc.
uc_print:
    li   $v0, 11
    syscall
    jr   $ra

# UI_DIBUJAR_TABLERO: dibuja el tablero 3x3 con separadores
#   1 | 2 | 3
#  ---+---+---
# Usa $s0 (fila) y $s1 (primer indice de la fila); los guarda en la pila.
UI_DIBUJAR_TABLERO:
    M_PUSH($ra)
    M_PUSH($s0)
    M_PUSH($s1)
    li   $s0, 0
udt_fila:
    M_PRINT_CHAR(32)            # margen
    mul  $s1, $s0, 3
    move $a0, $s1
    jal  UI_CELDA
    M_PRINT(SEP)
    addi $a0, $s1, 1
    jal  UI_CELDA
    M_PRINT(SEP)
    addi $a0, $s1, 2
    jal  UI_CELDA
    M_PRINT(CRLF)
    addi $s0, $s0, 1
    li   $t0, 3
    bge  $s0, $t0, udt_fin      # despues de la ultima fila no hay linea
    M_PRINT(LINEA_H)
    j    udt_fila
udt_fin:
    M_POP($s1)
    M_POP($s0)
    M_POP($ra)
    jr   $ra

# UI_DIBUJAR_HUD: PUNTOS / RECORD / VIDAS / TURNO en una linea
UI_DIBUJAR_HUD:
    M_PUSH($ra)
    M_PRINT(MSG_HUD1)
    lw   $t0, PUNTOS
    M_PRINT_INT($t0)
    M_PRINT(MSG_HUD2)
    lw   $t0, HIGHSCORE
    M_PRINT_INT($t0)
    M_PRINT(MSG_HUD3)
    lb   $t0, VIDAS
    M_PRINT_INT($t0)
    M_PRINT(MSG_HUD4)
    lb   $t0, TURNO
    li   $t1, 1
    bne  $t0, $t1, hud_cpu
    M_PRINT(MSG_TJ)
    j    hud_fin
hud_cpu:
    M_PRINT(MSG_TC)
hud_fin:
    M_PRINT(CRLF)
    M_POP($ra)
    jr   $ra

# ======================================================================
#  INTERFAZ: PANTALLAS                                          [KIM]
# ======================================================================

# UI_PANTALLA_MENU: titulo + marcador maximo + opciones
UI_PANTALLA_MENU:
    M_PUSH($ra)
    M_CLS
    M_PRINT(MSG_TITULO)
    M_PRINT(MSG_RECORD)
    lw   $t0, HIGHSCORE
    M_PRINT_INT($t0)
    M_PRINT(CRLF)
    M_PRINT(CRLF)
    M_PRINT(MSG_MENU)
    M_POP($ra)
    jr   $ra

# UI_PANTALLA_AYUDA: muestra instrucciones y espera cualquier tecla
UI_PANTALLA_AYUDA:
    M_PUSH($ra)
    M_CLS
    M_PRINT(MSG_AYUDA)
    jal  IN_LEER_TECLA
    M_POP($ra)
    jr   $ra

# UI_PANTALLA_PAUSA: mensaje de pausa debajo del tablero actual
UI_PANTALLA_PAUSA:
    M_PUSH($ra)
    M_PRINT(MSG_PAUSA)
    M_POP($ra)
    jr   $ra

# UI_MENSAJE_RESULTADO: GANASTE / EMPATE / PERDISTE segun RESULTADO
UI_MENSAJE_RESULTADO:
    M_PUSH($ra)
    lb   $t0, RESULTADO
    li   $t1, RES_JUGADOR
    bne  $t0, $t1, umr_1
    M_PRINT(MSG_GANASTE)
    j    umr_fin
umr_1:
    li   $t1, RES_EMPATE
    bne  $t0, $t1, umr_2
    M_PRINT(MSG_EMPATE)
    j    umr_fin
umr_2:
    M_PRINT(MSG_PERDISTE)
umr_fin:
    M_POP($ra)
    jr   $ra

# UI_PANTALLA_GAMEOVER: fin por quedarse sin vidas
UI_PANTALLA_GAMEOVER:
    M_PUSH($ra)
    M_CLS
    M_PRINT(MSG_GAMEOVER)
    jal  UI_PIE_FINAL
    M_POP($ra)
    jr   $ra

# UI_PANTALLA_VICTORIA: fin por alcanzar la meta de puntos
UI_PANTALLA_VICTORIA:
    M_PUSH($ra)
    M_CLS
    M_PRINT(MSG_VICTORIA)
    jal  UI_PIE_FINAL
    M_POP($ra)
    jr   $ra

# UI_PIE_FINAL (auxiliar): puntos finales, aviso de nuevo record y
# opciones de reinicio. Lo comparten GAME OVER y VICTORIA.
UI_PIE_FINAL:
    M_PUSH($ra)
    M_PRINT(MSG_PTS_FIN)
    lw   $t0, PUNTOS
    M_PRINT_INT($t0)
    M_PRINT(CRLF)
    lb   $t0, NUEVO_REC
    beqz $t0, upf_sin
    M_PRINT(MSG_NUEVOREC)
upf_sin:
    M_PRINT(MSG_REINICIO)
    M_POP($ra)
    jr   $ra
