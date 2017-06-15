`include "gobou.svh"

module gobou_ctrl_core
  ( input                       clk
  , input                       xrst
  , ctrl_bus.slave              in_ctrl
  , input                       req
  , input  [GOBOU_CORELOG-1:0]  net_sel
  , input                       net_we
  , input  [GOBOU_NETSIZE-1:0]  net_addr
  , input  [IMGSIZE-1:0]        in_offset
  , input  [IMGSIZE-1:0]        out_offset
  , input  [GOBOU_NETSIZE-1:0]  net_offset
  , input  [LWIDTH-1:0]         total_out
  , input  [LWIDTH-1:0]         total_in
  , input  signed [DWIDTH-1:0]  out_wdata
  , ctrl_bus.master             out_ctrl
  , output                      ack
  , output                      img_we
  , output [IMGSIZE-1:0]        img_addr
  , output signed [DWIDTH-1:0]  img_wdata
  , output [GOBOU_CORE-1:0]     mem_net_we
  , output [GOBOU_NETSIZE-1:0]  mem_net_addr
  , output                      breg_we
  , output                      serial_we
  );

  wire                s_weight_end;
  wire                s_bias_end;
  wire                s_output_end;
  wire                final_iter;
  wire [IMGSIZE-1:0]  w_img_addr;
  wire [IMGSIZE-1:0]  w_img_offset;

  enum reg [2-1:0] {
    S_WAIT, S_WEIGHT, S_BIAS, S_OUTPUT
  } r_state;
  ctrl_reg          r_out_ctrl;
  reg               r_ack;
  reg [LWIDTH-1:0]  r_total_out;
  reg [LWIDTH-1:0]  r_total_in;
  reg [LWIDTH-1:0]  r_count_out;
  reg [LWIDTH-1:0]  r_count_in;
  reg               r_img_we;
  reg [IMGSIZE-1:0] r_in_offset;
  reg [IMGSIZE-1:0] r_out_offset;
  reg [IMGSIZE-1:0] r_input_addr;
  reg [IMGSIZE-1:0] r_output_addr;
  reg [GOBOU_CORE-1:0]    r_net_we;
  reg [GOBOU_NETSIZE-1:0] r_net_addr;
  reg [GOBOU_NETSIZE-1:0] r_net_offset;
  reg               r_breg_we;
  reg               r_serial_we;
  reg [LWIDTH-1:0]  r_serial_cnt;

  assign final_iter = r_state == S_OUTPUT
                   && r_count_out + GOBOU_CORE >= r_total_out;

  always @(posedge clk)
    if (!xrst) begin
      r_state     <= S_WAIT;
      r_count_out <= 0;
      r_count_in  <= 0;
    end
    else
      case (r_state)
        S_WAIT:
          if (req)
            r_state <= S_WEIGHT;
        S_WEIGHT:
          if (s_weight_end) begin
            r_state     <= S_BIAS;
            r_count_in  <= 0;
          end
          else
            r_count_in <= r_count_in + 1;
        S_BIAS:
          if (s_bias_end)
            r_state <= S_OUTPUT;
        S_OUTPUT:
          if (s_output_end)
            if (r_count_out + GOBOU_CORE >= r_total_out) begin
              r_state     <= S_WAIT;
              r_count_out <= 0;
            end
            else begin
              r_state     <= S_WEIGHT;
              r_count_out <= r_count_out + GOBOU_CORE;
            end
        default:
          r_state <= S_WAIT;
      endcase

  always @(posedge clk)
    if (!xrst) begin
      r_total_in    <= 0;
      r_total_out   <= 0;
    end
    else if (r_state == S_WAIT && req) begin
      r_total_in    <= total_in;
      r_total_out   <= total_out;
    end

//==========================================================
// image control
//==========================================================

  assign img_we = r_img_we;

  always @(posedge clk)
    if (!xrst)
      r_img_we <= 0;
    else
      case (r_state)
        S_OUTPUT:
          r_img_we <= r_serial_we
                   || (0 < r_serial_cnt && r_serial_cnt < GOBOU_CORE);
        default:
          r_img_we <= 0;
      endcase

  assign img_addr = w_img_addr + w_img_offset;

  assign img_wdata = r_state == S_OUTPUT
                   ? out_wdata
                   : 0;

  assign w_img_addr = r_state == S_OUTPUT
                    ? r_output_addr
                    : r_input_addr;

  assign w_img_offset = r_state == S_OUTPUT
                      ? r_out_offset
                      : r_in_offset;

  always @(posedge clk)
    if (!xrst)
      r_input_addr <= 0;
    else if (r_state == S_BIAS)
      r_input_addr <= 0;
    else if (r_state == S_WEIGHT && !s_weight_end)
      r_input_addr <= r_input_addr + 1;

  always @(posedge clk)
    if (!xrst)
      r_output_addr <= 0;
    else if (ack)
      r_output_addr <= 0;
    else if (r_img_we)
      r_output_addr <= r_output_addr + 1;

  always @(posedge clk)
    if (!xrst) begin
      r_in_offset <= 0;
      r_out_offset <= 0;
    end
    else if (req || ack) begin
      r_in_offset <= in_offset;
      r_out_offset <= out_offset;
    end

//==========================================================
// network control
//==========================================================

  assign s_weight_end = r_state == S_WEIGHT && r_count_in == r_total_in - 1;
  assign s_bias_end   = r_state == S_BIAS;

  // assign mem_net_we   = r_net_we;
  // assign mem_net_addr = r_net_addr + r_net_offset;
  for (genvar i = 0; i < GOBOU_CORE; i++)
    assign mem_net_we[i] = net_we & net_sel == i;
  assign mem_net_addr = net_we
                      ? net_addr
                      : r_net_addr + r_net_offset;
  assign breg_we      = r_breg_we;

  // for (genvar i = 0; i < GOBOU_CORE; i++)
  //   always @(posedge clk)
  //     if (!xrst)
  //       r_net_we[i] <= 0;
  //     else if (net_we == i+1)
  //       r_net_we[i] <= 1;
  //     else
  //       r_net_we[i] <= 0;

  always @(posedge clk)
    if (!xrst)
      r_net_addr <= 0;
    else if (final_iter)
      r_net_addr <= 0;
    else if (r_state == S_WEIGHT)
      r_net_addr <= r_net_addr + 1;
    else if (r_state == S_BIAS)
      r_net_addr <= r_net_addr + 1;

  always @(posedge clk)
    if (!xrst)
      r_net_offset <= 0;
    else if (req || ack)
      r_net_offset <= net_offset;

  always @(posedge clk)
    if (!xrst)
      r_breg_we <= 0;
    else
      r_breg_we <= r_state == S_BIAS;

//==========================================================
// output control
//==========================================================

  assign s_output_end = r_state == S_OUTPUT && r_serial_cnt == GOBOU_CORE;

  assign out_ctrl.start = r_out_ctrl.start;
  assign out_ctrl.valid = r_out_ctrl.valid;
  assign out_ctrl.stop  = r_out_ctrl.stop;

  always @(posedge clk)
    if (!xrst) begin
      r_out_ctrl.start <= 0;
      r_out_ctrl.valid <= 0;
      r_out_ctrl.stop  <= 0;
    end
    else begin
      r_out_ctrl.start <= req
                       || s_output_end && (r_count_out + GOBOU_CORE < r_total_out);
      r_out_ctrl.valid <= r_state == S_BIAS || r_state == S_WEIGHT;
      r_out_ctrl.stop  <= s_bias_end;
    end

  assign ack = r_ack;

  always @(posedge clk)
    if (!xrst)
      r_ack <= 1;
    else if (req)
      r_ack <= 0;
    else if (s_output_end && r_count_out + GOBOU_CORE >= r_total_out)
      r_ack <= 1;

  assign serial_we = r_serial_we;

  always @(posedge clk)
    if (!xrst)
      r_serial_we <= 0;
    else
      r_serial_we <= in_ctrl.start;

  always @(posedge clk)
    if (!xrst)
      r_serial_cnt <= 0;
    else if (serial_we)
      r_serial_cnt <= 1;
    else if (r_serial_cnt > 0)
      if (r_serial_cnt == GOBOU_CORE)
        r_serial_cnt <= 0;
      else
        r_serial_cnt <= r_serial_cnt + 1;

endmodule
