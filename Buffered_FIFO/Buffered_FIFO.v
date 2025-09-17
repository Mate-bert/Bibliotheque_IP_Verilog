module Buffered_FIFO #(
    parameter DATA_WIDTH = 11,
    parameter MEM_DEPTH = 16,
    parameter LATENCY = 4
)(
    input  wire                 clk_i,
    input  wire                 rst_i,

    // Interface écriture
    input  wire [DATA_WIDTH-1:0] data_i,
    input  wire                  valid_i,
    output wire                  ready_o,

    // Interface lecture
    output wire [DATA_WIDTH-1:0] data_o,
    output wire                 valid_o,
    input  wire                 ready_i
);

    // =========================================================================
    // 1. DÉCLARATIONS DES SIGNAUX INTERNES
    // =========================================================================

    // =========================================================================
    // 1.1 Signaux FIFO_BSRAM
    // =========================================================================
    wire [DATA_WIDTH-1:0] bsram_data_o;
    wire bsram_valid_o;
    wire bsram_ready_o;
    wire bsram_mem_full_o;
    wire bsram_mem_empty_o;
    wire bsram_data_in_transit_o;
    // =========================================================================
    // 1.2 Signaux FIFO_registers
    // =========================================================================
    wire [DATA_WIDTH-1:0] cache_data_o;
    wire cache_valid_o;
    wire cache_ready_o;

    // =========================================================================
    // 1.3 Signaux Credit_box
    // =========================================================================
    wire add_credit_i;
    wire sub_credit_i;
    wire credit_box_rdy_o;

    // =========================================================================
    // 1.4 Signaux de répartition des données
    // =========================================================================
    wire bsram_read_mem_o;
    wire [DATA_WIDTH-1:0] data_for_cache;
    wire [DATA_WIDTH-1:0] data_for_bsram;
    wire data_for_bsram_valid;
    wire data_for_cache_valid;

    // =========================================================================
    // 2. INSTANCIATIONS DES MODULES
    // =========================================================================

    // =========================================================================
    // 2.1 Instanciation FIFO_BSRAM
    // =========================================================================
    FIFO_BSRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .LATENCY(LATENCY)
    ) fifo_bsram_inst (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i(data_for_bsram),
        .valid_i(data_for_bsram_valid),
        .ready_o(bsram_ready_o),

        .data_o(bsram_data_o),
        .valid_o(bsram_valid_o),
        .ready_i(credit_box_rdy_o),

        .mem_full_o(bsram_mem_full_o),
        .mem_empty_o(bsram_mem_empty_o),
        .data_in_transit_o(bsram_data_in_transit_o),
        .read_mem_o(bsram_read_mem_o)
    );

    // =========================================================================
    // 2.2 Instanciation FIFO_registers
    // =========================================================================
    FIFO_registers #(
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .LATENCY(LATENCY)
    ) fifo_registers_inst (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .data_i(data_for_cache),
        .valid_i(data_for_cache_valid),
        .ready_o(cache_ready_o),

        .data_o(cache_data_o),
        .valid_o(cache_valid_o),
        .ready_i(ready_i)
    );

    // =========================================================================
    // 2.3 Instanciation Credit_box
    // =========================================================================
    Credit_box #(
        .CREDIT_WIDTH(LATENCY)
    ) credit_box_inst (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .add_credit_i(add_credit_i),
        .sub_credit_i(sub_credit_i),
        .rdy_o(credit_box_rdy_o)
    );

    // =========================================================================
    // 3. LOGIQUE DE CONTRÔLE
    // =========================================================================

    // =========================================================================
    // 3.1 Gestion des crédits
    // =========================================================================
    assign add_credit_i = cache_valid_o && ready_i;
    assign sub_credit_i = 
        (bsram_mem_empty_o == 1 && valid_i == 1 && credit_box_rdy_o == 1)       ? 1'b1 : // si bsram vide et data_i valide
        (bsram_mem_empty_o == 0 && bsram_read_mem_o == 1 && credit_box_rdy_o == 1) ? 1'b1 : // si bsram pas vide et bsram_data_o valide
                                                                                  1'b0 ;   

    // =========================================================================
    // 3.2 Répartition des données vers le cache
    // =========================================================================
    assign data_for_cache = 
        (bsram_mem_empty_o == 1 && credit_box_rdy_o == 1 && bsram_data_in_transit_o == 0) ? data_i       : // si cache pas plein et bsram vide
        (bsram_mem_empty_o == 1 && bsram_data_in_transit_o == 1)                          ? bsram_data_o : // si cache pas plein et bsram vide et data en transit
        (bsram_mem_empty_o == 1 && bsram_data_in_transit_o == 0)                          ? 11'b0        : // si cache plein et bsram vide
        (bsram_mem_empty_o == 0)                                                          ? bsram_data_o : // si cache pas plein et bsram pas vide
                                                                                            11'b0        ;

    assign data_for_cache_valid = 
        (bsram_mem_empty_o == 1 && credit_box_rdy_o == 1 && bsram_data_in_transit_o == 0) ? valid_i       : // si cache pas plein et bsram vide
        (bsram_mem_empty_o == 1 && bsram_data_in_transit_o == 1)                          ? bsram_valid_o : // si cache pas plein et bsram vide et data en transit
        (bsram_mem_empty_o == 1 && bsram_data_in_transit_o == 0)                          ? 1'b0          : // si cache plein et bsram vide
        (bsram_mem_empty_o == 0)                                                          ? bsram_valid_o : // si cache pas plein et bsram pas vide et data en transit
                                                                                            1'b0          ;

    // =========================================================================
    // 3.3 Répartition des données vers la BSRAM
    // =========================================================================
    assign data_for_bsram = 
        (bsram_mem_empty_o == 1 && credit_box_rdy_o == 0) ? data_i : // si cache plein et bsram vide
        (bsram_mem_empty_o == 1 && credit_box_rdy_o == 1) ? 11'b0  : // si cache pas plein et bsram_vide
        (bsram_mem_empty_o == 0 && credit_box_rdy_o == 1) ? data_i : // si cache pas plein mais bsram pas vide
        (bsram_mem_empty_o == 0 && credit_box_rdy_o == 0) ? data_i : // si cache plein et bsram pas vide
        (bsram_mem_full_o == 1)                           ? 11'b0 : // si bsram pleine
                                                             11'b0; 

    assign data_for_bsram_valid = 
        (bsram_mem_empty_o == 1 && credit_box_rdy_o == 0) ? valid_i : // si cache plein et bsram vide
        (bsram_mem_empty_o == 1 && credit_box_rdy_o == 1) ? 1'b0    :   // si cache pas plein et bsram vide
        (bsram_mem_empty_o == 0 && credit_box_rdy_o == 1) ? valid_i :
        (bsram_mem_empty_o == 0 && credit_box_rdy_o == 0) ? valid_i :
        (bsram_mem_full_o == 1)                           ? 1'b0    :
                                                             1'b0    ;

    // =========================================================================
    // 4. INTERFACE DE SORTIE
    // =========================================================================
    assign valid_o = cache_valid_o;
    assign data_o = cache_data_o;
    assign ready_o = bsram_ready_o;

endmodule
