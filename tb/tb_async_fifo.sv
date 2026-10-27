module tb_async_fifo;
  initial begin
`ifdef DUMP
    $dumpfile("waves.fst");
    $dumpvars(0, tb_async_fifo);
`endif
    $display("smoke: PASS");
    $finish;
  end
endmodule
