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