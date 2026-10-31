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

.text

# LG_LIMPIAR_TABLERO: TABLERO = 0, TURNO = 1, RESULTADO = RES_CURSO
# Entrada: ninguna   Salida: ninguna            [ESQUELETO - Modulo 1]
LG_LIMPIAR_TABLERO:
    jr   $ra

# LG_VALIDAR_JUGADA: $a0 = casilla (1-9)
# Salida: $v0 = 0 jugada valida, 1 jugada invalida   [ESQUELETO - Modulo 2]
LG_VALIDAR_JUGADA:
    li   $v0, 1                 # por ahora toda jugada se rechaza
    jr   $ra

# LG_COLOCAR_FICHA: $a0 = casilla (1-9), $a1 = jugador (1 = X, 2 = O)
# Salida: ninguna                                    [ESQUELETO - Modulo 2]
LG_COLOCAR_FICHA:
    jr   $ra

# LG_VERIFICAR_FIN: actualiza RESULTADO (0 curso, 1 jugador, 2 CPU,
# 3 empate).  Entrada: ninguna   Salida: ninguna     [ESQUELETO - Modulo 3]
LG_VERIFICAR_FIN:
    jr   $ra

# LG_TURNO_CPU: la CPU coloca su ficha (O) en una casilla libre
# Entrada: ninguna   Salida: ninguna                 [ESQUELETO - Modulo 4]
LG_TURNO_CPU:
    jr   $ra