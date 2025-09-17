module pipeline #(
    parameter LATENCY = 3,
    parameter BUFF_WIDTH = 32
    )(
    input wire                  clk_i,
    input wire [BUFF_WIDTH-1:0] data_i,
    output reg [BUFF_WIDTH-1:0] data_o
    );

    // Registres intermédiaires pour créer le pipeline
    reg [BUFF_WIDTH-1:0] pipeline_regs [LATENCY-2:0];
    
    // Génération du pipeline avec des registres en cascade
    integer i;
    always @(posedge clk_i) begin
        // Premier étage du pipeline
        pipeline_regs[LATENCY-2] <= data_i;
        
        // Étages intermédiaires du pipeline
        for (i = LATENCY - 3; i >= 0; i = i - 1) begin
            pipeline_regs[i] <= pipeline_regs[i+1];
        end
        
        // Sortie du pipeline
        data_o <= pipeline_regs[0];
    end

endmodule