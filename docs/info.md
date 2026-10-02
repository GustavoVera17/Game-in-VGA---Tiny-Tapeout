## How it works

Este proyecto implementa el clásico juego **Snake** en hardware usando Verilog, generando gráficos en tiempo real a resolución **VGA 640x480 @ 60 Hz** con un reloj de 25.175 MHz.

- **Sincronización VGA y Cuadrícula (`hvsync_generator.v` y `project.v`):** La pantalla de 640x480 se divide en una cuadrícula de **20x15 bloques**, donde cada celda mide **32x32 píxeles** (`pix_x[9:5]` y `pix_y[8:5]`). La salida de color es RGB de 6 bits (`R[1:0]`, `G[1:0]`, `B[1:0]`).
- **Controlador Gamepad (`gamepad_pmod.v`):** Lee señales seriales (`pmod_data` en `ui_in[6]`, `pmod_clk` en `ui_in[5]` y `pmod_latch` en `ui_in[4]`) desde un mando tipo SNES y decodifica las flechas (`Up`, `Down`, `Left`, `Right`) y los botones (`Start`, `A`).
- **Motor del Juego (`project.v`):**
  - **Movimiento:** Un divisor de reloj genera un pulso (`tick`) cada 13,750,000 ciclos (~1.8 pasos/segundo). La serpiente almacena hasta **31 segmentos** y atraviesa los bordes de la pantalla (*wrap-around*).
  - **Fruta Aleatoria:** Un registro de desplazamiento con retroalimentación lineal (**LFSR** de 8 bits) genera coordenadas pseudoaleatorias dentro del tablero de 20x15.
  - **Estados:** `0` (Pantalla de inicio azul), `1` (Jugando: cabeza verde claro, cuerpo verde oscuro, fruta roja y cuadrícula tenue) y `2` (Game Over: pantalla roja al chocar con su propio cuerpo).

## How to test

1. **En el VGA Playground / Hardware:**
   - Configura el reloj a **25.175 MHz** y aplica un pulso de reset (`rst_n = 0` y luego `1`).
   - En la pantalla azul de inicio, presiona **Start** o el botón **A** para comenzar.
   - Usa las **flechas direccionales** para mover la serpiente y comer la fruta roja evitando chocar con tu propia cola.
   - Si pierdes (pantalla roja de Game Over), presiona **Start** o **A** para reiniciar.
2. **Simulación con Cocotb:**
   - En la carpeta `test/`, ejecuta `make -B` para correr `test/test.py`, el cual verifica la sincronización `hsync`/`vsync` y guarda capturas de los cuadros VGA en `test/output/`.

## External hardware

- **TinyVGA PMOD** conectado al puerto de salida (`uo_out[7:0]`).
- **Psychogenic Gamepad PMOD** (adaptador para control de SNES) conectado a los pines de entrada `ui_in[4]` (`latch`), `ui_in[5]` (`clk`) y `ui_in[6]` (`data`).
