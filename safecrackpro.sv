// MODULO 1: Decodificador de 7 segmentos (display de anodo comum, 0 acende)
// seg[6]=a ... seg[0]=g

module bcd_to_7segment_anodo (
    input  logic [3:0] bcd,
    output logic [6:0] seg
);
    always_comb begin
        case (bcd)
            4'd0: seg = 7'b0000001;
            4'd1: seg = 7'b1001111;
            4'd2: seg = 7'b0010010;
            4'd3: seg = 7'b0000110;
            4'd4: seg = 7'b1001100;
            4'd5: seg = 7'b0100100;
            4'd6: seg = 7'b0100000;
            4'd7: seg = 7'b0001111;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0000100;
            default: seg = 7'b1111110; // hifen
        endcase
    end
endmodule

// MODULO 2: Maquina de estados do cofre
module safecrackpro_fsm (
    input  logic            clk, // define o clock como 50
    input  logic            rstn, // define o reset
    input  logic [2:0]      btn, //define os botoes que serao usados da placa: btn[0]=KEY1, btn[1]=KEY2, btn[2]=KEY3
    output logic [3:0][3:0] digits, // os 4 digitos da senha
    output logic [1:0]      current_position_idx,  // indica qual digita esta edicao (1 a 4)
    output logic [17:0]     led_red, // leds vermelhos usados
    output logic [8:0]      led_green // leds verdes usados
);

    typedef enum logic [6:0] {
        DIGITO_0 = 7'b0000001, // edita o primeiro numero
        DIGITO_1 = 7'b0000010, // edita o segundo numero
        DIGITO_2 = 7'b0000100, // edita o terceiro numero
        DIGITO_3 = 7'b0001000, // edita o ultimo digito
        VERIFICA = 7'b0010000, // compara a senha certa com a senha inserida
        ABERTO   = 7'b0100000, // senha correta, acende os leds verdes
        FALHA    = 7'b1000000 // senha errada, acende os leds vermelhos
    } state_t;

    state_t state; // guarda o estado atual do cofre

    localparam logic [15:0] SENHA = {4'd4, 4'd3, 4'd2, 4'd1};   // senha certa (1-2-3-4), cada digito com 4 bits
    localparam int TEMPO_VERDE    = 5 * 50_000_000;             // 5 s com clock de 50MHz
    localparam int TEMPO_VERMELHO = 3 * 50_000_000;             // 3 s com clock de 50MHz

    logic [2:0] btn_antes;                                      // guarda como os botoes estavam no ciclo anterior
    logic       aperta_confirma, aperta_soma, aperta_subtrai;   // ficam em 1 so no ciclo em que o botao e apertado
    logic [$clog2(TEMPO_VERDE)-1:0] led_time_cnt;               // contador do tempo dos LEDs

    
    assign aperta_confirma = btn_antes[0] & ~btn[0];            // KEY1: confirma o digito e passa pro proximo
    assign aperta_soma     = btn_antes[1] & ~btn[1];            // KEY2: soma 1 no digito
    assign aperta_subtrai  = btn_antes[2] & ~btn[2];            // KEY3: subtrai 1 do digito

    always_ff @(posedge clk or negedge rstn) begin // roda a cada clock, com o reset agindo na hora
        if (~rstn) begin // reset apertado (ativo em baixo): volta tudo pro inicio
            btn_antes            <= 3'b000; // limpa os botoes
            digits               <= 0; // zera a senha digitada
            current_position_idx <= 0; // volta pro primeiro digito
            led_time_cnt         <= 0; // zera o contador de tempo dos leds
            state                <= DIGITO_0; // comeca editando o primeiro digito
        end
        else begin // reset solto: funcionamento normal
            btn_antes <= btn; // guarda os botoes para detectar o aperto no proximo

            case (state) // escolhe o que fazer de acordo com o estado atual

                DIGITO_0: begin // edicao do primeiro digito
                    if (aperta_confirma) begin // KEY1: confirma
                        state                <= DIGITO_1; // passa para o segundo digito
                        current_position_idx <= 1; // atualiza a posicao mostrada no display
                    end
                    else if (aperta_soma) begin // KEY2: aumenta o digito em 1
                        if (digits[0] == 9) digits[0] <= 0; // 9 vira 0
                        else                digits[0] <= digits[0] + 1; // senao, soma 1
                    end
                    else if (aperta_subtrai) begin // KEY3: diminui o digito em 1
                        if (digits[0] == 0) digits[0] <= 9; // 0 vira 9
                        else                digits[0] <= digits[0] - 1; // senao, subtrai 1
                    end
                end

                DIGITO_1: begin // segundo digito: mesma logica do DIGITO_0
                    if (aperta_confirma) begin
                        state                <= DIGITO_2;
                        current_position_idx <= 2;
                    end
                    else if (aperta_soma) begin
                        if (digits[1] == 9) digits[1] <= 0;
                        else                digits[1] <= digits[1] + 1;
                    end
                    else if (aperta_subtrai) begin
                        if (digits[1] == 0) digits[1] <= 9;
                        else                digits[1] <= digits[1] - 1;
                    end
                end

                DIGITO_2: begin // terceiro digito: mesma logica do DIGITO_0
                    if (aperta_confirma) begin
                        state                <= DIGITO_3;
                        current_position_idx <= 3;
                    end
                    else if (aperta_soma) begin
                        if (digits[2] == 9) digits[2] <= 0;
                        else                digits[2] <= digits[2] + 1;
                    end
                    else if (aperta_subtrai) begin
                        if (digits[2] == 0) digits[2] <= 9;
                        else                digits[2] <= digits[2] - 1;
                    end
                end

                DIGITO_3: begin 
                    if (aperta_confirma) begin
                        state <= VERIFICA; // ultimo digito: não avança posição, vai conferir a senha
                    end
                    else if (aperta_soma) begin
                        if (digits[3] == 9) digits[3] <= 0; // soma com volta: 9 vira 0
                        else                digits[3] <= digits[3] + 1;
                    end
                    else if (aperta_subtrai) begin
                        if (digits[3] == 0) digits[3] <= 9;
                        else                digits[3] <= digits[3] - 1;
                    end
                end

                VERIFICA: begin // dura só um ciclo: compara e escolhe o proximo estado
                    if (digits == SENHA) begin // senha digitada igual a senha correta
                        led_time_cnt <= TEMPO_VERDE - 1; // carrega 5s (-1 porque conta até 0)
                        state        <= ABERTO;
                    end
                    else begin // senha errada
                        led_time_cnt <= TEMPO_VERMELHO - 1;
                        state        <= FALHA;
                    end
                end

                ABERTO: begin  // senha certa: leds verdes acesos por 5s
                    if (led_time_cnt > 0) led_time_cnt <= led_time_cnt - 1; // conta pra tras 1 por clock
                    else begin // acabou o tempo: volta pro inicio
                        digits               <= 0;
                        current_position_idx <= 0;
                        state                <= DIGITO_0;
                    end
                end

                FALHA: begin // senha errada: leds vermelhos acesos por 3s
                    if (led_time_cnt > 0) led_time_cnt <= led_time_cnt - 1; // mesma contagem, só que de 3s
                    else begin
                        digits               <= 0;
                        current_position_idx <= 0;
                        state                <= DIGITO_0;
                    end
                end

                default: begin // se cair em estado inválido, volta pro inicio
                    digits               <= 0;
                    current_position_idx <= 0;
                    state                <= DIGITO_0;
                end

            endcase
        end
    end

    // saída dos LEDs:lógica combinacional que depende só do estado atual. Verde = ABERTO , vermelho = FALHA
    assign led_green = (state == ABERTO) ? 9'b111111111 : 9'b000000000; 
    assign led_red   = (state == FALHA)  ? 18'b111111111111111111 : 18'b000000000000000000;

endmodule



// MODULO 3 (TOP): liga a FSM aos displays. Este e o modulo principal do projeto.

module safecrackpro_top (
    input  logic        clk,
    input  logic        rstn,
    input  logic [2:0]  btn,
    output logic [6:0]  seg_pos1,      // HEX3: 1o digito da senha
    output logic [6:0]  seg_pos2,      // HEX2: 2o digito
    output logic [6:0]  seg_pos3,      // HEX1: 3o digito
    output logic [6:0]  seg_pos4,      // HEX0: 4o digito
    output logic [6:0]  seg_cur_pos,   // HEX4: posicao atual
    output logic [17:0] led_red,       // 18 LEDs vermelhos (senha errada)
    output logic [8:0]  led_green      // 9 LEDs verdes (senha correta)
);

    logic [3:0][3:0] digits;
    logic [1:0]      position;

    safecrackpro_fsm fsm_inst (
        .clk                  (clk),
        .rstn                 (rstn),
        .btn                  (btn),
        .digits               (digits),
        .current_position_idx (position),
        .led_red              (led_red),
        .led_green            (led_green)
    );

    bcd_to_7segment_anodo dec_pos1    (.bcd(digits[0]), .seg(seg_pos1));
    bcd_to_7segment_anodo dec_pos2    (.bcd(digits[1]), .seg(seg_pos2));
    bcd_to_7segment_anodo dec_pos3    (.bcd(digits[2]), .seg(seg_pos3));
    bcd_to_7segment_anodo dec_pos4    (.bcd(digits[3]), .seg(seg_pos4));
    bcd_to_7segment_anodo dec_cur_pos (.bcd({2'b00, position} + 4'd1), .seg(seg_cur_pos));

endmodule
