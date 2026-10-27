module sync_2ff #(
    parameter int WIDTH = 1
) (
    input logic clk, 
    input logic rst_n, 
    input logic [WIDTH-1:0] d, 
    output logic [WIDTH-1:0] q
);
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] meta; 
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta <= '0;
            sync <= '0;
        end else begin 
            meta <= d;
            sync <= meta;
        end
    end

    assign q = sync; 
endmodule
