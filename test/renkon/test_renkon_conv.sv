`include "renkon.svh"

module test_renkon_conv;

  reg clk;

  renkon_conv dut(.*);

  // clock
  initial begin
    clk = 0;
    forever
      #(STEP/2) clk = ~clk;
  end

  //flow
  initial begin

    $finish();
  end

  //display
  initial begin
    $display("clk: |");
    forever begin
      #(STEP/2-1);
      $display(
        "%d: ", $time/STEP,
        "| ",

        "|"
      );
      #(STEP/2+1);
    end
  end

endmodule
