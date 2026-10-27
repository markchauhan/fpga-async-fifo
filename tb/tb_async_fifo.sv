module tb_async_fifo;

  localparam int DATA_W = 8; 
  localparam int ADDR_W = 4; 
  localparam int DEPTH  = 1 << ADDR_W;
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

  // write d, retrying while the FIFO is full
  task automatic push(input logic [DATA_W-1:0] d);
    bit accepted;
    do write_word(d, accepted); while (!accepted);
  endtask

  // read one word, retrying while the FIFO is empty, and check it
  task automatic pop_expect(input logic [DATA_W-1:0] want);
    logic [DATA_W-1:0] d;
    bit accepted;
    do read_word(d, accepted); while (!accepted);
    if (d !== want) $fatal(1, "pop: got 0x%h, want 0x%h", d, want);
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

    // ---------- Step 11: fill to full ----------
    for (int i = 0; i < DEPTH; i++) begin
      write_word(DATA_W'(i), ok);
      if (!ok) $fatal(1, "write %0d rejected before full", i);
    end
    if (wr_full !== 1'b1) $fatal(1, "wr_full=%b after %0d writes, want 1", wr_full, DEPTH);
    write_word(8'hEE, ok);                       // one too many
    if (ok) $fatal(1, "write accepted while full");
    $display("fill to full: PASS");

    // ---------- Step 12: drain to empty ----------
    repeat (6) @(posedge rd_clk);                // let wr pointer cross
    for (int i = 0; i < DEPTH; i++) begin
      read_word(got, ok);
      if (!ok)                  $fatal(1, "read %0d rejected before empty", i);
      if (got !== DATA_W'(i))   $fatal(1, "read %0d: got 0x%h, want 0x%h", i, got, DATA_W'(i));
    end
    if (rd_empty !== 1'b1) $fatal(1, "rd_empty=%b after %0d reads, want 1", rd_empty, DEPTH);
    read_word(got, ok);                          // one too many
    if (ok) $fatal(1, "read accepted while empty");
    repeat (6) @(posedge wr_clk);                // let rd pointer cross back
    if (wr_full !== 1'b0) $fatal(1, "wr_full stuck at 1 after drain");
    $display("drain to empty: PASS");

    // ---------- Step 13: read and write at the same time ----------
    for (int i = 0; i < DEPTH/2; i++) push(DATA_W'(100 + i));   // half full
    repeat (6) @(posedge rd_clk);
    fork
      for (int i = DEPTH/2; i < DEPTH; i++) push(DATA_W'(100 + i));
      for (int i = 0;       i < DEPTH; i++) pop_expect(DATA_W'(100 + i));
    join
    $display("simultaneous rd/wr: PASS");

    $display("smoke: PASS");
    $finish;
  end

  // watchdog: a hung sim fails instead of running forever
  initial begin
    #100_000;
    $fatal(1, "timeout");
  end

endmodule
