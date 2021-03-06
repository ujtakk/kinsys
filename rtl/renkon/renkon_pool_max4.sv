`include "renkon.svh"

module renkon_pool_max4
  ( input                      clk
  , input                      xrst
  , input  signed [DWIDTH-1:0] pixel [4-1:0]
  , output signed [DWIDTH-1:0] pmap
  );

  wire signed [DWIDTH-1:0] max0_0;
  wire signed [DWIDTH-1:0] max0_1;
  wire signed [DWIDTH-1:0] max1_0;

  reg signed [DWIDTH-1:0] pixel$ [4-1:0];

  assign max0_0 = (pixel$[0] > pixel$[1])
                ? pixel$[0]
                : pixel$[1];

  assign max0_1 = (pixel$[2] > pixel$[3])
                ? pixel$[2]
                : pixel$[3];

  assign max1_0 = (max0_0 > max0_1)
                ? max0_0
                : max0_1;

  assign pmap = max1_0;

  for (genvar i = 0; i < 4; i++)
    always @(posedge clk)
      if (!xrst)
        pixel$[i] <= 0;
      else
        pixel$[i] <= pixel[i];

endmodule
