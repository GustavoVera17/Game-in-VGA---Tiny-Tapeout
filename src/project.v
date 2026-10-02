/*
 * Snake Game para VGA Playground
 * Control: Flechas (Moverse), Start / Botón A (Iniciar y Reiniciar)
 */

`default_nettype none

module tt_um_vga_example(
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Salidas no utilizadas
    assign uio_out = 0;
    assign uio_oe  = 0;

    // Suprimir advertencias de señales no utilizadas
    wire _unused_ok = &{1'b0, ena, ui_in[7], ui_in[3:0], uio_in};

    // Señales VGA
    wire hsync;
    wire vsync;
    reg [1:0] R;
    reg [1:0] G;
    reg [1:0] B;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    // Salida TinyVGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    // Generador de sincronización VGA (640x480 estándar)
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );
    
    // Instancia del controlador (Gamepad Pmod)
    wire inp_start, inp_up, inp_down, inp_left, inp_right, inp_a;

    gamepad_pmod_single driver (
        .rst_n(rst_n),
        .clk(clk),
        .pmod_data(ui_in[6]),
        .pmod_clk(ui_in[5]),
        .pmod_latch(ui_in[4]),
        .b(), .y(), .select(), .x(), .l(), .r(), // No usados
        .start(inp_start),
        .up(inp_up),
        .down(inp_down),
        .left(inp_left),
        .right(inp_right),
        .a(inp_a)
    );

    // ==========================================
    // LÓGICA DEL JUEGO
    // ==========================================

    // Divisor de reloj para la velocidad de la serpiente (~6.6 Hz)
    reg [21:0] tick_counter;
    wire tick = (tick_counter == 22'd13_750_000); 

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) tick_counter <= 0;
        else if (tick) tick_counter <= 0;
        else tick_counter <= tick_counter + 1;
    end

    // Memoria y estado del juego (Máximo 31 segmentos)
    reg [4:0] snake_x [0:31];
    reg [3:0] snake_y [0:31];
    reg [4:0] snake_len;
    
    reg [1:0] dir;       // 0: Arriba, 1: Abajo, 2: Izquierda, 3: Derecha
    reg [1:0] next_dir;
    
    reg [4:0] fruit_x;
    reg [3:0] fruit_y;
    
    reg [1:0] state;     // 0: Pantalla Inicio, 1: Jugando, 2: Game Over

    // Captura de controles (evita giros de 180 grados sobre sí misma)
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            next_dir <= 3;
        end else if (state == 1) begin
            if      (inp_up    && dir != 1) next_dir <= 0;
            else if (inp_down  && dir != 0) next_dir <= 1;
            else if (inp_left  && dir != 3) next_dir <= 2;
            else if (inp_right && dir != 2) next_dir <= 3;
        end
    end

    // LFSR: Generador pseudoaleatorio para las coordenadas de la fruta
    reg [7:0] lfsr;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) lfsr <= 8'hAA;
        else lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end
    
    // Ajuste de escala para que la fruta siempre caiga dentro de la pantalla (Grid de 20x15)
    wire [4:0] rand_x = (lfsr[4:0] < 20) ? lfsr[4:0] : (lfsr[4:0] - 5'd12);
    wire [3:0] rand_y = (lfsr[7:4] < 15) ? lfsr[7:4] : 4'd7;

    // Cálculo de la próxima posición de la cabeza
    wire [4:0] head_x = snake_x[0];
    wire [3:0] head_y = snake_y[0];
    reg  [4:0] next_head_x;
    reg  [3:0] next_head_y;

    always @(*) begin
        next_head_x = head_x;
        next_head_y = head_y;
        case (next_dir)
            0: next_head_y = (head_y == 0) ? 14 : head_y - 1; // Arriba (con wrap)
            1: next_head_y = (head_y == 14) ? 0 : head_y + 1; // Abajo (con wrap)
            2: next_head_x = (head_x == 0) ? 19 : head_x - 1; // Izquierda (con wrap)
            3: next_head_x = (head_x == 19) ? 0 : head_x + 1; // Derecha (con wrap)
        endcase
    end

    // Detección de colisiones (Chocar contra el propio cuerpo)
    reg collision;
    integer j;
    always @(*) begin
        collision = 0;
        for (j = 0; j < 31; j = j + 1) begin
            if (j < snake_len - 1) begin
                if (next_head_x == snake_x[j] && next_head_y == snake_y[j]) begin
                    collision = 1;
                end
            end
        end
    end

    // Máquina de estados principal y actualización de físicas
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= 0;
            snake_len <= 3;
            dir <= 3;
            fruit_x <= 10;
            fruit_y <= 7;
            for (i = 0; i < 32; i = i + 1) begin
                snake_x[i] <= 5; 
                snake_y[i] <= 5;
            end
            snake_x[0] <= 5; snake_y[0] <= 5;
            snake_x[1] <= 4; snake_y[1] <= 5;
            snake_x[2] <= 3; snake_y[2] <= 5;
        end else begin
            if (state == 0) begin // PANTALLA DE INICIO
                if (inp_start || inp_a) begin
                    state <= 1;
                    snake_len <= 3;
                    dir <= 3;
                    fruit_x <= rand_x;
                    fruit_y <= rand_y;
                    snake_x[0] <= 5; snake_y[0] <= 5;
                    snake_x[1] <= 4; snake_y[1] <= 5;
                    snake_x[2] <= 3; snake_y[2] <= 5;
                end
            end else if (state == 1) begin // JUGANDO
                if (tick) begin
                    dir <= next_dir;
                    if (collision) begin
                        state <= 2; // Game Over
                    end else begin
                        // Mover el cuerpo (desplazamiento de posiciones)
                        for (i = 31; i > 0; i = i - 1) begin
                            snake_x[i] <= snake_x[i-1];
                            snake_y[i] <= snake_y[i-1];
                        end
                        // Mover la cabeza
                        snake_x[0] <= next_head_x;
                        snake_y[0] <= next_head_y;

                        // Comer fruta
                        if (next_head_x == fruit_x && next_head_y == fruit_y) begin
                            if (snake_len < 31) snake_len <= snake_len + 1; // Crecer
                            fruit_x <= rand_x; // Nueva fruta aleatoria
                            fruit_y <= rand_y;
                        end
                    end
                end
            end else if (state == 2) begin // GAME OVER
                if (inp_start || inp_a) begin
                    state <= 0; // Volver al inicio para reiniciar
                end
            end
        end
    end

    // ==========================================
    // RENDERIZADO VISUAL (VGA)
    // ==========================================

    // Convertir resolución de píxeles (640x480) a coordenadas del grid (20x15)
    // Cada bloque del grid es de 32x32 píxeles
    wire [4:0] grid_x = pix_x[9:5];
    wire [3:0] grid_y = pix_y[8:5];
    
    // Evaluar si el píxel actual pertenece a la serpiente
    reg is_snake;
    always @(*) begin
        is_snake = 0;
        for (j = 0; j < 31; j = j + 1) begin
            if (j < snake_len && snake_x[j] == grid_x && snake_y[j] == grid_y) begin
                is_snake = 1;
            end
        end
    end

    wire is_fruit = (grid_x == fruit_x && grid_y == fruit_y);
    wire is_grid  = (pix_x[4:0] == 0) || (pix_y[4:0] == 0); // Líneas de la cuadrícula

    // Pintar los colores en pantalla
    always @(posedge clk) begin
        if (~rst_n) begin
            R <= 0; G <= 0; B <= 0;
        end else if (video_active) begin
            if (state == 0) begin
                // Inicio: Fondo Azul Oscuro
                R <= 0; 
                G <= is_snake ? 2'b11 : 0; 
                B <= is_snake ? 2'b00 : 2'b10;
            end else if (state == 2) begin
                // Game Over: Filtro Rojo
                R <= is_snake ? 2'b11 : 2'b01; 
                G <= 0; 
                B <= 0;
            end else begin
                // Jugando normal
                if (is_fruit) begin
                    R <= 2'b11; G <= 0; B <= 0; // Fruta Roja
                end else if (is_snake) begin
                    // Iluminar la cabeza un poco diferente
                    if (grid_x == snake_x[0] && grid_y == snake_y[0]) begin
                        R <= 2'b01; G <= 2'b11; B <= 2'b01; // Cabeza Verde Claro
                    end else begin
                        R <= 0; G <= 2'b10; B <= 0;         // Cuerpo Verde Oscuro
                    end
                end else begin
                    // Fondo con tenue cuadrícula
                    R <= 0; G <= 0; B <= is_grid ? 2'b01 : 2'b00; 
                end
            end
        end else begin
            R <= 0; G <= 0; B <= 0; // Fuera del área de video
        end
    end

endmodule