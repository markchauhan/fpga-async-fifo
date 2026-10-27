`default_nettype none

module async_fifo #(
    parameter int DATA_W = 8, 
    parameter int ADDR_W = 4
) (
    // write domain
    input logic wr_clk, 
    input logic wr_rst_n, //raw external rest
    input logic wr_en, 
    input logic [DATA_W-1:0] wr_data, 
    output logic wr_full, 

    // read domain
    input logic rd_clk, 
    input logic rd_rst_n, // raw external reset
    input logic rd_en, 
    output logic [DATA_W-1:0] rd_data, 
    output logic rd_empty
);

    localparam int PTR_W = ADDR_W + 1; //extra MSB counts laps

// ----- write domain ----
logic wr_rst_n_sync; 
reset_sync u_wr_rst_sync (
    .clk(wr_clk), .rst_n_async(wr_rst_n), .rst_n_sync(wr_rst_n_sync)
);

logic [PTR_W-1:0] wr_ptr_bin, wr_ptr_bin_next; 
logic [PTR_W-1:0] wr_ptr_gray, wr_ptr_gray_next;
logic [PTR_W-1:0] rd_ptr_gray; //driven by read side
logic [PTR_W-1:0] rd_ptr_gray_in_wr; //rd_ptr_gray synced in wr_clk

logic wr_full_next; 
logic wr_accept; // a write happens this cycle

sync_2ff #(.WIDTH(PTR_W)) u_rd_ptr_to_wr (
    .clk(wr_clk), .rst_n(wr_rst_n_sync), 
    .d(rd_ptr_gray), .q(rd_ptr_gray_in_wr)
);

assign wr_accept = wr_en && !wr_full; 
assign wr_ptr_bin_next = wr_ptr_bin + PTR_W'(wr_accept); 
assign wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;

// Full writer is exactly one lap ahead
//gray code top two bits are inverted and the rest match
assign wr_full_next = (wr_ptr_gray_next ==
                        {~rd_ptr_gray_in_wr[PTR_W-1:PTR_W-2], 
                          rd_ptr_gray_in_wr[PTR_W-3:0]});

always_ff @(posedge wr_clk or negedge wr_rst_n_sync) begin
    if (!wr_rst_n_sync) begin
        wr_ptr_bin <= '0;
        wr_ptr_gray <= '0;
        wr_full <= 1'b0; 
    end else begin 
        wr_ptr_bin <= wr_ptr_bin_next; 
        wr_ptr_gray <= wr_ptr_gray_next; 
        wr_full <= wr_full_next; 
    end
end

logic [ADDR_W-1:0] wr_addr; 
assign wr_addr = wr_ptr_bin[ADDR_W-1:0];

// ----- read domain ----
logic rd_rst_n_sync; 
reset_sync u_rd_rst_sync (
    .clk(rd_clk), .rst_n_async(rd_rst_n), .rst_n_sync(rd_rst_n_sync)
);

logic [PTR_W-1:0] rd_ptr_bin, rd_ptr_bin_next; 
logic [PTR_W-1:0] rd_ptr_gray_next; //
logic [PTR_W-1:0] wr_ptr_gray_in_rd; // wr_ptr_gray synced into rd_clk
logic rd_empty_next; 
logic rd_accept; // read happens this cycle

sync_2ff #(.WIDTH(PTR_W)) u_wr_ptr_to_rd (
    .clk(rd_clk), .rst_n(rd_rst_n_sync), 
    .d(wr_ptr_gray), .q(wr_ptr_gray_in_rd)
);

assign rd_accept = rd_en && !rd_empty; 
assign rd_ptr_bin_next = rd_ptr_bin + PTR_W'(rd_accept);
assign rd_ptr_gray_next = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next; 

// Empty = reader has caught up
assign rd_empty_next = (rd_ptr_gray_next == wr_ptr_gray_in_rd);

 always_ff @(posedge rd_clk or negedge rd_rst_n_sync) begin
    if (!rd_rst_n_sync) begin
        rd_ptr_bin <= '0; 
        rd_ptr_gray <= '0;
        rd_empty <= 1'b1;
    end else begin 
        rd_ptr_bin <= rd_ptr_bin_next; 
        rd_ptr_gray <= rd_ptr_gray_next; 
        rd_empty <= rd_empty_next; 
    end
 end
 
 logic [ADDR_W-1:0] rd_addr; 
 assign rd_addr = rd_ptr_bin[ADDR_W-1:0];

 // -- memory --- 
 localparam int DEPTH = 1 << ADDR_W; 
 logic [DATA_W-1:0] mem [DEPTH]; 

 always_ff @(posedge wr_clk) begin 
    if (wr_accept) mem[wr_addr] <= wr_data; 
 end
 assign rd_data = mem[rd_addr];
 
endmodule
