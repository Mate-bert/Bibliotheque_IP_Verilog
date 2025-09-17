module Credit_box #(
    parameter CREDIT_WIDTH = 4
)(
    input  wire clk_i,
    input  wire rst_i,
    input wire add_credit_i,
    input wire sub_credit_i,

    output wire rdy_o
);

    reg [$clog2(CREDIT_WIDTH):0] credit_reg;

    always @(posedge clk_i) begin
        if (rst_i) begin
            credit_reg <= CREDIT_WIDTH;
        end else begin
            if (add_credit_i && sub_credit_i) begin
                credit_reg <= credit_reg;
            end else if (add_credit_i) begin
                if (credit_reg < CREDIT_WIDTH) begin
                    credit_reg <= credit_reg + 1;
                end else begin
                    credit_reg <= CREDIT_WIDTH;
                end
            end else if (sub_credit_i) begin
                if (credit_reg > 0) begin
                    credit_reg <= credit_reg - 1;
                end else begin
                    credit_reg <= 0;
                end
            end
        end
    end

    assign rdy_o = (credit_reg > 0 && credit_reg <= CREDIT_WIDTH);
endmodule