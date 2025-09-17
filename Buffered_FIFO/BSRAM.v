// -----------------------------------------------------------------------------
// Module : BSRAM (True Dual Port, gestion de latence par pipeline)
// Description : Bloc mémoire synchrone à deux ports indépendants (A et B)
//              Interface conforme au schéma DPX9B fourni
//              Latence lecture/écriture gérée par pipeline
// -----------------------------------------------------------------------------

module BSRAM #(
    parameter WR_LATENCY = 2,
    parameter RD_LATENCY = 2
    ) (
    // Port A
    input  [17:0] DIA,
    input  [13:0] ADA,
    input  [2:0]  BLKSELA,
    input         WREA,
    input         CEA,
    input         CLKA,
    input         RESETA,
    input         OCEA,
    output reg [17:0] DOA,

    // Port B
    input  [17:0] DIB,
    input  [13:0] ADB,
    input  [2:0]  BLKSELB,
    input         WREB,
    input         CEB,
    input         CLKB,
    input         RESETB,
    input         OCEB,
    output reg [17:0] DOB
);

    // Adresse totale = BLKSEL (3 bits) + ADDR (14 bits) = 17 bits
    //wire [16:0] addrA = {BLKSELA, ADA};
    wire [9:0] addrA = ADA[9:0];
    //wire [16:0] addrB = {BLKSELB, ADB};
    wire [9:0] addrB = ADB[9:0];

    reg [17:0] mem [0:1024]; 

    wire [9:0] rd_addr_a_pip;
    wire        rd_oe_a_pip;

    wire [9:0] rd_addr_b_pip;
    wire        rd_oe_b_pip;

    
    // -------------------- LOGIQUE MEMOIRE --------------------
    // Port A
    always @(posedge CLKA) begin
        if (RESETA)
            DOA <= 18'b0;
        else begin
            if (WREA)
                mem[addrA] <= DIA;
            if (rd_oe_a_pip)
                DOA <= mem[rd_addr_a_pip];
            else 
                DOA <= 18'b0;
        end
    end

    // Port B
    always @(posedge CLKB) begin
        if (RESETB)
            DOB <= 18'b0;
        else begin
            if (WREB)
                mem[addrB] <= DIB;
            if (rd_oe_b_pip)
                DOB <= mem[rd_addr_b_pip];
            else
                DOB <= 18'b0;
        end
    end


    // -------------------- PIPELINES PORT A --------------------



    pipeline #(
        .LATENCY(RD_LATENCY),
        .BUFF_WIDTH(10)
    ) pipeline_rd_addr_a (
        .clk_i(CLKA),
        .data_i(addrA),
        .data_o(rd_addr_a_pip)
    );
    pipeline #(
        .LATENCY(RD_LATENCY),
        .BUFF_WIDTH(1)
    ) pipeline_rd_oe_a (
        .clk_i(CLKA),
        .data_i(OCEA & CEA),
        .data_o(rd_oe_a_pip)
    );

    // -------------------- PIPELINES PORT B --------------------

    pipeline #(
        .LATENCY(RD_LATENCY),
        .BUFF_WIDTH(10)
    ) pipeline_rd_addr_b (
        .clk_i(CLKB),
        .data_i(addrB),
        .data_o(rd_addr_b_pip)
    );
    pipeline #(
        .LATENCY(RD_LATENCY),
        .BUFF_WIDTH(1)
    ) pipeline_rd_oe_b (
        .clk_i(CLKB),
        .data_i(OCEB & CEB),
        .data_o(rd_oe_b_pip)
    );

endmodule 