module tb_async_fifo;

  localparam int DATA_W = 8; 
  localparam int ADDR_W = 4; 
  localparam real WR_PERIOD = 7.0; //ns
  localparam real RD_PERIOD = 3.2; // ns, unrelated to WR_PERIOD

  //---- clocks -----
  logic wr_clk, rd_clk;
  initial begin wr_clk = 1'b0; forever #(WR_PERIOD/2) wr_clk = ~wr_clk; end
  initial begin rd_clk = 1'b0; forever #(RD_PERIOD/2) rd_clk = ~rd_clk; end

  // ---- DUT -----
  logic wr_rst_n, rd_rst_n;
  logic wr_en, rd_en; 
  logic [DATA_W-1:0] wr_data, rd_data; 
  logic wr_full, rd_empty; 

  async_fifo #(.DATA_W(DATA_W), .ADDR_W(ADDR_W)) dut (
    .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .wr_en(wr_en),
    .wr_data(wr_data), .wr_full(wr_full),
    .rd_clk(rd_clk), .rd_rst_n(rd_rst_n), .rd_en(rd_en),
    .rd_data(rd_data), .rd_empty(rd_empty)
  );

  // --- tasks ---
  task automatic reset_dut();
    wr_rst_n = 1'b0;  rd_rst_n = 1'b0;
    wr_en    = 1'b0;  rd_en    = 1'b0;
    wr_data  = '0;
    repeat (4) @(posedge wr_clk);
    repeat (4) @(posedge rd_clk);
    wr_rst_n = 1'b1;  rd_rst_n = 1'b1;   // released at an arbitrary time
    repeat (4) @(posedge wr_clk);        // let reset_sync release
    repeat (4) @(posedge rd_clk);
  endtask

  // one write attempt, accepted = FIFO was not full
  task automatic write_word(input logic [DATA_W-1:0] d, output bit accepted);
    @(negedge wr_clk);
    accepted = !wr_full;
    wr_en    = 1'b1;
    wr_data  = d;
    @(negedge wr_clk);
    wr_en    = 1'b0;
  endtask
  
  // one read attempt, accepted FIFO wasn't empty, d = word popped
  task automatic read_word(output logic [DATA_W-1:0] d, output bit accepted);
    @(negedge rd_clk);
    accepted = !rd_empty;
    d        = rd_data;                  // first-word fall-through
    rd_en    = 1'b1;
    @(negedge rd_clk);
    rd_en    = 1'b0;
  endtask

  // --- test ---
  bit ok; 
  logic [DATA_W-1:0] got; 
  
  initial begin
`ifdef DUMP
    $dumpfile("waves.fst");
    $dumpvars(0, tb_async_fifo);
`endif
    reset_dut();
    if (rd_empty !== 1'b1) $fatal(1, "after reset: rd_empty=%b, want 1", rd_empty);
    if (wr_full  !== 1'b0) $fatal(1, "after reset: wr_full=%b, want 0",  wr_full);
    $display("reset: PASS");

    write_word(8'hA5, ok);
    if (!ok) $fatal(1, "write rejected on an empty FIFO");

    // the write pointer needs a few rd_clk cycles to cross
    repeat (6) @(posedge rd_clk);

    read_word(got, ok);
    if (!ok)          $fatal(1, "read rejected after a write");
    if (got !== 8'hA5) $fatal(1, "read 0x%h, want 0xA5", got);
    $display("one word: PASS");

    $display("smoke: PASS");
    $finish;
  end

  // watchdog: a hung sim fails instead of running forever
  initial begin
    #100_000;
    $fatal(1, "timeout");
  end

endmodule
