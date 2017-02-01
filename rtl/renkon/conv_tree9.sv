`include "renkon.svh"

module conv_tree9
  ( input                      clk
  , input                      xrst
  , input  signed [DWIDTH-1:0] pixel_in  [9-1:0]
  , input  signed [DWIDTH-1:0] weight    [9-1:0]
  , output signed [DWIDTH-1:0] pixel_out
  );

  wire signed [2*DWIDTH-1:0] pro       [9-1:0];
  wire signed [DWIDTH-1:0]   pro_short [9-1:0];
  wire signed [DWIDTH-1:0] sum0_0;
  wire signed [DWIDTH-1:0] sum0_1;
  wire signed [DWIDTH-1:0] sum0_2;
  wire signed [DWIDTH-1:0] sum0_3;
  wire signed [DWIDTH-1:0] sum1_0;
  wire signed [DWIDTH-1:0] sum1_1;
  wire signed [DWIDTH-1:0] sum2_0;
  wire signed [DWIDTH-1:0] sum3_0;
  wire signed [DWIDTH-1:0] fmap;

  reg signed [DWIDTH-1:0]   r_pixel     [9-1:0];
  reg signed [DWIDTH-1:0]   r_weight    [9-1:0];
  reg signed [2*DWIDTH-1:0] r_pro       [9-1:0];
  reg signed [DWIDTH-1:0]   r_pro_short [9-1:0];
  reg signed [DWIDTH-1:0]   r_sum0_0;
  reg signed [DWIDTH-1:0]   r_sum0_1;
  reg signed [DWIDTH-1:0]   r_sum0_2;
  reg signed [DWIDTH-1:0]   r_sum0_3;
  reg signed [DWIDTH-1:0]   r_sum1_0;
  reg signed [DWIDTH-1:0]   r_sum1_1;
  reg signed [DWIDTH-1:0]   r_sum2_0;
  reg signed [DWIDTH-1:0]   r_sum3_0;
  reg signed [DWIDTH-1:0]   r_pixel_out;

  for (genvar i = 0; i < 9; i++)
    assign pro[i] = r_pixel[i] * r_weight[i];

  for (genvar i = 0; i < 9; i++)
    assign pro_short[i] = round(r_pro[i]);

  assign sum0_0 = r_pro_short[0] + r_pro_short[1];
  assign sum0_1 = r_pro_short[2] + r_pro_short[3];
  assign sum0_2 = r_pro_short[4] + r_pro_short[5];
  assign sum0_3 = r_pro_short[6] + r_pro_short[7];
  assign sum1_0 = sum0_0 + sum0_1;
  assign sum1_1 = sum0_2 + sum0_3;
  assign sum2_0 = sum1_0 + sum1_1;
  assign sum3_0 = sum2_0 + pro_short[8];
  assign fmap = sum3_0;

  assign pixel_out = r_pixel_out;

  for (genvar i = 0; i < 9; i++)
    always @(posedge clk)
      if (!xrst)
        r_pixel[i] <= 0;
      else
        r_pixel[i] <= pixel[i];

  for (genvar i = 0; i < 9; i++)
    always @(posedge clk)
      if (!xrst)
        r_weight[i] <= 0;
      else
        r_weight[i] <= weight[i];

  for (genvar i = 0; i < 9; i++)
    always @(posedge clk)
      if (!xrst)
        r_pro[i] <= 0;
      else
        r_pro[i] <= pro[i];

  for (genvar i = 0; i < 9; i++)
    always @(posedge clk)
      if (!xrst)
        r_pro_short[i] <= 0;
      else
        r_pro_short[i] <= pro_short[i];

  for (genvar i = 0; i < 9; i++)
    always @(posedge clk)
      if (!xrst)
        r_pro_short[i] <= 0;
      else
        r_pro_short[i] <= pro_short[i];

  always @(posedge clk or negedge xrst)
    if(!xrst)
      r_pixel_out <= 0;
    else
      r_pixel_out <= fmap;

////////////////////////////////////////////////////////////
//  Function
////////////////////////////////////////////////////////////

  function signed [DWIDTH-1:0] round;
    input [2*DWIDTH-1:0] data;
    if (data[2*DWIDTH-DWIDTH/2-2] == 1 && data[DWIDTH/2-1:0] == 0)
      round = $signed({
                data[2*DWIDTH-DWIDTH/2-2],
                data[2*DWIDTH-DWIDTH/2-2:DWIDTH/2] - 1
              });
    else
      round = $signed({
                data[2*DWIDTH-DWIDTH/2-2],
                data[2*DWIDTH-DWIDTH/2-2:DWIDTH/2]
              });
  endfunction

endmodule
