// =========================================================================
// MODULE FIFO_BSRAM
// =========================================================================
// Description : FIFO basé sur mémoire BSRAM avec pipeline de latence
//               Utilise une architecture circulaire avec gestion des pointeurs
//               Intègre un pipeline pour gérer la latence de lecture mémoire
//               Optimisé pour une capacité élevée avec latence contrôlée
// =========================================================================

module FIFO_BSRAM #(
    parameter DATA_WIDTH = 11,    // Largeur des données
    parameter MEM_DEPTH = 16,    // Profondeur de la mémoire BSRAM
    parameter LATENCY = 4        // Latence de lecture de la mémoire
)(
    // =========================================================================
    // INTERFACE CLOCK ET RESET
    // =========================================================================
    input  wire                 clk_i,     // Horloge système
    input  wire                 rst_i,     // Reset asynchrone

    // =========================================================================
    // INTERFACE ECRITURE (AVALON-ST)
    // =========================================================================
    input  wire [DATA_WIDTH-1:0] data_i,   // Données à écrire
    input  wire                  valid_i,  // Signal de validité des données
    output wire                  ready_o,  // Signal de prêt à recevoir

    // =========================================================================
    // INTERFACE LECTURE (AVALON-ST)
    // =========================================================================
    output reg [DATA_WIDTH-1:0] data_o,   // Données lues
    output wire                 valid_o,   // Signal de validité des données lues
    input  wire                 ready_i,   // Signal de prêt du consommateur

    // =========================================================================
    // INTERFACE DE MONITORING ET CONTROLE
    // =========================================================================
    output wire                 read_mem_o,        // Signal de lecture mémoire active
    output wire                 mem_full_o,        // Signal mémoire pleine
    output wire                 mem_empty_o,       // Signal mémoire vide
    output wire                 data_in_transit_o  // Signal données en transit (pipeline)
);

    // =========================================================================
    // 1. PARAMETRES LOCAUX
    // =========================================================================
    localparam PTR_WIDTH = $clog2(MEM_DEPTH);  // Largeur des pointeurs mémoire

    // =========================================================================
    // 2. DECLARATIONS DES SIGNAUX INTERNES
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // 2.1 Pointeurs circulaires (+1 bit pour détecter le wrap-around)
    // -------------------------------------------------------------------------
    reg [PTR_WIDTH:0] mem_wr_ptr;      // Pointeur d'écriture mémoire
    reg [PTR_WIDTH:0] mem_rd_ptr;      // Pointeur de lecture mémoire
    
    // -------------------------------------------------------------------------
    // 2.2 Signaux de contrôle et état
    // -------------------------------------------------------------------------
    reg valid_reg;                      // Signal de validité interne
    reg [$clog2(LATENCY):0] latency_counter;  // Compteur de latence pipeline

    // =========================================================================
    // 3. LOGIQUE DE DETECTION D'ETAT (PLEIN/VIDE)
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // 3.1 Détection FIFO pleine
    // Principe : adresses identiques mais bits supplémentaires différents
    // -------------------------------------------------------------------------
    wire mem_full = (mem_wr_ptr[PTR_WIDTH] != mem_rd_ptr[PTR_WIDTH]) && 
                    (mem_wr_ptr[PTR_WIDTH-1:0] == mem_rd_ptr[PTR_WIDTH-1:0]);
    
    // -------------------------------------------------------------------------
    // 3.2 Détection FIFO vide
    // Principe : pointeurs identiques (même adresse et même bit supplémentaire)
    // -------------------------------------------------------------------------
    wire mem_empty = (mem_wr_ptr == mem_rd_ptr);

    // =========================================================================
    // 4. LOGIQUE DE CONTROLE DES INTERFACES
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // 4.1 Signaux de contrôle des opérations mémoire
    // -------------------------------------------------------------------------
    wire mem_write_en = valid_i && !mem_full;    // Écriture si données valides et mémoire non pleine
    wire mem_read_en  = !mem_empty && ready_i;   // Lecture si mémoire non vide et consommateur prêt
    
    // -------------------------------------------------------------------------
    // 4.2 Signaux de sortie des interfaces
    // -------------------------------------------------------------------------
    assign ready_o = !mem_full;                 // Prêt si mémoire non pleine
    assign valid_o = valid_reg;                   // Validité des données lues
    
    // -------------------------------------------------------------------------
    // 4.3 Signaux de monitoring
    // -------------------------------------------------------------------------
    assign mem_full_o = mem_full;                 // État mémoire pleine
    assign mem_empty_o = mem_empty;               // État mémoire vide
    assign data_in_transit_o = (latency_counter > 0);  // Données en transit dans le pipeline

    // =========================================================================
    // 5. GESTION DES POINTEURS D'ECRITURE
    // =========================================================================
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset : initialisation du pointeur d'écriture
            mem_wr_ptr <= 0;
        end else if (mem_write_en) begin
            // Incrémentation avec gestion du wrap-around
            if (mem_wr_ptr[PTR_WIDTH-1:0] == MEM_DEPTH-1) begin
                // Cas limite : rebouclement en changeant le bit supplémentaire
                mem_wr_ptr <= {~mem_wr_ptr[PTR_WIDTH], {PTR_WIDTH{1'b0}}};
            end else begin
                // Incrémentation normale
                mem_wr_ptr <= mem_wr_ptr + 1'b1;
            end
        end
    end

    // =========================================================================
    // 6. GESTION DES POINTEURS DE LECTURE
    // =========================================================================
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset : initialisation du pointeur de lecture
            mem_rd_ptr <= 0;
        end else if (mem_read_en) begin
            // Incrémentation avec gestion du wrap-around
            if (mem_rd_ptr[PTR_WIDTH-1:0] == MEM_DEPTH-1) begin
                // Cas limite : rebouclement en changeant le bit supplémentaire
                mem_rd_ptr <= {~mem_rd_ptr[PTR_WIDTH], {PTR_WIDTH{1'b0}}};
            end else begin
                // Incrémentation normale
                mem_rd_ptr <= mem_rd_ptr + 1'b1;
            end
        end
    end

    // =========================================================================
    // 7. GESTION DU COMPTEUR DE LATENCE PIPELINE
    // =========================================================================
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset : initialisation du compteur de latence
            latency_counter <= 0;
        end else begin
            if (mem_read_en) begin
                // Lecture déclenchée : initialisation du compteur à la latence maximale
                latency_counter <= LATENCY + 2;
            end else if (latency_counter > 0) begin
                // Décrémentation à chaque cycle d'horloge
                latency_counter <= latency_counter - 1'b1;
            end
        end
    end

    // =========================================================================
    // 8. INTERFACE BSRAM - DECLARATIONS DES SIGNAUX
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // 8.1 Port A (écriture uniquement)
    // -------------------------------------------------------------------------
    wire [17:0] data_in_mem_portA;   // Données d'entrée mémoire (18 bits)
    wire [13:0] addr_mem_portA;      // Adresse d'écriture mémoire
    wire wr_en_portA;                // Signal d'écriture mémoire

    // -------------------------------------------------------------------------
    // 8.2 Port B (lecture uniquement)
    // -------------------------------------------------------------------------
    wire [13:0] addr_mem_portB;      // Adresse de lecture mémoire
    wire [17:0] mem_data_out_b;      // Données de sortie mémoire (18 bits)
    wire mem_read_en_portB;          // Signal de lecture mémoire

    // =========================================================================
    // 9. PIPELINE POUR LA LATENCE DE LECTURE
    // =========================================================================
    wire mem_valid_piped;            // Signal de validité pipeliné
    
    pipeline #(
        .LATENCY(LATENCY + 1),       // Latence du pipeline (mémoire + pipeline)
        .BUFF_WIDTH(1)               // Largeur du buffer de pipeline
    ) pipeline_mem_valid (
        .clk_i(clk_i),               // Horloge système
        .data_i(mem_read_en_portB),  // Signal d'entrée du pipeline
        .data_o(mem_valid_piped)     // Signal de sortie pipeliné
    );

    // =========================================================================
    // 10. LOGIQUE DE SORTIE DES DONNEES
    // =========================================================================
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset : initialisation des sorties
            data_o <= 0;
            valid_reg <= 0;
        end else if (mem_valid_piped) begin
            // Données valides du pipeline : extraction des bits significatifs
            data_o <= mem_data_out_b[DATA_WIDTH-1:0];
            valid_reg <= 1'b1;
        end else begin
            // Pas de données valides : sorties à zéro
            data_o <= 0;
            valid_reg <= 1'b0;
        end
    end

    // =========================================================================
    // 11. CONNEXIONS BSRAM
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // 11.1 Connexions Port A (écriture)
    // -------------------------------------------------------------------------
    assign data_in_mem_portA = {7'b0, data_i};  // Zéro-extension si DATA_WIDTH < 18
    assign addr_mem_portA = {4'b0, mem_wr_ptr[PTR_WIDTH-1:0]};  // Adresse sans le bit supplémentaire
    assign wr_en_portA = mem_write_en;          // Signal d'écriture

    // -------------------------------------------------------------------------
    // 11.2 Connexions Port B (lecture)
    // -------------------------------------------------------------------------
    assign addr_mem_portB = {4'b0, mem_rd_ptr[PTR_WIDTH-1:0]};  // Adresse sans le bit supplémentaire
    assign mem_read_en_portB = mem_read_en;     // Signal de lecture

    // =========================================================================
    // 12. INSTANCIATION BSRAM
    // =========================================================================
    BSRAM #(
        .WR_LATENCY(0),             // Latence d'écriture (0 cycle)
        .RD_LATENCY(LATENCY)        // Latence de lecture (paramétrable)
    ) Memoire_FIFO_inst (
        // ---------------------------------------------------------------------
        // Port A (écriture FIFO)
        // ---------------------------------------------------------------------
        .DIA(data_in_mem_portA),    // Données d'entrée
        .ADA(addr_mem_portA),       // Adresse d'écriture
        .BLKSELA(3'b0),             // Sélection de bloc (non utilisée)
        .WREA(wr_en_portA),         // Signal d'écriture
        .CEA(1'b1),                 // Clock enable (toujours actif)
        .CLKA(clk_i),               // Horloge
        .RESETA(rst_i),             // Reset
        .OCEA(1'b0),                // Output enable (lecture désactivée sur port A)
        .DOA(),                     // Sortie données (non connectée)

        // ---------------------------------------------------------------------
        // Port B (lecture FIFO)
        // ---------------------------------------------------------------------
        .DIB(18'b0),                // Données d'entrée (non utilisées pour la lecture)
        .ADB(addr_mem_portB),       // Adresse de lecture
        .BLKSELB(3'b0),             // Sélection de bloc (non utilisée)
        .WREB(1'b0),                // Signal d'écriture (désactivé)
        .CEB(1'b1),                 // Clock enable (toujours actif)
        .CLKB(clk_i),               // Horloge
        .RESETB(rst_i),             // Reset
        .OCEB(mem_read_en_portB),   // Output enable (contrôlé par la logique FIFO)
        .DOB(mem_data_out_b)        // Sortie données
    );

    // =========================================================================
    // 13. INTERFACE DE MONITORING FINALE
    // =========================================================================
    assign read_mem_o = mem_read_en_portB;  // Signal de lecture mémoire active

endmodule
