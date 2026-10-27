module reset_sync (
  input  logic clk,
  input  logic rst_n_async,   // raw external reset
  output logic rst_n_sync     // use this in the domain
);
  (* ASYNC_REG = "TRUE" *) logic rst_meta;
  (* ASYNC_REG = "TRUE" *) logic rst_sync;

  always_ff @(posedge clk or negedge rst_n_async) begin
    if (!rst_n_async) begin
      rst_meta <= 1'b0;
      rst_sync <= 1'b0;
    end else begin
      rst_meta <= 1'b1;
      rst_sync <= rst_meta;
    end
  end

  assign rst_n_sync = rst_sync;
endmodule