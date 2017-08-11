`include "renkon.svh"

module test_renkon_ctrl_linebuf_pad;

  reg clk;

  renkon_ctrl_linebuf_pad dut(.*);

  // clock
  initial begin
    clk = 0;
    forever
      #(STEP/2) clk = ~clk;
  end

//==========================================================
// scenario
//==========================================================
// {{{

  initial begin

    $finish();
  end

// }}}
//==========================================================
// tasks
//==========================================================
// {{{

// }}}
//==========================================================
// models
//==========================================================
// {{{

// }}}
//==========================================================
// display
//==========================================================
// {{{

  initial begin
    $display("### test_renkon_ctrl_linebuf_pad");
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

// }}}
endmodule