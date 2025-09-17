// =========================================================================
// MODULE FIFO_REGISTERS
// =========================================================================
// Description : FIFO rapide basé sur des registres pour servir de cache
//               Utilise une architecture circulaire avec gestion des pointeurs
//               Optimisé pour une latence faible et un débit élevé
// =========================================================================

module FIFO_registers #(
    parameter DATA_WIDTH = 11,    // Largeur des données
    parameter MEM_DEPTH = 16,    // Profondeur mémoire (non utilisée ici)
    parameter LATENCY = 4        // Nombre de registres dans le cache
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
    output wire [DATA_WIDTH-1:0] data_o,   // Données lues
    output wire                 valid_o,   // Signal de validité des données lues
    input  wire                 ready_i    // Signal de prêt du consommateur
);

    // =========================================================================
    // 1. DECLARATIONS DES SIGNAUX INTERNES
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // 1.1 Mémoire cache (registres)
    // -------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] cache [0:LATENCY-1];  // Tableau de registres pour le cache
    
    // -------------------------------------------------------------------------
    // 1.2 Pointeurs circulaires (+1 bit pour détecter le wrap-around)
    // -------------------------------------------------------------------------
    reg [$clog2(LATENCY):0] cache_wr_ptr;      // Pointeur d'écriture
    reg [$clog2(LATENCY):0] cache_rd_ptr;      // Pointeur de lecture
    
    // -------------------------------------------------------------------------
    // 1.3 Signaux de contrôle internes
    // -------------------------------------------------------------------------
    wire valid_reg;                             // Signal de validité interne
    wire cache_write;                           // Signal d'écriture dans le cache
    wire cache_read;                            // Signal de lecture du cache

    // =========================================================================
    // 2. LOGIQUE DE DETECTION D'ETAT (PLEIN/VIDE)
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // 2.1 Détection FIFO pleine
    // Principe : adresses identiques mais bits supplémentaires différents
    // -------------------------------------------------------------------------
    wire cache_full = (cache_wr_ptr[$clog2(LATENCY)] != cache_rd_ptr[$clog2(LATENCY)]) && 
                      (cache_wr_ptr[$clog2(LATENCY)-1:0] == cache_rd_ptr[$clog2(LATENCY)-1:0]);
    
    // -------------------------------------------------------------------------
    // 2.2 Détection FIFO vide
    // Principe : pointeurs identiques (même adresse et même bit supplémentaire)
    // -------------------------------------------------------------------------
    wire cache_empty = (cache_wr_ptr == cache_rd_ptr);

    // =========================================================================
    // 3. LOGIQUE DE CONTROLE DES INTERFACES
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // 3.1 Signaux de contrôle des opérations
    // -------------------------------------------------------------------------
    assign cache_write = valid_i && !cache_full;    // Écriture si données valides et cache non plein
    assign cache_read  = valid_reg && ready_i;      // Lecture si données valides et consommateur prêt
    
    // -------------------------------------------------------------------------
    // 3.2 Signaux de sortie des interfaces
    // -------------------------------------------------------------------------
    assign ready_o = !cache_full;                   // Prêt si cache non plein
    assign valid_o = valid_reg;                      // Validité des données lues
    assign valid_reg = !cache_empty;                 // Validité interne basée sur l'état vide

    // =========================================================================
    // 4. GESTION DES POINTEURS D'ECRITURE
    // =========================================================================
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset : initialisation du pointeur d'écriture
            cache_wr_ptr <= 0;
        end else if (cache_write) begin
            // Incrémentation avec gestion du wrap-around
            if (cache_wr_ptr[$clog2(LATENCY)-1:0] == LATENCY-1) begin
                // Cas limite : rebouclement en changeant le bit supplémentaire
                cache_wr_ptr <= {~cache_wr_ptr[$clog2(LATENCY)], {$clog2(LATENCY){1'b0}}};
            end else begin
                // Incrémentation normale
                cache_wr_ptr <= cache_wr_ptr + 1'b1;
            end
        end
    end

    // =========================================================================
    // 5. ECRITURE DES DONNEES DANS LE CACHE
    // =========================================================================
    integer i;
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset : initialisation de tous les registres du cache
            for (i = 0; i < LATENCY; i = i + 1) begin
                cache[i] <= 0;
            end
        end else if (cache_write) begin
            // Écriture des données à l'adresse pointée par le pointeur d'écriture
            cache[cache_wr_ptr[$clog2(LATENCY)-1:0]] <= data_i;
        end
    end

    // =========================================================================
    // 6. GESTION DES POINTEURS DE LECTURE
    // =========================================================================
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset : initialisation du pointeur de lecture
            cache_rd_ptr <= 0;
        end else if (cache_read && !cache_empty) begin
            // Incrémentation avec gestion du wrap-around
            if (cache_rd_ptr[$clog2(LATENCY)-1:0] == LATENCY-1) begin
                // Cas limite : rebouclement en changeant le bit supplémentaire
                cache_rd_ptr <= {~cache_rd_ptr[$clog2(LATENCY)], {$clog2(LATENCY){1'b0}}};
            end else begin
                // Incrémentation normale
                cache_rd_ptr <= cache_rd_ptr + 1'b1;
            end
        end
    end

    // =========================================================================
    // 7. INTERFACE DE SORTIE DES DONNEES
    // =========================================================================
    assign data_o = cache[cache_rd_ptr[$clog2(LATENCY)-1:0]];  // Lecture des données à l'adresse pointée

endmodule